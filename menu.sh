#!/bin/bash
#############################################
## Klipper Backup & Restore Tool
## Supports GitHub · GitLab · Gitea
## github.com/m00seee/Klipper-Backup-Restore-tool
#############################################

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

CONFIG_FILE="$HOME/.klipper_backup.conf"
KLIPPER_CONFIG="$HOME/printer_data/config"
KLIPPER_EXTRAS="$HOME/klipper/klippy/extras"
REPO_RAW="https://raw.githubusercontent.com/m00seee/Klipper-Backup-Restore-tool/main"

# ── Output helpers ──────────────────────────────────────────────────────────────
header() {
  clear
  echo -e "${CYAN}${BOLD}"
  echo "  ╔══════════════════════════════════════════════╗"
  echo "  ║     Klipper Backup & Restore Tool            ║"
  echo "  ║     GitHub · GitLab · Gitea                  ║"
  echo "  ╚══════════════════════════════════════════════╝"
  echo -e "${NC}"
}
ok()   { echo -e "  ${GREEN}✓${NC} $*"; }
err()  { echo -e "  ${RED}✗${NC} $*" >&2; }
info() { echo -e "  ${BLUE}→${NC} $*"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $*"; }
step() { echo -e "\n  ${BOLD}━━ $* ━━${NC}"; }

# ── Spinner ─────────────────────────────────────────────────────────────────────
_spid=""
start_spinner() {
  local msg="$1" i=0 s='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  ( while true; do
      printf "\r  ${CYAN}${s:$i:1}${NC}  $msg"
      i=$(( (i+1) % ${#s} )); sleep 0.1
    done ) &
  _spid=$!
}
stop_spinner() {
  if [[ -n "$_spid" ]]; then
    kill "$_spid" 2>/dev/null; wait "$_spid" 2>/dev/null
    _spid=""; printf "\r\033[K"
  fi
}
trap stop_spinner EXIT INT TERM

# ── Input helpers ───────────────────────────────────────────────────────────────
ask() {
  local _var="$1" _prompt="$2" _default="${3:-}" _val
  while true; do
    [[ -n "$_default" ]] \
      && printf "  ${BOLD}%s${NC} [%s]: " "$_prompt" "$_default" \
      || printf "  ${BOLD}%s${NC}: " "$_prompt"
    read -r _val; _val="${_val:-$_default}"
    if [[ -n "$_val" ]]; then printf -v "$_var" '%s' "$_val"; return; fi
    err "This field cannot be empty."
  done
}

ask_secret() {
  local _var="$1" _prompt="$2" _val
  while true; do
    printf "  ${BOLD}%s${NC}: " "$_prompt"; read -rs _val; echo
    if [[ -n "$_val" ]]; then printf -v "$_var" '%s' "$_val"; return; fi
    err "This field cannot be empty."
  done
}

confirm() {
  local _prompt="$1" _default="${2:-n}" _in
  [[ "$_default" == "y" ]] \
    && printf "  ${BOLD}%s${NC} [Y/n]: " "$_prompt" \
    || printf "  ${BOLD}%s${NC} [y/N]: " "$_prompt"
  read -r _in; _in="${_in:-$_default}"
  [[ "$_in" =~ ^[Yy]$ ]]
}

# ── Config ──────────────────────────────────────────────────────────────────────
load_config() {
  [[ -f "$CONFIG_FILE" ]] || return 1
  # shellcheck source=/dev/null
  source "$CONFIG_FILE"
}

save_config() {
  cat > "$CONFIG_FILE" <<EOF
GIT_PROVIDER="${GIT_PROVIDER}"
GIT_USERNAME="${GIT_USERNAME}"
GIT_EMAIL="${GIT_EMAIL}"
GIT_TOKEN="${GIT_TOKEN}"
GIT_REPO="${GIT_REPO}"
GIT_BRANCH="${GIT_BRANCH}"
GITEA_HOST="${GITEA_HOST:-}"
EOF
  chmod 600 "$CONFIG_FILE"
  ok "Config saved to $CONFIG_FILE (mode 600)"
}

build_remote_url() {
  case "$GIT_PROVIDER" in
    github) echo "https://${GIT_USERNAME}:${GIT_TOKEN}@github.com/${GIT_REPO}.git" ;;
    gitlab) echo "https://oauth2:${GIT_TOKEN}@gitlab.com/${GIT_REPO}.git" ;;
    gitea)  echo "https://${GIT_USERNAME}:${GIT_TOKEN}@${GITEA_HOST}/${GIT_REPO}.git" ;;
  esac
}

