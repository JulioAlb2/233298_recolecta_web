# 09 · Pipeline modelo_reportes → clasificador_reportes

Conecta la creación de reportes (`anomalia`, dominio `Fallas` del backend) con los dos microservicios de ML: `modelo_reportes` (filtro de fraude/anomalías) y `clasificador_reportes` (clasificación simbólica + acción sugerida sobre el grafo de rutas). El algoritmo genético de rutas (AG) **no existe todavía** — este documento cubre solo hasta la clasificación; la acción sobre el AG queda como TODO explícito en el código.

## Arquitectura

Se eligió **orquestación centralizada en gin-backend**, no llamadas encadenadas entre los microservicios Python. `modelo_reportes` y `clasificador_reportes` están diseñados para ser servicios independientes y sin estado (ver sus propios README): solo reciben texto y responden, no se conocen entre sí. El backend Go ya es dueño de la tabla `anomalia`, de auth, y del dominio `Rutas`, así que es el candidato natural para coordinar el flujo.

Flujo:

1. Un ciudadano, conductor o miembro de staff hace `POST /api/anomalias/` con el texto del reporte. El backend lo guarda con `estado_pipeline = 'pendiente'` y responde de inmediato (201) — no espera a los modelos.
2. Una goroutine background reclama la fila (`ReclamarPipeline`, ver más abajo) y llama `POST {MODELO_REPORTES_URL}/infer`.
3. Si `nivel_riesgo_final == "alto"` → se marca `estado_pipeline = 'rechazado'` y el flujo termina ahí (reporte probablemente fraudulento/spam, no vale la pena clasificarlo).
4. Si no, llama `POST {CLASIFICADOR_URL}/clasificar` con el mismo texto (+ el `inferencia_id` devuelto en el paso 2, + `origen`: `"conductor"` o `"ciudadano"`).
5. Se guarda el resultado (`categoria_clasificada`, `subtipo_clasificado`, `accion_sugerida`) con `estado_pipeline = 'clasificado'`.
6. **Pendiente**: si `categoria_clasificada == "calle_tapada"` (equivalente: `accion_sugerida` en `block_edge`/`inflate_weight`), disparar el algoritmo genético de rutas. El TODO está marcado en `ProcesarPipelineAnomaliaUseCase.Run`.

### Confiabilidad: outbox pattern + worker de reintento

El primer diseño disparaba el pipeline solo desde una goroutine al crear el reporte, sin nada que lo respaldara: si el backend se reiniciaba a la mitad (Air en dev, un redeploy en prod), el reporte quedaba en `pendiente` para siempre. Se resolvió con el patrón estándar para este problema (transactional outbox + worker de polling), sin meter infraestructura nueva (ni cola/broker):

- **Estados de `estado_pipeline`:** `pendiente` → `procesando` → `clasificado` | `rechazado` | `error`.
- **Claim atómico (`IAnomalia.ReclamarPipeline`):** un `UPDATE ... WHERE` condicional que solo tiene efecto si la fila está en un estado "reclamable" (`pendiente`, `procesando` abandonada hace más de 2 minutos, o `error` con `pipeline_intentos` por debajo del máximo). Es lo que evita que dos disparadores (la goroutine del alta y el worker) procesen la misma anomalía dos veces — el que pierde la carrera simplemente no hace nada, sin locks explícitos.
- **`PipelineRetryWorker`:** corre en background durante toda la vida del proceso (arrancado una sola vez con `go worker.Run()`, igual que `tracking_ws.Hub`). Cada 30s revisa la tabla por filas reclamables y vuelve a llamar `ProcesarPipelineAnomaliaUseCase.Run` sobre ellas — es la red de seguridad que recupera lo que la goroutine del camino rápido no pudo terminar.
- **`pipeline_intentos`:** cuenta cuántas veces se reclamó la fila. Tras `MaxIntentosPipeline` (5) intentos fallidos, el worker deja de reintentarla sola; queda visible en `pipeline_error` para revisión manual desde el frontend web (`/anomalias`).

Se descartó un enfoque con webhooks (los microservicios llamando de vuelta al backend cuando terminan) porque no resuelve el problema real — seguiría haciendo falta persistir "hay un trabajo pendiente" para sobrevivir un reinicio, que es justo lo que ya da `estado_pipeline`/`pipeline_intentos` — y porque los tres servicios viven en la misma red Docker privada, mismo equipo: la complejidad extra de un endpoint entrante, autenticación y verificación de duplicados no se justifica cuando las respuestas de `modelo_reportes`/`clasificador_reportes` ya son rápidas (segundos, no minutos).

