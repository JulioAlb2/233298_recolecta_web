# Plan de Multitenancy — Modelo Pool (adaptado a `233298_recolecta_web`)

Este plan reemplaza al `MULTITENANCY_PLAN.md` original: aquel se escribió sobre una copia local
que ya no existe: este está adaptado a tu estructura real actual — repo contenedor con submódulos
(`gin-backend`, `modelo-reportes`, `clasificador-reportes`, `frontend`, `map-view`), Docker Compose,
y el flujo de forks descrito en `docs/06-guia-forks-y-submodulos.md`.

**Estrategia: Modelo Pool** (base compartida + columna `tenant_id`), reforzado con Row-Level
Security de Postgres en `gin-backend`, y con `tenant_id` obligatorio en cada query en
`modelo-reportes`/`clasificador-reportes` (SQLite, sin RLS disponible).

---

## Por qué Pool y no Silo/Bridge — resumen de la decisión

Ya se hizo el análisis comparativo completo (ver conversación / `docs/`), pero el resumen que
justifica cada fase de este plan:

- **Bridge queda descartado de raíz** para `modelo-reportes` y `clasificador-reportes`: corren
  sobre SQLite en este `docker-compose`, y SQLite no tiene el concepto de "schema" — no hay nada
  que particionar lógicamente.
- **Silo multiplicaría un pipeline que ya tiene un bug conocido** (ver Fase 0): con tres repos
  mantenidos por gente distinta bajo submódulos, coordinar N inicializaciones de infraestructura
  por tenant es sustancialmente más caro que en un monorepo.
- **Pool es el único compatible con los tres motores de base de datos a la vez** (Postgres en
  `gin-backend`, SQLite en los otros dos) y con el patrón de login existente (buscar por email de
  forma global, antes de conocer el tenant — ver Fase 4).

---

## Fase 0 — Arreglar `docker/postgresql/init-scripts/init-database.sh` (prerequisito)

**Qué:** el script declara `SCHEMA_CONSTRAINTS_PATH` y `SCHEMA_INDEXES_PATH` pero nunca los
ejecuta — solo corre `db_script.sql`. Agregar la ejecución de `db_constraints.sql` y
`db_indexes.sql` (mismo patrón que ya usa para `db_script.sql`: completo en primera creación,
`tail` si la base ya existe salvo que estos dos no tengan el preámbulo de `CREATE DATABASE`/`\c`
a recortar).

**Por qué primero:** todo lo que se planea en `db_constraints.sql` en las fases siguientes
(foreign keys, índices, y sobre todo las políticas RLS) depende de que este archivo se ejecute de
verdad al levantar `docker compose up`. Sin este fix, el resto del plan se escribiría en un
archivo que Docker ignora — riesgo real de repetir el mismo error de la vez pasada, ahora
descubierto antes de que pase.

---

## Fase 1 — Esquema Postgres (`gin-backend/db_script.sql`)

**Qué:** tabla `tenant` (`tenant_id`, `nombre`, `activo`, `created_at`), sembrada con
`tenant_id=1` ("Tenant Demo/Legacy") como destino de los datos existentes. Columna
`tenant_id INTEGER NOT NULL DEFAULT 1` en las 19 tablas tenant-scoped:

`empleado`, `licencia`, `dispositivos`, `historial_asignacion_camion`, `camion`,
`alerta_mantenimiento`, `registro_mantenimiento`, `ruta_camion`, `ruta`, `punto_recoleccion`,
`relleno_sanitario`, `estado_camion`, `registro_vaciado`, `colonia`, `ciudadano`, `domicilio`,
`alerta_usuario`, `aviso`, `anomalia`.

Se quedan sin `tenant_id` (catálogo global, compartido entre todos los tenants): `rol`,
`tipo_camion`, `tipo_mantenimiento`.