build_public_url() {
  case "$GIT_PROVIDER" in
    github) echo "https://github.com/${GIT_REPO}.git" ;;
    gitlab) echo "https://gitlab.com/${GIT_REPO}.git" ;;
    gitea)  echo "https://${GITEA_HOST}/${GIT_REPO}.git" ;;
  esac
}

# ── Dependency check ────────────────────────────────────────────────────────────
check_deps() {
  step "Checking dependencies"
  local fail=0
  for dep in git wget; do
    command -v "$dep" &>/dev/null \
      && ok "$dep found" \
      || { err "$dep not found — fix with: sudo apt install $dep -y"; fail=1; }
  done
  if [[ ! -d "$KLIPPER_CONFIG" ]]; then
    err "Klipper config directory not found: $KLIPPER_CONFIG"
    warn "Ensure Klipper is installed before running this tool."
    fail=1
  else
    ok "Klipper config directory found"
  fi
  [[ $fail -eq 1 ]] && { echo; err "Resolve the issues above, then re-run."; exit 1; }
}

# ── Install gcode_shell_command.py ──────────────────────────────────────────────
install_shell_command() {
  local dest="$KLIPPER_EXTRAS/gcode_shell_command.py"
  if [[ -f "$dest" ]]; then
    ok "gcode_shell_command.py already installed"
    return
  fi
  mkdir -p "$KLIPPER_EXTRAS"
  if wget -q -O "$dest" "$REPO_RAW/gcode_shell_command.py"; then
    ok "gcode_shell_command.py installed to $KLIPPER_EXTRAS"
  else
    err "Failed to download gcode_shell_command.py"
    exit 1
  fi
}

# ── Write shell scripts ─────────────────────────────────────────────────────────
install_scripts() {
  cat > "$HOME/backup_command.sh" <<'SCRIPT'
#!/bin/bash
# shellcheck source=/dev/null
source "$HOME/.klipper_backup.conf"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
die() { log "ERROR: $1"; exit 1; }

if [[ "$GIT_PROVIDER" == "gitlab" ]]; then
  REMOTE_URL="https://oauth2:${GIT_TOKEN}@gitlab.com/${GIT_REPO}.git"
elif [[ "$GIT_PROVIDER" == "gitea" ]]; then
  REMOTE_URL="https://${GIT_USERNAME}:${GIT_TOKEN}@${GITEA_HOST}/${GIT_REPO}.git"
else
  REMOTE_URL="https://${GIT_USERNAME}:${GIT_TOKEN}@github.com/${GIT_REPO}.git"
fi

cd "$HOME/printer_data/config" || die "Cannot access Klipper config directory"

git remote set-url origin "$REMOTE_URL" 2>/dev/null \
  || git remote add origin "$REMOTE_URL"

log "Pulling latest changes..."
git pull --rebase origin "$GIT_BRANCH" 2>&1 \
  || log "WARNING: Pull failed — will still attempt to push local changes"

log "Staging all changes..."
git add -A

if git diff --cached --quiet; then
  log "Nothing to commit — config is already up to date."
  exit 0
fi

git commit -m "Backup: $(date '+%Y-%m-%d %H:%M:%S')" \
  || die "Commit failed"

log "Pushing to ${GIT_PROVIDER}..."
git push origin "$GIT_BRANCH" \
  || die "Push failed — check token permissions and repository path"

log "Backup complete."
SCRIPT
  chmod +x "$HOME/backup_command.sh"
  ok "backup_command.sh written"

  cat > "$HOME/restore_command.sh" <<'SCRIPT'
#!/bin/bash
# shellcheck source=/dev/null
source "$HOME/.klipper_backup.conf"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
die() { log "ERROR: $1"; exit 1; }

if [[ "$GIT_PROVIDER" == "gitlab" ]]; then
  REMOTE_URL="https://oauth2:${GIT_TOKEN}@gitlab.com/${GIT_REPO}.git"
elif [[ "$GIT_PROVIDER" == "gitea" ]]; then
  REMOTE_URL="https://${GIT_USERNAME}:${GIT_TOKEN}@${GITEA_HOST}/${GIT_REPO}.git"
else
  REMOTE_URL="https://${GIT_USERNAME}:${GIT_TOKEN}@github.com/${GIT_REPO}.git"
fi

cd "$HOME/printer_data/config" || die "Cannot access Klipper config directory"

git remote set-url origin "$REMOTE_URL" 2>/dev/null \
  || git remote add origin "$REMOTE_URL"

log "Fetching from ${GIT_PROVIDER}..."
git fetch origin \
  || die "Fetch failed — check your network connection and token"

log "Restoring to origin/${GIT_BRANCH}..."
git reset --hard "origin/${GIT_BRANCH}" \
  || die "Reset failed"

log "Restore complete. A Klipper/Moonraker restart may be required."
SCRIPT
  chmod +x "$HOME/restore_command.sh"
  ok "restore_command.sh written"
}

