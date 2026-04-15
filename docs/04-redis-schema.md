# Redis Schema (MVP) - Geolocalización y Notificaciones

Este documento define la estructura de datos en Redis para el MVP. Redis es la fuente de verdad para:
- Coordenadas geográficas
- Tokens FCM
- Estado temporal de camiones
- Historial temporal de notificaciones

PostgreSQL NO se usa para coordenadas ni FCM. Redis es el único repositorio para datos geoespaciales.

---

## Objetivos de diseño

1) Búsqueda geoespacial rápida (radio 100m/200m)
2) Evitar duplicados de notificaciones por estado
3) Trazabilidad mínima de estado del camión
4) Persistencia clara: permanentes vs temporales
5) Compatible con los datos base del seed de PostgreSQL

---

## Convenciones de claves

- Prefijo por entidad: user, route, point, truck, notification, metrics
- Separador con dos puntos: `:`
- Fechas en formato `YYYY-MM-DD`

---

## Datos permanentes (sin TTL)

### 1) Usuarios (FCM + metadatos)

**Key:** `user:{user_id}`
**Type:** HASH
**Fields:**
- `fcm_token` (string)
- `fcm_status` (string: valid | invalid | expired)
- `fcm_created_at` (ISO 8601)
- `fcm_expires_at` (ISO 8601)
- `updated_at` (ISO 8601)

**Ejemplo:**
- `user:100` → { fcm_token: "...", fcm_status: "valid", fcm_expires_at: "2026-03-01T00:00:00Z" }


### 2) Índice geoespacial de usuarios

**Key:** `users:geo`
**Type:** GEO (internamente es ZSET)
**Members:** `user_id`
**Score:** lat/lon

**Uso:** búsquedas por radio desde coordenadas del camión.


### 3) Puntos de ruta (coordenadas)

**Key:** `point:{punto_id}`
**Type:** HASH
**Fields:**
- `route_id` (int)
- `lat` (float)
- `lon` (float)
- `label` (string, referencia humana)


### 4) Orden de puntos por ruta (lineal)

**Key:** `route:points:{ruta_id}`
**Type:** LIST
**Value:** lista ordenada de `punto_id`

**Uso:** representar la ruta como vector dirigido A→B→C.

---

## Datos temporales (con TTL)

### 5) Última ubicación / estado del camión

**Key:** `truck:state:{truck_id}`
**Type:** HASH
**Fields:**
- `route_id` (int)
- `current_point_id` (int)
- `lat` (float)
- `lon` (float)
- `state` (INIT | IN_ROUTE | WARN | ARRIVAL | DEPARTURE | COMEBACK)
- `updated_at` (ISO 8601)
- `assignment_source` (string)

**TTL:** 24h


### 6) Historial diario de puntos visitados

**Key:** `truck:route:history:{truck_id}:{date}`
**Type:** LIST
**Value:** `punto_id` en orden visitado

**TTL:** 24h


### 7) Control de notificaciones por estado

**Key:** `notification:sent:{user_id}:{truck_id}:{date}`
**Type:** SET
**Members:** WARN, ARRIVAL, DEPARTURE, COMEBACK

**TTL:** 24h

**Objetivo:** evitar duplicidad por estado en el mismo día.


### 8) Log de notificaciones por usuario

**Key:** `notification:log:{user_id}`
**Type:** SORTED SET
**Member:** `notification:{notification_id}`
**Score:** epoch timestamp

**TTL:** 7 días


### 9) Detalle de notificación

**Key:** `notification:{notification_id}`
**Type:** HASH
**Fields:**
- `type` (WARN | ARRIVAL | DEPARTURE | COMEBACK)
- `status` (pending | delivered | failed)
- `truck_id` (int)
- `point_id` (int)
- `timestamp` (ISO 8601)

**TTL:** 7 días

---

## Métricas (opcional MVP)

### 10) Métricas diarias por camión

**Key:** `metrics:notifications:{truck_id}:{date}`
**Type:** HASH
**Fields:**
- `total_sent`
- `warn_count`
- `arrival_count`
- `departure_count`
- `comeback_count`
- `delivery_success`
- `delivery_failed`

**TTL:** 7 días

