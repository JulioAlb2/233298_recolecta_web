# Data Lifecycle - Flujos de Negocio

Este documento describe el ciclo de vida de cada tipo de dato, desde su origen hasta su eliminación.

---

## 1. Flujo de Usuario: Alta y Geocodificación

### Requisitos previos
- Usuario registrado en PostgreSQL (tabla `ciudadano`)
- Domicilio registrado en PostgreSQL (tabla `domicilio`)
- Dirección completa disponible

### Proceso: Alta de Usuario en Redis

**Trigger:** Usuario abre app por primera vez o actualiza domicilio

**Pasos:**

1. **Geocodificación** (externa, Google Maps API)
   - Input: dirección de `domicilio.direccion` (ej: "Calle Olmo 100, Centro Histórico...")
   - Output: `lat, lon`
   - Guardado: En memoria de la app (no en PostgreSQL)

2. **Carga en Redis** (Go)
   - Ejecuta: `HSET user:{user_id} fcm_token "{token_fcm}" fcm_status "valid" fcm_expires_at "2026-03-01T00:00:00Z"`
   - Ejecuta: `GEOADD users:geo {lon} {lat} "{user_id}"`

3. **Validación**
   - Confirmar que `HGET user:{user_id} fcm_token` existe
   - Confirmar que `GEOPOS users:geo {user_id}` devuelve coordenadas

### Idempotencia
- Si `user:{user_id}` ya existe, se sobrescribe (sin duplicados)
- `GEOADD` también sobrescribe automáticamente si el member ya existe

### Ejemplo de ejecución

```bash
# Usuario 100 nuevo
HSET user:100 fcm_token "eJydUMtuwjAM_BXLZ0gsISE4cYEDUi9..." \
              fcm_status "valid" \
              fcm_expires_at "2026-03-01T00:00:00Z" \
              updated_at "2026-01-30T10:30:00Z"

GEOADD users:geo -87.0739 20.6295 "100"

# Verificar
HGET user:100 fcm_token
GEOPOS users:geo 100
```

---

## 2. Flujo de Camión: Inicio de Ruta y Estado

### Requisitos previos
- Ruta asignada en PostgreSQL (`registro_asignacion_ruta`)
- Camión asignado conductor en PostgreSQL (`historial_asignacion`)

### Proceso: Camión Inicia Ruta

**Trigger:** Conductor inicia sesión en app o presiona "Iniciar Ruta"

**Pasos:**

1. **Go recupera asignación del día**
   - Query: `SELECT ruta_id FROM registro_asignacion_ruta WHERE camion_id = 5 ORDER BY fecha_asignacion DESC LIMIT 1`

2. **Carga ruta en Redis** (si no está ya)
   - Ejecuta: `RPUSH route:points:1 10 11 12 13 14` (para ruta 1)
   - Ejecuta: `HSET point:10 route_id 1 lat 20.6300 lon -87.0742 label "Av Juárez esq Calle 10"`
   - (Repite para puntos 11, 12, 13, 14)

3. **Inicializar estado del camión**
   - Ejecuta: `HSET truck:state:5 route_id 1 current_point_id 10 state "IN_ROUTE" lat 20.6295 lon -87.0739 updated_at "2026-01-30T06:00:00Z" assignment_source "registro_asignacion_ruta"`
   - TTL: `EXPIRE truck:state:5 86400` (24 horas)

4. **Inicializar historial del día**
   - Ejecuta: `DEL truck:route:history:5:2026-01-30` (limpiar si existe)
   - Ejecuta: `RPUSH truck:route:history:5:2026-01-30 "STARTED"` (marca de inicio)
   - TTL: `EXPIRE truck:route:history:5:2026-01-30 86400` (24 horas)

### Validación
- `HGET truck:state:5 route_id` == 1
- `LRANGE route:points:1 0 -1` devuelve 5 puntos

---

## 3. Flujo de Notificación: 4 Estados

### Contexto
Camión se mueve por su ruta. App detecta cambios de proximidad (mediante GPS del celular).

### Estados de Notificación