# ── Write Klipper config files ──────────────────────────────────────────────────
install_configs() {
  local printer_cfg="$KLIPPER_CONFIG/printer.cfg"
  local provider_upper; provider_upper=$(echo "$GIT_PROVIDER" | tr '[:lower:]' '[:upper:]')

  cat > "$KLIPPER_CONFIG/backup.cfg" <<EOF
[gcode_shell_command backup_to_git]
command: bash /home/${USER}/backup_command.sh
timeout: 300.
verbose: True

[gcode_macro BACKUP_TO_${provider_upper}]
gcode:
    RUN_SHELL_COMMAND CMD=backup_to_git
EOF
  ok "backup.cfg written (macro: BACKUP_TO_${provider_upper})"
  if [[ -f "$printer_cfg" ]]; then
    grep -q "include backup.cfg" "$printer_cfg" \
      || { sed -i '1 i\[include backup.cfg]\n' "$printer_cfg"; ok "backup.cfg included in printer.cfg"; }
  else
    warn "printer.cfg not found — add [include backup.cfg] manually"
  fi

  cat > "$KLIPPER_CONFIG/restore.cfg" <<EOF
[gcode_shell_command restore_from_git]
command: bash /home/${USER}/restore_command.sh
timeout: 300.
verbose: True

[gcode_macro RESTORE_FROM_${provider_upper}]
gcode:
    RUN_SHELL_COMMAND CMD=restore_from_git
EOF
  ok "restore.cfg written (macro: RESTORE_FROM_${provider_upper})"
  if [[ -f "$printer_cfg" ]]; then
    grep -q "include restore.cfg" "$printer_cfg" \
      || { sed -i '1 i\[include restore.cfg]\n' "$printer_cfg"; ok "restore.cfg included in printer.cfg"; }
  else
    warn "printer.cfg not found — add [include restore.cfg] manually"
  fi
}

# ── Git initialisation ──────────────────────────────────────────────────────────
init_git() {
  cd "$KLIPPER_CONFIG" || { err "Cannot access $KLIPPER_CONFIG"; exit 1; }
  local remote_url; remote_url=$(build_remote_url)

  git config --global user.name  "$GIT_USERNAME"
  git config --global user.email "$GIT_EMAIL"

  if [[ -d ".git" ]]; then
    git remote set-url origin "$remote_url"
    ok "Git remote URL updated"
  else
    git init
    git symbolic-ref HEAD "refs/heads/${GIT_BRANCH}"
    git remote add origin "$remote_url"
    ok "Git initialised (branch: ${GIT_BRANCH})"
  fi
}

