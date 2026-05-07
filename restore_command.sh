#!/bin/bash
# Klipper restore — pull config from remote Git repository.
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

log "Fetching from ${GIT_PROVIDER}..."
git fetch origin \
  || die "Fetch failed — check your network connection and token"

log "Restoring to origin/${GIT_BRANCH}..."
git reset --hard "origin/${GIT_BRANCH}" \
  || die "Reset failed"

log "Restore complete. A Klipper/Moonraker restart may be required."