Los tres contenedores (`gin_backend`, `modelo_reportes`, `clasificador_reportes`) están en la misma red de Docker (`app_internal_net`, definida en `docker.compose.yml`). El backend les habla directo por nombre de contenedor (`http://modelo_reportes:8000`, `http://clasificador_reportes:8001`) — **no pasa por nginx**, eso solo existe para acceso externo/testing (`/modelo/`, `/clasificador/`). Esto no cambia entre dev y despliegue real: mientras todo se levante desde el mismo `docker compose up`, el DNS interno de Docker resuelve igual sin importar el servidor.

## Archivos nuevos

| Archivo | Qué hace |
|---|---|
| `gin-backend/migrations/2026-07-22_pipeline_reportes_anomalia.sql` | Agrega las columnas del pipeline a `anomalia`. Idempotente (`IF NOT EXISTS`). |
| `gin-backend/src/Fallas/domain/pipeline_reportes.go` | Interfaz `PipelineReportesClient` (puerto hexagonal) + tipos `InferenciaResultado`/`ClasificacionResultado`. |
| `gin-backend/src/Fallas/infrastructure/pipeline_client.go` | Implementación HTTP real de `PipelineReportesClient` (`InferirRiesgo`, `ClasificarReporte`). |
| `gin-backend/src/Fallas/application/ProcesarPipelineAnomaliaUseCase.go` | Orquesta el pipeline: infiere → (si no rechazado) clasifica → persiste. Corre en background. Define `MaxIntentosPipeline`/`PipelineProcesandoStaleDespues` y reclama la fila (`ReclamarPipeline`) antes de procesar. |
| `gin-backend/src/Fallas/infrastructure/pipeline_retry_worker.go` | `PipelineRetryWorker`: hace polling cada 30s sobre filas reclamables y reintenta el pipeline. Arrancado con `go worker.Run()` desde `anomalia_routes.go`. |
| `gin-backend/migrations/2026-07-23_pipeline_retry_worker.sql` | Agrega `pipeline_intentos` a `anomalia`. Idempotente. |

## Archivos modificados

| Archivo | Cambio |
|---|---|
| `gin-backend/db_script.sql` | Columnas nuevas en el `CREATE TABLE anomalia` (para instalaciones nuevas). |
| `gin-backend/config/config.go` | `ModeloReportesURL` / `ClasificadorURL`, leídas de env con default a los nombres de contenedor. |
| `.env`, `.env.example`, `gin-backend/.env.example` | Nuevas vars `MODELO_REPORTES_URL` / `CLASIFICADOR_URL`. |
| `gin-backend/src/Fallas/domain/anomalia_repository.go` | `IAnomalia` gana `ActualizarPipeline`, `ReclamarPipeline` y `ListoParaPipeline`. |
| `gin-backend/src/Fallas/infrastructure/postgres_anomalia_repository.go` | Implementa `ActualizarPipeline`, `ReclamarPipeline` (UPDATE condicional/claim atómico) y `ListoParaPipeline` (SELECT de candidatas para el worker). `anomaliaColumnas`/`scanAnomalia` incluyen las columnas nuevas, para que `GET` las devuelva. |
| `gin-backend/src/Fallas/domain/entities/anomalia.go` | Struct `Anomalia` gana los 7 campos del pipeline (`EstadoPipeline`, `NivelRiesgo`, `InferenciaID`, `CategoriaClasificada`, `SubtipoClasificado`, `AccionSugerida`, `PipelineError`) más `PipelineIntentos`. |
| `gin-backend/src/Fallas/application/CreateAnomaliaUseCase.go` | Dispara `ProcesarPipelineAnomaliaUseCase` en background tras guardar (solo tipos `ANOMALIA`/`INCIDENCIA`/`REPORTE_CONDUCTOR`). De paso corrige un bug preexistente: `string(anomalia.TipoAnomalia)` no llamaba a `.String()` (convertía el enum a un carácter Unicode, no al texto) — esto también rompía silenciosamente la alerta a supervisores para `REPORTE_FALLA_CRITICA`/`INCIDENCIA`, que ahora sí dispara. |
| `gin-backend/src/Fallas/infrastructure/dependencies_anomalia.go` | `InitAnomaliaDependencies` arma el `HTTPPipelineClient`, lo inyecta en `CreateAnomaliaUseCase`, y construye el `PipelineRetryWorker`. |
| `gin-backend/src/Fallas/infrastructure/anomalia_routes.go` | `POST /api/anomalias/` pasa a un grupo propio con solo `JWTAuthMiddleware()` (cualquier usuario autenticado: ciudadano, conductor o staff). El resto del CRUD (`GET/PUT/DELETE`, listados) sigue restringido a `ADMIN/SUPERVISOR/COORDINADOR`. También arranca `go pipelineRetryWorker.Run()`. |
| `gin-backend/dependencies.go` | Pasa `cfg.ModeloReportesURL`/`cfg.ClasificadorURL` al armar `AnomaliaRouter`. |
| `gin-backend/src/Fallas/domain/entities/anomalia_swagger.go` | Bug de documentación preexistente corregido: `tipo_anomalia` y `fecha_reporte` estaban tipados como el enum interno / `time.Time` en el modelo de Swagger, cuando el controller real espera texto plano. Causaba `"must be an integer"` al probar desde Swagger UI. |
| `gin-backend/src/Fallas/infrastructure/CreateAnomaliaController.go` | Comentario `@Description` actualizado para reflejar que el endpoint ya no es solo de staff. |

