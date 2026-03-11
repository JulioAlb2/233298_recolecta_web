#!/bin/sh
# Valida migraciones/seed aplicadas en PostgreSQL (docker compose)
# Uso:
#   ./test_seed_validation.sh [--run-seed] [--mode checksum|structure|hybrid] [table1 table2 ...]
# - Modos:
#     checksum: sólo valida checksums registrados en la BD.
#     structure: sólo valida existencia de tablas y conteos mínimos.
#     hybrid: hace ambas (por defecto).
# - Si no se pasan tablas y el modo es `structure` o `hybrid`, se validan las tablas mínimas configuradas.
# - Si se pasa --run-seed ejecuta el seed.sql (ATENCIÓN: sólo si sabes que es seguro).

set -eu

# Cargar .env (tres niveles arriba)
ENV_PATH="$(dirname "$0")/../../../.env"
if [ -f "$ENV_PATH" ]; then
  export $(grep -v '^#' "$ENV_PATH" | xargs)
fi

DOCKER_COMPOSE_FILE="docker/docker.compose.yml"
PG_SERVICE=${PG_SERVICE:-database}

# Mapear variables DB_ a PG_ si las PG_ no existen
PGUSER="${PGUSER:-${DB_USER:-postgres}}"
PGDATABASE="${PGDATABASE:-${DB_NAME:-postgres}}"
PGHOST="${PGHOST:-${DB_HOST:-db}}"
PGPORT="${PGPORT:-${DB_PORT:-5432}}"

SEED_FILE_PATH="docker/postgresql/seeds/seed.sql"
SEED_CHECKS_FILE="scripts/tests/postgres/seed_checks.sql"

# Modo por defecto: hybrid (checksum + estructura mínima)
MODE="hybrid"

# Tablas mínimas para validación de estructura (espacio-separadas)
# Añadimos `colonia` y `domicilio` como solicitaste
MIN_TABLES="schema_version rol empleado ciudadano camion ruta punto_recoleccion colonia domicilio"

# Umbrales mínimos por tabla (devuelve número mínimo de filas esperado)
min_count_for_table() {
  case "$1" in
    schema_version) echo 1 ;; # debe existir registro de versiones
    rol) echo 5 ;;
    empleado) echo 12 ;;
    ciudadano) echo 200 ;;
    camion) echo 1 ;;
    ruta|Ruta) echo 1 ;;
    punto_recoleccion) echo 1 ;;
    colonia) echo 1 ;;
    domicilio) echo 1 ;;
    *) echo 0 ;;
  esac
}

# Función para calcular checksum en el host (sha256sum o openssl)
compute_checksum_host() {
  f="$1"
  if [ ! -f "$f" ]; then
    echo ""
    return
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$f" | awk '{print $2}'
  else
    echo ""
  fi
}

# Verificar que el checksum registrado en la BD coincide con el archivo local
check_registered_checksum() {
  local file_path="$1"; shift
  local script_name="$1"; shift
  local type="$1"; shift

  if [ ! -f "$file_path" ]; then
    echo "[WARN] Archivo local no encontrado: $file_path — omitiendo check de versión."
    return 0
  fi

  cs=$(compute_checksum_host "$file_path" || echo "")
  if [ -z "$cs" ]; then
    echo "[WARN] No se pudo calcular checksum de $file_path — omitiendo check."
    return 0
  fi

  # Consultar la tabla schema_version en la BD
  cnt=$(docker compose -f "$DOCKER_COMPOSE_FILE" exec -T "$PG_SERVICE" \
    psql -U "$PGUSER" -d "$PGDATABASE" -h "$PGHOST" -p "$PGPORT" -t -c "SELECT COUNT(*) FROM schema_version WHERE script_name = '$script_name' AND type = '$type' AND checksum = '$cs';" 2>/dev/null | tr -d ' ')

  if [ "x$cnt" = "x" ] || [ "$cnt" = "0" ]; then
    echo "[ERROR] Checksum no registrado en la BD para $script_name (esperado: $cs)"
    return 1
  fi

  echo "[OK] Checksum verificado para $script_name ($type)"
  return 0
}

