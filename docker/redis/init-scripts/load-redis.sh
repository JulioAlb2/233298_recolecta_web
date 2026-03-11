#!/bin/sh
# ============================================================================
# load-redis.sh - Cargador seguro del seed Redis tab-delimitado
# ============================================================================

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SEEDS_DIR="$SCRIPT_DIR/../seeds"

if [ -L "$SEEDS_DIR/redis-seed-latest.txt" ]; then
    SEED_FILE="$SEEDS_DIR/redis-seed-latest.txt"
else
    SEED_FILE=$(ls -t "$SEEDS_DIR"/redis-seed_v*.txt 2>/dev/null | head -1 || true)
fi

REDIS_HOST="${1:-localhost}"
REDIS_PORT="${2:-6379}"
REDIS_PASSWORD="${3:-}"
REDIS_DB="${4:-0}"

if [ -n "$REDIS_PASSWORD" ]; then
    export REDISCLI_AUTH="$REDIS_PASSWORD"
fi

redis_cmd() {
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -n "$REDIS_DB" "$@"
}

log_info() {
    echo "[CARGANDO] $1"
}

log_detail() {
    echo "[DETALLE] $1" >&2
}

log_error() {
    echo "[ERROR] $1"
}

if [ -z "${SEED_FILE:-}" ] || [ ! -f "$SEED_FILE" ]; then
    log_error "archivo de seed no encontrado"
    log_detail "Ejecute primero: generate-seed-data.sh"
    exit 1
fi

if ! redis_cmd PING >/dev/null 2>&1; then
    log_error "No se puede conectar a Redis en $REDIS_HOST:$REDIS_PORT"
    exit 1
fi

log_info "Iniciando carga de datos en Redis"
log_detail "Host: $REDIS_HOST:$REDIS_PORT | DB: $REDIS_DB"
log_detail "Seed: $SEED_FILE"

payload_checksum=""
header_generated_at=""
header_contract_version=""
header_reference_date=""
current_collection="sin-coleccion"
line_number=0
processed_commands=0
error_count=0

while IFS= read -r line || [ -n "$line" ]; do
    line_number=$((line_number + 1))

    case "$line" in
        '# SEED-METADATA:'*)
            header_contract_version=$(printf '%s\n' "$line" | sed -n 's/.*contract_version=\([^ ]*\).*/\1/p')
            payload_checksum=$(printf '%s\n' "$line" | sed -n 's/.*payload_checksum=\([^ ]*\).*/\1/p')
            header_reference_date=$(printf '%s\n' "$line" | sed -n 's/.*reference_date=\([^ ]*\).*/\1/p')
            header_generated_at=$(printf '%s\n' "$line" | sed -n 's/.*generated_at=\([^ ]*\).*/\1/p')
            continue
            ;;
        '# COLLECTION:'*)
            current_collection=$(printf '%s\n' "$line" | sed 's/^# COLLECTION: //')
            log_info "Colección: $current_collection"
            continue
            ;;
        '#'*|'')
            continue
            ;;
    esac

    old_ifs=$IFS
    IFS=$(printf '\t')
    set -- $line
    IFS=$old_ifs

    if [ "$#" -eq 0 ]; then
        continue
    fi

    if ! redis_cmd "$@" >/dev/null 2>"$SEED_FILE.error.tmp"; then
        error_message=$(tr '\n' ' ' < "$SEED_FILE.error.tmp" | sed 's/[[:space:]]\+/ /g')
        log_error "Línea $line_number en colección '$current_collection': $error_message"
        error_count=$((error_count + 1))
    fi
    rm -f "$SEED_FILE.error.tmp"

    processed_commands=$((processed_commands + 1))
    if [ $((processed_commands % 250)) -eq 0 ]; then
        log_detail "Procesados $processed_commands comandos"
    fi
done < "$SEED_FILE"

if [ -n "$payload_checksum" ]; then
    redis_cmd HSET seed:metadata \
        payload_checksum "$payload_checksum" \
        generated_at "$header_generated_at" \
        contract_version "$header_contract_version" \
        reference_date "$header_reference_date" >/dev/null
fi

if [ "$error_count" -gt 0 ]; then
    log_error "Carga completada con $error_count errores"
    exit 1
fi

user_count=$(redis_cmd ZCARD users:geo 2>/dev/null || echo "0")
route_count=$(redis_cmd LLEN route:points:1 2>/dev/null || echo "0")
point_geo_count=$(redis_cmd ZCARD points:ruta:1 2>/dev/null || echo "0")

log_detail "Comandos procesados: $processed_commands"
log_detail "Usuarios GEO: $user_count"
log_detail "Puntos ordenados ruta 1: $route_count"
log_detail "Puntos GEO ruta 1: $point_geo_count"

if [ "$user_count" -eq 200 ] && [ "$route_count" -eq 5 ] && [ "$point_geo_count" -eq 5 ]; then
    log_info "Carga completada correctamente"
    exit 0
fi

log_error "La carga terminó pero la validación mínima no coincide con el contrato"
exit 1