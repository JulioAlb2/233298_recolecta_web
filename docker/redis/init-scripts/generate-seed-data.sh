#!/bin/sh
# ============================================================================
# generate-seed-data.sh - Generador determinista del seed Redis
# ============================================================================

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SEEDS_DIR="$SCRIPT_DIR/../seeds"
CONTRACT_VERSION="2.0"
SEED_PREFIX="redis-seed_v2"
OUTPUT_FILE="$SEEDS_DIR/${SEED_PREFIX}_$(date '+%Y%m%d_%H%M%S').txt"
LATEST_LINK="$SEEDS_DIR/redis-seed-latest.txt"

BASE_LAT="16.5896"
BASE_LON="-93.0547"
EXPECTED_USERS="200"
EXPECTED_POINTS="25"
EXPECTED_ROUTES="5"
EXPECTED_COLONIAS="8"
EXPECTED_TRUCKS="6"
EXPECTED_ASSIGNED_TRUCKS="5"
REFERENCE_DATE="2026-01-30"

mkdir -p "$SEEDS_DIR"
> "$OUTPUT_FILE"

emit_collection() {
    printf '# COLLECTION: %s\n' "$1" >> "$OUTPUT_FILE"
}

emit_cmd() {
    first=1
    for arg in "$@"; do
        if [ "$first" -eq 1 ]; then
            printf '%s' "$arg" >> "$OUTPUT_FILE"
            first=0
        else
            printf '\t%s' "$arg" >> "$OUTPUT_FILE"
        fi
    done
    printf '\n' >> "$OUTPUT_FILE"
}

compute_checksum() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    elif command -v openssl >/dev/null 2>&1; then
        openssl dgst -sha256 "$1" | awk '{print $2}'
    else
        md5sum "$1" | awk '{print $1}'
    fi
}

coord_value() {
    base="$1"
    offset="$2"
    seed="$3"
    scale="$4"
    awk -v base="$base" -v offset="$offset" -v seed="$seed" -v scale="$scale" 'BEGIN {
        delta = (((seed * 37) % 201) - 100) * scale;
        printf "%.5f", base + offset + delta;
    }'
}

get_colonia() {
    case "$1" in
        1) echo "Centro Histórico|Centro|0.0000|0.0000" ;;
        2) echo "Colonia Industrial|Norte|0.0150|-0.0120" ;;
        3) echo "Las Palmas|Norte|0.0180|0.0080" ;;
        4) echo "Vista Hermosa|Sur|-0.0200|0.0100" ;;
        5) echo "Jardines del Valle|Sur|-0.0250|-0.0150" ;;
        6) echo "El Mirador|Centro|-0.0080|0.0150" ;;
        7) echo "Residencial San Miguel|Norte|0.0220|-0.0050" ;;
        8) echo "Fraccionamiento Los Pinos|Sur|-0.0120|-0.0200" ;;
        *) return 1 ;;
    esac
}

get_route() {
    case "$1" in
        1) echo "Ruta Norte A|Cobertura Colonia Industrial y Las Palmas|2|Norte|matutino|2,3|PR-NA" ;;
        2) echo "Ruta Norte B|Cobertura Residencial San Miguel|7|Norte|vespertino|7|PR-NB" ;;
        3) echo "Ruta Centro|Cobertura Centro Histórico y El Mirador|1|Centro|matutino|1,6|PR-CE" ;;
        4) echo "Ruta Sur A|Cobertura Vista Hermosa y Jardines del Valle|4|Sur|matutino|4,5|PR-SA" ;;
        5) echo "Ruta Sur B|Cobertura Fraccionamiento Los Pinos|8|Sur|vespertino|8|PR-SB" ;;
        *) return 1 ;;
    esac
}

get_route_colonia() {
    route_colonias="$1"
    point_index="$2"
    # Use printf '%s\n' to ensure a trailing newline so wc -l counts correctly
    # even when route_colonias is a single value with no commas (e.g. "7").
    count=$(printf '%s\n' "$route_colonias" | tr ',' '\n' | wc -l | tr -d ' ')
    pick=$((point_index % count + 1))
    printf '%s' "$route_colonias" | cut -d',' -f"$pick"
}

get_truck_assignment() {
    case "$1" in
        1) echo "1|1|IN_ROUTE|16.60425|-93.06600|registro_asignacion_ruta" ;;
        2) echo "3|11|IN_ROUTE|16.58910|-93.05340|registro_asignacion_ruta" ;;
        3) echo "4|16|IN_ROUTE|16.56910|-93.04590|registro_asignacion_ruta" ;;
        4) echo "5|21|IN_ROUTE|16.57850|-93.07380|registro_asignacion_ruta" ;;
        5) echo "2|6|IN_ROUTE|16.61110|-93.05920|registro_asignacion_ruta" ;;
        6) echo "0|0|IDLE|16.58960|-93.05470|sin_asignacion" ;;
        *) return 1 ;;
    esac
}

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Generando seed Redis determinista (contrato $CONTRACT_VERSION)..." >&2