## Por qué solo un endpoint de creación

Se evaluó tener `/api/anomalias/reportar` (público) separado de `/api/anomalias/` (staff), pero el controller/use case es idéntico para ambos casos — no hay ninguna diferencia de lógica según quién llama. Mantener dos rutas para la misma operación solo generaba confusión (incluyendo Swagger documentando la misma cosa dos veces). Se optó por un solo path (`POST /api/anomalias/`) con auth relajada, y el resto del CRUD en un grupo aparte con `RequireRole`. Los ciudadanos no tienen `role_id` en el esquema de roles de empleados (su JWT trae `role_id: 0`, ver `login_ciudadano.go`) y `CONDUCTOR` (4) tampoco es staff — por eso la creación necesitaba su propio grupo de middleware.

## Pasos para quien jale estos cambios

1. **Migraciones obligatorias** — no se aplican solas, el contenedor de Postgres solo corre `db_script.sql` en el primer arranque del volumen. Correr ambas, en orden:
   ```bash
   docker exec -i postgres_db psql -U <DB_USER> -d <DB_NAME> < gin-backend/migrations/2026-07-22_pipeline_reportes_anomalia.sql
   docker exec -i postgres_db psql -U <DB_USER> -d <DB_NAME> < gin-backend/migrations/2026-07-23_pipeline_retry_worker.sql
   docker exec -i postgres_db psql -U <DB_USER> -d <DB_NAME> < gin-backend/migrations/2026-07-23_anomalia_lat_lon.sql
   docker exec -i postgres_db psql -U <DB_USER> -d <DB_NAME> < gin-backend/migrations/2026-07-23_anomalia_ciudadano_id.sql
   ```
   En PowerShell, usar `Get-Content -Raw | docker exec -i ...` en vez de `<` (no soportado).

2. **Variables de entorno** — opcionales. Si no se definen `MODELO_REPORTES_URL`/`CLASIFICADOR_URL`, caen a los defaults (`http://modelo_reportes:8000` / `http://clasificador_reportes:8001`), que ya son correctos si se usa el `docker.compose.yml` de este repo tal cual.

3. **Rebuild del backend** (el código Go cambió):
   ```bash
   docker compose -f docker/docker.compose.yml -f docker/docker.compose.dev.yml --env-file .env up -d --build backend
   ```

4. **Confirmar que `modelo_reportes` tiene el modelo entrenado cargado** — si a alguien le falta el pull de los artefactos (`entrenamienot/artefactos/*.joblib`), el `/infer` va a fallar y todo reporte va a terminar en `estado_pipeline = "error"`. Probar directo:
   ```bash
   curl -X POST http://localhost:8000/infer -H "Content-Type: application/json" -d '{"reporte":"prueba","tenant_id":1}'
   ```

