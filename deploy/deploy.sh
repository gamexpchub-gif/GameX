#!/usr/bin/env bash
# Run on YOUR computer from the GameX folder:
#   bash deploy/deploy.sh                      # deploys to root@200.234.32.137
#   bash deploy/deploy.sh root@other.ip        # another VPS
# Optional: CERT_EMAIL=you@example.com bash deploy/deploy.sh
# You'll be asked for the VPS password once.
set -euo pipefail

TARGET="${1:-root@200.234.32.137}"
DOMAIN="${DOMAIN:-admin.deencircle.online}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOCK="${TMPDIR:-/tmp}/gamex-ssh-$$"
SSH=(ssh -o ControlMaster=auto -o "ControlPath=$SOCK" -o ControlPersist=300 -o StrictHostKeyChecking=accept-new)

say() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
cleanup() { "${SSH[@]}" -O exit "$TARGET" >/dev/null 2>&1 || true; }
trap cleanup EXIT

for tool in npm rsync ssh; do
  command -v "$tool" >/dev/null || { echo "Please install $tool first (sudo apt install -y $tool)"; exit 1; }
done

say "Building the admin panel (served at /hisab/)"
(cd "$ROOT/admin" && npm ci --no-audit --no-fund --loglevel=error && ADMIN_BASE=/hisab/ npm run build)

say "Connecting to $TARGET"
"${SSH[@]}" "$TARGET" 'mkdir -p /opt/gamex/server /opt/gamex/admin/dist && (command -v rsync >/dev/null || (apt-get update -qq && apt-get install -y -qq rsync >/dev/null))'

say "Uploading files"
RSYNC_SSH="${SSH[*]}"
rsync -az --delete -e "$RSYNC_SSH" \
  --exclude node_modules --exclude 'data/*.json' --exclude 'uploads/*' \
  "$ROOT/server/" "$TARGET:/opt/gamex/server/"
rsync -az --delete -e "$RSYNC_SSH" "$ROOT/admin/dist/" "$TARGET:/opt/gamex/admin/dist/"
rsync -az -e "$RSYNC_SSH" "$ROOT/deploy/remote-setup.sh" "$TARGET:/opt/gamex/remote-setup.sh"

say "Setting up the VPS"
"${SSH[@]}" -t "$TARGET" "DOMAIN='$DOMAIN' CERT_EMAIL='${CERT_EMAIL:-}' bash /opt/gamex/remote-setup.sh"
