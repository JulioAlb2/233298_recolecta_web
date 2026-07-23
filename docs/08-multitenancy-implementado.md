# Multitenancy implementado — resultado de ejecutar `docs/07-plan-multitenancy.md`

Este documento registra lo que realmente se implementó al ejecutar el plan de
`docs/07-plan-multitenancy.md`, fase por fase, y justifica las decisiones de
diseño tomadas — incluyendo las que solo se pudieron confirmar al correr los
cambios contra el Postgres real del `docker compose` de desarrollo.

---

## Por qué Pool y no Silo/Bridge (confirmado contra este proyecto real)

- **Bridge** quedó descartado para `modelo-reportes` y `clasificador-reportes`: ambos corren sobre
  SQLite (`docker/docker.compose.yml`, `DATABASE_URL: sqlite:////data/...`), y SQLite no tiene
  concepto de "schema" que particionar.
- **Silo** hubiera multiplicado el bug real que tenía `init-database.sh` (Fase 0): el script
  declaraba `SCHEMA_CONSTRAINTS_PATH`/`SCHEMA_INDEXES_PATH` pero nunca los ejecutaba — solo corría
  `db_script.sql`. Confirmado al leer el script antes de tocar nada. Coordinar N inicializaciones de
  infraestructura de este tipo, una por tenant, hubiera sido bastante más caro que arreglarlo una
  vez en un modelo Pool.
- **Pool** es el único que sirve a la vez para Postgres (`gin-backend`, con RLS) y SQLite
  (`modelo-reportes`/`clasificador-reportes`, sin RLS, con filtro explícito), y es compatible con el
  login existente: `empleado`/`ciudadano` se buscan por email/username de forma global, *antes* de
  saber a qué tenant pertenecen — ver la sección de Fase 4/5 más abajo.

---

## Fase 0 — `docker/postgresql/init-scripts/init-database.sh`

Se agregó la función `apply_schema_file`, que corre `db_constraints.sql` y `db_indexes.sql`
completos contra `$DB_NAME` (sin `tail`, porque a diferencia de `db_script.sql` estos dos archivos
no tienen el preámbulo `CREATE DATABASE`/`\c` que recortar — su único `\c proyecto_recolecta;` es
inofensivo corrido las veces que sea), y registra su checksum en `schema_version` con el mismo
patrón que ya usaba el script para `db_script.sql`. Se llama justo después del bloque
existe/no-existe de la base, para que ambos casos (primera creación y arranque sobre una base ya
inicializada) terminen con constraints e índices aplicados de verdad.

**Nota operativa importante:** el volumen `postgres_data` del stack de desarrollo ya tenía datos al
momento de ejecutar este plan, así que el entrypoint de Postgres nunca vuelve a correr
`/docker-entrypoint-initdb.d` (solo corre en la primera creación del volumen). Este fix de Fase 0
queda verificado por lectura e importa para el día que alguien levante el proyecto desde cero, pero
**no** fue lo que aplicó los cambios de esquema a la base de desarrollo actual — eso se hizo
aplicando manualmente los tres `.sql` ya editados vía
`docker exec -i postgres_db psql -U recolecta_dev -d proyecto_recolecta -f -`, en orden
(script → constraints → indexes), simulando exactamente lo que el script corregido haría en una
base nueva.

---

## Fase 1-3 — Esquema, columna+FK, índices

- `gin-backend/db_script.sql`: tabla `tenant` (`tenant_id SERIAL PRIMARY KEY, nombre, activo,
  created_at`), sembrada con `tenant_id=1` ("Tenant Demo/Legacy") vía
  `INSERT ... ON CONFLICT (tenant_id) DO NOTHING`. Columna `tenant_id INTEGER NOT NULL DEFAULT 1`
  agregada a las 19 tablas tenant-scoped listadas en el plan original. `rol`, `tipo_camion` y
  `tipo_mantenimiento` se dejaron sin tocar (catálogo global).
