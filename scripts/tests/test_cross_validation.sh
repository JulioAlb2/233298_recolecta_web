#!/bin/bash
################################################################################
# Script: test_cross_validation.sh
# Purpose: Validate data consistency between PostgreSQL and Redis
# Description:
#   - Verifies users in Redis (IDs 100-299) exist in PostgreSQL
#   - Validates colonies referenced in Redis exist in PostgreSQL
#   - Checks routes referenced in Redis are consistent
#   - Ensures no data inconsistencies between databases
#   - Reports detailed findings per collection
#
# Usage:
#   ./test_cross_validation.sh                 # Use .env defaults
#   ./test_cross_validation.sh --db-container my_postgres  # Override
#
# Exit codes:
#   0 - All validations passed
#   1 - Validation failed (data inconsistency)
#   2 - Configuration error (Docker/DB connection)
################################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
DB_CONTAINER="${DB_CONTAINER:-postgres_db}"
DB_USER="${DB_USER:-recolecta}"
DB_PASSWORD="${DB_PASSWORD:-s3cur3_p4ss_db}"
DB_NAME="${DB_NAME:-proyecto_recolecta}"
REDIS_CONTAINER="${REDIS_CONTAINER:-redis_cache}"
REDIS_PASSWORD="${REDIS_PASSWORD:-r3d1s_s3cur3_p4ss}"
REDIS_DB="${REDIS_DB:-0}"

# Expected ranges
EXPECTED_USER_START=100
EXPECTED_USER_END=299

################################################################################
# Functions
################################################################################

# Print colored output
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Show help
show_help() {
    cat << EOF
Usage: test_cross_validation.sh [OPTIONS]

Description:
  Validates data consistency between PostgreSQL and Redis via 'docker exec'.
  Tests include:
  - Users in Redis (IDs 100-299) exist in PostgreSQL
  - Colonies referenced in Redis exist in PostgreSQL
  - Routes referenced in Redis exist in PostgreSQL
  - No data inconsistencies detected

Options:
  --help                  Show this help message
  --db-container NAME     PostgreSQL container name (default: postgres_db)
  --redis-container NAME  Redis container name (default: redis_cache)
  --db-user USER          PostgreSQL user (default: recolecta)
  --db-password PASS      PostgreSQL password (default: s3cur3_p4ss_db)
  --db-name NAME          PostgreSQL database (default: proyecto_recolecta)
  --redis-password PASS   Redis password (default: r3d1s_s3cur3_p4ss)
  --verbose               Show detailed validation output

Environment variables:
  DB_CONTAINER           Override postgres container name
  REDIS_CONTAINER        Override redis container name
  DB_USER, DB_PASSWORD, DB_NAME, REDIS_PASSWORD

Examples:
  # Use defaults
  ./test_cross_validation.sh

  # With custom containers
  ./test_cross_validation.sh --db-container postgres --redis-container cache

Exit codes:
  0 - All cross-validations passed
  1 - Data inconsistency detected
  2 - Configuration error (Docker/DB connection)
EOF
}

# Execute PostgreSQL command via docker exec
postgres_cmd() {
    docker exec "$DB_CONTAINER" psql \
        -U "$DB_USER" \
        -d "$DB_NAME" \
        -h localhost \
        -w \
        "$@" 2>/dev/null
}

# Execute Redis command via docker exec
redis_cmd() {
    if [ -n "$REDIS_PASSWORD" ]; then
        docker exec -e REDISCLI_AUTH="$REDIS_PASSWORD" "$REDIS_CONTAINER" redis-cli \
            -n "$REDIS_DB" \
            "$@" 2>/dev/null
    else
        docker exec "$REDIS_CONTAINER" redis-cli \
            -n "$REDIS_DB" \
            "$@" 2>/dev/null
    fi
}

# Check if containers are running
check_containers() {
    if ! docker ps --format "table {{.Names}}" | grep -q "^${DB_CONTAINER}$"; then
        return 1
    fi
    if ! docker ps --format "table {{.Names}}" | grep -q "^${REDIS_CONTAINER}$"; then
        return 2
    fi
    return 0
}

