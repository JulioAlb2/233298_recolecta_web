#!/bin/sh
set -e

NGINX_SERVER_NAME="${NGINX_SERVER_NAME:-localhost}"
SSL_CERTIFICATE="/etc/letsencrypt/live/${NGINX_SERVER_NAME}/fullchain.pem"
SSL_CERTIFICATE_KEY="/etc/letsencrypt/live/${NGINX_SERVER_NAME}/privkey.pem"

export NGINX_SERVER_NAME
export SSL_CERTIFICATE
export SSL_CERTIFICATE_KEY

if [ -f "$SSL_CERTIFICATE" ] && [ -f "$SSL_CERTIFICATE_KEY" ]; then
    echo "SSL: certificados encontrados para ${NGINX_SERVER_NAME}, habilitando HTTPS"
    envsubst '${NGINX_SERVER_NAME} ${SSL_CERTIFICATE} ${SSL_CERTIFICATE_KEY}' \
        < /etc/nginx/templates/nginx.https.conf.template \
        > /etc/nginx/nginx.conf
else
    echo "SSL: sin certificados para ${NGINX_SERVER_NAME}, sirviendo solo HTTP"
    echo "SSL: ejecuta scripts/setup-ssl.sh en el servidor para obtener Let's Encrypt"
    envsubst '${NGINX_SERVER_NAME}' \
        < /etc/nginx/templates/nginx.http.conf.template \
        > /etc/nginx/nginx.conf
fi

nginx -t
exec nginx -g 'daemon off;'
