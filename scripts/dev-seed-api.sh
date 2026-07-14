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
max_attempts=20
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
  exit 1
fi

token=$(printf "%s" "$login_body" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
if [ -z "$token" ]; then
  echo "[seed-api] No se pudo extraer token del login"
  exit 1
fi

# 1. SEED COLONIAS
create_colonia() {
  nombre="$1"
  zona="$2"
  payload=$(printf '{"nombre":"%s","zona":"%s"}' "$nombre" "$zona")
  result=$(post_json "$API_BASE_URL/api/colonias" "$payload" "$token")
  echo "[seed-api] colonia $nombre -> $(printf "%s" "$result" | sed -n '1p')"
}

echo "[seed-api] Sembrando Colonias..."
create_colonia "Centro Histórico" "Centro"
create_colonia "Colonia Industrial" "Norte"
create_colonia "Las Palmas" "Norte"
create_colonia "Vista Hermosa" "Sur"
create_colonia "Jardines del Valle" "Sur"
create_colonia "El Mirador" "Centro"
create_colonia "Residencial San Miguel" "Norte"
create_colonia "Fraccionamiento Los Pinos" "Sur"

# 2. SEED EMPLEADOS
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
  echo "[seed-api] empleado $mail -> HTTP $code"
}

echo "[seed-api] Sembrando Empleados..."
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

# 3. SEED CIUDADANOS Y DOMICILIOS (CON PERSISTENCIA DUAL REDIS + PG)
create_domicilio() {
  cid="$1"
  colid="$2"
  alias="$3"
  calle="$4"
  num="$5"
  ref="$6"
  lat="$7"
  lon="$8"
  payload=$(printf '{"ciudadano_id":%s,"colonia_id":%s,"alias":"%s","calle":"%s","numero":"%s","referencia":"%s","lat":%s,"lon":%s}' \
    "$cid" "$colid" "$alias" "$calle" "$num" "$ref" "$lat" "$lon")
  result=$(post_json "$API_BASE_URL/api/domicilios" "$payload" "$token")
  echo "[seed-api] domicilio para ciudadano $cid -> $(printf "%s" "$result" | sed -n '1p')"
}

create_ciudadano() {
  email="$1"
  alias="$2"
  fcm_token="$3"
  n="$4"
  payload=$(printf '{"email":"%s","alias":"%s","password":"%s","fcm_token":"%s"}' "$email" "$alias" "$SEED_CIUDADANO_PASSWORD" "$fcm_token")

  result=$(post_json "$API_BASE_URL/api/ciudadanos" "$payload")
  code=$(printf "%s" "$result" | sed -n '1p')
  body=$(printf "%s" "$result" | sed -n '2,$p')

  if [ "$code" = "201" ] || [ "$code" = "200" ]; then
    cid=$(printf "%s" "$body" | sed -n 's/.*"id":\([0-9]*\).*/\1/p' || echo "")
    if [ -n "$cid" ]; then
      colid=$(( (n % 8) + 1 ))
      lat=$(printf "20.6%04d" $(( (n * 17) % 10000 )))
      lon=$(printf "-103.3%04d" $(( (n * 23) % 10000 )))
      calle=$(printf "Calle Roble %d" "$n")
      numero=$(( n + 10 ))
      create_domicilio "$cid" "$colid" "Domicilio Principal" "$calle" "$numero" "Frente a parque" "$lat" "$lon"
    fi
    echo "[seed-api] ciudadano $email -> HTTP $code"
  else
    echo "[seed-api] Error creando ciudadano $email ($code): $body"
  fi
}

echo "[seed-api] Sembrando Ciudadanos y Domicilios..."
created=0
n="$SEED_CIUDADANOS_START"
while [ "$created" -lt "$SEED_CIUDADANOS_COUNT" ]; do
  create_ciudadano "user${n}@example.com" "user${n}" "dev-fcm-user${n}" "$n"
  created=$((created + 1))
  n=$((n + 1))