- `gin-backend/db_constraints.sql`: bloque `DO $$ ... FOREACH tbl IN ARRAY [...]` que agrega
  `ADD COLUMN IF NOT EXISTS tenant_id` + `ADD CONSTRAINT fk_<tabla>_tenant` a las 19 tablas, para
  que la columna quede garantizada sin importar si la tabla ya tenía datos de antes (`CREATE TABLE
  IF NOT EXISTS` de la Fase 1 no las hubiera tocado).
- `gin-backend/db_indexes.sql`: mismo tipo de loop, `CREATE INDEX idx_<tabla>_tenant_id` en las 19
  tablas.

**Verificado contra el Postgres real:** las 19 tablas tienen la columna+FK, `tenant` tiene la fila
semilla (`tenant_id=1, 'Tenant Demo/Legacy'`), y los 19 índices existen (`idx_*_tenant_id`).

**Errores encontrados al aplicar, y por qué no se tocaron:** al correr `db_constraints.sql` contra
la base de desarrollo aparecieron 4 errores que **ya existían antes de este plan** (confirmado con
`git diff --stat`, que muestra que mi edición fue puramente aditiva sobre ese archivo):

- `fk_chofer_historial` — datos huérfanos en `historial_asignacion_camion` (choferes que ya no
  existen en `empleado`).
- `uq_placa_camion` — placas duplicadas en `camion`.
- `fk_camion_asignado_ruta` — `camion_id` huérfanos en `ruta_camion`.
- `uq_nombre_ruta` — nombres duplicados en `ruta`.
- (bonus, apareció en el segundo intento) `fk_rol` — el archivo original chequea
  `constraint_name = 'fk_rol_empleado'` antes de crear la constraint, pero la constraint que
  realmente crea se llama `fk_rol` — el guard nunca matchea en una segunda corrida. Bug
  pre-existente de nomenclatura, no de multitenancy.

Estos son problemas de calidad de datos/constraints preexistentes, no introducidos por
multitenancy — quedan fuera del alcance de este plan y no se tocaron.

---

## Fase 4 — JWT, middleware, login

`gin-backend/src/core/jwt.go`: `Claims` gana `TenantID int`; `GenerateToken` gana un tercer
parámetro `tenantID int`. `jwt_middleware.go` propaga `c.Set("tenant_id", claims.TenantID)` al
contexto de Gin, igual que ya hacía con `user_id`/`role_id`. Los 2 call sites de `GenerateToken`
(`empleado/application/login.go`, `Ciudadanos/.../login_ciudadano.go`) ahora pasan el tenant leído
de la entidad.

`entities.Empleado` y `entities.Ciudadano` ganan `TenantID int`. En `postgresempleado.go` y
`postgreSQLCiudadano.go`, **todos los SELECT** (`GetByID`, `List`, `FindByMail`/`FindByEmail`,
`FindByUsername`/`FindByAlias`, `FindByMailOrUsername`/`FindByEmailOrAlias`) ahora leen y escanean
`tenant_id`. El `INSERT` de `Create` en ambos repositorios **no** incluye `tenant_id` a propósito:
se deja caer al `DEFAULT 1` de la columna, porque en esta pasada el alta de empleado/ciudadano
todavía no tiene contexto de tenant (eso es justo lo que Fase 6 deja pendiente para el resto de
módulos).

**Por qué `empleado`/`ciudadano` no llevan RLS:** el login los busca por email/username de forma
global — es exactamente el paso que determina a qué tenant pertenecen. Forzar RLS ahí bloquearía el
login de cualquier empleado/ciudadano que no perteneciera al tenant de respaldo (`1`), ya que RLS
solo puede filtrar una vez que `app.current_tenant` está fijado, y en el momento del login todavía
no se sabe cuál es. **Qué haría falta para activarlo ahí también:** separar el lookup de
autenticación (por email/username, sin filtro de tenant, usado solo para validar credenciales y
determinar el tenant) de cualquier otra operación de lectura/escritura sobre esas tablas — y correr
esas otras operaciones sí dentro de `RunInTenantTx`. Hoy el CRUD de `empleado`/`Ciudadanos` no
distingue ambos casos, así que activar RLS ahí de golpe rompería también las lecturas legítimas
post-login.

