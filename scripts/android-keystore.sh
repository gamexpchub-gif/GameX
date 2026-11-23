#!/usr/bin/env bash
# Creates the Android upload (release) key for the GAMEX apps and wires it
# into both Flutter projects. Run once, on YOUR computer, from the GameX folder:
#   bash scripts/android-keystore.sh
#
# The keystore is stored OUTSIDE the repo in ~/gamex-keys/ and the passwords
# only in android/key.properties + merchant/android/key.properties (both
# git-ignored). BACK UP ~/gamex-keys/ - if you lose it you cannot update
# the apps on Play Store with the same key.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="${GAMEX_KEY_DIR:-$HOME/gamex-keys}"
STORE="$DIR/gamex-upload.jks"
ALIAS="gamex-upload"

command -v keytool >/dev/null || { echo "keytool not found. Install a JDK (sudo apt install -y openjdk-17-jdk-headless) or use Android Studio's JDK."; exit 1; }

mkdir -p "$DIR"
chmod 700 "$DIR"

if [ -f "$STORE" ]; then
  echo "Keystore already exists: $STORE (reusing it)"
  read -rsp "Keystore password: " PASS; echo
else
  echo "Creating a new upload key for GAMEX."
  while true; do
    read -rsp "Choose a keystore password (min 8 characters): " PASS; echo
    read -rsp "Repeat the password: " PASS2; echo
    [ "${#PASS}" -ge 8 ] && [ "$PASS" = "$PASS2" ] && break
    echo "Passwords don't match or are too short. Try again."
  done
  read -rp "Name of the business owner (for the certificate): " CN
  read -rp "City: " CITY
  keytool -genkeypair -v -keystore "$STORE" -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 \
    -alias "$ALIAS" -storepass "$PASS" -keypass "$PASS" \
    -dname "CN=${CN:-GAMEX}, O=GAMEX, L=${CITY:-Mumbai}, C=IN" >/dev/null
  chmod 600 "$STORE"
  echo "Created $STORE"
fi

for app in "$ROOT/android" "$ROOT/merchant/android"; do
  [ -d "$app" ] || continue
  umask 077
  cat > "$app/key.properties" <<PROPS
storeFile=$STORE
storePassword=$PASS
keyAlias=$ALIAS
keyPassword=$PASS
PROPS
  echo "Wrote ${app#$ROOT/}/key.properties"
done

SHA=$(keytool -list -v -keystore "$STORE" -alias "$ALIAS" -storepass "$PASS" | awk -F': ' '/SHA256:/{print $2; exit}')
echo
echo "Upload key SHA-256 (for ANDROID_SHA256 / Firebase):"
echo "  $SHA"
echo
echo "Next:"
echo "  1. Back up the folder $DIR somewhere safe (Google Drive / pendrive)."
echo "  2. Build:   bash scripts/build-release.sh"
echo "  3. After the first Play Store upload, also copy the 'App signing key'"
echo "     SHA-256 from Play Console -> Test and release -> App integrity."
echo "     Put both in ANDROID_SHA256 (comma separated) with deploy/set-secrets.sh."
echo
echo "Note: apps signed with this key replace debug-signed installs only after"
echo "uninstalling the old app once (adb uninstall com.gamex.gamex_shop)."