done

# 4. SEED TIPOS DE CAMIÓN
create_tipo_camion() {
  id="$1"
  nombre="$2"
  desc="$3"
  payload=$(printf '{"tipo_camion_id":%s,"nombre":"%s","descripcion":"%s"}' "$id" "$nombre" "$desc")
  result=$(post_json "$API_BASE_URL/api/tipo-camion/" "$payload" "$token")
  echo "[seed-api] tipo-camion $nombre -> $(printf "%s" "$result" | sed -n '1p')"
}

echo "[seed-api] Sembrando Tipos de Camión..."
create_tipo_camion 1 "Compactador 12m³" "Camión compactador estándar capacidad 12 metros cúbicos"
create_tipo_camion 2 "Compactador 15m³" "Camión compactador gran capacidad 15 metros cúbicos"
create_tipo_camion 3 "Camión de Volteo" "Camión de volteo para escombros y residuos voluminosos"

# 5. SEED CAMIONES
create_camion() {
  id="$1"
  placa="$2"
  modelo="$3"
  tipo_id="$4"
  rentado="$5"
  estado="$6"
  payload=$(printf '{"camion_id":%s,"placa":"%s","modelo":"%s","tipo_camion_id":%s,"es_rentado":%s,"disponibilidad_id":1,"nombre_disponibilidad":"%s"}' \
    "$id" "$placa" "$modelo" "$tipo_id" "$rentado" "$estado")
  result=$(post_json "$API_BASE_URL/api/camion/" "$payload" "$token")
  echo "[seed-api] camion $placa -> $(printf "%s" "$result" | sed -n '1p')"
}

echo "[seed-api] Sembrando Camiones..."
create_camion 1 "ABC-123-MX" "Freightliner M2 106 2022" 1 "false" "Disponible"
create_camion 2 "DEF-456-MX" "International DuraStar 2021" 2 "false" "Disponible"
create_camion 3 "GHI-789-MX" "Kenworth T370 2023" 1 "false" "Disponible"
create_camion 4 "JKL-012-MX" "Volvo VHD 2020" 2 "true" "Disponible"
create_camion 5 "MNO-345-MX" "Peterbilt 337 2021" 1 "true" "Disponible"
create_camion 6 "PQR-678-MX" "Mack LR 2019" 3 "true" "Disponible"

# 6. SEED HISTORIAL DE ASIGNACIÓN
create_historial() {
  chofer_id="$1"
  camion_id="$2"
  fecha="$3"
  payload=$(printf '{"id_chofer":%s,"id_camion":%s,"fecha_asignacion":"%s"}' "$chofer_id" "$camion_id" "$fecha")
  result=$(post_json "$API_BASE_URL/api/historial-asignacion/" "$payload" "$token")
  echo "[seed-api] historial chofer $chofer_id camion $camion_id -> $(printf "%s" "$result" | sed -n '1p')"
}

echo "[seed-api] Sembrando Historial de Asignaciones..."
create_historial 7 1 "2024-02-10"
create_historial 8 2 "2024-02-10"
create_historial 9 3 "2024-02-10"
create_historial 10 4 "2024-02-15"
create_historial 11 5 "2024-02-15"
create_historial 12 6 "2024-02-15"

# 7. SEED RUTAS Y PUNTOS DE RECOLECCIÓN (CON PERSISTENCIA DUAL REDIS + PG)
create_ruta() {
  nombre="$1"
  desc="$2"
  json_ruta="$3"
  payload=$(printf '{"nombre":"%s","descripcion":"%s","json_ruta":%s}' "$nombre" "$desc" "$json_ruta")
  result=$(post_json "$API_BASE_URL/api/rutas/" "$payload" "$token")
  echo "[seed-api] ruta $nombre -> $(printf "%s" "$result" | sed -n '1p')"
}