# ── Provider & credential setup ─────────────────────────────────────────────────
select_provider() {
  step "Git Provider"
  echo
  echo "  1) GitHub"
  echo "  2) GitLab"
  echo "  3) Gitea  (self-hosted)"
  echo
  while true; do
    printf "  ${BOLD}Choose${NC} [1-3]: "
    read -r _c
    case "$_c" in
      1) GIT_PROVIDER="github"; break ;;
      2) GIT_PROVIDER="gitlab"; break ;;
      3) GIT_PROVIDER="gitea";  break ;;
      *) err "Please enter 1, 2, or 3." ;;
    esac
  done
  ok "Provider: ${GIT_PROVIDER}"
}

enter_credentials() {
  step "Credentials"
  echo
  if [[ "$GIT_PROVIDER" == "gitea" ]]; then
    ask GITEA_HOST "Gitea hostname (e.g. git.example.com)"
  else
    GITEA_HOST=""
  fi
  ask        GIT_USERNAME "Username"
  ask        GIT_EMAIL    "Email address"
  ask_secret GIT_TOKEN    "Personal access token"
  echo
  case "$GIT_PROVIDER" in
    github|gitea) info "Repository format:  username/repo-name" ;;
    gitlab)       info "Repository format:  username/repo  or  group/subgroup/repo" ;;
  esac
  ask GIT_REPO   "Repository path"
  ask GIT_BRANCH "Default branch name" "main"
}

test_connection() {
  step "Testing connection"
  local url; url=$(build_remote_url)
  start_spinner "Connecting to ${GIT_PROVIDER}..."
  local git_output
  git_output=$(git ls-remote "$url" 2>&1)
  local exit_code=$?
  stop_spinner

  if [[ $exit_code -eq 0 ]]; then
    ok "Successfully connected to ${GIT_PROVIDER}"
    return
  fi

  err "Connection failed"
  echo

  # Give specific guidance based on the error output
  if echo "$git_output" | grep -qi "could not resolve host"; then
    warn "Cannot reach the server — check your network connection."
    [[ "$GIT_PROVIDER" == "gitea" ]] && warn "Also verify the Gitea hostname is correct: ${GITEA_HOST}"

  elif echo "$git_output" | grep -qi "authentication failed\|could not read username\|invalid username or password\|bad credentials"; then
    warn "Authentication failed — your token was rejected."
    echo
    case "$GIT_PROVIDER" in
      github)
        info "For a classic token:       Settings → Developer settings → Tokens (classic)"
        info "                           Tick the 'repo' scope"
        info "For a fine-grained token:  Settings → Developer settings → Fine-grained tokens"
        info "                           Set Contents to Read and Write on your repo"
        ;;
      gitlab)
        info "Token needs:  read_repository  and  write_repository  scopes"
        ;;
      gitea)
        info "Regenerate your token in Gitea under Settings → Applications"
        ;;
    esac

  elif echo "$git_output" | grep -qi "repository not found\|not found\|404"; then
    warn "Repository not found — check the path is correct."
    info "Expected format:  username/repo-name  (no https://, no .git)"
    info "Your current value:  ${GIT_REPO}"
    [[ "$GIT_PROVIDER" == "github" ]] && info "Also ensure the repository exists on GitHub before running setup."

  elif echo "$git_output" | grep -qi "permission\|403\|forbidden"; then
    warn "Permission denied — your token doesn't have write access to this repo."
    case "$GIT_PROVIDER" in
      github)
        info "Classic token:       ensure the 'repo' scope is ticked"
        info "Fine-grained token:  set Contents to Read and Write (not Read-only)"
        ;;
      gitlab)
        info "Token needs write_repository scope, not just read_repository"
        ;;
    esac

  else
    warn "Unexpected error — full output below:"
    echo "$git_output" | sed 's/^/    /'
  fi

  echo
  if confirm "Re-enter credentials and retry?"; then
    enter_credentials
    test_connection
  else
    exit 1
  fi
}

