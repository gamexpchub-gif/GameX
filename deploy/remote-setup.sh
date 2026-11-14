#!/usr/bin/env bash
# Runs ON the VPS (as root). Called by deploy/deploy.sh after the files are
# uploaded to /opt/gamex. Safe to run again for every update.
set -euo pipefail

DOMAIN="${DOMAIN:-admin.deencircle.online}"
CERT_EMAIL="${CERT_EMAIL:-}"
APP_DIR=/opt/gamex
ENV_FILE=/etc/gamex.env
export DEBIAN_FRONTEND=noninteractive

say() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!! %s\033[0m\n' "$*"; }

[ "$(id -u)" -eq 0 ] || { echo "Run as root"; exit 1; }
command -v apt-get >/dev/null || { echo "This script supports Debian/Ubuntu VPS only."; exit 1; }

# Refuse to fight another web server for port 80.
if ss -ltnp 2>/dev/null | grep -E ':80\s' | grep -qv nginx; then
  warn "Port 80 is used by another web server (not nginx):"
  ss -ltnp | grep -E ':80\s' || true
  echo "Stop it or ask for an nginx-free setup, then run deploy again."
  exit 1
fi

say "Installing system packages (nginx, certbot, Node.js)"
apt-get update -qq
apt-get install -y -qq curl ca-certificates nginx rsync openssl certbot python3-certbot-nginx >/dev/null
if ! command -v node >/dev/null || [ "$(node -p 'process.versions.node.split(".")[0]')" -lt 20 ]; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash - >/dev/null
  apt-get install -y -qq nodejs >/dev/null
fi
echo "Node $(node -v), nginx $(nginx -v 2>&1 | cut -d/ -f2)"

say "Installing GAMEX server"
id gamex >/dev/null 2>&1 || useradd --system --home-dir "$APP_DIR" --shell /usr/sbin/nologin gamex
mkdir -p "$APP_DIR/server/data" "$APP_DIR/server/uploads"
cd "$APP_DIR/server"
npm ci --omit=dev --no-audit --no-fund --loglevel=error
chown -R gamex:gamex "$APP_DIR/server/data" "$APP_DIR/server/uploads"

NEW_PASSWORD=""
if [ ! -f "$ENV_FILE" ]; then
  NEW_PASSWORD="$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | cut -c1-16)"
  cat > "$ENV_FILE" <<EOF
PORT=8080
HOST=127.0.0.1
ADMIN_BASE=/gamex
ADMIN_EMAIL=admin@deencircle.online
ADMIN_PASSWORD=$NEW_PASSWORD
EOF
  chmod 600 "$ENV_FILE"
fi

# GAMEX is served under /gamex (older deploys used /hisab).
if grep -q '^ADMIN_BASE=' "$ENV_FILE"; then
  sed -i 's#^ADMIN_BASE=.*#ADMIN_BASE=/gamex#' "$ENV_FILE"
else
  echo 'ADMIN_BASE=/gamex' >> "$ENV_FILE"
fi

cat > /etc/systemd/system/gamex.service <<EOF
[Unit]
Description=GAMEX marketplace server
After=network.target

[Service]
Type=simple
User=gamex
WorkingDirectory=$APP_DIR/server
EnvironmentFile=$ENV_FILE
ExecStart=$(command -v node) src/index.js
Restart=always
RestartSec=3
NoNewPrivileges=true
ProtectSystem=full
ProtectHome=true
PrivateTmp=true
ReadWritePaths=$APP_DIR/server/data $APP_DIR/server/uploads

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable gamex >/dev/null 2>&1
systemctl restart gamex

for i in $(seq 1 20); do
  curl -fs http://127.0.0.1:8080/api/health >/dev/null && break
  sleep 0.5
done
curl -fs http://127.0.0.1:8080/api/health >/dev/null || {
  warn "Server did not start. Last log lines:"
  journalctl -u gamex -n 30 --no-pager
  exit 1
}
echo "GAMEX server is running (systemd service: gamex)"

say "Configuring nginx: $DOMAIN/gamex -> GAMEX"
# GAMEX (admin panel + API + photos) lives entirely under /gamex/.
mkdir -p /etc/nginx/snippets
# Move an older /hisab setup over to /gamex.
OLD_FILES="$(grep -Rl 'gamex-hisab.conf' /etc/nginx/sites-enabled /etc/nginx/conf.d /etc/nginx/nginx.conf 2>/dev/null | xargs -r -n1 readlink -f | sort -u || true)"
for f in $OLD_FILES; do
  cp -a "$f" "/root/$(basename "$f").before-gamex-path-$(date +%s)"
  sed -i 's#snippets/gamex-hisab\.conf#snippets/gamex.conf#; s#/hisab/dashboard#/gamex/dashboard#' "$f"
done
cat > /etc/nginx/snippets/gamex.conf <<'NGINX'
# GAMEX under /gamex/ - managed by deploy/remote-setup.sh
location = /gamex { return 301 /gamex/; }
location ^~ /gamex/ {
    client_max_body_size 10m;
    proxy_pass http://127.0.0.1:8080;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_read_timeout 60s;
}
NGINX

