#!/bin/sh
# ============================================================================
# Script que se ejecuta en el entrypoint de Docker para cargar datos solo
# si Redis está vacío. Evita duplicación de datos.
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Parse args
FORCE_SEED=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --force) FORCE_SEED=1; shift ;;
        *) shift ;;
    esac
done

# If REDIS_PASSWORD present, export REDISCLI_AUTH so redis-cli doesn't need -a
if [ -n "$REDIS_PASSWORD" ]; then
    export REDISCLI_AUTH="$REDIS_PASSWORD"
fi

# Esperar a que Redis esté disponible
echo "[ESPERANDO] Esperando a Redis..."
echo "[DETALLE] Esperando a Redis..." >&2
for i in $(seq 1 30); do
    if redis-cli -h redis ping > /dev/null 2>&1; then
        echo "[OK] Redis disponible"
        echo "[DETALLE] Redis respondió al PING" >&2
        break
    fi
    echo "[DETALLE] Intento $i/30..." >&2
    sleep 1
done

# Verificar si ya hay datos
DBSIZE=$(redis-cli DBSIZE 2>/dev/null || echo "")
if ! echo "$DBSIZE" | grep -q '^[0-9]*$'; then
    INFO_KEYSPACE=$(redis-cli INFO keyspace 2>/dev/null || echo "")
    DBSIZE=$(echo "$INFO_KEYSPACE" | sed -n 's/.*keys=\([0-9]*\).*/\1/p' | head -1)
    DBSIZE=${DBSIZE:-0}
fi

if [ "$DBSIZE" -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Redis vacío - inicializando..."
    
    SEED_DIR="$SCRIPT_DIR/../seeds"
    LATEST_LINK="$SEED_DIR/redis-seed-latest.txt"

    need_generate=0
    if [ "$FORCE_SEED" -eq 1 ]; then
        need_generate=1
    else
        # Check if a latest seed exists and validate metadata + checksum
        if [ -L "$LATEST_LINK" ] || [ -f "$LATEST_LINK" ]; then
            # Resolve target
            link_target=$(readlink "$LATEST_LINK" 2>/dev/null || true)
            if [ -z "$link_target" ]; then
                SEED_FILE="$LATEST_LINK"
            else
                # If link_target is absolute use it, otherwise it's relative to seeds dir
                case "$link_target" in
                    /*) SEED_FILE="$link_target" ;;
                    *) SEED_FILE="$SEED_DIR/$link_target" ;;
                esac
            fi

            if [ -f "$SEED_FILE" ]; then
                meta_line=$(head -n1 "$SEED_FILE" 2>/dev/null || true)
                if echo "$meta_line" | grep -q '^# SEED-METADATA:'; then
                    # extract checksum and fields
                    checksum_meta=$(echo "$meta_line" | awk -F"checksum=" '{print $2}' | awk '{print $1}' 2>/dev/null || true)
                    users_meta=$(echo "$meta_line" | awk -F"users=" '{print $2}' | awk '{print $1}' 2>/dev/null || true)
                    points_meta=$(echo "$meta_line" | awk -F"points=" '{print $2}' | awk '{print $1}' 2>/dev/null || true)
                    routes_meta=$(echo "$meta_line" | awk -F"routes=" '{print $2}' | awk '{print $1}' 2>/dev/null || true)

                    # compute actual checksum of file excluding first line
                    tail -n +2 "$SEED_FILE" > "$SEED_FILE.check.tmp"
                    if command -v sha256sum >/dev/null 2>&1; then
                        actual_checksum=$(sha256sum "$SEED_FILE.check.tmp" | awk '{print $1}')
                    elif command -v openssl >/dev/null 2>&1; then
                        actual_checksum=$(openssl sha256 "$SEED_FILE.check.tmp" | awk '{print $2}')
                    else
                        actual_checksum=$(md5sum "$SEED_FILE.check.tmp" | awk '{print $1}')
                    fi
                    rm -f "$SEED_FILE.check.tmp"

                    if [ "$actual_checksum" = "$checksum_meta" ] && [ "$users_meta" = "200" ] && [ "$points_meta" = "25" ] && [ "$routes_meta" = "5" ]; then
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Seed existente válido: $SEED_FILE (checksum match)"
                        need_generate=0
                    else
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Seed existente inválido o desactualizado: regenerando"
                        need_generate=1
                    fi
                else
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Metadata no encontrada en $SEED_FILE: regenerando"
                    need_generate=1
                fi
            else
                need_generate=1
            fi
        else
            need_generate=1
        fi
    fi

    if [ "$need_generate" -eq 1 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Generando seed..."
        sh "$SCRIPT_DIR/generate-seed-data.sh"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Usando seed existente, no se genera uno nuevo"
    fi
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cargando datos..."
    sh "$SCRIPT_DIR/load-redis.sh" redis 6379 "$REDIS_PASSWORD"
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Verificando integridad..."
    sh "$SCRIPT_DIR/verify-redis.sh" redis 6379 "$REDIS_PASSWORD"
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ Inicialización completada"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Redis ya contiene datos ($DBSIZE claves) - saltando inicialización"
fi
=======
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
