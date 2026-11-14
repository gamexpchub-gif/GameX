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
ADMIN_BASE=/hisab
ADMIN_EMAIL=admin@deencircle.online
ADMIN_PASSWORD=$NEW_PASSWORD
EOF
  chmod 600 "$ENV_FILE"
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

say "Configuring nginx for $DOMAIN"
SITE=/etc/nginx/sites-available/gamex
if [ ! -f "$SITE" ] || ! grep -q "managed by Certbot" "$SITE"; then
  cat > "$SITE" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;

    client_max_body_size 10m;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 60s;
    }
}
EOF
fi
ln -sf "$SITE" /etc/nginx/sites-enabled/gamex
nginx -t
systemctl enable nginx >/dev/null 2>&1
systemctl reload nginx || systemctl restart nginx

if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
  ufw allow OpenSSH >/dev/null
  ufw allow 'Nginx Full' >/dev/null
fi

say "HTTPS certificate"
MY_IPS="$(hostname -I) $(curl -fs4 --max-time 5 https://api.ipify.org || true)"
DNS_IP="$(getent ahostsv4 "$DOMAIN" | awk 'NR==1{print $1}')"
HTTPS=no
if [ -z "$DNS_IP" ]; then
  warn "$DOMAIN does not resolve yet. Add a DNS A record: $DOMAIN -> this server's IP, then run deploy again."
elif ! grep -qw "$DNS_IP" <<<"$MY_IPS"; then
  warn "$DOMAIN points to $DNS_IP, not this server ($MY_IPS). Fix the DNS A record, then run deploy again."
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
echo "Admin panel:  $SCHEME://$DOMAIN/hisab/dashboard"
echo "API for apps: $SCHEME://$DOMAIN"
if [ -n "$NEW_PASSWORD" ]; then
  echo
  echo "Admin login (save this, it is shown only once):"
  echo "  Email:    admin@deencircle.online"
  echo "  Password: $NEW_PASSWORD"
  echo "  (stored in $ENV_FILE on the VPS)"
else
  echo "Admin login unchanged (see $ENV_FILE on the VPS)."
fi