---

## Fase 5 — `RunInTenantTx` + RLS

Nuevo `gin-backend/src/core/tenant_db.go`: `RunInTenantTx(ctx, pool, tenantID, fn)` abre una
transacción, fija `app.current_tenant` con
`SELECT set_config('app.current_tenant', $1, true)` (parametrizado, `is_local=true`), corre `fn`, y
hace commit/rollback.

**Por qué `is_local=true` y no un `SET` de sesión:** `pgxpool` reutiliza conexiones físicas entre
requests de tenants distintos. Si la variable quedara fijada a nivel de sesión (`SET` sin
`is_local`), una conexión podría "arrastrar" el tenant de un request anterior al siguiente request
que la reutilice — un query de tenant B podría ejecutarse todavía bajo el `app.current_tenant` del
tenant A si cayó en la misma conexión física. Al acotarla a la transacción, Postgres la resetea sola
en el `COMMIT`/`ROLLBACK`, sin importar qué tenant use esa conexión después.

En `db_constraints.sql`: `ENABLE ROW LEVEL SECURITY` + `FORCE ROW LEVEL SECURITY` + política
`tenant_isolation` con
`USING (tenant_id = COALESCE(NULLIF(current_setting('app.current_tenant', true), ''), 1))` sobre
las 17 tablas tenant-scoped que sí pueden llevar RLS (las 19 de Fase 1 menos `empleado`/`ciudadano`).

**Por qué el fallback a tenant `1` en vez de bloquear todo sin contexto:** permite activar RLS de
forma incremental. Los módulos que todavía no llamen `RunInTenantTx` (todos excepto `colonia`, ver
Fase 6) caen al tenant `1` en vez de quedarse sin datos — siguen funcionando exactamente igual que
antes de este plan, mientras se migran uno por uno. El riesgo que esto **acepta**: esos módulos
comparten un tenant implícito (el `1`) hasta que se migren explícitamente; el riesgo que
**controla**: que activar RLS no rompa de golpe todo el sistema el día que se activó.

### Hallazgo importante: `DB_USER` es superusuario en este entorno de desarrollo

`SELECT rolsuper FROM pg_roles WHERE rolname = 'recolecta_dev';` → **`true`**.

Esto significa que, tal como está configurada la conexión de la app hoy (`.env` → `DB_USER`), **RLS
no se está aplicando de verdad en el tráfico real de la aplicación**, sin importar `FORCE ROW LEVEL
SECURITY` — los superusuarios de Postgres ignoran RLS incondicionalmente. Es un requisito operativo
que ya el plan original anticipaba verificar (Fase 5), y el resultado es que **hoy RLS es una red de
seguridad inerte para el rol configurado en `.env`**: cualquier aislamiento efectivo depende
actualmente solo del filtro explícito en la capa de aplicación (que `colonia` sí implementa, ver
Fase 6; el resto de módulos, no).

**Para que RLS aplique de verdad**, `DB_USER` en `.env` debe apuntar a un rol `NOSUPERUSER` con los
`GRANT` necesarios sobre las tablas tenant-scoped. No se cambió en este plan porque es una decisión
de configuración de infraestructura (afecta cómo se conecta toda la app en desarrollo) fuera del
alcance de "ejecutar el plan de esquema/código"; queda documentado aquí como el siguiente paso
crítico antes de confiar en RLS como capa de defensa real.

Para probar que las políticas en sí (no el rol actual) funcionan como se diseñaron, el test de
integración de Fase 9 crea su propio rol `NOSUPERUSER` temporal — ver esa sección.

---

## Fase 6 — `colonia` como plantilla completa