**Por qué `dispositivos` es tenant-scoped:** es nueva en este repo (no estaba en la versión
anterior) — cada dispositivo pertenece a un `conductor_id`, que a su vez pertenece a un tenant vía
`empleado`. Un dispositivo de un municipio no debe ser visible ni asignable desde otro.

**Por qué `DEFAULT 1` y no `NOT NULL` a secas:** permite que el script sea idempotente tanto en
una base nueva como en la que ya tiene datos de desarrollo, y evita que las tablas cuyo
repositorio todavía no se actualice (ver Fase 4) generen errores de inserción mientras tanto.

---

## Fase 2 — Garantizar la columna en tablas preexistentes + FKs (`gin-backend/db_constraints.sql`)

**Qué:** bloque `DO $$ ... ALTER TABLE ... ADD COLUMN IF NOT EXISTS tenant_id ...` +
`ADD CONSTRAINT fk_<tabla>_tenant FOREIGN KEY (tenant_id) REFERENCES tenant(tenant_id)` para las
19 tablas, recorriendo un arreglo (mismo patrón que ya usa este archivo para otros constraints).

**Por qué un bloque aparte y no solo lo de la Fase 1:** `CREATE TABLE IF NOT EXISTS` no modifica
una tabla que ya existe. Como el `init-database.sh` corregido en la Fase 0 re-ejecuta
`db_script.sql` en cada arranque (vía `tail -n +6` cuando la base ya existe) pero eso tampoco
altera tablas existentes, este bloque explícito es el que de verdad garantiza la columna sin
importar si la tabla es nueva o si ya tenía datos de antes.

---

## Fase 3 — Índices (`gin-backend/db_indexes.sql`)

**Qué:** `CREATE INDEX idx_<tabla>_tenant_id ON <tabla>(tenant_id)` para las 19 tablas.

**Por qué:** cada política RLS de la Fase 5 agrega un filtro `WHERE tenant_id = ...` (implícito)
a toda query sobre estas tablas — sin índice, eso degrada el rendimiento a medida que crece el
volumen de datos por tenant.

---

## Fase 4 — JWT y middleware (`gin-backend/src/core/jwt.go`, `jwt_middleware.go`)

**Qué:** agregar `TenantID` a los claims del JWT y a `GenerateToken`; el middleware lo propaga al
contexto de Gin (`c.Set("tenant_id", ...)`), igual que ya hace con `user_id`/`role_id`.

`empleado` y `Ciudadanos`: agregar `TenantID` a la entidad y al repositorio (columna en
`SELECT`/`INSERT`), para que el login pueda incluirlo al generar el token.

**Por qué `empleado`/`ciudadano` NO llevan RLS (ver Fase 5):** el login busca al usuario por email
de forma global — es exactamente el paso que determina su tenant. Forzar RLS ahí bloquearía el
login de cualquier empleado/ciudadano que no perteneciera al tenant de respaldo (`1`). Este es un
ejemplo concreto de por qué Silo/Bridge complicarían más este mismo problema (ver sección inicial):
en esos modelos habría que saber a qué base/esquema conectarse *antes* de poder buscar al usuario
que determina esa misma información.

---

## Fase 5 — Row-Level Security + helper de transacción (`gin-backend/src/core/tenant_db.go` nuevo)

**Qué:** función `RunInTenantTx(ctx, pool, tenantID, fn)` que abre una transacción, fija
`app.current_tenant` con `SELECT set_config('app.current_tenant', $1, true)` (parametrizado,
`is_local=true`), corre `fn`, y hace commit/rollback. En `db_constraints.sql`:
`ENABLE ROW LEVEL SECURITY` + `FORCE ROW LEVEL SECURITY` + política

```sql
USING (tenant_id = COALESCE(NULLIF(current_setting('app.current_tenant', true), ''), 1))
```

sobre las 17 tablas tenant-scoped que sí pueden llevar RLS (las 19 menos `empleado`/`ciudadano`).