| Estado | Evento | Distancia | Acción |
|--------|--------|-----------|--------|
| **WARN** | Camión se acerca | ~200m | Enviar: "Camión aproximándose" |
| **ARRIVAL** | Camión llega | ~50m | Enviar: "Camión llegó a tu punto" |
| **DEPARTURE** | Camión se aleja | ~200m (siguiente punto) | Enviar: "Camión ya pasó" |
| **COMEBACK** | Camión vuelve cercano | Dentro de radio nuevamente | Enviar: "Puedes alcanzarlo aún" |

### Proceso: Transición de Estados (por usuario)

**Trigger:** App del usuario detecta cambio de proximidad a punto

**Ejemplo: Usuario 100 → Punto 10 → Camión 5**

#### Transición 1: Inicia en estado INIT, detecta camión a 200m

1. **Verificar si ya notificó HOY para este estado**
   - Query: `SISMEMBER notification:sent:100:5:2026-01-30 "WARN"`
   - Respuesta: 0 (no, primera vez)

2. **Generar notificación**
   - ID: `notification:XXXXXXXXX` (uuid único)
   - HSET notification:XXXXXXXXX type "WARN" status "pending" truck_id 5 point_id 10 timestamp "2026-01-30T08:15:00Z"
   - TTL: 7 días

3. **Enviar FCM**
   - Recuperar: `HGET user:100 fcm_token`
   - Enviar a Google FCM
   - Resultado: success / failed

4. **Actualizar estado de notificación**
   - Si success: `HSET notification:XXXXXXXXX status "delivered"`
   - Si failed: `HSET notification:XXXXXXXXX status "failed"`

5. **Registrar que se envió**
   - Ejecuta: `SADD notification:sent:100:5:2026-01-30 "WARN"`
   - TTL: `EXPIRE notification:sent:100:5:2026-01-30 86400` (24h)

6. **Agregar a log del usuario**
   - Ejecuta: `ZADD notification:log:100 {epoch_timestamp} "notification:XXXXXXXXX"`
   - (El score es el timestamp Unix para ordenar temporalmente)

7. **Actualizar métricas**
   - HINCRBY metrics:notifications:5:2026-01-30 total_sent 1
   - HINCRBY metrics:notifications:5:2026-01-30 warn_count 1
   - Si delivered: HINCRBY metrics:notifications:5:2026-01-30 delivery_success 1

#### Transición 2: Camión entra en punto (WARN → ARRIVAL)

1. **Verificar si ya notificó ARRIVAL**
   - Query: `SISMEMBER notification:sent:100:5:2026-01-30 "ARRIVAL"`
   - Respuesta: 0 (no, primera vez)

2. **Generar y enviar ARRIVAL** (repetir pasos 2-7 arriba, pero con type: "ARRIVAL")

#### Transición 3: Camión sale del punto (ARRIVAL → DEPARTURE)

1. **Verificar si ya notificó DEPARTURE**
   - Query: `SISMEMBER notification:sent:100:5:2026-01-30 "DEPARTURE"`
   - Respuesta: 0 (no)

2. **Generar y enviar DEPARTURE** (repetir con type: "DEPARTURE")

#### Transición 4: Camión se aleja mucho (DEPARTURE → COMEBACK, si vuelve cercano)

Si por alguna razón el camión vuelve cercano (ej: falla mecánica, vuelta):

1. **Verificar si ya notificó COMEBACK**
   - Query: `SISMEMBER notification:sent:100:5:2026-01-30 "COMEBACK"`
   - Respuesta: 0 (no)

2. **Generar y enviar COMEBACK** (repetir con type: "COMEBACK")

### Idempotencia garantizada

**Clave:** `notification:sent:{user_id}:{truck_id}:{date}`

Es un SET. Una vez que agregas "WARN", no se agrega nuevamente. Por lo tanto:
- Máximo 1 notificación WARN por usuario/camión/día
- Máximo 1 notificación ARRIVAL por usuario/camión/día
- Máximo 1 notificación DEPARTURE por usuario/camión/día
- Máximo 1 notificación COMEBACK por usuario/camión/día

**Total máximo:** 4 notificaciones por usuario/camión/día

