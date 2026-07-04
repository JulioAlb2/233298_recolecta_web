#!/bin/sh

set -e

# =====================
# VARIABLES DE ENTORNO
# =====================
DB_NAME="${POSTGRES_DB:-proyecto_recolecta}"
DB_USER="${POSTGRES_USER:-recolecta}"
DB_PORT="${POSTGRES_PORT:-5432}"
# Usamos socket local para evitar problemas de auth en TCP durante init
DB_HOST="/var/run/postgresql"
# BD base para chequeos (siempre existe)
DEFAULT_DB="postgres"
# Password para conexiones no interactuantes
export PGPASSWORD="${POSTGRES_PASSWORD:-${DB_PASSWORD:-}}"
# Montamos el SQL con sufijo .skip para evitar que el entrypoint lo ejecute por defecto
SCRIPT_PATH="/docker-entrypoint-initdb.d/01-db_script.sql.skip"
SCHEMA_CONSTRAINTS_PATH="/docker-entrypoint-initdb.d/02-db_constraints.sql.skip"
SCHEMA_INDEXES_PATH="/docker-entrypoint-initdb.d/03-db_indexes.sql.skip"
# Seed
SEED_PATH="/docker-entrypoint-initdb.d/04-seed.sql.skip"

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
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

database_exists() {
    local query="SELECT 1 FROM pg_database WHERE datname = '$DB_NAME';"
    local result

    result=$(psql -U "$DB_USER" -p "$DB_PORT" -h "$DB_HOST" -d "$DEFAULT_DB" -t -c "$query" 2>/dev/null || echo "")

    if [ -z "$result" ]; then
        return 1  # BD no existe
    else
        return 0  # BD existe
    fi
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

# =====================
# MAIN SCRIPT
# =====================

log_info "Iniciando script de inicialización de base de datos..."
log_info "Base de datos: $DB_NAME"
log_info "Usuario: $DB_USER"
log_info "Puerto: $DB_PORT"
log_info "Seed path: $SEED_PATH"

# Esperar a que PostgreSQL esté listo
log_info "Esperando a que PostgreSQL esté disponible..."
for i in $(seq 1 30); do
    if pg_isready -U "$DB_USER" -p "$DB_PORT" -h "$DB_HOST" -d "$DEFAULT_DB" >/dev/null 2>&1; then
        log_success "PostgreSQL está disponible"
        break
    fi

    if [ "$i" -eq 30 ]; then
        log_error "PostgreSQL no está disponible después de 30 intentos"
        exit 1
    fi

    sleep 1
done

CREATED_DB=0

# =====================
# VERIFICAR SI BD EXISTE
# =====================

# Crear/Verificar schema_version (orchestration table)
    log_info "Verificando tabla de versioning..."
    psql -U "$DB_USER" -p "$DB_PORT" -h "$DB_HOST" -d "$DB_NAME" <<-EOSQL
        CREATE TABLE IF NOT EXISTS schema_version (
            version_id SERIAL PRIMARY KEY,
            script_name VARCHAR(255) NOT NULL,
            type VARCHAR(20) NOT NULL,
            checksum VARCHAR(64) NOT NULL,
            description TEXT,
            applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            applied_by VARCHAR(100) DEFAULT CURRENT_USER,
            UNIQUE (script_name, checksum)
        );
EOSQL

if database_exists; then
    log_success "Tabla schema_version verificada"
    log_warning "La base de datos '$DB_NAME' ya existe"
    log_info "Ejecutando script desde línea 6 en adelante (omitiendo CREATE DATABASE)..."

    tail -n +6 "$SCRIPT_PATH" | psql -U "$DB_USER" -p "$DB_PORT" -h "$DB_HOST" -d "$DB_NAME" 2>&1

    if [ $? -eq 0 ]; then
        log_success "Script ejecutado exitosamente (modo de actualización)"
        # Registrar checksum del schema aplicado (modo actualización)
        schema_checksum=$(compute_checksum "$SCRIPT_PATH" || echo "")
        if [ -n "$schema_checksum" ]; then
            psql -U "$DB_USER" -p "$DB_PORT" -h "$DB_HOST" -d "$DB_NAME" <<-EOSQL
                INSERT INTO schema_version (script_name, type, checksum, description)
                VALUES ('db_script.sql', 'schema', '$schema_checksum', 'applied update')
                ON CONFLICT (script_name, checksum) DO NOTHING;
EOSQL
            log_info "Registrado schema checksum: $schema_checksum"
        fi
    else
        log_error "Error al ejecutar el script"
        exit 1
    fi
else
    log_info "La base de datos '$DB_NAME' no existe"
    log_info "Ejecutando script completo (creando BD)..."
    CREATED_DB=1

    # Ejecutar script completo
    psql -U "$DB_USER" -p "$DB_PORT" -h "$DB_HOST" -d "$DEFAULT_DB" -f "$SCRIPT_PATH" 2>&1

    if [ $? -eq 0 ]; then
        log_success "Script ejecutado exitosamente (primera creación)"
        # Registrar checksum del schema aplicado (primera creación)
        schema_checksum=$(compute_checksum "$SCRIPT_PATH" || echo "")
        if [ -n "$schema_checksum" ]; then
            psql -U "$DB_USER" -p "$DB_PORT" -h "$DB_HOST" -d "$DB_NAME" <<-EOSQL
                INSERT INTO schema_version (script_name, type, checksum, description)
                VALUES ('db_script.sql', 'schema', '$schema_checksum', 'initial apply')
                ON CONFLICT (script_name, checksum) DO NOTHING;
EOSQL
            log_info "Registrado schema checksum: $schema_checksum"
        fi
    else
        log_error "Error al ejecutar el script"
        exit 1
    fi

    # Crear schema_version en primera creación (orchestration table)
    log_info "Creando tabla de versioning..."
    psql -U "$DB_USER" -p "$DB_PORT" -h "$DB_HOST" -d "$DB_NAME" <<-EOSQL
        CREATE TABLE IF NOT EXISTS schema_version (
            version_id SERIAL PRIMARY KEY,
            script_name VARCHAR(255) NOT NULL,
            type VARCHAR(20) NOT NULL,
            checksum VARCHAR(64) NOT NULL,
            description TEXT,
            applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            applied_by VARCHAR(100) DEFAULT CURRENT_USER,
            UNIQUE (script_name, checksum)
        );
EOSQL
    log_success "Tabla schema_version creada"
fi

# Nota: el seed se ejecuta en 01-seed-if-empty.sh para centralizar estrategia
# (sql/backend) y evitar ejecución duplicada.


# =====================
# REPORTE FINAL
# =====================

log_info "Obteniendo estadísticas finales..."

TABLE_COUNT=$(psql -U "$DB_USER" -p "$DB_PORT" -h "$DB_HOST" -d "$DB_NAME" -t -c \
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';")

INDEX_COUNT=$(psql -U "$DB_USER" -p "$DB_PORT" -h "$DB_HOST" -d "$DB_NAME" -t -c \
    "SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'public';")

echo ""
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}✓ INICIALIZACIÓN COMPLETADA${NC}"
echo -e "${GREEN}==========================================${NC}"
echo "Base de datos: $DB_NAME"
echo "Tablas: $TABLE_COUNT"
echo "Índices: $INDEX_COUNT"
echo -e "${GREEN}==========================================${NC}"
echo ""

log_success "Script de inicialización finalizado"