**Por qué `is_local=true` y no un `SET` de sesión:** `pgxpool` reutiliza conexiones físicas entre
requests de tenants distintos. Si la variable quedara fijada a nivel de sesión, una conexión
podría "arrastrar" el tenant de un request anterior al siguiente. Al acotarla a la transacción,
Postgres la resetea sola en el `COMMIT`/`ROLLBACK`, sin importar qué tenant use esa conexión
después.

**Por qué el `COALESCE(..., 1)` en vez de bloquear todo cuando no hay contexto:** permite activar
RLS de forma incremental. Los módulos que todavía no llamen `RunInTenantTx` (ver Fase 6) caen al
tenant `1` en vez de quedarse sin datos — es decir, siguen funcionando exactamente igual que hoy
mientras se van migrando uno por uno, en vez de romperse todos de golpe el día que se activa RLS.

**Requisito operativo:** el rol de conexión de la app (`DB_USER` en tu `.env`) no debe ser
superusuario de Postgres — los superusuarios ignoran RLS sin importar `FORCE`. Verificar con
`SELECT rolsuper FROM pg_roles WHERE rolname = '<DB_USER>';` una vez levantado el contenedor.

---

## Fase 6 — Módulo de referencia (`colonia`) y alcance del resto de módulos Go

**Qué:** aplicar el patrón completo a `colonia` (entidad, puerto, adaptador Postgres, casos de
uso, controller): `Create`/`Update`/`Delete` (rutas protegidas con JWT) pasan `tenantID` obligatorio
y corren dentro de `RunInTenantTx`; `GetByID`/`GetAll` (rutas públicas, sin JWT) quedan sin tocar
porque no hay tenant que filtrar ahí — dependen únicamente del fallback de RLS a tenant 1.

Los demás módulos tenant-scoped (`Camion`, `Fallas`, `Rutas`, `alerta_usuario`, `notificacion`,
`dispositivos`, CRUD completo de `empleado`/`Ciudadanos`) quedan con la columna y la protección de
RLS activa (fallback a tenant 1), pero sin el filtro explícito en el repositorio — mismo patrón
que `colonia`, pendiente de replicar módulo por módulo.

**Por qué no todos los módulos en esta pasada:** cada uno implica tocar puerto + adaptador + caso
de uso + controller (4 archivos mínimo, más los que ya existan por módulo). Hacerlo de una sola
pasada para los ~10 módulos restantes tiene alto riesgo de errores no detectables sin compilador
en este entorno. `colonia` sirve como plantilla verificada; replicarlo es mecánico.

---

## Fase 7 — `modelo-reportes` y `clasificador-reportes`

**Qué:** columna `tenant_id` (obligatoria, sin default silencioso) en los modelos SQLAlchemy,
schemas Pydantic, y cada función de repositorio/endpoint de listado y consulta. El campo se exige
en el body de `POST /infer` y `POST /clasificar`, y como query param obligatorio en los `GET` de
listado/consulta por id.

**Por qué es obligatorio y no opcional con default:** estos dos servicios corren sobre SQLite
(ver `docker/docker.compose.yml`) — no hay Row-Level Security disponible como red de seguridad.
El filtro explícito en cada query es la única barrera real; hacerlo opcional anularía la
protección en el primer endpoint que alguien llame sin pensar en tenants.

---

## Fase 8 — Revisión de Redis (`gin-backend/src/notificacion`)

**Qué:** revisar (no necesariamente reescribir) los 4 repositorios Redis del módulo de
notificaciones. La mayoría usa IDs ya únicos globalmente (vienen de `SERIAL` de Postgres), así que
no hay colisión cruzada en lookups por ID. Confirmar si `RedisNotificationRuleRepository.List()`
(que lista sin ningún filtro) debe seguir siendo configuración global o necesita volverse por
tenant.

**Por qué solo revisión y no cambio automático:** requiere una decisión de producto (¿las reglas
de notificación son iguales para todos los municipios o cada uno las personaliza?), no una
decisión técnica que se pueda resolver sin input tuyo o del equipo.

---

## Fase 9 — Tests de aislamiento