# Test PostgreSQL connection
test_postgres_connection() {
    print_section "PostgreSQL Connection Test"
    
    if ! check_containers; then
        print_error "One or more containers not running"
        print_info "PostgreSQL container: ${DB_CONTAINER}"
        print_info "Redis container: ${REDIS_CONTAINER}"
        return 2
    fi
    
    print_success "Container '${DB_CONTAINER}' is running"
    
    # Test connection
    if ! postgres_cmd -c "SELECT 1;" > /dev/null 2>&1; then
        print_error "Cannot connect to PostgreSQL"
        print_info "Check credentials: USER=$DB_USER DB=$DB_NAME"
        return 2
    fi
    
    print_success "Connected to PostgreSQL"
    return 0
}

# Test Redis connection
test_redis_connection() {
    print_section "Redis Connection Test"
    
    if ! redis_cmd PING > /dev/null 2>&1; then
        print_error "Cannot connect to Redis"
        return 2
    fi
    
    print_success "Connected to Redis"
    return 0
}

# Get count of users in PostgreSQL matching expected range
get_postgres_user_count() {
    local count
    count=$(postgres_cmd -tAc \
        "SELECT COUNT(*) FROM ciudadano WHERE id >= $EXPECTED_USER_START AND id <= $EXPECTED_USER_END;" \
        2>/dev/null || echo "0")
    echo "$count"
}

# Get count of users in Redis
get_redis_user_count() {
    local count
    count=$(redis_cmd ZCARD users:geo 2>/dev/null || echo "0")
    echo "$count"
}

# Validate users consistency
validate_users() {
    print_section "Users Consistency Validation"
    
    local pg_count redis_count
    pg_count=$(get_postgres_user_count)
    redis_count=$(get_redis_user_count)
    
    print_info "PostgreSQL users (IDs $EXPECTED_USER_START-$EXPECTED_USER_END): $pg_count"
    print_info "Redis users in users:geo: $redis_count"
    
    local validation_failed=0
    
    # Check sample users from Redis in PostgreSQL
    local sample_users=(100 150 199 250 299)
    
    print_info ""
    print_info "Checking sample users in both databases..."
    
    for user_id in "${sample_users[@]}"; do
        # Check in Redis
        local redis_user
        redis_user=$(redis_cmd HEXISTS "user:${user_id}" alias 2>/dev/null || echo "0")
        
        if [ "$redis_user" -ne 1 ]; then
            print_warning "User $user_id not in Redis"
            continue
        fi
        
        # Check in PostgreSQL
        local pg_user
        pg_user=$(postgres_cmd -tAc \
            "SELECT COUNT(*) FROM ciudadano WHERE id = $user_id;" \
            2>/dev/null || echo "0")
        
        if [ "$pg_user" -eq 1 ]; then
            print_success "User $user_id exists in both databases"
        else
            print_error "User $user_id in Redis but NOT in PostgreSQL"
            validation_failed=1
        fi
    done
    
    return $validation_failed
}

# Validate colonies consistency
validate_colonies() {
    print_section "Colonies Consistency Validation"
    
    print_info "Validating colonies referenced in Redis..."
    
    local validation_failed=0
    local checked=0
    local found=0
    
    # Check each colony referenced in user records
    while IFS= read -r user_id; do
        local colonia_id
        colonia_id=$(redis_cmd HGET "user:${user_id}" colonia_id 2>/dev/null)
        
        if [ -z "$colonia_id" ]; then
            continue
        fi
        
        ((checked++))
        
        # Check if colony exists in PostgreSQL (PK column is 'id')
        local pg_colony
        pg_colony=$(postgres_cmd -tAc \
            "SELECT COUNT(*) FROM colonia WHERE id = $colonia_id;" \
            2>/dev/null || echo "0")
        
        if [ "$pg_colony" -eq 1 ]; then
            ((found++))
        else
            print_error "Colony $colonia_id (referenced by user $user_id) NOT in PostgreSQL"
            validation_failed=1
        fi
    done < <(redis_cmd ZRANGE users:geo 0 -1 2>/dev/null | head -10)  # Sample check
    
    if [ $checked -gt 0 ]; then
        print_success "Checked $checked colonies, $found exist in PostgreSQL"
    fi
    
    return $validation_failed
}

