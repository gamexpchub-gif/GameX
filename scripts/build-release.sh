#!/usr/bin/env bash
# Builds signed release builds of the GAMEX apps. Run from the GameX folder:
#   bash scripts/build-release.sh            # customer app (APK + Play Store AAB)
#   bash scripts/build-release.sh seller     # seller app
#
# Firebase push for the customer app: put the 4 values in
# secrets/firebase.json (git-ignored), see docs/LAUNCH_SETUP.md:
#   {"FIREBASE_API_KEY":"...","FIREBASE_APP_ID":"...","FIREBASE_SENDER_ID":"...","FIREBASE_PROJECT_ID":"..."}
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-customer}"
DIR="$ROOT"
[ "$APP" = "seller" ] && DIR="$ROOT/merchant"
cd "$DIR"

DEFINES=()
if [ "$APP" = "customer" ] && [ -f "$ROOT/secrets/firebase.json" ]; then
  DEFINES+=(--dart-define-from-file="$ROOT/secrets/firebase.json")
  echo "Firebase push: ON (secrets/firebase.json)"
elif [ "$APP" = "customer" ]; then
  echo "Firebase push: off (no secrets/firebase.json) - in-app notifications only"
fi

if [ -f android/key.properties ]; then
  echo "Signing: release key (android/key.properties)"
else
  echo "Signing: DEBUG key - run 'bash scripts/android-keystore.sh' before publishing"
fi

flutter pub get
flutter build apk --release "${DEFINES[@]}"
flutter build appbundle --release "${DEFINES[@]}"

echo
echo "Done:"
echo "  APK (install on phones):   $DIR/build/app/outputs/flutter-apk/app-release.apk"
echo "  AAB (upload to Play Store): $DIR/build/app/outputs/bundle/release/app-release.aab"
echo "Install on a connected phone:  cd \"$DIR\" && flutter install --release"