DOMAIN_RE="$(printf '%s' "$DOMAIN" | sed 's/\./\\./g')"
NAME_RE="server_name[^;]*[[:space:]]${DOMAIN_RE}([[:space:]]|;)"

# Is another site (e.g. your existing app) already serving this domain?
EXISTING=()
FOUND="$(grep -RlE "$NAME_RE" /etc/nginx/sites-enabled /etc/nginx/conf.d /etc/nginx/nginx.conf 2>/dev/null | xargs -r -n1 readlink -f | sort -u || true)"
for f in $FOUND; do
  if [ "$f" != /etc/nginx/sites-available/gamex ]; then EXISTING+=("$f"); fi
done

SHARED=no
if [ "${#EXISTING[@]}" -gt 0 ]; then
  SHARED=yes
  echo "$DOMAIN is already served by: ${EXISTING[*]}"
  echo "Adding GAMEX at /gamex/ to that config - your existing site keeps working."
  rm -f /etc/nginx/sites-enabled/gamex /etc/nginx/sites-available/gamex
  BACKUP="/root/nginx-backup-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$BACKUP"
  for f in "${EXISTING[@]}"; do
    cp -a "$f" "$BACKUP/"
    grep -q 'snippets/gamex.conf' "$f" ||
      sed -i --follow-symlinks -E "/${NAME_RE}/a\\    include snippets/gamex.conf;" "$f"
  done
  if ! nginx -t; then
    warn "nginx rejected the change - restoring your original config from $BACKUP"
    for f in "${EXISTING[@]}"; do cp -a "$BACKUP/$(basename "$f")" "$f"; done
    nginx -t && systemctl reload nginx
    exit 1
  fi
else
  SITE=/etc/nginx/sites-available/gamex
  if [ ! -f "$SITE" ] || ! grep -q "managed by Certbot" "$SITE"; then
    cat > "$SITE" <<NGINX
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    include snippets/gamex.conf;
    location = / { return 302 /gamex/dashboard; }
}
NGINX
  fi
  ln -sf "$SITE" /etc/nginx/sites-enabled/gamex
  nginx -t
fi
systemctl enable nginx >/dev/null 2>&1
systemctl reload nginx || systemctl restart nginx
grep -Rq 'gamex-hisab.conf' /etc/nginx/sites-enabled /etc/nginx/conf.d 2>/dev/null || rm -f /etc/nginx/snippets/gamex-hisab.conf
sleep 1
if curl -fs -H "Host: $DOMAIN" http://127.0.0.1/gamex/api/health >/dev/null ||
   curl -fsk --resolve "$DOMAIN:443:127.0.0.1" "https://$DOMAIN/gamex/api/health" >/dev/null; then
  echo "nginx -> GAMEX OK"
else
  warn "nginx is not forwarding /gamex/ yet. Check with: nginx -T | grep -n gamex"
fi

if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
  ufw allow OpenSSH >/dev/null
  ufw allow 'Nginx Full' >/dev/null
fi

say "HTTPS certificate"
MY_IPS="$(hostname -I) $(curl -fs4 --max-time 5 https://api.ipify.org || true)"
DNS_IP="$(getent ahostsv4 "$DOMAIN" | awk 'NR==1{print $1}' || true)"
HTTPS=no
if [ -z "$DNS_IP" ]; then
  warn "$DOMAIN does not resolve yet. Add a DNS A record: $DOMAIN -> this server's IP, then run deploy again."
elif ! grep -qw "$DNS_IP" <<<"$MY_IPS"; then
  warn "$DOMAIN points to $DNS_IP, not this server ($MY_IPS). Fix the DNS A record, then run deploy again."
elif [ "$SHARED" = yes ] && grep -qE 'listen[^;]*443' "${EXISTING[@]}"; then
  echo "$DOMAIN already has HTTPS - keeping your existing certificate."
  HTTPS=yes
else
  if [ -n "$CERT_EMAIL" ]; then EMAIL_ARGS=(-m "$CERT_EMAIL"); else EMAIL_ARGS=(--register-unsafely-without-email); fi
  if certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --redirect "${EMAIL_ARGS[@]}"; then
    HTTPS=yes
  else
    warn "Certbot failed (see above). The site still works on http:// for now."
  fi
fi

SCHEME=http
[ "$HTTPS" = yes ] && SCHEME=https
say "Done"
echo "Admin panel:  $SCHEME://$DOMAIN/gamex/dashboard"
echo "API for apps: $SCHEME://$DOMAIN/gamex"
if [ -n "$NEW_PASSWORD" ]; then
  echo
  echo "Admin login (save this, it is shown only once):"
  echo "  Email:    admin@deencircle.online"
  echo "  Password: $NEW_PASSWORD"
  echo "  (stored in $ENV_FILE on the VPS)"
else
  echo "Admin login unchanged (see $ENV_FILE on the VPS)."
fi
