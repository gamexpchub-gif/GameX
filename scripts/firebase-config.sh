#!/usr/bin/env bash
# Reads the google-services.json you downloaded from Firebase and writes
# secrets/firebase.json (git-ignored) for scripts/build-release.sh.
#   bash scripts/firebase-config.sh ~/Downloads/google-services.json
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:?Usage: bash scripts/firebase-config.sh path/to/google-services.json}"
mkdir -p "$ROOT/secrets"
python3 - "$SRC" "$ROOT/secrets/firebase.json" <<'PY'
import json, sys
src, out = sys.argv[1], sys.argv[2]
j = json.load(open(src))
pkg = 'com.gamex.gamex_shop'
client = next((c for c in j['client'] if c['client_info']['android_client_info']['package_name'] == pkg), None)
if client is None:
    sys.exit(f'No Android app with package {pkg} in this file. Add it in Firebase → Project settings → Your apps.')
cfg = {
    'FIREBASE_API_KEY': client['api_key'][0]['current_key'],
    'FIREBASE_APP_ID': client['client_info']['mobilesdk_app_id'],
    'FIREBASE_SENDER_ID': j['project_info']['project_number'],
    'FIREBASE_PROJECT_ID': j['project_info']['project_id'],
}
json.dump(cfg, open(out, 'w'), indent=2)
print(f'Wrote {out} for project {cfg["FIREBASE_PROJECT_ID"]}')
PY
chmod 600 "$ROOT/secrets/firebase.json"
echo "Now build with: bash scripts/build-release.sh"