### 11) Dedupe y trazabilidad de eventos (fase de orquestación)

**Key:** `event_deduplication:{event_hash}`  
**Type:** HASH  
**Fields sugeridos:** `event_id`, `event_type`, `truck_id`, `processed_at`, `result`  
**TTL objetivo:** 30 días

**Key:** `event_trace:{event_id}`  
**Type:** HASH  
**Fields sugeridos:** `event_version`, `state_code`, `resolved_action`, `admin_notified`, `citizen_fanout_count`, `created_at`  
**TTL objetivo:** 30 días

**Key:** `event_trace:truck:{truck_id}`  
**Type:** SORTED SET  
**Member:** `event_id`  
**Score:** epoch timestamp  
**TTL objetivo:** 30 días

**Implementación actual en backend (`issue/10`):**
- `event_deduplication:{event_hash}` se registra con `HSETNX` por hash de evento y TTL 30 días.
- `event_trace:{event_id}` guarda `event_hash`, `state_code`, `resolved_action`, `admin_notified`, `citizen_fanout_count`, `result`.
- `event_trace:truck:{truck_id}` indexa eventos por timestamp (ZSET) para auditoría por camión.

### 12) Sesiones realtime de administrador (websocket)

**Key:** `realtime:server_epoch:current`  
**Type:** STRING  
**Uso:** invalidar sesiones/tokens restaurados desde backup anterior.

**Key:** `ws:upgrade:{jti}`  
**Type:** HASH  
**Fields sugeridos:** `admin_id`, `session_id`, `server_epoch`, `issued_at`, `expires_at`, `used`  
**TTL recomendado:** corto (ej. 5 minutos).

**Key:** `ws:session:{session_id}`  
**Type:** HASH  
**Fields sugeridos:** `admin_id`, `server_epoch`, `last_seen_at`, `connected_at`, `status`  
**TTL objetivo por inactividad:** 1 hora.

**Implementación actual en backend (`issue/11`):**
- `realtime:server_epoch:current` se crea/lee en backend para validar continuidad tras restore.
- `ws:upgrade:{jti}` almacena token one-time con `used=false` y TTL corto (5 min).
- `ws:session:{session_id}` almacena sesión activa con heartbeat renovando TTL de 1 hora.

### 13) Motor dinámico de reglas de notificación

**Key:** `rules:state:{state_code}`  
**Type:** HASH  
**Fields activos en backend:** `state_code`, `action`, `radius_meters`, `priority`, `enabled`, `template_title`, `template_body`, `version`, `updated_at`.

**Key:** `rules:version`  
**Type:** STRING  
**Uso:** contador global incremental para invalidar cachés cuando se crea, actualiza o elimina una regla.

**Convención de escritura:** `state_code` se normaliza a mayúsculas.

---

## Relación con el seed de PostgreSQL

El seed actual define:
- 5 rutas (`ruta_id` 1..5)
- 25 puntos (`punto_id` 1..25)
- 6 estados de camión (`truck_id` 1..6, 5 asignados a ruta)
- 200 usuarios ciudadanos (`user_id` 100..299)

**Implicación para Redis:**
- Crear `route:points:{1..5}` con 5 puntos cada una
- Crear `point:{1..25}` con coordenadas reales
- Crear `user:{100..299}` con FCM tokens
- Agregar todos los `user_id` al índice `users:geo`

---

## Validaciones mínimas

- `users:geo` debe contener al menos 200 usuarios
- Cada `route:points:{id}` debe tener 5 elementos
- Cada `point:{id}` debe tener `lat/lon` válidos
- Cada `user:{id}` debe tener `fcm_token`

---

## Reglas de negocio clave

- Un usuario recibe máximo 1 notificación por estado por día
- GEO es el índice espacial; la información del usuario vive en HASH
- Coordenadas no se duplican en HASH (solo en GEO)
- Rutas son lineales: LIST ordenada sin bifurcaciones

---

## Notas de implementación

- Los datos permanentes en Redis se cargan al iniciar el entorno
- Los datos temporales expiran por TTL y se regeneran automáticamente
- GEO y HASH deben actualizarse juntos cuando cambie el domicilio del usuario
