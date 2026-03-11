#!/bin/bash
# Test script for healthcheck of Redis container
set -e

echo "Starting Redis healthcheck test..."

# Cambiar al directorio raíz del proyecto
cd "$(dirname "$0")/../../.." || exit 1

COMPOSE_FILE="docker/docker.compose.yml"

# Verificar que el archivo existe
if [ ! -f "$COMPOSE_FILE" ]; then
  echo "Error: $COMPOSE_FILE not found"
  exit 1
fi

# Extraer el bloque del servicio redis (2 espacios de indentación = nivel de servicio)
# -A 30 cubre todo el bloque aunque tenga muchos volúmenes
REDIS_BLOCK=$(grep -A 30 "^  redis:" "$COMPOSE_FILE")

# Verificar healthcheck
echo "$REDIS_BLOCK" | grep -q "healthcheck:" || { echo "Error: Healthcheck not found in Redis service."; exit 1; }

# Verificar test command
echo "$REDIS_BLOCK" | grep -q "redis-cli.*PING" || { echo "Error: Healthcheck PING test not found."; exit 1; }

# Verificar parámetros
echo "$REDIS_BLOCK" | grep -q "interval:" || { echo "Error: Healthcheck interval not found."; exit 1; }
echo "$REDIS_BLOCK" | grep -q "timeout:" || { echo "Error: Healthcheck timeout not found."; exit 1; }
echo "$REDIS_BLOCK" | grep -q "retries:" || { echo "Error: Healthcheck retries not found."; exit 1; }

echo "Redis healthcheck test passed successfully!"
exit 0