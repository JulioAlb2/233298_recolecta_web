#!/usr/bin/env bash
# Obtiene certificado Let's Encrypt y habilita HTTPS en nginx_proxy.
# Uso (desde la raíz del proyecto, en el VPS):
#   bash scripts/setup-ssl.sh tu-dominio.com admin@tu-dominio.com

set -euo pipefail

DOMAIN="${1:-}"
EMAIL="${2:-}"

if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
    echo "Uso: bash scripts/setup-ssl.sh <dominio> <email>"
    echo "Ejemplo: bash scripts/setup-ssl.sh recolecta.ejemplo.com admin@ejemplo.com"
    exit 1
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if [ ! -f ".env" ]; then
    echo "Error: no existe .env en $ROOT_DIR"
    exit 1
fi

echo "==> Configurando NGINX_SERVER_NAME=$DOMAIN en .env"
if grep -q '^NGINX_SERVER_NAME=' .env; then
    sed -i "s|^NGINX_SERVER_NAME=.*|NGINX_SERVER_NAME=$DOMAIN|" .env
else
    echo "NGINX_SERVER_NAME=$DOMAIN" >> .env
fi

if grep -q '^LETSENCRYPT_DIR=' .env; then
    sed -i 's|^LETSENCRYPT_DIR=.*|LETSENCRYPT_DIR=/etc/letsencrypt|' .env
else
    echo "LETSENCRYPT_DIR=/etc/letsencrypt" >> .env
fi

mkdir -p docker/certbot/www

if ! command -v certbot >/dev/null 2>&1; then
    echo "==> Instalando certbot..."
    apt-get update
    apt-get install -y certbot
fi

echo "==> Levantando stack (HTTP) para validación ACME..."
docker compose --env-file .env -f docker/docker.compose.yml up -d --build proxy

echo "==> Solicitando certificado Let's Encrypt..."
certbot certonly --webroot \
    -w "$ROOT_DIR/docker/certbot/www" \
    -d "$DOMAIN" \
    --email "$EMAIL" \
    --agree-tos \
    --non-interactive

echo "==> Reiniciando nginx para cargar certificados..."
docker compose --env-file .env -f docker/docker.compose.yml up -d --build proxy

echo ""
echo "HTTPS habilitado en https://$DOMAIN"
echo "Verifica: curl -I https://$DOMAIN/health"
echo ""
echo "Renovación automática (agregar a crontab -e):"
echo "0 3 1 * * certbot renew --quiet --webroot -w $ROOT_DIR/docker/certbot/www && docker compose --env-file $ROOT_DIR/.env -f $ROOT_DIR/docker/docker.compose.yml restart proxy"