- `domain/repository.go`: `Create`/`Update`/`Delete` ahora reciben `(ctx, tenantID, ...)`.
- `infrastructure/postgres/colonia_repository.go`: esos 3 métodos corren dentro de
  `core.RunInTenantTx`; el `INSERT` de `Create` incluye `tenant_id` explícito (del contexto de quien
  crea, no del default). `GetByID`/`GetAll` (rutas públicas) quedan intactos — dependen solo del
  fallback de RLS a tenant 1, tal como especifica el plan original.
- `application/{create,update,delete}_colonia.go`: `Execute` gana `ctx`/`tenantID`.
- `infrastructure/http/colonia_controller.go`: `Create`/`Update`/`Delete` leen `tenant_id` del
  contexto de Gin (puesto ahí por el middleware JWT de Fase 4) y responden 401 si falta — garantía
  extra, ya que esas rutas están detrás de `JWTAuthMiddleware`.

**Verificado end-to-end:** login como admin → token con `tenant_id:1` → `POST /api/colonia` → fila
creada en Postgres con `tenant_id=1` correcto.

**Módulos que quedaron solo con columna + RLS pasivo (sin el filtro explícito en el repositorio):**
`Camion`, `Fallas`, `Rutas`, `alerta_usuario`, `dispositivos`, CRUD completo de
`empleado`/`Ciudadanos`. El checklist para replicar el patrón de `colonia` en cualquiera de ellos es
mecánico:
1. Cambiar la interfaz del repositorio para que los métodos de escritura reciban `(ctx, tenantID, ...)`.
2. Envolver esos métodos en `core.RunInTenantTx`, agregando `tenant_id` explícito al `INSERT`.
3. Propagar `ctx`/`tenantID` por la capa de aplicación.
4. Leer `tenant_id` del contexto de Gin en el controller y pasarlo al caso de uso.

---

## Fase 7 — `modelo-reportes` (clasificador-reportes ya lo tenía)

Al revisar el repo antes de ejecutar el plan se encontró que **`clasificador-reportes` ya tenía la
Fase 7 aplicada** (commit `8bf1c6b`, de una sesión previa): `Clasificacion` ya tenía `tenant_id`
obligatorio, y `/clasificaciones` + `/clasificaciones/{id}` ya filtraban por `tenant_id` como query
param obligatorio, con tests de aislamiento ya escritos en `tests/test_api.py`. No se tocó nada ahí.

`modelo-reportes` sí necesitaba el mismo tratamiento:
- `api/models/inference.py`: `tenant_id` obligatorio (`nullable=False`, sin default) en el modelo
  SQLAlchemy.
- `api/schemas/inference.py`: `tenant_id` obligatorio en `InferenceCreate` y presente en
  `InferenceRead`/`InferenceListResponse`.
- `api/repositories/inference_repository.py`: `list_inferences`/`count_inferences` filtran por
  `tenant_id`.
- `api/routers/inference.py`: `POST /infer` lo exige en el body; `GET /inferences` lo exige como
  query param obligatorio.
- `api/services/inference_service.py`: propaga `tenant_id` del request al modelo persistido.

**Migración de datos:** la tabla `inferencias` en el SQLite de desarrollo ya existía pero estaba
vacía (0 filas) — se le agregó la columna con
`ALTER TABLE inferencias ADD COLUMN tenant_id INTEGER NOT NULL DEFAULT 1` directamente sobre el
archivo montado en el volumen `modelo_reportes_data`, ya que `Base.metadata.create_all()` de
SQLAlchemy no altera tablas existentes.

**Por qué es obligatorio y no opcional con default (en el schema/API, aunque la columna SQLite
tenga `DEFAULT 1` para la migración):** esta base corre sobre SQLite — no hay Row-Level Security
disponible como red de seguridad. El filtro explícito en cada endpoint es la única barrera real;
hacerlo opcional habría anulado la protección en el primer llamado que alguien hiciera sin pensar en
tenants.