create_punto() {
  ruta_id="$1"
  cp="$2"
  lat="$3"
  lon="$4"
  payload=$(printf '{"ruta_id":%s,"cp":"%s","lat":%s,"lon":%s}' "$ruta_id" "$cp" "$lat" "$lon")
  result=$(post_json "$API_BASE_URL/api/puntos-recoleccion/" "$payload" "$token")
  echo "[seed-api] punto $cp -> $(printf "%s" "$result" | sed -n '1p')"
}

echo "[seed-api] Sembrando Rutas..."
create_ruta "Ruta Norte A" "Cobertura Colonia Industrial y Las Palmas" '{"zona":"Norte","turno":"matutino"}'
create_ruta "Ruta Sur A" "Cobertura Vista Hermosa y Jardines" '{"zona":"Sur","turno":"matutino"}'
create_ruta "Ruta Centro A" "Cobertura Centro Histórico y El Mirador" '{"zona":"Centro","turno":"matutino"}'
create_ruta "Ruta Norte B" "Cobertura Residencial San Miguel" '{"zona":"Norte","turno":"vespertino"}'
create_ruta "Ruta Sur B" "Cobertura Los Pinos y Jardines" '{"zona":"Sur","turno":"vespertino"}'

echo "[seed-api] Sembrando Puntos de Recolección..."
create_punto 1 "PR-NA-001" 20.6736 -103.3440
create_punto 1 "PR-NA-002" 20.6750 -103.3450
create_punto 1 "PR-NA-003" 20.6760 -103.3460
create_punto 1 "PR-NA-004" 20.6770 -103.3470
create_punto 1 "PR-NA-005" 20.6780 -103.3480

create_punto 2 "PR-SA-001" 20.6800 -103.3500
create_punto 2 "PR-SA-002" 20.6810 -103.3510
create_punto 2 "PR-SA-003" 20.6820 -103.3520
create_punto 2 "PR-SA-004" 20.6830 -103.3530
create_punto 2 "PR-SA-005" 20.6840 -103.3540

create_punto 3 "PR-CA-001" 20.6600 -103.3300
create_punto 3 "PR-CA-002" 20.6610 -103.3310
create_punto 3 "PR-CA-003" 20.6620 -103.3320
create_punto 3 "PR-CA-004" 20.6630 -103.3330
create_punto 3 "PR-CA-005" 20.6640 -103.3340

create_punto 4 "PR-NB-001" 20.6900 -103.3600
create_punto 4 "PR-NB-002" 20.6910 -103.3610
create_punto 4 "PR-NB-003" 20.6920 -103.3620
create_punto 4 "PR-NB-004" 20.6930 -103.3630
create_punto 4 "PR-NB-005" 20.6940 -103.3640

create_punto 5 "PR-SB-001" 20.6500 -103.3200
create_punto 5 "PR-SB-002" 20.6510 -103.3210
create_punto 5 "PR-SB-003" 20.6520 -103.3220
create_punto 5 "PR-SB-004" 20.6530 -103.3230
create_punto 5 "PR-SB-005" 20.6540 -103.3240

# 8. SEED ASIGNACIÓN RUTA-CAMIÓN
create_ruta_camion() {
  ruta_id="$1"
  camion_id="$2"
  fecha="$3"
  payload=$(printf '{"ruta_id":%s,"camion_id":%s,"fecha":"%s"}' "$ruta_id" "$camion_id" "$fecha")
  result=$(post_json "$API_BASE_URL/api/ruta-camion/" "$payload" "$token")
  echo "[seed-api] ruta-camion ruta $ruta_id camion $camion_id -> $(printf "%s" "$result" | sed -n '1p')"
}

echo "[seed-api] Sembrando Asignación Ruta-Camión..."
create_ruta_camion 1 1 "2026-07-14"
create_ruta_camion 2 5 "2026-07-14"
create_ruta_camion 3 2 "2026-07-14"
create_ruta_camion 4 3 "2026-07-14"
create_ruta_camion 5 4 "2026-07-14"

