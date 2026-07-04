#!/bin/sh
# ============================================================================
# Valida que todos los datos fueron cargados correctamente
# Uso: ./verify-redis.sh [redis-host] [redis-port] [redis-password]
# ============================================================================
# Configuración
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SEEDS_DIR="$SCRIPT_DIR/../seeds"

# Parámetros
=======
# verify-redis.sh - Validador de contrato Redis para seeds nivelados
# ============================================================================

set -eu

EXPECTED_CONTRACT_VERSION="2.0"
EXPECTED_USERS="200"
EXPECTED_POINTS="25"
EXPECTED_ROUTES="5"
EXPECTED_TRUCKS="6"
EXPECTED_ASSIGNED_TRUCKS="5"
REFERENCE_DATE="2026-01-30"

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

ok() {
    echo "[OK] $1"
}

fail() {
    echo "[ERROR] $1"
    FAILED=1
}

require_equals() {
    label="$1"
    actual="$2"
    expected="$3"
    if [ "$actual" = "$expected" ]; then
        ok "$label = $actual"
    else
        fail "$label = $actual (esperado $expected)"
    fi
}

require_positive_ttl() {
    key="$1"
    ttl=$(redis_cmd TTL "$key" 2>/dev/null || echo "-2")
    if [ "$ttl" -gt 0 ]; then
        ok "TTL activo en $key ($ttl s)"
    else
        fail "TTL ausente o expirado en $key (TTL=$ttl)"
    fi
}

require_hash_fields() {
    key="$1"
    shift
    for field in "$@"; do
        exists=$(redis_cmd HEXISTS "$key" "$field" 2>/dev/null || echo "0")
        if [ "$exists" -ne 1 ]; then
            fail "$key no contiene field requerido: $field"
            return 1
        fi
    done
    ok "$key contiene fields críticos"
    return 0
}

FAILED=0

echo "[VALIDANDO] Contrato Redis Seed"

if redis_cmd PING >/dev/null 2>&1; then
    ok "Redis responde al PING"
else
    echo "[ERROR] Redis no responde al PING"
    exit 1
fi

dbsize=$(redis_cmd DBSIZE 2>/dev/null || echo "0")
if [ "$dbsize" -gt 0 ]; then
    ok "Base con datos ($dbsize claves)"
else
    echo "[ERROR] Base vacía"
    exit 1
fi

require_equals "users:geo" "$(redis_cmd ZCARD users:geo 2>/dev/null || echo 0)" "$EXPECTED_USERS"

route_total=0
point_geo_total=0
for route_id in $(seq 1 5); do
    list_len=$(redis_cmd LLEN "route:points:$route_id" 2>/dev/null || echo "0")
    geo_len=$(redis_cmd ZCARD "points:ruta:$route_id" 2>/dev/null || echo "0")
    route_total=$((route_total + list_len))
    point_geo_total=$((point_geo_total + geo_len))
    require_equals "route:points:$route_id" "$list_len" "5"
    require_equals "points:ruta:$route_id" "$geo_len" "5"
    require_hash_fields "route:$route_id" name description colonia_id zone shift total_points status
done
require_equals "total puntos ordenados" "$route_total" "$EXPECTED_POINTS"
require_equals "total puntos GEO" "$point_geo_total" "$EXPECTED_POINTS"

require_hash_fields "user:100" alias email colonia_id fcm_token fcm_status fcm_created_at fcm_expires_at updated_at
require_hash_fields "user:199" alias email colonia_id fcm_token fcm_status fcm_created_at fcm_expires_at updated_at
require_hash_fields "user:299" alias email colonia_id fcm_token fcm_status fcm_created_at fcm_expires_at updated_at

for user_id in 100 199 299; do
    geo_position=$(redis_cmd GEOPOS users:geo "$user_id" 2>/dev/null || true)
    if [ -n "$geo_position" ]; then
        ok "GEOPOS users:geo $user_id disponible"
    else
        fail "GEOPOS users:geo $user_id vacío"
    fi
done

for point_id in 1 12 25; do
    require_hash_fields "point:$point_id" route_id colonia_id point_code label lat lon
done

assigned_trucks=0
truck_state_count=$(redis_cmd KEYS 'truck:state:*' | wc -l | tr -d ' ')
for truck_id in $(seq 1 6); do
    require_hash_fields "truck:state:$truck_id" route_id current_point_id state lat lon updated_at assignment_source
    require_positive_ttl "truck:state:$truck_id"
    route_id=$(redis_cmd HGET "truck:state:$truck_id" route_id 2>/dev/null || echo "0")
    if [ "$route_id" -gt 0 ]; then
        assigned_trucks=$((assigned_trucks + 1))
    fi
done
require_equals "camiones con ruta asignada en Redis" "$assigned_trucks" "$EXPECTED_ASSIGNED_TRUCKS"
require_equals "camiones con estado temporal" "$truck_state_count" "$EXPECTED_TRUCKS"

notification_key="notification:sent:100:1:$REFERENCE_DATE"
notif_members=$(redis_cmd SMEMBERS "$notification_key" 2>/dev/null | sort | tr '\n' ',' | sed 's/,$//')
require_equals "$notification_key" "$notif_members" "ARRIVAL,COMEBACK,DEPARTURE,WARN"
require_positive_ttl "$notification_key"

for state in WARN ARRIVAL DEPARTURE COMEBACK; do
    require_hash_fields "notification:seed:100:1:$state" type status truck_id point_id timestamp
    require_positive_ttl "notification:seed:100:1:$state"
done

require_hash_fields "metrics:notifications:1:$REFERENCE_DATE" total_sent warn_count arrival_count departure_count comeback_count delivery_success delivery_failed
require_positive_ttl "metrics:notifications:1:$REFERENCE_DATE"

require_hash_fields "seed:metadata" contract_version expected_users expected_points expected_routes expected_colonias expected_trucks expected_assigned_trucks reference_date payload_checksum generated_at
require_equals "seed:metadata.contract_version" "$(redis_cmd HGET seed:metadata contract_version 2>/dev/null || echo '')" "$EXPECTED_CONTRACT_VERSION"
require_equals "seed:metadata.reference_date" "$(redis_cmd HGET seed:metadata reference_date 2>/dev/null || echo '')" "$REFERENCE_DATE"

if [ "$FAILED" -ne 0 ]; then
    echo "[ERROR] Contrato Redis inválido"
    exit 1
fi

echo "[OK] Contrato Redis válido"
