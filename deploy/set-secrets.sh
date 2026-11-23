#!/usr/bin/env bash
# Adds live-service keys to the GAMEX server (/etc/gamex.env) and restarts it.
# Run on YOUR computer from the GameX folder:
#   bash deploy/set-secrets.sh                 # root@200.234.32.137
#   bash deploy/set-secrets.sh root@other.ip
# Secrets are typed here (hidden) and sent over SSH stdin - never put them in
# chat, git or command-line arguments.
set -euo pipefail

TARGET="${1:-root@200.234.32.137}"
DOMAIN="${DOMAIN:-admin.deencircle.online}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOCK="${TMPDIR:-/tmp}/gamex-ssh-$$"
SSH=(ssh -o ControlMaster=auto -o "ControlPath=$SOCK" -o ControlPersist=300 -o StrictHostKeyChecking=accept-new)
cleanup() { "${SSH[@]}" -O exit "$TARGET" >/dev/null 2>&1 || true; }
trap cleanup EXIT

declare -a SET=()     # KEY=VALUE lines to write
declare -a UNSET=()   # keys to remove
FCM_FILE=""

ask() { local v; read -rp "  $1: " v; printf '%s' "$v"; }
secret() { local v; read -rsp "  $1 (hidden): " v; echo >&2; printf '%s' "$v"; }
need() { [ -n "$2" ] || { echo "  ✗ $1 is required - skipped"; return 1; }; }

menu() {
  cat <<'M'

  GAMEX live services
  ───────────────────
  1) SMS OTP login - MSG91          5) Courier - Shiprocket
  2) SMS OTP login - Twilio         6) Share links - Android SHA-256
  3) Payments - Razorpay            7) OTP test mode (on/off)
  4) Push - Firebase service account
  s) Show current status            a) APPLY changes & restart
  q) Quit without changes
M
}

status() {
  echo
  curl -fsS "https://$DOMAIN/gamex/api/config" 2>/dev/null | sed 's/,/,\n  /g; s/{/{\n  /' || echo "  Could not reach https://$DOMAIN/gamex/api/config"
  echo
}

