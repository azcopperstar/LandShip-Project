#!/bin/zsh
set -e

REPO_DIR="/Users/JP/Library/CloudStorage/Dropbox/xCode/LandShip"
cd "$REPO_DIR"

export PATH="/usr/bin:/usr/local/bin:$PATH"
export HOME="/Users/JP"

git add -A -- . ':!*conflicted copy*'

if ! git diff --cached --quiet; then
    git commit -m "Automatic daily backup - $(date '+%Y-%m-%d %H:%M')"
    git push origin main
fi