**Verificado:** `POST /infer` sin `tenant_id` → 422. `GET /inferences` sin `tenant_id` → 422. Tests
nuevos en `modelo-reportes/tests/test_api.py` (4 casos, corridos con pytest dentro de la imagen
reconstruida) verifican que un tenant no ve las inferencias de otro, insertando directo vía el
repositorio (no se pudo probar `POST /infer` de punta a punta porque este entorno no tiene los
artefactos de modelo entrenado en `entrenamienot/artefactos/` — limitación preexistente, no
relacionada con multitenancy).

---

## Fase 8 — Redis en `notificacion` (decisión de producto: reglas por tenant)

Revisión de los 4 repositorios Redis de `gin-backend/src/notificacion/infrastructure/`:

- `redis_event_trace_repository.go` (keys `event:trace:<event_id>`, `truck:events:<truck_id>`) y
  `redis_admin_realtime_session_repository.go` (keys `ws:upgrade:<jti>`, `ws:session:<session_id>`):
  **seguros por construcción** — sus IDs (SERIAL de Postgres, o JTI/session ID únicos globalmente)
  nunca se listan sin conocer primero el ID exacto, así que no hay operación de enumeración
  cross-tenant posible.
- `redis_notification_repository.go` (key `user:<uid>`): igual, seguro por construcción — requiere
  ya conocer el ID de usuario específico, pasado por el caller.
- `redis_notification_rule_repository.go` (key `rules:state:<code>`, `List()` sin ningún filtro):
  **el único de los 4 sin ningún tenant scoping** — era configuración puramente global.

Se consultó al usuario si las reglas debían seguir siendo globales o pasar a ser por tenant.
**Decisión: por tenant.** Como en el momento de la decisión no había ninguna regla configurada
(`redis-cli KEYS "rules:state:*"` vacío), no hizo falta migración de datos.

Cambios:
- `domain/notification_rule.go`: `NotificationRule` gana `TenantID`; los 4 métodos de
  `INotificationRuleRepository` ganan `tenantID int` como primer parámetro.
- `redis_notification_rule_repository.go`: la key pasa de `rules:state:<code>` a
  `rules:state:<tenant_id>:<code>`; `List()` filtra con `KEYS "rules:state:<tenant_id>:*"`.
- `manage_notification_rules.go` y `notification_rules_controller.go`: propagan `tenantID`, leído
  del contexto de Gin (las 4 rutas de `/api/notificaciones-push/reglas` ya estaban detrás de
  `JWTAuthMiddleware`).
- `ProcessTruckArrivalUseCase.Execute` gana `tenantID` y lo pasa a `GetByStateCode`;
  `ProcessArrivalController.Run` lo lee del contexto (esa ruta ya tenía `JWTAuthMiddleware` +
  `RequireRole(CONDUCTOR)` + `DeviceValidationMiddleware`).

**Bug preexistente encontrado y corregido al verificar esto:** la ruta registra el parámetro como
`/:codigo_estado`, pero el controller leía `c.Param("state_code")` — un nombre que nunca existía en
el contexto de Gin, así que `code` siempre llegaba vacío. No tiene relación con multitenancy (existía
desde antes de este plan, confirmado con `git show HEAD:...`), pero bloqueaba verificar el cambio de
Fase 8, así que se corrigió (`c.Param("codigo_estado")`, 3 ocurrencias).

**Verificado end-to-end:** `PUT /api/notificaciones-push/reglas/ARRIVAL` con token de tenant 1 →
persiste en Redis como `rules:state:1:ARRIVAL`; `GET /api/notificaciones-push/reglas` con ese mismo
token devuelve `tenant_id:1` en la regla; sin token → 401.

---

## Fase 9 — Tests de aislamiento (corridos contra los contenedores reales)