# ── Quick Restore ───────────────────────────────────────────────────────────────
quick_restore() {
  step "Quick Restore"
  echo
  info "Downloads your config files directly from your repository."
  info "No git setup, no macros — just your files restored fast."
  echo
  warn "This will overwrite files in ${KLIPPER_CONFIG}"
  echo

  # If saved config exists, offer to reuse it
  if load_config 2>/dev/null && [[ -n "${GIT_REPO:-}" ]]; then
    info "Saved config found: ${GIT_PROVIDER} — ${GIT_REPO} (${GIT_BRANCH})"
    if confirm "Use these saved settings?" "y"; then
      _do_quick_restore
      return
    fi
  fi

  # Otherwise collect the minimum needed
  select_provider
  echo
  if [[ "$GIT_PROVIDER" == "gitea" ]]; then
    ask GITEA_HOST "Gitea hostname (e.g. git.example.com)"
  else
    GITEA_HOST=""
  fi
  case "$GIT_PROVIDER" in
    github|gitea) info "Repository format:  username/repo-name" ;;
    gitlab)       info "Repository format:  username/repo  or  group/subgroup/repo" ;;
  esac
  ask GIT_REPO   "Repository path"
  ask GIT_BRANCH "Branch" "main"
  GIT_USERNAME="" GIT_TOKEN=""

  _do_quick_restore
}

_do_quick_restore() {
  local url; url=$(build_public_url)
  local tmp_dir; tmp_dir=$(mktemp -d)

  start_spinner "Cloning from ${GIT_PROVIDER}..."
  local clone_output
  clone_output=$(git clone --depth 1 --branch "$GIT_BRANCH" "$url" "$tmp_dir" 2>&1)
  local exit_code=$?
  stop_spinner

  # If auth failure, ask for a token and retry once
  if [[ $exit_code -ne 0 ]] && echo "$clone_output" | grep -qi "authentication\|could not read username\|bad credentials\|403\|forbidden"; then
    rm -rf "$tmp_dir"; tmp_dir=$(mktemp -d)
    warn "Repository appears to be private — a token is required."
    echo
    ask        GIT_USERNAME "Username"
    ask_secret GIT_TOKEN    "Personal access token"
    url=$(build_remote_url)
    start_spinner "Retrying with token..."
    clone_output=$(git clone --depth 1 --branch "$GIT_BRANCH" "$url" "$tmp_dir" 2>&1)
    exit_code=$?
    stop_spinner
  fi

  if [[ $exit_code -ne 0 ]]; then
    err "Clone failed"
    echo "$clone_output" | sed 's/^/    /'
    rm -rf "$tmp_dir"
    echo
    if confirm "Retry with different details?"; then
      select_provider
      echo
      [[ "$GIT_PROVIDER" == "gitea" ]] && ask GITEA_HOST "Gitea hostname"
      ask GIT_REPO   "Repository path"
      ask GIT_BRANCH "Branch" "main"
      GIT_USERNAME="" GIT_TOKEN=""
      _do_quick_restore
    fi
    return
  fi

  info "Copying files to ${KLIPPER_CONFIG}..."
  # Copy everything except the .git directory
  rsync -a --exclude='.git' "$tmp_dir/" "$KLIPPER_CONFIG/" 2>/dev/null \
    || cp -r "$tmp_dir"/. "$KLIPPER_CONFIG/" && rm -rf "$KLIPPER_CONFIG/.git"
  rm -rf "$tmp_dir"

  echo
  ok "Quick restore complete!"
  warn "Restart Klipper/Moonraker to apply the restored configuration."
  echo
  info "To set up automatic backups, run ${BOLD}./menu.sh${NC}${BLUE} again and choose Full Setup."
}