5. **Probar el flujo completo**: crear un reporte vía `POST /api/anomalias/` (cualquier usuario logueado), esperar ~10s, y consultar `GET /api/anomalias/{id}` (requiere rol de staff) para ver `estado_pipeline` avanzar de `pendiente` → `clasificado`/`rechazado`/`error`.

## Coordenadas GPS (`lat`/`lon`)

`anomalia` gana dos columnas nullable, `lat`/`lon` (`DOUBLE PRECISION`), agregadas en `migrations/2026-07-23_anomalia_lat_lon.sql`. Es insumo para el algoritmo genético de rutas: cuando exista, necesita saber *dónde* ocurrió el bloqueo/incidente para decidir qué arista del grafo modificar. No se deriva de `punto_id` porque muchos reportes (p. ej. "calle bloqueada") ocurren en un punto arbitrario de una ruta, no en un `punto_recoleccion` ya registrado. Mismo nombre/tipo que ya usa `Rutas.PuntoRecoleccion` (`Lat`/`Lon` `float64`), para mantener la convención existente en el backend — con la diferencia de que aquí son punteros porque, a diferencia de un punto de recolección fijo, no todo reporte va a traer ubicación.

`POST`/`PUT /api/anomalias/` ya aceptan `lat`/`lon` opcionales en el body. **Pendiente**: ningún cliente (app conductor/ciudadano, web) los captura ni los envía todavía — eso requiere agregar captura de ubicación (permisos GPS) en las apps, fuera del alcance de este cambio de esquema.

## Ciudadano como reportero de primera clase

Hasta ahora un ciudadano podía crear una anomalía, pero la fila no guardaba quién la reportó (no había `ciudadano_id`) -- no podía después listar "mis reportes" ni borrar el suyo, a diferencia del conductor. Se agregó:

- **`ciudadano_id`** (nullable) en `anomalia`, migración `2026-07-23_anomalia_ciudadano_id.sql`. Nunca convive con `conductor_id`: una anomalía la reporta un conductor o un ciudadano, no los dos.
- **`core.CIUDADANO = 0`** en `src/core/roles.go`: nombra el valor centinela que `login_ciudadano.go` ya usaba a mano como `role_id` del JWT.
- **`CreateAnomaliaController`** ya no confía en `conductor_id`/`ciudadano_id` del body salvo cuando quien crea es staff: para cualquier ciudadano o conductor, el backend los deriva del JWT (`role_id` + `user_id`), cerrando de paso la limitación que ya estaba documentada más abajo ("`origen` confía en el body, no en el JWT").
- **`DeleteAnomaliaUseCase`** ahora compara `CiudadanoID` cuando `requesterRoleID == core.CIUDADANO`, y `ConductorID` en cualquier otro caso no-staff. Importante: `conductor_id` referencia `empleado` y `ciudadano_id` referencia `ciudadano` -- dos espacios de IDs distintos que pueden coincidir en número, por eso hace falta el rol para saber contra cuál comparar.
- **`GET /api/anomalias/mis-reportes`** (nuevo, grupo abierto): devuelve los reportes del usuario autenticado -- ciudadano o conductor, según su JWT, sin recibir ningún ID por parámetro (a diferencia de `/chofer/:choferId`, que es staff-only y sí acepta cualquier ID).

## Limitaciones conocidas / pendientes

- **`tenant_id` fijo en `1`.** El dominio `Fallas`/`Anomalia` no está conectado al sistema de multi-tenant real del backend (que hoy tampoco es funcional del todo — ver `docs/08-multitenancy-implementado.md`). Si en algún momento se conecta, hay que pasar el tenant real hasta `ProcesarPipelineAnomaliaUseCase.Run` en vez del `1` fijo.
- **`origen` (conductor/ciudadano) confía en el body del request**, no en el JWT. Un ciudadano podría mandar cualquier `conductor_id`. No se corrigió porque no afecta el pipeline en sí, pero si llega a importar la trazabilidad real, `origen`/`conductor_id` deberían derivarse del token, no del body.
- **Algoritmo genético de rutas: no implementado.** Solo está referenciado como nodo futuro en el grafo de conocimiento de `clasificador_reportes` (`grafo_conocimiento.json`, nodo `c_ga`). Cuando exista, el punto de integración es el `TODO` en `ProcesarPipelineAnomaliaUseCase.Run`.