while true; do
  menu
  read -rp "Choose: " c
  case "$c" in
    1)
      echo "  MSG91 → Settings → API keys; OTP template must be DLT-approved and contain ##OTP##"
      k=$(secret "MSG91 auth key"); t=$(ask "MSG91 OTP template ID")
      need "auth key" "$k" && need "template ID" "$t" && SET+=("MSG91_AUTH_KEY=$k" "MSG91_TEMPLATE_ID=$t") && UNSET+=(OTP_DEV_MODE) && echo "  ✓ MSG91 queued" ;;
    2)
      s=$(ask "Twilio Account SID"); k=$(secret "Twilio Auth Token"); f=$(ask "Twilio sender number (+1...)")
      need SID "$s" && need token "$k" && need number "$f" && SET+=("TWILIO_SID=$s" "TWILIO_TOKEN=$k" "TWILIO_FROM=$f") && UNSET+=(OTP_DEV_MODE) && echo "  ✓ Twilio queued" ;;
    3)
      echo "  Razorpay Dashboard → Account & Settings → API Keys (use rzp_test_ first, then rzp_live_)"
      i=$(ask "Key ID (rzp_...)"); k=$(secret "Key Secret")
      [[ "$i" == rzp_* ]] || { echo "  ✗ Key ID must start with rzp_"; continue; }
      echo "  Webhook (for automatic refund status): Razorpay → Webhooks → Add"
      echo "    URL: https://admin.deencircle.online/gamex/api/payments/razorpay/webhook"
      echo "    Events: refund.processed, refund.failed, payment.captured — choose any secret"
      w=$(secret "Webhook secret (Enter to skip)")
      need secret "$k" && SET+=("RAZORPAY_KEY_ID=$i" "RAZORPAY_KEY_SECRET=$k") && { [ -n "$w" ] && SET+=("RAZORPAY_WEBHOOK_SECRET=$w"); true; } && echo "  ✓ Razorpay queued" ;;
    4)
      echo "  Firebase console → Project settings → Service accounts → Generate new private key"
      p=$(ask "Path to the downloaded JSON file")
      p="${p/#\~/$HOME}"
      if [ -f "$p" ] && grep -q '"private_key"' "$p"; then FCM_FILE="$p"; SET+=("FCM_SERVICE_ACCOUNT=/etc/gamex-fcm.json"); echo "  ✓ Firebase queued"; else echo "  ✗ Not a service-account JSON: $p"; fi ;;
    5)
      echo "  Shiprocket → Settings → API → Create an API user (use a separate email)"
      e=$(ask "API user email"); k=$(secret "API user password"); pl=$(ask "Pickup location name [Primary]")
      need email "$e" && need password "$k" && SET+=("SHIPROCKET_EMAIL=$e" "SHIPROCKET_PASSWORD=$k" "SHIPROCKET_PICKUP=${pl:-Primary}") && echo "  ✓ Shiprocket queued" ;;
    6)
      d=""
      if [ -f "$ROOT/android/key.properties" ] && command -v keytool >/dev/null; then
        store=$(grep '^storeFile=' "$ROOT/android/key.properties" | cut -d= -f2-)
        pass=$(grep '^storePassword=' "$ROOT/android/key.properties" | cut -d= -f2-)
        alias=$(grep '^keyAlias=' "$ROOT/android/key.properties" | cut -d= -f2-)
        d=$(keytool -list -v -keystore "$store" -alias "$alias" -storepass "$pass" 2>/dev/null | awk -F': ' '/SHA256:/{print $2; exit}')
        [ -n "$d" ] && echo "  Upload key SHA-256: $d"
      fi
      x=$(ask "Play Console 'App signing key' SHA-256 (Enter to skip)")
      v=$(printf '%s' "$d,$x" | sed 's/^,//; s/,$//')
      need SHA-256 "$v" && SET+=("ANDROID_SHA256=$v") && echo "  ✓ App Links queued" ;;
    7)
      read -rp "  Turn OTP test mode ON (codes shown in the app - testing only)? [y/N] " y
      if [[ "$y" =~ ^[Yy]$ ]]; then SET+=("OTP_DEV_MODE=1"); else UNSET+=(OTP_DEV_MODE); fi
      echo "  ✓ queued" ;;
    s) status ;;
    q) echo "No changes made."; exit 0 ;;
    a) break ;;
    *) ;;
  esac
done

if [ ${#SET[@]} -eq 0 ] && [ ${#UNSET[@]} -eq 0 ]; then echo "Nothing to apply."; exit 0; fi

echo
echo "Connecting to $TARGET ..."
if [ -n "$FCM_FILE" ]; then
  "${SSH[@]}" "$TARGET" 'umask 077; cat > /etc/gamex-fcm.json && chgrp gamex /etc/gamex-fcm.json 2>/dev/null; chmod 640 /etc/gamex-fcm.json' < "$FCM_FILE"
  echo "  ✓ Firebase service account uploaded"
fi

{
  for k in "${UNSET[@]}"; do printf 'UNSET %s\n' "$k"; done
  for l in "${SET[@]}"; do printf 'SET %s\n' "$l"; done
} | "${SSH[@]}" "$TARGET" '
  set -e
  F=/etc/gamex.env
  touch "$F"; chmod 600 "$F"
  cp "$F" "$F.bak.$(date +%s)"
  while IFS=' ' read -r cmd line; do
    key="${line%%=*}"
    grep -v "^${key}=" "$F" > "$F.tmp" || true
    [ "$cmd" = SET ] && printf "%s\n" "$line" >> "$F.tmp"
    mv "$F.tmp" "$F"
  done
  chmod 600 "$F"
  systemctl restart gamex
  sleep 2
  systemctl is-active --quiet gamex && echo "  ✓ GAMEX restarted" || { echo "  ✗ GAMEX did not start - see: journalctl -u gamex -n 50"; exit 1; }
  ls -1t /etc/gamex.env.bak.* 2>/dev/null | tail -n +6 | xargs -r rm -f
'
echo
echo "Live service status:"
status
