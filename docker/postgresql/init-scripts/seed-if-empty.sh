#!/bin/sh

set -e

# =====================
# SEED CON VERSIONING
# =====================
# Script ejecutado DESPUÉS de 00-init-database.sh
# Verifica si hay datos antes de ejecutar seed

# =====================
# VARIABLES DE ENTORNO
# =====================
DB_NAME="${POSTGRES_DB:-proyecto_recolecta}"
DB_USER="${POSTGRES_USER:-recolecta}"
DB_PORT="${POSTGRES_PORT:-5432}"
DB_HOST="/var/run/postgresql"
export PGPASSWORD="${POSTGRES_PASSWORD:-${DB_PASSWORD:-}}"
SEED_PATH="/docker-entrypoint-initdb.d/04-seed.sql.skip"
SEED_MODE="${DB_SEED_MODE:-backend}"

# =====================
# COLORES PARA OUTPUT
# =====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =====================
# FUNCIONES
# =====================

log_info() {
    echo -e "${BLUE}[SEED]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Calcular checksum SHA256 de archivo (soporta sha256sum o openssl)
compute_checksum() {
    file="$1"
    if [ ! -f "$file" ]; then
        echo ""
        return
    fi
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
    elif command -v openssl >/dev/null 2>&1; then
        openssl dgst -sha256 "$file" | awk '{print $2}'
    else
        echo ""
    fi
}

check_seed_applied() {
    local seed_checksum="$1"
    local result
    result=$(psql -U "$DB_USER" -p "$DB_PORT" -h "$DB_HOST" -d "$DB_NAME" -t -c \
        "SELECT EXISTS(SELECT 1 FROM schema_version WHERE script_name = 'seed.sql' AND checksum = '$seed_checksum');" 2>/dev/null || echo "f")
    echo "$result" | tr -d '[:space:]'
}

check_table_has_data() {
    local table_name=$1
    local count
    count=$(psql -U "$DB_USER" -p "$DB_PORT" -h "$DB_HOST" -d "$DB_NAME" -t -c \
        "SELECT COUNT(*) FROM $table_name LIMIT 1;" 2>/dev/null || echo "0")
    echo "$count" | tr -d '[:space:]'
}

# =====================
# MAIN SCRIPT
# =====================

log_info "Verificando si se necesita ejecutar seed..."

if [ "$SEED_MODE" = "backend" ]; then
    log_warning "DB_SEED_MODE=backend: se omite seed SQL. Usa seeding por API en desarrollo."
    exit 0
fi

# Verificar si el archivo de seed existe
if [ ! -f "$SEED_PATH" ]; then
    log_warning "No se encontró archivo de seed: $SEED_PATH"
    exit 0
fi

# Verificar si ya se ejecutó este seed (usando checksum)
SEED_CHECKSUM=$(compute_checksum "$SEED_PATH")
if [ -n "$SEED_CHECKSUM" ] && [ "$(check_seed_applied "$SEED_CHECKSUM")" = "t" ]; then
    log_warning "Seed ya fue aplicado anteriormente (checksum: $SEED_CHECKSUM)"
    exit 0
fi

# Verificar si la tabla centinela tiene datos
ROL_COUNT=$(check_table_has_data "rol")

if [ "$ROL_COUNT" != "0" ] && [ -n "$ROL_COUNT" ]; then
    log_warning "Tabla 'rol' ya contiene datos ($ROL_COUNT registros). Omitiendo seed."
    # Registrar el seed como aplicado aunque no se ejecute (datos ya existen)
    if [ -n "$SEED_CHECKSUM" ]; then
        psql -U "$DB_USER" -p "$DB_PORT" -h "$DB_HOST" -d "$DB_NAME" -c \
            "INSERT INTO schema_version (script_name, type, checksum, description)
             VALUES ('seed.sql', 'seed', '$SEED_CHECKSUM', 'Seed data (omitido, datos preexistentes)')
             ON CONFLICT (script_name, checksum) DO NOTHING;" >/dev/null 2>&1
    fi
    exit 0
fi

# =====================
# EJECUTAR SEED
# =====================

log_info "Tabla 'rol' está vacía. Ejecutando seed..."

psql -U "$DB_USER" -p "$DB_PORT" -h "$DB_HOST" -d "$DB_NAME" -f "$SEED_PATH" 2>&1

if [ $? -eq 0 ]; then
    log_success "Seed ejecutado correctamente"

    # Registrar checksum del seed aplicado
    if [ -n "$SEED_CHECKSUM" ]; then
        psql -U "$DB_USER" -p "$DB_PORT" -h "$DB_HOST" -d "$DB_NAME" -c \
            "INSERT INTO schema_version (script_name, type, checksum, description)
             VALUES ('seed.sql', 'seed', '$SEED_CHECKSUM', 'Seed data inicial')
             ON CONFLICT (script_name, checksum) DO NOTHING;" >/dev/null 2>&1

        log_success "Seed checksum registrado: $SEED_CHECKSUM"
    fi

    # Reporte de datos insertados
    ROL_COUNT=$(check_table_has_data "rol")
    EMPLOYEE_COUNT=$(check_table_has_data "empleado")
    CAMION_COUNT=$(check_table_has_data "camion")
    COLONIA_COUNT=$(check_table_has_data "colonia")
    USUARIO_COUNT=$(check_table_has_data "ciudadano")

    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ SEED COMPLETADO${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo "Roles: $ROL_COUNT"
    echo "Colonias: $COLONIA_COUNT"
    echo "Empleados: $EMPLOYEE_COUNT"
    echo "Camiones: $CAMION_COUNT"
    echo "Ciudadanos: $USUARIO_COUNT"
    echo -e "${GREEN}========================================${NC}"
    echo ""
else
    log_error "Error al ejecutar seed"
    exit 1
fi

log_success "Script de seed finalizado"