- **Go:** `gin-backend/tests/integration/colonia/tenant_isolation_test.go`. Dado el hallazgo de
  Fase 5 (`recolecta_dev` es superusuario), la prueba **no** usa el pool de conexión normal de la
  app para el aserto de aislamiento — en su lugar, crea su propio rol Postgres `NOSUPERUSER`
  temporal (con solo los `GRANT` necesarios sobre `colonia`), abre una conexión con ese rol, y usa
  `RunInTenantTx` real para: crear una colonia como tenant A, confirmar que tenant B no la ve
  (`COUNT = 0`) ni puede modificarla (`UPDATE` afecta 0 filas), y que tenant A sí la ve. Esto prueba
  que las políticas RLS en sí funcionan correctamente, independientemente de que el rol configurado
  hoy en `.env` no las esté aprovechando. El test limpia su rol y datos de prueba al terminar
  (`t.Cleanup`, incluyendo `DROP OWNED BY` antes de `DROP ROLE` — necesario porque Postgres no deja
  soltar un rol con privilegios `GRANT` pendientes).
  Corrido con `docker exec gin_backend_dev go test ./tests/integration/colonia/... -v` → **PASS**.
  `go test ./...` completo también corrido: todo pasa excepto un `[build failed]` preexistente en
  `src/Fallas/application` (falla de `go vet` por una conversión `int→string`, archivo no tocado en
  este plan, confirmado sin diff) — no relacionado con multitenancy.
- **Python:** `modelo-reportes/tests/test_api.py` (nuevo, 4 casos) y
  `clasificador-reportes/tests/test_api.py` (ya existía) corridos con `pytest` dentro de las
  imágenes reconstruidas de cada servicio. `modelo-reportes`: 4 passed. `clasificador-reportes`: 57
  passed (suite completa, sin regresiones).

---

## Incidente durante la ejecución: caída y recuperación del stack de Docker

En medio de la Fase 7, justo después de reconstruir la imagen de `modelo-reportes`, **todo el stack
de Docker se detuvo simultáneamente** (todos los contenedores con exit code 137, la firma de un
`SIGKILL` — consistente con un reinicio del motor de Docker/WSL2, no con algo que
`docker compose up -d modelo-reportes` por sí solo pudiera causar en servicios no relacionados como
`postgres_db` o `frontend_dev`). Se volvió a levantar todo el stack
(`docker compose -p recolecta-dev-env -f docker.compose.yml -f docker.compose.dev.yml up -d`) y se
verificó que los datos de Postgres (incluyendo todo el esquema de multitenancy ya aplicado) seguían
intactos en el volumen. No se identificó una causa atribuible a los comandos de esta sesión.

---

## Checklist final

- [x] Fase 0 — `init-database.sh` ejecuta `db_constraints.sql` y `db_indexes.sql`
- [x] Fase 1 — tabla `tenant` + columna en 19 tablas (`db_script.sql`)
- [x] Fase 2 — `ADD COLUMN IF NOT EXISTS` + FK para tablas preexistentes (`db_constraints.sql`)
- [x] Fase 3 — índices en `tenant_id` (`db_indexes.sql`)
- [x] Fase 4 — `tenant_id` en JWT/middleware, login de `empleado`/`ciudadano`
- [x] Fase 5 — `RunInTenantTx` + políticas RLS (17 tablas) — **con el hallazgo de que `DB_USER`
      actual es superusuario y por lo tanto RLS no aplica todavía al tráfico real de la app**
- [x] Fase 6 — `colonia` como referencia completa; resto de módulos con columna+RLS pasivo
- [x] Fase 7 — `tenant_id` obligatorio en `modelo-reportes` (`clasificador-reportes` ya lo tenía)
- [x] Fase 8 — Redis: reglas de notificación pasadas a por-tenant (decisión de producto del usuario)
- [x] Fase 9 — tests de aislamiento (Go + Python), corridos contra Docker real
- [x] Fase 10 — este documento + commits por submódulo + puntero en la raíz

## Pendiente para que RLS sea una protección real (no solo de código)

Cambiar `DB_USER` en `.env` a un rol Postgres `NOSUPERUSER` con los `GRANT` necesarios sobre las 17
tablas con política `tenant_isolation`. Sin este cambio de infraestructura, el aislamiento efectivo
en producción-como-hoy depende solo del filtro explícito en la capa de aplicación (que hoy solo
`colonia` implementa).