**Qué:** test de integración en Go (`gin-backend/tests/integration/colonia/tenant_isolation_test.go`)
que crea una colonia como tenant A y confirma que tenant B no puede verla ni modificarla (usa
`RunInTenantTx` directamente). Tests de pytest en `modelo-reportes` y `clasificador-reportes` que
verifican que un tenant nunca ve datos de otro, corridos de verdad contra sus bases SQLite.

**Por qué esta vez sí se pueden correr de extremo a extremo:** al estar todo dockerizado con
`docker compose`, se puede levantar el stack real y correr el test de Go contra el Postgres del
contenedor (`DB_HOST=localhost DB_PORT=5432 ... go test ./tests/integration/colonia/... -v`), algo
que no era posible en el entorno de trabajo anterior por no tener Go ni una base real disponibles
ahí.

---

## Fase 10 — Documentación final y flujo de git

**Qué doble entregable:**

1. **Commits por submódulo**, siguiendo `docs/06-guia-forks-y-submodulos.md`: dentro de
   `gin-backend`, `modelo-reportes` y `clasificador-reportes` — `git add` + `commit` (push a
   `origin`, tu fork, según lo que decidas) — y después, desde la raíz de `233298_recolecta_web`,
   actualizar el puntero de cada submódulo y commitear ese cambio ahí también. Sin este segundo
   paso, el repo raíz seguiría apuntando a la versión vieja de cada submódulo aunque el trabajo ya
   esté pusheado.

2. **`docs/08-multitenancy-implementado.md`** (siguiente número disponible en tu carpeta `docs/`):
   documento que no solo lista qué se hizo, sino que **justifica cada decisión de diseño** tomada
   en este plan — específicamente:
   - Por qué Pool y no Silo/Bridge, con la evidencia concreta de este proyecto (motores de BD
     heterogéneos, bug de `init-database.sh`, problema del login).
   - Por qué `empleado`/`ciudadano` quedan sin RLS y qué haría falta para activarlo ahí también.
   - Por qué `is_local=true` en el `set_config` y qué pasaría si se usara `SET` de sesión en su
     lugar.
   - Por qué la política RLS cae a tenant `1` en vez de bloquear todo cuando no hay contexto, y
     qué riesgo controla esa decisión (no romper los módulos aún no migrados) vs. qué riesgo acepta
     (esos módulos siguen compartiendo un tenant implícito hasta que se migren).
   - Qué módulos quedaron con el patrón completo (`colonia`) vs. cuáles solo con la columna y RLS
     pasivo, y el mismo checklist mecánico para replicarlo.

   Este documento es el que le sirve tanto a tu equipo (para entender por qué el sistema quedó así
   sin tener que releer cada commit) como a ti para la entrega académica.

---

## Checklist resumen

- [ ] Fase 0 — `init-database.sh` ejecuta `db_constraints.sql` y `db_indexes.sql`
- [ ] Fase 1 — tabla `tenant` + columna en 19 tablas (`db_script.sql`)
- [ ] Fase 2 — `ADD COLUMN IF NOT EXISTS` + FK para tablas preexistentes (`db_constraints.sql`)
- [ ] Fase 3 — índices en `tenant_id` (`db_indexes.sql`)
- [ ] Fase 4 — `tenant_id` en JWT/middleware, login de `empleado`/`ciudadano`
- [ ] Fase 5 — `RunInTenantTx` + políticas RLS (17 tablas)
- [ ] Fase 6 — `colonia` como referencia completa; resto de módulos con columna+RLS pasivo
- [ ] Fase 7 — `tenant_id` obligatorio en `modelo-reportes` y `clasificador-reportes`
- [ ] Fase 8 — revisión de Redis en `notificacion`
- [ ] Fase 9 — tests de aislamiento (Go + Python), corridos contra Docker real
- [ ] Fase 10 — commits por submódulo + puntero en la raíz + `docs/08-multitenancy-implementado.md`
