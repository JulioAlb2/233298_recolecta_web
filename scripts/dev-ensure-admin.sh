#!/bin/sh
set -eu

DB_HOST="${DB_HOST:-postgres_db}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-proyecto_recolecta}"
DB_USER="${DB_USER:-recolecta}"
DB_PASSWORD="${DB_PASSWORD:-}"

ADMIN_EMAIL="${ADMIN_EMAIL:-${ADMIN_MAIL:-}}"
ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
ADMIN_NOMBRE="${ADMIN_NOMBRE:-Admin}"
ADMIN_APELLIDOS="${ADMIN_APELLIDOS:-Sistema}"

if [ -z "$DB_PASSWORD" ]; then
  echo "[ensure-admin] Falta DB_PASSWORD"
  exit 1
fi
if [ -z "$ADMIN_EMAIL" ] || [ -z "$ADMIN_PASSWORD" ]; then
  echo "[ensure-admin] Faltan ADMIN_EMAIL (o ADMIN_MAIL) / ADMIN_PASSWORD"
  exit 1
fi

export PGPASSWORD="$DB_PASSWORD"

echo "[ensure-admin] Esperando PostgreSQL en $DB_HOST:$DB_PORT/$DB_NAME"
for i in $(seq 1 45); do
  if pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; then
    break
  fi
  if [ "$i" -eq 45 ]; then
    echo "[ensure-admin] PostgreSQL no disponible"
    exit 1
  fi
  sleep 2
done

echo "[ensure-admin] Upsert de rol/admin"
psql -v ON_ERROR_STOP=1 -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
  -v admin_email="$ADMIN_EMAIL" \
  -v admin_username="$ADMIN_USERNAME" \
  -v admin_password="$ADMIN_PASSWORD" \
  -v admin_nombre="$ADMIN_NOMBRE" \
  -v admin_apellidos="$ADMIN_APELLIDOS" <<'SQL'
CREATE EXTENSION IF NOT EXISTS pgcrypto;

INSERT INTO rol (id, nombre, active)
VALUES (1, 'Administrador', TRUE)
ON CONFLICT (id) DO UPDATE
SET nombre = EXCLUDED.nombre,
    active = TRUE;

UPDATE empleado
SET nombre = :'admin_nombre',
    apellidos = :'admin_apellidos',
    mail = lower(:'admin_email'),
    username = lower(:'admin_username'),
    password = crypt(:'admin_password', gen_salt('bf', 10)),
    desactivado = FALSE,
    rol_id = 1,
    deleted_at = NULL,
    updated_at = NOW()
WHERE lower(mail) = lower(:'admin_email')
   OR lower(username) = lower(:'admin_username');

INSERT INTO empleado (
  nombre, apellidos, mail, password, username,
  desactivado, rol_id, created_at, updated_at, deleted_at
)
SELECT
  :'admin_nombre', :'admin_apellidos', lower(:'admin_email'),
  crypt(:'admin_password', gen_salt('bf', 10)),
  lower(:'admin_username'),
  FALSE, 1, NOW(), NOW(), NULL
WHERE NOT EXISTS (
  SELECT 1
  FROM empleado
  WHERE lower(mail) = lower(:'admin_email')
     OR lower(username) = lower(:'admin_username')
);
SQL

echo "[ensure-admin] Admin listo: $ADMIN_EMAIL"
