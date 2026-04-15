# 3. Operaciones Redis - Casos de Uso y Benchmarks

Continuación de [05-data-lifecycle.md](05-data-lifecycle.md). Esta sección cubre casos de uso reales, benchmarks de performance, y ejemplos de integración con el backend Go/Gin.

## 🎯 Capacidades Operacionales

Con los datos generados, el backend puede implementar:

---

## 1. Búsquedas Geoespaciales

### Usuarios Cercanos
```redis
# Buscar todos los usuarios a menos de 1km
GEORADIUS users:geo 16.5896 -93.0547 1 km

# Resultado: 50-60 usuarios en el centro
```

### Usuarios por Colonia
```redis
# Obtener todos los usuarios de una colonia
HGET user:100 colonia_id
# Resultado: usuario está en colonia 1
```

### Rutas Operativas
```redis
# Ver orden lineal de puntos en una ruta
LRANGE route:points:1 0 -1

# Obtener coordenadas exactas de un punto
HGETALL point:1
```

---

## 2. Sistema de 4 Estados de Notificación

**Capacidad:** Máximo 4 notificaciones por usuario por ruta por día (idempotente con SET)

### WARN - Advertencia (200m antes)
```
Usuario en colonia A → Camión se acerca a 200m
Notificación WARN: "El recolector se acerca a tu punto en 2 minutos"
```

### ARRIVAL - Llegada
```
Camión llega exactamente al punto
Notificación ARRIVAL: "El recolector ha llegado a tu punto"
```

### DEPARTURE - Salida (200m después)
```
Camión se aleja 200m del punto
Notificación DEPARTURE: "El recolector ha terminado en tu punto"
```

### COMEBACK - Retorno
```
Si el camión vuelve al punto ese día (urgencia)
Notificación COMEBACK: "El recolector necesita pasar nuevamente por tu punto"
```

---

## 3. Rastreo de Camiones

### Estado Actual del Camión
```redis
HGET truck:state:1 route_id         # ¿Qué ruta está operando?
HGET truck:state:1 current_point_id # ¿En qué punto está?
HGET truck:state:1 lat              # Latitud
HGET truck:state:1 lon              # Longitud
HGET truck:state:1 updated_at       # Última actualización
```

### Historial de Vaciados
```redis
# Últimos vaciados en un relleno
LRANGE historial:vaciado:1:1 0 -1

# Ejemplo de formato: "camion:1|ts:1706652000|status:completado"
```

---

## 4. Gestión de Tokens FCM

### Validación de Tokens
```redis
HGET user:100 fcm_token      # Token FCM del usuario
HGET user:100 fcm_status     # Estado: valid, invalid, expired
HGET user:100 fcm_expires_at # Cuando expira

# Sistema backend puede:
# 1. Validar si token está activo
# 2. Intentar envío si está válido
# 3. Marcar como inválido si falla
# 4. Renovar si está próximo a expirar
```

---

## 5. Métricas en Tiempo Real

### Contador de Notificaciones
```redis
HINCRBY metrics:notifications:1:2026-01-30 total_sent 1
HINCRBY metrics:notifications:1:2026-01-30 warn_count 1
HINCRBY metrics:notifications:1:2026-01-30 arrival_count 1
HINCRBY metrics:notifications:1:2026-01-30 departure_count 1
HINCRBY metrics:notifications:1:2026-01-30 comeback_count 1
HINCRBY metrics:notifications:1:2026-01-30 delivery_success 1
HINCRBY metrics:notifications:1:2026-01-30 delivery_failed 1
```

### Dashboard Potencial
```
Notificaciones Enviadas Hoy:
  - WARN: 234 (82 entregadas)
  - ARRIVAL: 198 (172 entregadas)
  - DEPARTURE: 198 (180 entregadas)
  - COMEBACK: 12 (10 entregadas)
  - Total: 642 (Tasa éxito: 88%)
```

---

## 📊 Ejemplos Reales de Operación

### Escenario 1: Usuario Recibe 4 Notificaciones en un Día

```
08:00 - Usuario 150 está en Centro Histórico (colonia 1)
        Ruta 1 inicia operaciones

08:25 - WARN: Camión a 200m de usuario
  Redis: SADD notification:sent:150:1:2025-01-30 "WARN"
        FCM: "Recolección en 2 minutos"

08:27 - ARRIVAL: Camión llega al punto
  Redis: SADD notification:sent:150:1:2025-01-30 "ARRIVAL"
        FCM: "Recolección iniciada"

08:30 - DEPARTURE: Camión se aleja 200m
  Redis: SADD notification:sent:150:1:2025-01-30 "DEPARTURE"
        FCM: "Recolección completada"

14:00 - COMEBACK: Ruta devuelve (urgencia)
  Redis: SADD notification:sent:150:1:2025-01-30 "COMEBACK"
        FCM: "Recolección adicional disponible"

Resultado: Máximo 4 notificaciones ese día
           (Si intenta enviar la misma WARN nuevamente: SET rechaza duplicado)
```