# Ejecutar psql dentro del contenedor
pg_exec() {
  docker compose -f "$DOCKER_COMPOSE_FILE" exec -T "$PG_SERVICE" \
    psql -U "$PGUSER" -d "$PGDATABASE" -h "$PGHOST" -p "$PGPORT" -c "$1"
}

# Ejecutar fichero SQL dentro del contenedor (stdin safe)
pg_exec_file() {
  docker compose -f "$DOCKER_COMPOSE_FILE" exec -T "$PG_SERVICE" \
    psql -U "$PGUSER" -d "$PGDATABASE" -h "$PGHOST" -p "$PGPORT" -f - <<'PSQL_EOF'
$(cat "${1}")
PSQL_EOF
}

# Mostrar tablas actuales
list_tables() {
  echo "[SEED-VALIDATION] Listando tablas (schema.table):"
  docker compose -f "$DOCKER_COMPOSE_FILE" exec -T "$PG_SERVICE" \
    psql -U "$PGUSER" -d "$PGDATABASE" -h "$PGHOST" -p "$PGPORT" -c "\dt" || return 1
}

# Verificar existencia de tablas pasadas como argumentos
check_tables() {
  missing=0
  for t in "$@"; do
    # Buscar en information_schema para ser más robusto
    res=$(docker compose -f "$DOCKER_COMPOSE_FILE" exec -T "$PG_SERVICE" \
      psql -U "$PGUSER" -d "$PGDATABASE" -h "$PGHOST" -p "$PGPORT" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_name = '$t';" 2>/dev/null | tr -d ' ')
    if [ "x$res" = "x" ] || [ "$res" = "0" ]; then
      echo "[ERROR] Tabla esperada no encontrada: $t"
      missing=1
    else
      echo "[OK] Tabla encontrada: $t"
    fi
  done
  return $missing
}

# Ejecutar comprobaciones de datos definidas en SEED_CHECKS_FILE
run_seed_checks() {
  if [ -f "$SEED_CHECKS_FILE" ]; then
    echo "[SEED-VALIDATION] Ejecutando checks de seed en $SEED_CHECKS_FILE"
    # El formato esperado: cada línea es una consulta que debe devolver al menos una fila, comentarios con --
    failed=0
    while IFS= read -r line || [ -n "$line" ]; do
      # Saltar líneas vacías y comentarios
      trimmed=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
      case "$trimmed" in
        ''|--*) continue ;;
      esac
      echo "[CHECK] $trimmed"
      out=$(docker compose -f "$DOCKER_COMPOSE_FILE" exec -T "$PG_SERVICE" \
        psql -U "$PGUSER" -d "$PGDATABASE" -h "$PGHOST" -p "$PGPORT" -t -c "$trimmed" 2>/dev/null || true)
      if [ -z "$(echo "$out" | tr -d '[:space:]')" ]; then
        echo "[FAIL] Check falló o no devolvió filas: $trimmed"
        failed=1
      else
        echo "[PASS] Check devolvió resultado."
      fi
    done < "$SEED_CHECKS_FILE"
    return $failed
  else
    echo "[SEED-VALIDATION] No se encontró $SEED_CHECKS_FILE — omitiendo checks de datos."
    return 0
  fi
}

# Ejecutar el seed (ADVERTENCIA: no idempotente si el seed.sql no lo es)
run_seed() {
  if [ ! -f "$SEED_FILE_PATH" ]; then
    echo "[ERROR] No se encontró $SEED_FILE_PATH"
    return 1
  fi
  echo "[SEED-VALIDATION] Ejecutando seed: $SEED_FILE_PATH"
  # Pasar el contenido del seed al psql dentro del contenedor
  docker compose -f "$DOCKER_COMPOSE_FILE" exec -T "$PG_SERVICE" \
    psql -U "$PGUSER" -d "$PGDATABASE" -h "$PGHOST" -p "$PGPORT" -f - <<'SQL_EOF'
$(cat "$SEED_FILE_PATH")
SQL_EOF
}

usage() {
  echo "Uso: $0 [--run-seed] [--mode checksum|structure|hybrid] [table1 table2 ...]"
  echo "  --run-seed   Ejecuta el seed.sql antes de validar (ATENCIÓN: no idempotente)"
  echo "  --mode       Modo de validación: checksum (solo checksums), structure (solo estructura), hybrid (ambos, por defecto)"
  exit 2
}

