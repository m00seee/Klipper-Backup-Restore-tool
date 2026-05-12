#!/bin/bash
# Klipper backup — push config to remote Git repository.
# Credentials and settings are read from ~/.klipper_backup.conf
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

log "Staging local changes..."
git update-index --refresh -q 2>/dev/null || true
git add -A

if [[ -n "$(git status --porcelain)" ]]; then
  git commit -m "Backup: $(date '+%Y-%m-%d %H:%M:%S')" \
    || die "Commit failed"
else
  log "No new changes to commit."
fi

log "Pushing to ${GIT_PROVIDER}..."
git push origin "$GIT_BRANCH" \
  || git push --force origin "$GIT_BRANCH" \
  || die "Push failed — check token permissions and repository path"

log "Backup complete."
