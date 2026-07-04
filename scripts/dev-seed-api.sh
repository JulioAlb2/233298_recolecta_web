#!/bin/sh
set -eu

API_BASE_URL="${API_BASE_URL:-http://localhost}"
HEALTHCHECK_URL="${HEALTHCHECK_URL:-${API_BASE_URL%/}/health}"
ADMIN_EMAIL="${ADMIN_EMAIL:-${ADMIN_MAIL:-}}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
SEED_EMPLEADO_PASSWORD="${SEED_EMPLEADO_PASSWORD:-}"
SEED_CIUDADANO_PASSWORD="${SEED_CIUDADANO_PASSWORD:-}"
SEED_CIUDADANOS_COUNT="${SEED_CIUDADANOS_COUNT:-50}"
SEED_CIUDADANOS_START="${SEED_CIUDADANOS_START:-1}"
MAX_WAIT_SECONDS="${MAX_WAIT_SECONDS:-90}"

if [ -z "$ADMIN_EMAIL" ] || [ -z "$ADMIN_PASSWORD" ]; then
  echo "[seed-api] Falta ADMIN_EMAIL (o ADMIN_MAIL) o ADMIN_PASSWORD"
  exit 1
fi
if [ -z "$SEED_EMPLEADO_PASSWORD" ] || [ -z "$SEED_CIUDADANO_PASSWORD" ]; then
  echo "[seed-api] Faltan SEED_EMPLEADO_PASSWORD o SEED_CIUDADANO_PASSWORD"
  exit 1
fi

wait_for_health() {
  elapsed=0
  echo "[seed-api] Esperando healthcheck en $HEALTHCHECK_URL"

  while [ "$elapsed" -lt "$MAX_WAIT_SECONDS" ]; do
    code=$(curl -sS -o /dev/null -w "%{http_code}" "$HEALTHCHECK_URL" || true)
    if [ "$code" = "200" ]; then
      echo "[seed-api] Healthcheck OK"
      return 0
    fi

    sleep 2
    elapsed=$((elapsed + 2))
  done

  echo "[seed-api] Timeout esperando healthcheck ($MAX_WAIT_SECONDS s)"
  return 1
}

