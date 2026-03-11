#!/bin/bash
################################################################################
# Script: test_seed_integrity.sh
# Purpose: Validate Redis keyspace against canonical contract v2.0
# Description:
#   Verifies that the Redis seed data matches the canonical contract:
#   - Key counts  (users, points, routes)
#   - Hash field presence for user:{id}, point:{id}, route:{id}, truck:state:{id}
#   - TTL on ephemeral keys  (truck:state, notification:sent)
#   - seed:metadata contract_version and reference_date
#   - notification:sent SET members
#
# Usage:
#   ./scripts/tests/redis/test_seed_integrity.sh
#   REDIS_CONTAINER=redis_cache REDIS_PASSWORD=xxx ./scripts/tests/redis/test_seed_integrity.sh
#
# Env vars:
#   REDIS_CONTAINER  (default: redis_cache)
#   REDIS_PASSWORD   (default: r3d1s_s3cur3_p4ss)
#   REDIS_DB         (default: 0)
################################################################################

set -u

# Change to project root so relative paths work consistently
cd "$(dirname "$0")/../../.." || exit 1

# Source .env if available
if [ -f .env ]; then
    set -a
    # shellcheck disable=SC1091
    source .env
    set +a
fi

# ── Configuration ─────────────────────────────────────────────────────────────
REDIS_CONTAINER="${REDIS_CONTAINER:-redis_cache}"
REDIS_PASSWORD="${REDIS_PASSWORD:-r3d1s_s3cur3_p4ss}"
REDIS_DB="${REDIS_DB:-0}"
REFERENCE_DATE="2026-01-30"

# ── Colors ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ── State ─────────────────────────────────────────────────────────────────────
PASS=0
FAIL=0
FAILED_TESTS=()

# ── Helpers ───────────────────────────────────────────────────────────────────
rcli() {
    docker exec -e REDISCLI_AUTH="$REDIS_PASSWORD" "$REDIS_CONTAINER" \
        redis-cli -n "$REDIS_DB" "$@" 2>/dev/null
}

pass_test() {
    echo -e "  ${GREEN}✓${NC} $1"
    PASS=$((PASS + 1))
}

fail_test() {
    echo -e "  ${RED}✗${NC} $1"
    FAIL=$((FAIL + 1))
    FAILED_TESTS+=("$1")
}

assert_eq() {
    local label="$1" actual="$2" expected="$3"
    if [ "$actual" = "$expected" ]; then
        pass_test "$label = $actual"
    else
        fail_test "$label: got '$actual', expected '$expected'"
    fi
}

assert_positive_ttl() {
    local key="$1"
    local ttl
    ttl=$(rcli TTL "$key")
    if [ -n "$ttl" ] && [ "$ttl" -gt 0 ] 2>/dev/null; then
        pass_test "TTL $key = ${ttl}s (activo)"
    else
        fail_test "TTL $key = '${ttl}' (esperado > 0)"
    fi
}

assert_hash_has_fields() {
    local key="$1"
    shift
    local hkeys
    hkeys=$(rcli HKEYS "$key" | sort)
    for field in "$@"; do
        if echo "$hkeys" | grep -qx "$field"; then
            pass_test "HKEYS $key ∋ '$field'"
        else
            fail_test "HKEYS $key falta campo '$field'"
        fi
    done
}

assert_set_has_members() {
    local key="$1"
    shift
    local smembers
    smembers=$(rcli SMEMBERS "$key")
    for m in "$@"; do
        if echo "$smembers" | grep -qx "$m"; then
            pass_test "SMEMBERS $key ∋ '$m'"
        else
            fail_test "SMEMBERS $key falta miembro '$m'"
        fi
    done
}

section() {
    echo ""
    echo -e "${YELLOW}── $1 ──${NC}"
}

# ── Connectivity ──────────────────────────────────────────────────────────────
echo "Redis Seed Integrity Test — contrato v2.0"
echo "==========================================="
echo "Container : $REDIS_CONTAINER"
echo "DB        : $REDIS_DB"
echo "Ref date  : $REFERENCE_DATE"
echo ""

if ! rcli PING | grep -q "PONG"; then
    echo -e "${RED}FATAL: No se puede conectar al contenedor '$REDIS_CONTAINER'${NC}"
    exit 1
fi

# ── 1. Counts ─────────────────────────────────────────────────────────────────
section "1. Conteos de keyspace"

assert_eq "ZCARD users:geo" "$(rcli ZCARD users:geo)" "200"

for rid in 1 2 3 4 5; do
    assert_eq "LLEN route:points:$rid" "$(rcli LLEN "route:points:$rid")" "5"
    assert_eq "ZCARD points:ruta:$rid" "$(rcli ZCARD "points:ruta:$rid")" "5"
done

# ── 2. user:{id} HASH — campos del contrato ───────────────────────────────────
section "2. user:{id} HASH campos"

for uid in 100 199 299; do
    assert_hash_has_fields "user:$uid" \
        alias email colonia_id fcm_token fcm_status fcm_created_at fcm_expires_at updated_at
done

# ── 3. point:{id} HASH — campos del contrato ─────────────────────────────────
section "3. point:{id} HASH campos"

for pid in 1 12 25; do
    assert_hash_has_fields "point:$pid" \
        route_id colonia_id point_code label lat lon
done

# ── 4. route:{id} HASH — campos del contrato ─────────────────────────────────
section "4. route:{id} HASH campos"

for rid in 1 3 5; do
    assert_hash_has_fields "route:$rid" \
        name description colonia_id zone shift total_points status
done

# ── 5. truck:state:{id} HASH + TTL ───────────────────────────────────────────
section "5. truck:state:{id} HASH + TTL"

# Assigned trucks: route 1→truck 1, route 2→truck 5, route 3→truck 2, route 4→truck 3, route 5→truck 4
for tid in 1 2 3 4 5; do
    assert_hash_has_fields "truck:state:$tid" \
        route_id current_point_id state lat lon updated_at assignment_source
    assert_positive_ttl "truck:state:$tid"
done

# ── 6. notification:sent SET members + TTL ───────────────────────────────────
section "6. notification:sent SET"

notif_key="notification:sent:100:1:${REFERENCE_DATE}"
assert_set_has_members "$notif_key" WARN ARRIVAL DEPARTURE COMEBACK
assert_positive_ttl "$notif_key"

# ── 7. seed:metadata ─────────────────────────────────────────────────────────
section "7. seed:metadata"

assert_eq "contract_version"    "$(rcli HGET seed:metadata contract_version)"    "2.0"
assert_eq "reference_date"      "$(rcli HGET seed:metadata reference_date)"      "$REFERENCE_DATE"
assert_eq "expected_users"      "$(rcli HGET seed:metadata expected_users)"      "200"
assert_eq "expected_points"     "$(rcli HGET seed:metadata expected_points)"     "25"
assert_eq "expected_routes"     "$(rcli HGET seed:metadata expected_routes)"     "5"
assert_eq "expected_colonias"   "$(rcli HGET seed:metadata expected_colonias)"   "8"
assert_eq "expected_trucks"     "$(rcli HGET seed:metadata expected_trucks)"     "6"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "==========================================="
echo -e "Resultado: ${GREEN}${PASS} pasaron${NC}  ${RED}${FAIL} fallaron${NC}"

if [ "${#FAILED_TESTS[@]}" -gt 0 ]; then
    echo ""
    echo -e "${RED}Tests fallidos:${NC}"
    for t in "${FAILED_TESTS[@]}"; do
        echo "  - $t"
    done
fi

echo "==========================================="

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi

exit 0