---

## 4. Flujo de Historial del Camión

### Registro de puntos visitados

**Trigger:** Camión reporta que llegó a punto

**Proceso:**

1. **Go recibe GPS del conductor**: lat=20.6300, lon=-87.0742
2. **Go identifica punto cercano**: punto_id=10
3. **Agregar al historial**
   - Ejecuta: `RPUSH truck:route:history:5:2026-01-30 10`
   - Ejecuta: `RPUSH truck:route:history:5:2026-01-30 11` (después)
   - Ejecuta: `RPUSH truck:route:history:5:2026-01-30 12` (después)

4. **Actualizar último estado**
   - Ejecuta: `HSET truck:state:5 lat 20.6300 lon -87.0742 updated_at "2026-01-30T09:00:00Z"`

### Consultas del historial

**Ver puntos visitados hoy:**
```bash
LRANGE truck:route:history:5:2026-01-30 0 -1
# → [10, 11, 12]
```

**Ver última ubicación:**
```bash
HGETALL truck:state:5
# → {lat: 20.6300, lon: -87.0742, timestamp: "2026-01-30T09:00:00Z", state: "ARRIVAL"}
```

---

## 5. Flujo de Validación de Tokens FCM

### Requisitos
- Al iniciar Go, carga usuarios desde PostgreSQL (`user_id` 100..299)
- Para cada uno, verifica el token FCM en Redis

### Proceso en Startup

**Trigger:** Go inicia (docker up)

**Pasos:**

1. **Cargar usuarios de PostgreSQL**
   - Query: `SELECT id AS user_id FROM ciudadano` (ciudadanos)
   - Resultado: user_id 100..299

2. **Verificar tokens en Redis**
   ```bash
   FOR each user_id in 100..299:
      token = HGET user:{user_id} fcm_token
      if token == null:
         # Token no existe, solicitará nuevo al abrir app
      else:
         expiry = HGET user:{user_id} fcm_expires_at
         if expiry < NOW:
            HSET user:{user_id} fcm_status "expired"
         else:
            HSET user:{user_id} fcm_status "valid"
   ```

3. **Marcar como invalid si FCM rechaza**
   - Cuando Go intenta enviar FCM y falla:
   - `HSET user:{user_id} fcm_status "invalid"`
   - La app solicitará nuevo token en próxima apertura

---

## 6. Flujo de Métricas

### Registro automático

Cada notificación enviada actualiza métricas:

```bash
HINCRBY metrics:notifications:{truck_id}:{date} total_sent 1
HINCRBY metrics:notifications:{truck_id}:{date} warn_count 1
HINCRBY metrics:notifications:{truck_id}:{date} delivery_success 1
```

### Consultas de métricas

**Ver métricas de camión 5 hoy:**
```bash
HGETALL metrics:notifications:5:2026-01-30
# → {
#   total_sent: 145,
#   warn_count: 50,
#   arrival_count: 45,
#   departure_count: 40,
#   comeback_count: 10,
#   delivery_success: 140,
#   delivery_failed: 5
# }
```

---

## 7. Limpieza y Expiración

### TTLs automáticos

| Clave | TTL | Razón |
|-------|-----|-------|
| `truck:state:{id}` | 24h | Estado camión relevante solo hoy |
| `truck:route:history:{id}:{date}` | 24h | Historial del día |
| `notification:sent:{u}:{c}:{date}` | 24h | Control diario de duplicidad |
| `notification:log:{user_id}` | 7 días | Log temporal para auditoría operativa |
| `notification:{id}` | 7 días | Detalles de notificación |
| `metrics:notifications:{c}:{date}` | 7 días | Auditoría de métricas |

### Limpieza manual (opcional)

Si necesitas limpiar todo un camión o usuario:
```bash
# Limpiar estado temporal de camión 5
DEL truck:state:5
DEL truck:route:history:5:2026-01-30

# Limpiar historial de usuario 100
DEL notification:sent:100:1:2026-01-30
DEL notification:log:100
```

---

## Resumen de reglas clave