post_json() {
  url="$1"
  data="$2"
  auth_header="${3:-}"

  tmp_file="/tmp/seed_api_resp_$$.json"

  if [ -n "$auth_header" ]; then
    code=$(curl -sS -o "$tmp_file" -w "%{http_code}" -X POST "$url" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $auth_header" \
      -d "$data")
  else
    code=$(curl -sS -o "$tmp_file" -w "%{http_code}" -X POST "$url" \
      -H "Content-Type: application/json" \
      -d "$data")
  fi

  body=$(cat "$tmp_file" 2>/dev/null || true)
  rm -f "$tmp_file"

  printf "%s\n%s" "$code" "$body"
}

if ! wait_for_health; then
  exit 1
fi

echo "[seed-api] Login admin en $API_BASE_URL/api/empleados/login"
login_payload=$(printf '{"email":"%s","password":"%s"}' "$ADMIN_EMAIL" "$ADMIN_PASSWORD")

attempt=1
max_attempts=60
login_code=""
login_body=""
while [ "$attempt" -le "$max_attempts" ]; do
  login_result=$(post_json "$API_BASE_URL/api/empleados/login" "$login_payload")
  login_code=$(printf "%s" "$login_result" | sed -n '1p')
  login_body=$(printf "%s" "$login_result" | sed -n '2,$p')

  if [ "$login_code" = "200" ]; then
    break
  fi

  echo "[seed-api] intento $attempt/$max_attempts login admin -> HTTP $login_code"
  sleep 2
  attempt=$((attempt + 1))
done

if [ "$login_code" != "200" ]; then
  echo "[seed-api] Error login admin ($login_code): $login_body"
  echo "[seed-api] Verifica ADMIN_EMAIL/ADMIN_PASSWORD y que ese admin exista por init/.env"
  exit 1
fi

token=$(printf "%s" "$login_body" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
if [ -z "$token" ]; then
  echo "[seed-api] No se pudo extraer token del login: $login_body"
  exit 1
fi

create_empleado() {
  nombre="$1"
  apellidos="$2"
  mail="$3"
  username="$4"
  rol_id="$5"

  payload=$(printf '{"nombre":"%s","apellidos":"%s","mail":"%s","username":"%s","password":"%s","rol_id":%s,"desactivado":false}' \
    "$nombre" "$apellidos" "$mail" "$username" "$SEED_EMPLEADO_PASSWORD" "$rol_id")

  result=$(post_json "$API_BASE_URL/api/empleados/" "$payload" "$token")
  code=$(printf "%s" "$result" | sed -n '1p')
  body=$(printf "%s" "$result" | sed -n '2,$p')

  if [ "$code" = "201" ] || [ "$code" = "200" ] || [ "$code" = "400" ]; then
    echo "[seed-api] empleado $mail -> HTTP $code"
    return 0
  fi

  echo "[seed-api] Error creando empleado $mail ($code): $body"
  return 1
}

create_empleado "María Elena" "Torres" "maria.torres@recolecta.mx" "mtorres" 2
create_empleado "Carlos" "Ramírez López" "carlos.ramirez@recolecta.mx" "cramirez" 2
create_empleado "Ana Patricia" "Morales" "ana.morales@recolecta.mx" "amorales" 3
create_empleado "Jorge Luis" "Sánchez" "jorge.sanchez@recolecta.mx" "jsanchez" 3
create_empleado "Patricia" "Hernández Cruz" "patricia.hernandez@recolecta.mx" "phernandez" 3
create_empleado "Juan Manuel" "Flores" "juan.flores@recolecta.mx" "jflores" 4
create_empleado "Pedro" "Ávila Gómez" "pedro.avila@recolecta.mx" "pavila" 4
create_empleado "Luis Alberto" "Vargas" "luis.vargas@recolecta.mx" "lvargas" 4
create_empleado "Miguel Ángel" "Medina" "miguel.medina@recolecta.mx" "mmedina" 4
create_empleado "José Antonio" "Ruiz" "jose.ruiz@recolecta.mx" "jruiz" 4
create_empleado "Francisco Javier" "Castro" "francisco.castro@recolecta.mx" "fcastro" 4

create_ciudadano() {
  email="$1"
  alias="$2"
  fcm_token="$3"
  payload=$(printf '{"email":"%s","alias":"%s","password":"%s","fcm_token":"%s"}' "$email" "$alias" "$SEED_CIUDADANO_PASSWORD" "$fcm_token")

  result=$(post_json "$API_BASE_URL/api/ciudadanos" "$payload")
  code=$(printf "%s" "$result" | sed -n '1p')
  body=$(printf "%s" "$result" | sed -n '2,$p')

  if [ "$code" = "201" ] || [ "$code" = "200" ] || [ "$code" = "400" ]; then
    echo "[seed-api] ciudadano $email -> HTTP $code"
    return 0
  fi

  echo "[seed-api] Error creando ciudadano $email ($code): $body"
  return 1
}

case "$SEED_CIUDADANOS_COUNT" in
  ''|*[!0-9]*)
    echo "[seed-api] SEED_CIUDADANOS_COUNT debe ser numérico"
    exit 1
    ;;
esac

case "$SEED_CIUDADANOS_START" in
  ''|*[!0-9]*)
    echo "[seed-api] SEED_CIUDADANOS_START debe ser numérico"
    exit 1
    ;;
esac

created=0
n="$SEED_CIUDADANOS_START"
while [ "$created" -lt "$SEED_CIUDADANOS_COUNT" ]; do
  create_ciudadano "user${n}@example.com" "user${n}" "dev-fcm-user${n}"
  created=$((created + 1))
  n=$((n + 1))
done

echo "[seed-api] Seeding dev por API completado (ciudadanos solicitados: $SEED_CIUDADANOS_COUNT, inicio: $SEED_CIUDADANOS_START)"