# Parse args (soportar flags en cualquier orden)
RUN_SEED=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --run-seed)
      RUN_SEED=1; shift ;;
    --mode)
      if [ "$#" -lt 2 ]; then usage; fi
      MODE="$2"; shift 2 ;;
    --mode=*)
      MODE="${1#--mode=}"; shift ;;
    --help|-h)
      usage; break ;;
    --*)
      echo "Unknown option: $1"; usage ;;
    *)
      break ;;
  esac
done

TABLES="$*"

# Si no se pasaron tablas y el modo implica estructura, usar la lista mínima
if [ -z "$TABLES" ] && [ "$RUN_SEED" -eq 0 ] && { [ "$MODE" = "structure" ] || [ "$MODE" = "hybrid" ]; }; then
  TABLES="$MIN_TABLES"
fi

# Si no hay tablas y no pedimos estructura, solo listar y salir
if [ -z "$TABLES" ] && [ "$MODE" = "checksum" ]; then
  list_tables
  exit $?
fi

# Si se pidió ejecutar seed
if [ "$RUN_SEED" -eq 1 ]; then
  echo "[INFO] Ejecutando seed (flag --run-seed habilitado)."
  if ! run_seed; then
    echo "[ERROR] Ejecución de seed falló. Abortando."
    exit 3
  fi
fi

# Verificar estructura (existencia + umbrales) si el modo lo requiere
if [ "$MODE" = "structure" ] || [ "$MODE" = "hybrid" ]; then
  if [ -n "$TABLES" ]; then
    echo "[SEED-VALIDATION] Verificando existencia/umbrales de tablas: $TABLES"
    # check_tables solo comprueba existencia; añadimos comprobación de conteos
    missing=0
    for t in $TABLES; do
      if ! check_tables "$t"; then
        missing=1
        continue
      fi
      # comprobar mínimo de filas si aplica
      minc=$(min_count_for_table "$t" || echo 0)
      if [ -n "$minc" ] && [ "$minc" -gt 0 ]; then
        cnt=$(docker compose -f "$DOCKER_COMPOSE_FILE" exec -T "$PG_SERVICE" \
          psql -U "$PGUSER" -d "$PGDATABASE" -h "$PGHOST" -p "$PGPORT" -t -c "SELECT COUNT(*) FROM \"$t\";" 2>/dev/null | tr -d ' ')
        if [ "x$cnt" = "x" ] || [ "$cnt" -lt "$minc" ]; then
          echo "[ERROR] Tabla $t tiene $cnt filas (esperadas >= $minc)"
          missing=1
        else
          echo "[OK] Tabla $t cumple umbral: $cnt >= $minc"
        fi
      fi
    done
    if [ "$missing" -ne 0 ]; then
      echo "[ERROR] Falló la verificación de estructura/umbrales."
      exit 4
    fi
  fi
fi

# Ejecutar checks de datos (si existen)
if ! run_seed_checks; then
  echo "[ERROR] Fallaron los checks de datos del seed."
  exit 5
fi

# Verificar que los archivos de schema/seed aplicados coinciden con los registros en la BD
if [ "$MODE" = "checksum" ] || [ "$MODE" = "hybrid" ]; then
  echo "[SEED-VALIDATION] Verificando checksums registrados en la BD..."
  errors=0
  # Archivo de schema en el repo
  SCHEMA_FILE="gin-backend/db_script.sql"
  if ! check_registered_checksum "$SCHEMA_FILE" "db_script.sql" "schema"; then
    errors=1
  fi
  # Archivo de seed (si existe)
  if [ -f "$SEED_FILE_PATH" ]; then
    if ! check_registered_checksum "$SEED_FILE_PATH" "seed.sql" "seed"; then
      errors=1
    fi
  else
    echo "[WARN] No se encontró archivo de seed local $SEED_FILE_PATH — omitiendo verificación de seed."
  fi

  if [ "$errors" -ne 0 ]; then
    echo "[ERROR] Verificación de checksums falló."
    exit 6
  fi
fi

echo "[SEED-VALIDATION] Validación completada correctamente (modo: $MODE)."
exit 0