emit_collection "points_geo"
point_id=1
for route_id in $(seq 1 5); do
    route_data=$(get_route "$route_id")
    route_colonias=$(printf '%s' "$route_data" | cut -d'|' -f6)
    route_prefix=$(printf '%s' "$route_data" | cut -d'|' -f7)
    for point_index in $(seq 0 4); do
        colonia_id=$(get_route_colonia "$route_colonias" "$point_index")
        colonia_data=$(get_colonia "$colonia_id")
        colonia_name=$(printf '%s' "$colonia_data" | cut -d'|' -f1)
        lat_offset=$(printf '%s' "$colonia_data" | cut -d'|' -f3)
        lon_offset=$(printf '%s' "$colonia_data" | cut -d'|' -f4)
        point_lat=$(coord_value "$BASE_LAT" "$lat_offset" "$point_id" "0.00003")
        point_lon=$(coord_value "$BASE_LON" "$lon_offset" "$point_id" "0.00003")
        point_code=$(printf '%s-%03d' "$route_prefix" $((point_index + 1)))
        label=$(printf '%s · %s' "$point_code" "$colonia_name")

        emit_cmd GEOADD "points:ruta:$route_id" "$point_lon" "$point_lat" "$point_id"
        emit_cmd HSET "point:$point_id" \
            route_id "$route_id" \
            colonia_id "$colonia_id" \
            point_code "$point_code" \
            label "$label" \
            lat "$point_lat" \
            lon "$point_lon"

        point_id=$((point_id + 1))
    done
done

emit_collection "users"
for user_id in $(seq 100 299); do
    user_offset=$((user_id - 100))
    colonia_id=$(((user_offset % 8) + 1))
    colonia_data=$(get_colonia "$colonia_id")
    lat_offset=$(printf '%s' "$colonia_data" | cut -d'|' -f3)
    lon_offset=$(printf '%s' "$colonia_data" | cut -d'|' -f4)
    user_lat=$(coord_value "$BASE_LAT" "$lat_offset" "$user_id" "0.00008")
    user_lon=$(coord_value "$BASE_LON" "$lon_offset" "$user_id" "0.00008")
    alias="user$user_id"
    email="$alias@example.com"
    fcm_token="fcm-$alias-redis-contract-v2"

    emit_cmd GEOADD "users:geo" "$user_lon" "$user_lat" "$user_id"
    emit_cmd HSET "user:$user_id" \
        alias "$alias" \
        email "$email" \
        colonia_id "$colonia_id" \
        fcm_token "$fcm_token" \
        fcm_status "valid" \
        fcm_created_at "2026-01-01T00:00:00Z" \
        fcm_expires_at "2026-03-01T00:00:00Z" \
        updated_at "2026-01-30T06:00:00Z"
done

emit_collection "routes"
point_start=1
for route_id in $(seq 1 5); do
    route_data=$(get_route "$route_id")
    route_name=$(printf '%s' "$route_data" | cut -d'|' -f1)
    route_description=$(printf '%s' "$route_data" | cut -d'|' -f2)
    colonia_id=$(printf '%s' "$route_data" | cut -d'|' -f3)
    route_zone=$(printf '%s' "$route_data" | cut -d'|' -f4)
    route_shift=$(printf '%s' "$route_data" | cut -d'|' -f5)

    emit_cmd RPUSH "route:points:$route_id" "$point_start" "$((point_start + 1))" "$((point_start + 2))" "$((point_start + 3))" "$((point_start + 4))"
    emit_cmd HSET "route:$route_id" \
        name "$route_name" \
        description "$route_description" \
        colonia_id "$colonia_id" \
        zone "$route_zone" \
        shift "$route_shift" \
        total_points "5" \
        status "active"

    point_start=$((point_start + 5))
done

emit_collection "truck_state"
for truck_id in $(seq 1 6); do
    truck_data=$(get_truck_assignment "$truck_id")
    route_id=$(printf '%s' "$truck_data" | cut -d'|' -f1)
    current_point_id=$(printf '%s' "$truck_data" | cut -d'|' -f2)
    truck_state=$(printf '%s' "$truck_data" | cut -d'|' -f3)
    truck_lat=$(printf '%s' "$truck_data" | cut -d'|' -f4)
    truck_lon=$(printf '%s' "$truck_data" | cut -d'|' -f5)
    assignment_source=$(printf '%s' "$truck_data" | cut -d'|' -f6)

    emit_cmd HSET "truck:state:$truck_id" \
        route_id "$route_id" \
        current_point_id "$current_point_id" \
        state "$truck_state" \
        lat "$truck_lat" \
        lon "$truck_lon" \
        updated_at "2026-01-30T06:00:00Z" \
        assignment_source "$assignment_source"
    emit_cmd EXPIRE "truck:state:$truck_id" "86400"