# ── Backup / Restore actions ────────────────────────────────────────────────────
run_backup() {
  step "Backup"
  echo
  if bash "$HOME/backup_command.sh"; then
    echo; ok "Backup complete"
  else
    echo; err "Backup failed — see output above"
  fi
}

run_restore() {
  step "Restore"
  echo
  warn "This will overwrite your Klipper config with the version stored on ${GIT_PROVIDER}."
  echo
  if ! confirm "Continue with restore?"; then
    info "Restore cancelled."
    return
  fi
  echo
  if bash "$HOME/restore_command.sh"; then
    echo; ok "Restore complete"
    warn "Restart Klipper/Moonraker to apply the restored configuration."
  else
    echo; err "Restore failed — see output above"
  fi
}

# ── First-time setup wizard ─────────────────────────────────────────────────────
run_setup() {
  header
  step "Welcome"
  echo
  echo "  1) Full Setup    — configure backups and install Klipper macros"
  echo "  2) Quick Restore — just pull my config files from a repo, nothing else"
  echo
  while true; do
    printf "  ${BOLD}Choose${NC} [1-2]: "
    read -r _c
    case "$_c" in
      1) break ;;
      2) quick_restore; exit 0 ;;
      *) err "Please enter 1 or 2." ;;
    esac
  done

  header
  step "Full Setup"
  echo
  info "This wizard will:"
  echo "       1. Configure your Git provider and credentials"
  echo "       2. Set up backup and restore scripts"
  echo "       3. Install Klipper macros (BACKUP / RESTORE)"
  echo

  select_provider
  enter_credentials
  test_connection

  step "Saving configuration"
  save_config

  step "Initialising Git"
  init_git

  step "Installing components"
  install_shell_command
  install_scripts
  install_configs

  step "Initial backup"
  if confirm "Push an initial backup to ${GIT_PROVIDER} now?" "y"; then
    echo
    cd "$KLIPPER_CONFIG"
    # Pull first in case the remote was initialised with a README or other commit
    git pull --rebase --allow-unrelated-histories origin "$GIT_BRANCH" 2>/dev/null || true
    git add -A
    if ! git diff --cached --quiet; then
      git commit -m "Initial backup ($(date '+%Y-%m-%d %H:%M:%S'))"
    fi
    if git push -u origin "$GIT_BRANCH" 2>/dev/null; then
      ok "Initial backup pushed"
    elif git push --set-upstream origin "HEAD:refs/heads/${GIT_BRANCH}"; then
      ok "Initial backup pushed (branch '${GIT_BRANCH}' created)"
    else
      err "Initial push failed — run a manual Backup from the main menu."
    fi
  fi

  echo
  ok "Setup complete!"
  warn "A reboot is recommended so Klipper loads the new macros."
  echo
  if confirm "Reboot now?" "n"; then
    sudo reboot
  fi
}

# ── Main menu ───────────────────────────────────────────────────────────────────
main_menu() {
  while true; do
    header
    load_config
    echo -e "  ${CYAN}Provider:${NC} ${GIT_PROVIDER}   ${CYAN}Repo:${NC} ${GIT_REPO}   ${CYAN}Branch:${NC} ${GIT_BRANCH}\n"
    echo "  1) Backup now"
    echo "  2) Restore from ${GIT_PROVIDER}"
    echo "  3) Quick Restore (clone only, no setup)"
    echo "  4) Reconfigure"
    echo "  5) Exit"
    echo
    printf "  ${BOLD}Choose${NC} [1-5]: "
    read -r _choice

    case "$_choice" in
      1) run_backup ;;
      2) run_restore ;;
      3) quick_restore ;;
      4)
        select_provider
        enter_credentials
        test_connection
        save_config
        init_git
        install_scripts
        install_configs
        ;;
      5) echo; exit 0 ;;
      *) err "Invalid option — enter 1 to 5." ;;
    esac

    echo
    printf "  Press Enter to return to menu..."
    read -r
  done
}

# ── Entry point ─────────────────────────────────────────────────────────────────
check_deps

if load_config; then
  main_menu
else
  run_setup
  main_menu
fi