# 9. SEED TIPOS DE MANTENIMIENTO
create_tipo_mantenimiento() {
  id="$1"
  nombre="$2"
  cat="$3"
  payload=$(printf '{"tipo_mantenimiento_id":%s,"nombre":"%s","categoria":"%s","eliminado":false}' "$id" "$nombre" "$cat")
  result=$(post_json "$API_BASE_URL/api/tipo-mantenimiento/" "$payload" "$token")
  echo "[seed-api] tipo-mantenimiento $nombre -> $(printf "%s" "$result" | sed -n '1p')"
}

echo "[seed-api] Sembrando Tipos de Mantenimiento..."
create_tipo_mantenimiento 1 "Cambio de Aceite" "preventivo"
create_tipo_mantenimiento 2 "Revisión de Frenos" "preventivo"
create_tipo_mantenimiento 3 "Alineación y Balanceo" "preventivo"
create_tipo_mantenimiento 4 "Cambio de Filtros" "preventivo"
create_tipo_mantenimiento 5 "Reparación Motor" "correctivo"
create_tipo_mantenimiento 6 "Reparación Transmisión" "correctivo"
create_tipo_mantenimiento 7 "Reparación Sistema Hidráulico" "correctivo"
create_tipo_mantenimiento 8 "Reemplazo Neumáticos" "correctivo"

# 10. SEED ALERTAS DE MANTENIMIENTO
create_alerta_mantenimiento() {
  id="$1"
  camion_id="$2"
  tipo_id="$3"
  desc="$4"
  obs="$5"
  atendido="$6"
  payload=$(printf '{"alerta_id":%s,"camion_id":%s,"tipo_mantenimiento_id":%s,"descripcion":"%s","observaciones":"%s","atendido":%s}' \
    "$id" "$camion_id" "$tipo_id" "$desc" "$obs" "$atendido")
  result=$(post_json "$API_BASE_URL/api/alertas-mantenimiento/" "$payload" "$token")
  echo "[seed-api] alerta-mantenimiento $desc -> $(printf "%s" "$result" | sed -n '1p')"
}

echo "[seed-api] Sembrando Alertas de Mantenimiento..."
create_alerta_mantenimiento 1 2 1 "Aceite sucio" "Requiere cambio de aceite inmediato" "true"
create_alerta_mantenimiento 2 5 2 "Ruidos en frenos" "El chofer reportó un chirrido al frenar" "true"
create_alerta_mantenimiento 3 6 4 "Servicio trimestral" "Cambio de filtros trimestral programado" "true"

# 11. SEED REGISTROS DE MANTENIMIENTO
create_registro_mantenimiento() {
  alerta_id="$1"
  camion_id="$2"
  coord_id="$3"
  mecanico="$4"
  fecha="$5"
  km="$6"
  obs="$7"
  payload=$(printf '{"alerta_id":%s,"camion_id":%s,"coordinador_id":%s,"mecanico_responsable":"%s","fecha_realizada":"%s","kilometraje_mantenimiento":%s,"observaciones":"%s"}' \
    "$alerta_id" "$camion_id" "$coord_id" "$mecanico" "$fecha" "$km" "$obs")
  result=$(post_json "$API_BASE_URL/api/registros-mantenimiento/" "$payload" "$token")
  echo "[seed-api] registro-mantenimiento camion $camion_id -> $(printf "%s" "$result" | sed -n '1p')"
}

echo "[seed-api] Sembrando Registros de Mantenimiento..."
create_registro_mantenimiento 1 2 2 "Mecánico Juan" "2026-01-20 12:00:00" 15000 "Servicio realizado con éxito"
create_registro_mantenimiento 2 5 2 "Mecánico Pedro" "2026-01-22 17:00:00" 102000 "Se cambiaron balatas delanteras"
create_registro_mantenimiento 3 6 3 "Mecánico Carlos" "2026-01-25 11:00:00" 89000 "Filtros reemplazados"

echo "[seed-api] Seeding dev por API completado con sincronización a Redis!"