done

emit_collection "truck_history"
for truck_id in 1 2 3 4 5; do
    truck_data=$(get_truck_assignment "$truck_id")
    current_point_id=$(printf '%s' "$truck_data" | cut -d'|' -f2)
    previous_point_id=$((current_point_id - 1))
    emit_cmd RPUSH "truck:route:history:$truck_id:$REFERENCE_DATE" "$previous_point_id" "$current_point_id"
    emit_cmd EXPIRE "truck:route:history:$truck_id:$REFERENCE_DATE" "86400"
done
emit_cmd RPUSH "truck:route:history:6:$REFERENCE_DATE" "IDLE"
emit_cmd EXPIRE "truck:route:history:6:$REFERENCE_DATE" "86400"

emit_collection "historial_vaciado"
for record in \
    "1|1|camion:1|ts:1769731200|status:completado" \
    "1|2|camion:5|ts:1769734800|status:completado" \
    "3|1|camion:2|ts:1769738400|status:completado" \
    "4|2|camion:3|ts:1769742000|status:completado" \
    "5|1|camion:4|ts:1769745600|status:completado"
do
    route_id=$(printf '%s' "$record" | cut -d'|' -f1)
    landfill_id=$(printf '%s' "$record" | cut -d'|' -f2)
    payload=$(printf '%s' "$record" | cut -d'|' -f3-)
    emit_cmd RPUSH "historial:vaciado:$route_id:$landfill_id" "$payload"
done

emit_collection "notifications"
for user_id in $(seq 100 110); do
    for truck_id in 1 2 3; do
        notif_key="notification:sent:$user_id:$truck_id:$REFERENCE_DATE"
        emit_cmd SADD "$notif_key" "WARN" "ARRIVAL" "DEPARTURE" "COMEBACK"
        emit_cmd EXPIRE "$notif_key" "86400"
    done
done

for state in WARN ARRIVAL DEPARTURE COMEBACK; do
    notification_id="notification:seed:100:1:$state"
    emit_cmd HSET "$notification_id" \
        type "$state" \
        status "delivered" \
        truck_id "1" \
        point_id "1" \
        timestamp "2026-01-30T08:15:00Z"
    emit_cmd EXPIRE "$notification_id" "604800"
done
emit_cmd ZADD "notification:log:100" \
    "1769760900" "notification:seed:100:1:WARN" \
    "1769761200" "notification:seed:100:1:ARRIVAL" \
    "1769761500" "notification:seed:100:1:DEPARTURE" \
    "1769761800" "notification:seed:100:1:COMEBACK"
emit_cmd EXPIRE "notification:log:100" "604800"

emit_collection "notification_metrics"
for truck_id in $(seq 1 6); do
    emit_cmd HSET "metrics:notifications:$truck_id:$REFERENCE_DATE" \
        total_sent "0" \
        warn_count "0" \
        arrival_count "0" \
        departure_count "0" \
        comeback_count "0" \
        delivery_success "0" \
        delivery_failed "0"
    emit_cmd EXPIRE "metrics:notifications:$truck_id:$REFERENCE_DATE" "604800"
done

emit_collection "seed_metadata"
emit_cmd HSET "seed:metadata" \
    contract_version "$CONTRACT_VERSION" \
    expected_users "$EXPECTED_USERS" \
    expected_points "$EXPECTED_POINTS" \
    expected_routes "$EXPECTED_ROUTES" \
    expected_colonias "$EXPECTED_COLONIAS" \
    expected_trucks "$EXPECTED_TRUCKS" \
    expected_assigned_trucks "$EXPECTED_ASSIGNED_TRUCKS" \
    reference_date "$REFERENCE_DATE"

payload_checksum=$(compute_checksum "$OUTPUT_FILE")
generated_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

tmp_file="${OUTPUT_FILE}.tmp"
printf '# SEED-METADATA: contract_version=%s payload_checksum=%s expected_users=%s expected_points=%s expected_routes=%s expected_colonias=%s expected_trucks=%s expected_assigned_trucks=%s reference_date=%s generated_at=%s\n' \
    "$CONTRACT_VERSION" \
    "$payload_checksum" \
    "$EXPECTED_USERS" \
    "$EXPECTED_POINTS" \
    "$EXPECTED_ROUTES" \
    "$EXPECTED_COLONIAS" \
    "$EXPECTED_TRUCKS" \
    "$EXPECTED_ASSIGNED_TRUCKS" \
    "$REFERENCE_DATE" \
    "$generated_at" > "$tmp_file"
cat "$OUTPUT_FILE" >> "$tmp_file"
mv "$tmp_file" "$OUTPUT_FILE"

ln -sf "$(basename "$OUTPUT_FILE")" "$LATEST_LINK"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ Seed generado: $OUTPUT_FILE" >&2
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ Checksum payload: $payload_checksum" >&2
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ Symlink actualizado: $(basename "$LATEST_LINK")" >&2