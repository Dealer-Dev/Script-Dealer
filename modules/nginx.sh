#!/usr/bin/env bash
# modules/nginx.sh - Instala y configura NGINX para reverse-proxy multiuso
# Soporta Ubuntu 16.04+ y Debian

set -euo pipefail
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

GREEN="\e[32m"
RESET="\e[0m"

echo -e "${GREEN}>>> Instalando NGINX y utilidades...${RESET}"
apt update -y
apt install -y curl wget ca-certificates lsb-release gnupg2 apt-transport-https

# Instalar la versión stock de nginx (si quieres nginx mainline, lo adaptamos)
apt install -y nginx

# Asegurarse de que nginx está habilitado
systemctl enable nginx
systemctl start nginx

NGINX_CONF_DIR="/etc/nginx"
SITES_AVAILABLE="${NGINX_CONF_DIR}/sites-available"
SITES_ENABLED="${NGINX_CONF_DIR}/sites-enabled"
STREAM_CONF_DIR="${NGINX_CONF_DIR}/stream.d"

mkdir -p "${SITES_AVAILABLE}" "${SITES_ENABLED}" "${STREAM_CONF_DIR}"

echo -e "${GREEN}>>> Configurando ajustes globales de nginx...${RESET}"

# Seguridad básica y optimizaciones (keepalive, buffers, timeouts)
cat > "${NGINX_CONF_DIR}/nginx.conf" <<'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
events {
    worker_connections 10240;
    multi_accept on;
}
http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;

    # Buffers
    client_body_buffer_size 16K;
    client_header_buffer_size 1k;
    large_client_header_buffers 4 8k;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    gzip on;
    gzip_disable "msie6";

    # Include vhost configs
    include /etc/nginx/sites-enabled/*;
}
# Stream for TCP/UDP passthrough
stream {
    include /etc/nginx/stream.d/*.conf;
}
EOF

# Default catch-all site (redirect http->https)
cat > "${SITES_AVAILABLE}/default_http.conf" <<'EOF'
server {
    listen 80 default_server;
    server_name _;
    location / {
        return 301 https://$host$request_uri;
    }
}
EOF

ln -sf "${SITES_AVAILABLE}/default_http.conf" "${SITES_ENABLED}/default_http.conf"

# Basic template for domain vhost (replace server_name and proxy_pass as needed)
cat > "${SITES_AVAILABLE}/00_script_dealer.conf" <<'EOF'
server {
    listen 443 ssl http2;
    server_name keys.script-dealer.com;

    # SSL certs are added by acme.sh (see below)
    ssl_certificate /etc/ssl/script-dealer/fullchain.cer;
    ssl_certificate_key /etc/ssl/script-dealer/private.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    # Proxy settings for web (example: forward /validate to local app)
    location /validate {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Fallback to a simple status page or index
    location / {
        proxy_pass http://127.0.0.1:8080; # your python/web app
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

ln -sf "${SITES_AVAILABLE}/00_script_dealer.conf" "${SITES_ENABLED}/00_script_dealer.conf"

# Ensure directories for certs
mkdir -p /etc/ssl/script-dealer

# Install acme.sh (lightweight) for certs
echo -e "${GREEN}>>> Instalando acme.sh para certificados...${RESET}"
if ! command -v acme.sh >/dev/null 2>&1; then
  curl https://get.acme.sh | sh
  export PATH="$HOME/.acme.sh:$PATH"
fi

# Function to issue cert for keys.script-dealer.com (requires the domain to point to the server)
issue_cert(){
  DOMAIN="$1"
  echo -e "${GREEN}>>> Solicitando certificado para ${DOMAIN} (usando acme.sh)...${RESET}"
  # Use standalone mode or webroot; standalone requires port 80 free
  "$HOME/.acme.sh"/acme.sh --issue -d "${DOMAIN}" --standalone --keylength ec-256 || {
    echo "acme.sh failed to issue cert for ${DOMAIN}"
    return 1
  }
  mkdir -p /etc/ssl/script-dealer
  "$HOME/.acme.sh"/acme.sh --install-cert -d "${DOMAIN}" \
    --fullchain-file /etc/ssl/script-dealer/fullchain.cer \
    --key-file /etc/ssl/script-dealer/private.key \
    --ecc
  echo -e "${GREEN}Certificado instalado para ${DOMAIN}${RESET}"
}

# Try to issue cert for keys.script-dealer.com (best-effort)
DOMAIN="keys.script-dealer.com"
if curl -s --head "http://${DOMAIN}" | head -n 1 | grep -q "HTTP/"; then
  # domain resolves to this server - try to issue cert
  issue_cert "${DOMAIN}" || true
else
  echo -e "${GREEN}Dominio ${DOMAIN} no resuelve localmente: salteando emisión automática de certificado${RESET}"
fi

# Example stream config (TCP passthrough) - THIS IS A TEMPLATE
cat > "${STREAM_CONF_DIR}/00_stream_template.conf" <<'EOF'
# Example TCP passthrough: forward port 8443 to local 8443
# server {
#     listen 8443;
#     proxy_pass 127.0.0.1:8443;
# }
EOF

# Reload nginx
echo -e "${GREEN}>>> Probando configuración de nginx...${RESET}"
nginx -t
systemctl reload nginx

echo -e "${GREEN}NGINX instalado y configurado (plantillas).${RESET}"
echo -e "${GREEN}Edita /etc/nginx/sites-available/00_script_dealer.conf y stream.d/*.conf para tus backends reales.${RESET}"
