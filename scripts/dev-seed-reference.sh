#!/bin/sh
set -eu

DB_HOST="${DB_HOST:-postgres_db}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-proyecto_recolecta}"
DB_USER="${DB_USER:-recolecta}"
DB_PASSWORD="${DB_PASSWORD:-}"

if [ -z "$DB_PASSWORD" ]; then
  echo "[seed-reference] Falta DB_PASSWORD"
  exit 1
fi

export PGPASSWORD="$DB_PASSWORD"

echo "[seed-reference] Esperando PostgreSQL en $DB_HOST:$DB_PORT/$DB_NAME"
for i in $(seq 1 45); do
  if pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; then
    break
  fi
  if [ "$i" -eq 45 ]; then
    echo "[seed-reference] PostgreSQL no disponible"
    exit 1
  fi
  sleep 2
done

echo "[seed-reference] Aplicando datos de referencia (colonias, camiones, rutas GPS...)"
psql -v ON_ERROR_STOP=1 -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f /seed/dev-seed-reference.sql

echo "[seed-reference] Datos de referencia listos"
