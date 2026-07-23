#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script as root." >&2
  exit 1
fi

if [[ -z "${DEPLOY_PUBLIC_KEY:-}" ]]; then
  echo "DEPLOY_PUBLIC_KEY is required." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y ca-certificates curl gnupg openssl

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

. /etc/os-release
arch="$(dpkg --print-architecture)"
echo \
  "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker

if ! id fitrelay >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash fitrelay
fi
usermod -aG docker fitrelay

install -d -m 0755 -o fitrelay -g fitrelay \
  /opt/fitrelay \
  /opt/fitrelay/releases \
  /opt/fitrelay/shared
install -d -m 0750 -o 10001 -g 10001 /opt/fitrelay/data

install -d -m 0700 -o fitrelay -g fitrelay /home/fitrelay/.ssh
authorized_keys="/home/fitrelay/.ssh/authorized_keys"
touch "$authorized_keys"
if ! grep -Fqx "$DEPLOY_PUBLIC_KEY" "$authorized_keys"; then
  printf '%s\n' "$DEPLOY_PUBLIC_KEY" >> "$authorized_keys"
fi
chown fitrelay:fitrelay "$authorized_keys"
chmod 0600 "$authorized_keys"

env_file="/opt/fitrelay/shared/.env"
if [[ ! -e "$env_file" ]]; then
  umask 077
  phone_hash_secret="$(openssl rand -hex 32)"
  cat > "$env_file" <<ENV
APP_ENV=production
HTTP_ADDR=:8080
DATABASE_PATH=/app/data/app.db
LLM_PROVIDER=rules
LLM_BASE_URL=https://api.deepseek.com
LLM_API_KEY=
LLM_MODEL=deepseek-v4-flash
LLM_TIMEOUT=20s

MAX_REQUEST_BODY_BYTES=262144
INSTALLATION_REQUESTS_PER_HOUR=30
LOG_LEVEL=info
LOG_RAW_PAYLOADS=false

PHONE_AUTH_VERIFY_URL=
PHONE_AUTH_API_KEY=
PHONE_HASH_SECRET=${phone_hash_secret}
ENV
  chown root:fitrelay "$env_file"
  chmod 0640 "$env_file"
fi

if [[ -f /etc/caddy/Caddyfile && ! -f /etc/caddy/Caddyfile.pre-fitrelay ]]; then
  cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.pre-fitrelay
fi

cat > /etc/caddy/Caddyfile <<'CADDY'
:80 {
  encode zstd gzip
  reverse_proxy 127.0.0.1:18080

  header {
    X-Content-Type-Options nosniff
    X-Frame-Options DENY
    Referrer-Policy no-referrer
  }

  log
}
CADDY

caddy validate --config /etc/caddy/Caddyfile
systemctl reload caddy

echo "FitRelay server provisioning completed."
