# Fix: 500 al guardar rutas por `colonia_id` hardcodeado

## Síntoma

Desde el dashboard web (`frontend/src/Pages/Dashboard/Dashboard.tsx`, función `guardarRuta`),
al crear una ruta y dar "Guardar" el POST a `/api/rutas/` devolvía **500** con el mensaje
`ApiError: 500` en consola, sin llegar a crear la ruta ni los puntos de recolección.

## Causa raíz

`docs/08-multitenancy-implementado.md` (Fase 1-3, commit `9ed2eb7` en `gin-backend`) agregó a
`gin-backend/db_constraints.sql` la restricción:

```sql
ALTER TABLE ruta ADD CONSTRAINT fk_colonia_ruta
  FOREIGN KEY (colonia_id) REFERENCES colonia(colonia_id);
```

Antes de ese commit, `ruta.colonia_id` era `NOT NULL` pero **sin FK**, así que cualquier entero
servía. `gin-backend/src/Rutas/infraestructure/adapters/PostgresRuta.go` (método `Save`)
aprovechaba eso e insertaba `colonia_id` fijo en `1`:

```go
// nota: colonia_id es NOT NULL en DB, por defecto usamos 1
sql := `INSERT INTO ruta (..., colonia_id, ...) VALUES ($1, $2, $3, 1, $4) RETURNING id`
```

`gin-backend/db_script.sql` nunca siembra la tabla `colonia` (a diferencia de `tenant`, que sí se
siembra con `tenant_id=1`). Si en el ambiente no existe una fila con `colonia_id = 1` (por ejemplo,
porque nadie ha usado el módulo de colonias, o porque esa fila se creó y luego se borró y el
`SERIAL` ya avanzó), **cada INSERT a `ruta` viola `fk_colonia_ruta`**. Postgres devuelve el error de
FK, `createRuta_controller.go` lo envuelve con `core.RespondInternalServerError` y el frontend recibe
un 500 plano, sin pista de que el problema era una FK de colonia.

Esto explica por qué el error apareció justo después de correr la migración de multitenancy: el
código de guardado de rutas no cambió, pero el esquema le agregó una validación que el hardcode ya
no podía cumplir.

## Cambio aplicado

Archivo: `gin-backend/src/Rutas/infraestructure/adapters/PostgresRuta.go`.

1. Se eliminó el `colonia_id` fijo en `1` del INSERT de `Save`.
2. Se agregó `resolveDefaultColoniaID(ctx)`, que:
   - Busca la primera colonia existente (`SELECT colonia_id FROM colonia ORDER BY colonia_id LIMIT 1`)
     y la usa si existe.
   - Si la tabla `colonia` está vacía (`pgx.ErrNoRows`), crea una colonia por defecto
     (`"Sin colonia asignada"` / `"Sin definir"`) y usa el `colonia_id` recién creado.
   - Si la consulta falla por cualquier otro motivo, propaga el error (ya no se ignora en
     silencio).
3. `Save` ahora llama a `resolveDefaultColoniaID` antes del INSERT y usa ese valor como parámetro
   (`$4`) en vez del literal `1`.

No se tocó `frontend/`, `createRuta_controller.go`, ni el esquema (`db_script.sql` /
`db_constraints.sql`): el fix es puramente en el adapter de Postgres, que es donde vivía el
supuesto inválido.

## Qué queda pendiente (multitenancy)

`resolveDefaultColoniaID` resuelve la colonia **globalmente**, no por tenant — a propósito, para no
mezclar este fix puntual con el trabajo de multitenancy que sigue en curso (ver
`docs/07-plan-multitenancy.md` y `docs/08-multitenancy-implementado.md`). El propio
`colonia_repository.go` ya usa `RunInTenantTx` para `Create`/`Update`/`Delete`, así que cuando el
módulo de Rutas se conecte a ese flujo, `resolveDefaultColoniaID` debería:

- recibir el `tenant_id` del contexto de la petición (igual que `colonia_repository.go`), y
- filtrar/crear la colonia por defecto dentro de ese tenant, no de forma global.

Queda marcado como `TODO(multitenant)` directamente en el código, en `PostgresRuta.go`, para
retomarlo cuando se termine de integrar el resto de las ramas de multitenancy.

## Por qué no se sembró una colonia fija en su lugar

Se evaluó como alternativa rápida agregar un `INSERT` de una colonia con `colonia_id=1` en
`db_script.sql`. Se descartó como solución final porque no arregla el problema de fondo: el
hardcode seguiría ahí, listo para romperse de nuevo (por ejemplo, si esa fila se borra, o si más
adelante el multitenancy exige que cada colonia pertenezca a un tenant específico). El fix de este
documento resuelve la causa raíz en el código en vez de parchear los datos.