1. **Idempotencia:** Máximo 1 notificación por estado por usuario/camión/día
2. **GEO + HASH:** Siempre sincronizados en usuario
3. **Rutas lineales:** Puntos ordenados en LIST
4. **TTL:** Datos temporales con expiración automática
5. **Métricas:** Se actualizan con cada notificación
6. **Validación:** Tokens FCM verificados en startup y en cada rechazo

---

## 8. Flujo de Contrato de Evento + Canal Realtime Admin

### Contrato server-owned para eventos de camión

Los clientes móviles deben enviar eventos con contrato versionado:

```json
{
  "event_id": "evt_01JXYZ...",
  "event_type": "TRUCK_STATE_CHANGED",
  "event_version": "v1",
  "truck_id": 5,
  "occurred_at": "2026-04-15T11:45:00Z",
  "payload": {
    "state_code": "ARRIVAL",
    "point_id": 10,
    "lat": 20.6300,
    "lon": -87.0742
  }
}
```

### Dedupe + trazabilidad (Redis-first)

1. Resolver hash de deduplicación por contenido del evento.
2. Revisar `event_deduplication:{event_hash}`.
3. Si existe, no reprocesar.
4. Si no existe, procesar regla y persistir:
   - `event_deduplication:{event_hash}` (TTL 30 días)
   - `event_trace:{event_id}` (TTL 30 días)

### Endpoint operativo del backend

El backend expone `POST /api/notifications/events/truck-state` para ejecutar este flujo:

1. Validar contrato (`event_id`, `event_type`, `event_version`, `truck_id`, `occurred_at`, `payload.state_code`).
2. Calcular `event_hash` determinístico por contenido relevante.
3. Intentar dedupe en Redis (`event_deduplication:{event_hash}`).
4. Si es duplicado, responder `deduplicated=true` sin reprocesar.
5. Si es nuevo:
   - Resolver regla por `state_code` en `rules:state:{state_code}`.
   - Persistir `event_trace:{event_id}` y `event_trace:truck:{truck_id}`.
   - Responder acción resuelta y resultado.

### Login admin -> token exclusivo de upgrade websocket

1. Admin autentica sesión normal.
2. Backend emite token exclusivo de upgrade (`ws_upgrade_token`).
3. Backend guarda claim en `ws:upgrade:{jti}` con expiración corta.
4. Handshake websocket solo acepta ese token exclusivo (no cualquier bearer).

### Sesión viva y recuperación tras backup/restore

Para evitar que sesiones restauradas desde backup queden válidas:

1. Backend define `realtime:server_epoch:current` en cada arranque.
2. Claims/sesiones WS guardan `server_epoch`.
3. En handshake y heartbeat se valida coincidencia de epoch.
4. Si no coincide, se rechaza la conexión.

Además:
- Si el admin cierra sesión, la sesión WS se invalida.
- Si no hay heartbeat por 1 hora, expira `ws:session:{session_id}`.

---

## 9. Flujo de Configuración Dinámica de Reglas (Admin)

### Objetivo
Permitir cambios de acción, radio y contenido de notificación por estado sin despliegue.

### Endpoints backend
- `GET /api/notifications/rules`
- `GET /api/notifications/rules/:state_code`
- `PUT /api/notifications/rules/:state_code`
- `DELETE /api/notifications/rules/:state_code`

Los endpoints de reglas usan `JWTAuthMiddleware`.

### Proceso: Upsert de regla

1. Admin envía `PUT /api/notifications/rules/WARN` con payload.
2. Backend valida:
   - `state_code` obligatorio (path param).
   - `action` obligatoria.
   - `radius_meters >= 0`.
3. Backend persiste en Redis:
   - `HSET rules:state:WARN ...`
   - `INCR rules:version`
4. Backend responde la regla con versión actual.

### Proceso: Eliminación de regla

1. Admin envía `DELETE /api/notifications/rules/WARN`.
2. Backend elimina `rules:state:WARN`.
3. Backend incrementa `rules:version`.

### Consistencia esperada
- Reglas activas se leen en tiempo real desde Redis.
- `rules:version` permite invalidar caché en consumidores realtime.