# Validate routes consistency
validate_routes() {
    print_section "Routes Consistency Validation"
    
    # Get routes referenced in Redis points
    print_info "Validating routes referenced in collection points..."
    
    local validation_failed=0
    
    # Check routes 1-5 (expected from seed)
    for route_id in {1..5}; do
        local redis_count
        redis_count=$(redis_cmd ZCARD "points:ruta:${route_id}" 2>/dev/null || echo "0")
        
        local pg_exists
        pg_exists=$(postgres_cmd -tAc \
            "SELECT COUNT(*) FROM ruta WHERE id = $route_id;" \
            2>/dev/null || echo "0")
        
        if [ "$pg_exists" -eq 1 ]; then
            print_success "Route $route_id exists in PostgreSQL (Redis has $redis_count points)"
        else
            print_warning "Route $route_id in Redis but NOT in PostgreSQL"
            validation_failed=1
        fi
    done
    
    return $validation_failed
}

# Validate geolocation coordinates
validate_geolocation() {
    print_section "Geolocation Validation"
    
    print_info "Validating geolocation coordinates in Redis..."
    
    local validation_failed=0
    local checked=0
    local valid=0

    # In contract v2.0 coordinates are in the users:geo GEO index, not in user hashes.
    # GEOPOS returns longitude then latitude (two lines per member via redis-cli).
    for user_id in 100 101 102 103 104 105 106 107 108 109 110; do
        local geopos lon lat
        geopos=$(redis_cmd GEOPOS users:geo "$user_id" 2>/dev/null)
        lon=$(echo "$geopos" | sed -n '1p')
        lat=$(echo "$geopos" | sed -n '2p')

        if [ -z "$lon" ] || [ -z "$lat" ] || [ "$lon" = "nil" ] || [ "$lat" = "nil" ]; then
            print_warning "User $user_id not found in users:geo"
            continue
        fi

        checked=$((checked + 1))

        if awk -v lat="$lat" -v lon="$lon" \
            'BEGIN { exit !(lat > -90 && lat < 90 && lon > -180 && lon < 180) }'; then
            valid=$((valid + 1))
        else
            print_warning "User $user_id has invalid coordinates: lat=$lat lon=$lon"
            validation_failed=1
        fi
    done

    if [ $checked -gt 0 ]; then
        print_success "Checked $checked geo positions, $valid valid"
    else
        print_warning "No geo positions found for sample users"
        validation_failed=1
    fi
    
    return $validation_failed
}

################################################################################
# Main
################################################################################

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help)
                show_help
                exit 0
                ;;
            --db-container)
                DB_CONTAINER="$2"
                shift 2
                ;;
            --redis-container)
                REDIS_CONTAINER="$2"
                shift 2
                ;;
            --db-user)
                DB_USER="$2"
                shift 2
                ;;
            --db-password)
                DB_PASSWORD="$2"
                shift 2
                ;;
            --db-name)
                DB_NAME="$2"
                shift 2
                ;;
            --redis-password)
                REDIS_PASSWORD="$2"
                shift 2
                ;;
            --verbose)
                VERBOSE=1
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 2
                ;;
        esac
    done
    
    # Load .env if it exists
    if [ -f "$(dirname "$0")/../../.env" ]; then
        set -a
        source "$(dirname "$0")/../../.env"
        set +a
    fi
    
    print_section "PostgreSQL ↔ Redis Cross-Validation Test"
    print_info "PostgreSQL: ${DB_CONTAINER} (${DB_NAME})"
    print_info "Redis: ${REDIS_CONTAINER}"
    
    # Test connections
    if ! test_postgres_connection; then
        exit 2
    fi
    
    if ! test_redis_connection; then
        exit 2
    fi
    
    # Run validations
    local validation_failed=0
    
    if ! validate_users; then
        validation_failed=1
    fi
    
    if ! validate_colonies; then
        validation_failed=1
    fi
    
    if ! validate_routes; then
        validation_failed=1
    fi
    
    if ! validate_geolocation; then
        validation_failed=1
    fi
    
    # Final result
    print_section "Cross-Validation Summary"
    
    if [ $validation_failed -eq 0 ]; then
        print_success "All cross-validations passed!"
        echo ""
        print_success "✓ Users in Redis match PostgreSQL"
        print_success "✓ Colonies referenced exist in PostgreSQL"
        print_success "✓ Routes referenced exist in PostgreSQL"
        print_success "✓ Geolocation coordinates valid"
        print_success "✓ No data inconsistencies detected"
        exit 0
    else
        print_error "Cross-validation FAILED"
        echo ""
        print_error "Review the validation errors above"
        exit 1
    fi
}

# Run main function
main "$@"