### Escenario 2: Búsqueda Geoespacial

```
Camión 1 ubicado en: 16.5896, -93.0547 (Centro)

Query: Buscar ciudadanos a menos de 500m para próxima ruta
Redis: GEORADIUS users:geo 16.5896 -93.0547 500 m

Resultado:
  user:102 - 180m
  user:105 - 320m
  user:108 - 450m
  ... (15-20 usuarios típicamente)

Backend puede:
  1. Ordenar por distancia (WITHCOORD, WITHDIST)
  2. Verificar su estado FCM
  3. Preparar notificaciones para próximos 30min
```

### Escenario 3: Reporte de Eficiencia

```
Query: Métricas del día
Redis: HGETALL metrics:notifications:1:2026-01-30

Resultado:
  total_sent: 1,247
  warn_count: 356
  arrival_count: 312
  departure_count: 298
  comeback_count: 281
  fcm_success: 1,087
  fcm_failed: 160

Dashboard: Hoy se enviaron 1,247 notificaciones con 87% de éxito
```

---

## ⚡ Benchmarks Esperados

Con 200 usuarios distribuidos:

| Operación | Tiempo | Volumen |
|-----------|--------|---------|
| GEORADIUS (1km) | < 5ms | 50-60 usuarios |
| HGETALL user | < 1ms | 8 campos |
| SADD SET (dedup) | < 1ms | O(1) |
| RPUSH historial | < 1ms | Append-only |
| HINCRBY metrics | < 1ms | Atómico |
| Cargar 200 usuarios | ~2s | Una sola vez |

**Escalabilidad:** El sistema puede manejar 5000-10000 usuarios sin problemas

---

## 💡 Casos de Uso Adicionales

### Análisis de Cobertura
```
¿Qué colonias están siendo servidas?
- Centro Histórico: 25 usuarios atendidos
- Colonia Industrial: 22 usuarios
- Las Palmas: 28 usuarios
- Vista Hermosa: 19 usuarios
```

### Optimización de Rutas
```
¿Qué ruta tiene más usuarios cercanos?
GEORADIUS points:ruta:1 16.5896 -93.0547 2 km
→ Ruta 1 tiene 48 puntos a cubrir (alta densidad)

GEORADIUS points:ruta:4 16.5696 -93.0447 2 km
→ Ruta 4 tiene 12 puntos a cubrir (baja densidad)
```

### Historial de Movimiento
```
¿Dónde estuvo el camión 1 en las últimas 24h?
LRANGE truck:route:history:1:2026-01-30 0 -1

Ejemplo de datos:
  08:00 - punto:1 (completado)
  08:15 - punto:2 (en progreso)
  08:30 - punto:3 (completado)
  ...
```

---

## 🔌 Integración con Go/Gin Backend

El backend puede implementar endpoints:

### `POST /api/notifications/check`
```
Entrada: {user_id: 100, truck_id: 1, tipo: "WARN"}
Proceso:
  1. SADD notification:sent:{user_id}:{truck_id}:{date} {tipo}
  2. Si es nuevo: HGET user:{user_id} fcm_token
  3. Enviar a FCM
  4. HINCRBY metrics:notifications:{truck_id}:{date} warn_count 1
Salida: {success: true, token_status: "valid"}
```

### `GET /api/usuarios/cercanos?lat=16.5&lon=-93.05`
```
Entrada: Coordenadas actuales del camión
Proceso:
  1. GEORADIUS users:geo {lat} {lon} 1 km WITHCOORD WITHDIST
  2. Para cada usuario: HGET user:{id} fcm_status
  3. Filtrar activos
Salida: [
  {user_id: 102, distancia: 0.18km, fcm_status: "valid"},
  {user_id: 105, distancia: 0.32km, fcm_status: "valid"},
  ...
]
```

### `GET /api/metricas/hoy`
```
Entrada: Fecha de hoy
Proceso:
  1. HGETALL metrics:notifications:{truck_id}:{date}
  2. Calcular porcentaje de éxito
  3. Comparar con histórico
Salida: {
  total_enviadas: 1247,
  exitosas: 1087,
  fallidas: 160,
  tasa_exito: 87.1%
}
```

---

## 📚 Ver También

- [04-redis-schema.md](04-redis-schema.md) - Esquema de datos
- [05-data-lifecycle.md](05-data-lifecycle.md) - Flujos de datos
- [testing/redis-tests.md](testing/redis-tests.md) - Suite de pruebas Redis

---

**Última actualización:** 2026-01-30
**Versión:** 1.0 - MVP
