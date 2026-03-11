#!/bin/sh
# ============================================================================
# init-if-empty.sh - Inicialización Redis basada en contrato del seed
# ============================================================================

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SEED_DIR="$SCRIPT_DIR/../seeds"
LATEST_LINK="$SEED_DIR/redis-seed-latest.txt"
EXPECTED_CONTRACT_VERSION="2.0"
EXPECTED_USERS="200"
EXPECTED_POINTS="25"
EXPECTED_ROUTES="5"
EXPECTED_COLONIAS="8"
EXPECTED_TRUCKS="6"
EXPECTED_ASSIGNED_TRUCKS="5"

FORCE_SEED=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --force) FORCE_SEED=1 ;;
    esac
    shift
done

if [ -n "${REDIS_PASSWORD:-}" ]; then
    export REDISCLI_AUTH="$REDIS_PASSWORD"
fi

redis_cmd() {
    redis-cli -h redis -p 6379 "$@"
}

compute_checksum() {
    file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
    elif command -v openssl >/dev/null 2>&1; then
        openssl dgst -sha256 "$file" | awk '{print $2}'
    else
        md5sum "$file" | awk '{print $1}'
    fi
}

extract_meta() {
    key="$1"
    line="$2"
    printf '%s\n' "$line" | sed -n "s/.*$key=\\([^ ]*\\).*/\\1/p"
}

resolve_seed_file() {
    if [ -L "$LATEST_LINK" ]; then
        link_target=$(readlink "$LATEST_LINK" 2>/dev/null || true)
        case "$link_target" in
            /*) printf '%s\n' "$link_target" ;;
            '') printf '%s\n' "$LATEST_LINK" ;;
            *) printf '%s\n' "$SEED_DIR/$link_target" ;;
        esac
        return
    fi

    if [ -f "$LATEST_LINK" ]; then
        printf '%s\n' "$LATEST_LINK"
        return
    fi

    ls -t "$SEED_DIR"/redis-seed_v*.txt 2>/dev/null | head -1 || true
}

validate_seed_file() {
    file="$1"
    [ -f "$file" ] || return 1

    meta_line=$(head -n 1 "$file" 2>/dev/null || true)
    case "$meta_line" in
        '# SEED-METADATA:'*) : ;;
        *) return 1 ;;
    esac

    contract_version=$(extract_meta contract_version "$meta_line")
    payload_checksum=$(extract_meta payload_checksum "$meta_line")
    expected_users=$(extract_meta expected_users "$meta_line")
    expected_points=$(extract_meta expected_points "$meta_line")
    expected_routes=$(extract_meta expected_routes "$meta_line")
    expected_colonias=$(extract_meta expected_colonias "$meta_line")
    expected_trucks=$(extract_meta expected_trucks "$meta_line")
    expected_assigned_trucks=$(extract_meta expected_assigned_trucks "$meta_line")

    payload_tmp="$file.payload.tmp"
    tail -n +2 "$file" > "$payload_tmp"
    actual_checksum=$(compute_checksum "$payload_tmp")
    rm -f "$payload_tmp"

    [ "$contract_version" = "$EXPECTED_CONTRACT_VERSION" ] || return 1
    [ "$payload_checksum" = "$actual_checksum" ] || return 1
    [ "$expected_users" = "$EXPECTED_USERS" ] || return 1
    [ "$expected_points" = "$EXPECTED_POINTS" ] || return 1
    [ "$expected_routes" = "$EXPECTED_ROUTES" ] || return 1
    [ "$expected_colonias" = "$EXPECTED_COLONIAS" ] || return 1
    [ "$expected_trucks" = "$EXPECTED_TRUCKS" ] || return 1
    [ "$expected_assigned_trucks" = "$EXPECTED_ASSIGNED_TRUCKS" ] || return 1
}

echo "[ESPERANDO] Esperando a Redis..."
for i in $(seq 1 30); do
    if redis_cmd PING >/dev/null 2>&1; then
        echo "[OK] Redis disponible"
        break
    fi
    if [ "$i" -eq 30 ]; then
        echo "[ERROR] Redis no respondió al PING"
        exit 1
    fi
    sleep 1
done

dbsize=$(redis_cmd DBSIZE 2>/dev/null || echo "0")
if ! printf '%s' "$dbsize" | grep -Eq '^[0-9]+$'; then
    dbsize=0
fi

seed_file=$(resolve_seed_file)
need_generate=0

if [ "$FORCE_SEED" -eq 1 ]; then
    need_generate=1
elif [ -z "${seed_file:-}" ] || ! validate_seed_file "$seed_file"; then
    need_generate=1
fi

if [ "$dbsize" -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Redis vacío - inicializando"

    if [ "$need_generate" -eq 1 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Generando seed por contrato inválido o ausente"
        sh "$SCRIPT_DIR/generate-seed-data.sh"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Seed existente válido: $seed_file"
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cargando datos en Redis"
    sh "$SCRIPT_DIR/load-redis.sh" redis 6379 "${REDIS_PASSWORD:-}" 0

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Verificando integridad"
    sh "$SCRIPT_DIR/verify-redis.sh" redis 6379 "${REDIS_PASSWORD:-}" 0

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ Inicialización completada"
    exit 0
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Redis ya contiene datos ($dbsize claves)"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Validando contrato cargado sin regenerar"
sh "$SCRIPT_DIR/verify-redis.sh" redis 6379 "${REDIS_PASSWORD:-}" 0