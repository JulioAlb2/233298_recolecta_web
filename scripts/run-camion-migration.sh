#!/bin/sh
set -e

DB_NAME="${POSTGRES_DB:-proyecto_recolecta}"
DB_USER="${POSTGRES_USER:-recolecta_dev}"
DB_PORT="${POSTGRES_PORT:-5432}"
DB_HOST="${DB_HOST:-db}"
MIGRATION_FILE="${1:-docker/postgresql/migrations/004_migrate_camion_tipo_camion_schema.sql}"

export PGPASSWORD="${POSTGRES_PASSWORD:-${DB_PASSWORD:-dev_password_123}}"

if [ ! -f "$MIGRATION_FILE" ]; then
  echo "No se encontró la migración: $MIGRATION_FILE"
  exit 1
fi

echo "Aplicando migración: $MIGRATION_FILE"
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$MIGRATION_FILE"
echo "Migración aplicada correctamente."
