# 📋 Changelog

> Todos los cambios importantes en este proyecto están documentados aquí.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/) y el proyecto sigue [Versionado Semántico](https://semver.org/lang/es/).

Referencias de como usarlo: [Guia del Changelog](./CHANGELOG.md#-guía-del-changelog)

---
# 0.13.0-alpha - 2026-04-15
## Rodrigo Mijangos [Issue #11](https://github.com/RodrigoMijangos/recolecta_web/issues/11)
### Changed
- `docs/04-redis-schema.md` documenta la implementación operativa de sesiones realtime (`realtime:server_epoch:current`, `ws:upgrade:*`, `ws:session:*`).
- `docs/05-data-lifecycle.md` incorpora flujo de emisión/consumo de token exclusivo de upgrade y ciclo de sesión realtime.
- Se actualiza el puntero del submódulo `gin-backend` con la Fase 4.

# 0.12.0-alpha - 2026-04-15
## Rodrigo Mijangos [Issue #10](https://github.com/RodrigoMijangos/recolecta_web/issues/10)
### Changed
- `docs/04-redis-schema.md` documenta la implementación activa de dedupe/traza (`event_deduplication`, `event_trace`) en backend.
- `docs/05-data-lifecycle.md` documenta el endpoint operativo `POST /api/notifications/events/truck-state`.
- Se actualiza el puntero del submódulo `gin-backend` con la Fase 3.

# 0.11.0-alpha - 2026-04-15
## Rodrigo Mijangos [Issue #9](https://github.com/RodrigoMijangos/recolecta_web/issues/9)
### Changed
- `docs/04-redis-schema.md` incorpora la estructura de reglas dinámicas `rules:state:{state_code}` y versionado global `rules:version`.
- `docs/05-data-lifecycle.md` incorpora el flujo operativo de administración de reglas dinámicas en backend.
- Se actualiza el puntero del submódulo `gin-backend` con la Fase 2.

# 0.10.0-alpha - 2026-04-15
## Rodrigo Mijangos [PR #52](https://github.com/RodrigoMijangos/recolecta_web/pull/52)
### Changed
- `docker/docker.compose.dev.yml` ahora carga `.env` y propaga variables FCM al contenedor backend.
- `docs/01-setup-local.md` documenta la configuración segura de credenciales Firebase para desarrollo y producción.
- `.env.example` incorpora `GOOGLE_APPLICATION_CREDENTIALS` como variable de referencia para FCM.
- `.gitignore` se ajusta para evitar versionar credenciales y la carpeta `/credentials`.
- Se actualiza el puntero del submódulo `gin-backend` con los cambios de integración FCM.
- `docs/04-redis-schema.md` incorpora diseño de deduplicación/trazabilidad de eventos y sesiones realtime de administrador.
- `docs/05-data-lifecycle.md` incorpora flujo de contrato versionado de eventos y upgrade seguro a websocket con token exclusivo.

# 0.9.0-alpha - 2026-03-11
## Rodrigo Mijangos [Issue #1](https://github.com/RodrigoMijangos/recolecta_web/issues/1)
### Added
- Configuración de docker compose para entorno productivo y de desarrollo.
- Configuración de Dockerfile para nginx.
- Nuevas variables de entorno para configuración de servicios.
- Integración de revisión healthcheck para servicio backend en frontend placeholder.
- Aislamiento de servicios redis, postgresql y backend en redes de docker separadas para mayor seguridad en producción.
- Se exponer backend en puerto 8081 en desarrollo.

### Changed
- Documentación general actualizada para reflejar cambios en configuración de servicios y uso de docker compose.

# 0.8.0-alpha - 2026-03-11
## Rodrigo Mijangos [Issue #49](https://github.com/RodrigoMijangos/recolecta_web/issues/49)
### Added
- Testing de Integridad de datos de redis.

### Changed
- Seeding de Redis y Seeding de postgresql ahora estan amoldados al nuevo schema.
- Testing de integridad de datos de redis ahora verifica que los datos en Redis correspondan con los datos en PostgreSQL, asegurando consistencia entre ambos sistemas.
- Testing rediseñados según el nuevo schema de postgresql.

# 0.7.0-alpha - 2026-01-31
## Rodrigo Mijangos [Issue #5](https://github.com/RodrigoMijangos/recolecta_web/issues/5)
### Added
- Script de validación cruzada entre PostgreSQL y Redis.
- Script de reset ligero que ejecuta init scripts dentro de contenedores.

### Changed
- Autenticación redis-cli usando REDISCLI_AUTH (más segura, elimina warnings).
- Salida de scripts Redis simplificada (stdout solo estados, detalles en stderr).
- Seeds Redis con metadata + checksum, evitando regeneraciones innecesarias.
- Healthcheck de Redis actualizado para auth segura.

### Docs
- Ejemplos actualizados para conexion en redis-cli con auth.

# 0.6.0-alpha - 2026-01-30
## Rodrigo Mijangos [Issue #40](https://github.com/RodrigoMijangos/recolecta_web/issues/26)
### Added
- Documentación del schema de Redis para geolocalización y notificaciones en `docs/04-redis-schema.md`.
- Documentacion del ciclo de vida de notificaciones FCM en `docs/05-fcm-notification-lifecycle.md`.
- Script de generacion de datos de prueba para redis.
- Script de carga de datos de prueba en redis.
- Script de verificación de integridad de datos en redis.
- Documentación de casos de uso de Redis en `docs/03-redis-operations.md`.

### Changed
- Archivo compose para developmet environment.
- Cambio de archivo `env.example` para variables más intuitivas.
- Documentacion general en Readme.md sobre Redis y enlaces a documentación técnica.
- Documentacion de suite de tests de Redis en `docs/testing/redis-tests.md`.

# 0.5.0-alpha - 2026-01-30
## Rodrigo Mijangos [Issue #40](https://github.com/RodrigoMijangos/recolecta_web/issues/40)
### Added
- Healthcheck para servicio de postgresql.
- Test para verificación funcional de CRUD básico en postgresql.
- Test para verificacion de schema y seeding en postgresql.
- Test para verificación de persistencia de datos tras reinicio de contenedor intencionado.
- Documentación de suite de tests de postgresql en `docs/testing/postgres-tests.md`.

### Changed
- Actualización de comandos en documentación para levantar servicios con docker compose v2.
- Explicación del uso de `--env-file` en docker compose para evitar warnings de variables de entorno.
- `init-database.sh` ahora utiliza una tabla de control con checksum para validar que schema y seeding se ha aplicado recientemente.
- `seed-if-empty.sh` ahora inserta su checksum en la tabla de control tras insertar datos.
- Cambios menores de documentacion general.

### Fixed
- Restauración de carpeta `docs/` que fue eliminada accidentalmente por cherry-pick en issue #33.
- Cherry-pick del commit `3a526dd` (de issue #34) para recuperar documentación estructurada.
- Cherry-pick del commit `e25b7bd` para recuperar documentación de tests de Redis.

### Notes
- Los archivos recuperados incluyen:
  - `docs/01-setup-local.md` 
  - `docs/02-database-operations.md`
  - `docs/testing/redis-tests.md` - Documenta suite de tests de Redis
- Esta restauración asegura que toda la documentación eliminada sea recuperada.
- Conflictos en README.md y .gitignore resueltos manteniendo versiones actuales.

# 0.4.0-alpha - 2026-01-27
## Rodrigo Mijangos [Issue #33](https://github.com/RodrigoMijangos/recolecta_web/issues/33)
### Added
- Scripts de inicialización de base de datos en Docker.
- Scripts de seed automático de base de datos en Docker.
- Scripts para dump y restore de base de datos en Docker.
- Creación de Seeders para tablas principales.
- Gitattributes para manejo de archivos sensibles a fin de línea.

### Changed
- Configuración de Docker Compose para PostgreSQL.
- Configuración de la persistencia de Datos de PostgreSQL.

# 0.3.0-alpha - 2026-01-27
## Rodrigo Mijangos [Issue #34](https://github.com/RodrigoMijangos/recolecta_web/issues/34)
### Added
- Documentación inicial para operaciones de base de datos con Docker.
- Documentación de setup local con Docker Compose.
- Documentación de testing local para redis.
- Documentación de seeding automático de base de datos.
- Documentación de estructura del proyecto.
- Documentación de orquestación con Docker Compose.
- Documentación de configuración de variables de entorno.
- Documentación de requisitos previos para desarrollo local.
- Documentación de quick start para levantar ambiente local.
- Documentación de enlaces rápidos para setup local y operaciones de base de datos.

## 0.2.0-alpha - 2026-01-20

### Added
- Se agrega información util para nuevos desarrolladores.
- Información sobre como ejecutar contenedores de Docker.
- Información sobre los servicios de docker.
- Quickstart.

### Changed
- Información que muestra README.md actualizada.
- Configuración de Docker Compose actualizada.
- Redis requiere una contraseña de manera obligatoria.
  
---

## 0.1.0-alpha - 2026-01-20

### Added
- Submódulo del **frontend** integrado al repositorio
- Submódulo del **backend** (Gin) integrado al repositorio
- Configuración de **Docker Compose** para desarrollo
- Configuración de **Docker Compose** para producción
- Dockerfile personalizado para **Nginx**
- Archivo `.gitignore` para proteger variables de entorno (`.env`)
- Archivo `.gitignore` para archivos `.env`
- Docker Compose de desarrollo con servicios base
- Docker Compose de producción optimizado
- Configuración temporal para ejecutar Docker en desarrollo
- Archivo de configuración `.gitignore` refinado para ignorar docs y scripts auxiliares

### Removed
- Archivo de ejemplo para Docker Compose

---

[Volver Arriba](#-changelog)

## 📖 Guía del Changelog

### 🎯 Cómo Leerlo

Cada versión está dividida en **categorías** que te ayudan a identificar qué tipo de cambios se hicieron:

| Categoría | Significa | Ejemplo |
|-----------|-----------|---------|
| **Added** | Nuevas funcionalidades | Nueva página de login |
| **Changed** | Cambios en funcionalidad existente | Refactor de componentes |
| **Deprecated** | Features que pronto desaparecerán | Método antiguo que será reemplazado |
| **Removed** | Código o archivos removidos | Componentes deprecados |
| **Fixed** | Bug fixes | Corrección de error en validación |
| **Security** | Parches de seguridad | Actualización de dependencias críticas |

### 🏗️ Cómo Mantenerlo

Cada vez que hagas cambios importantes, **debes actualizar el changelog** ANTES de hacer el commit:

#### En Desarrollo (rama activa)

```markdown
## [Unreleased]

### Added
- Nueva funcionalidad X

### Fixed
- Bug en el componente Y
```

#### 📝 Guía de Traducción: Commits → Changelog

Usa esta tabla para decidir si un commit debe ir al changelog y cómo categorizarlo:

| Tipo Commit | ¿Va al Changelog? | Categoría | Ejemplo |
|-------------|-------------------|-----------|---------|
| `feat:` | ✅ Sí | **Added** | `feat: agregar notificaciones FCM` → `Added: Sistema de notificaciones FCM` |
| `fix:` | ✅ Sí | **Fixed** | `fix: corregir cálculo de radio` → `Fixed: Cálculo de radio en geolocalización` |
| `perf:` | ✅ Sí | **Changed** | `perf: optimizar consultas Redis` → `Changed: Optimización de consultas geoespaciales` |
| `refactor:` | ⚠️ Solo si es significativo | **Changed** | `refactor: reestructurar módulo rutas` → `Changed: Reestructuración de módulo de rutas` |
| `docs:` | ⚠️ Solo si es importante | **Added/Changed** | `docs: agregar guía Redis` → `Added: Documentación de schema Redis` |
| `chore:` | ❌ No (generalmente) | - | `chore: actualizar deps` → (no va al changelog) |
| `test:` | ❌ No | - | `test: agregar tests unitarios` → (no va al changelog) |
| `style:` | ❌ No | - | `style: formatear código` → (no va al changelog) |
| `build:` | ❌ No | - | `build: actualizar Dockerfile` → (no va al changelog) |
| `ci:` | ❌ No | - | `ci: configurar GitHub Actions` → (no va al changelog) |

**Reglas:**
- Si el cambio **afecta al usuario o desarrollador**, va al changelog
- Si es solo interno/mantenimiento, NO va
- Traduce commits técnicos a lenguaje claro para el changelog

#### ✅ Al Hacer Release

1. **Reemplaza `[Unreleased]` con la versión** en formato `X.Y.Z`
2. **Añade la fecha** en formato `YYYY-MM-DD`
3. **Crea un nuevo tag** en Git

```bash
# Ejemplo:
git tag -a v0.2.0 -m "Release version 0.2.0"
git push origin v0.2.0
```

---

## 📊 Sistema de Versionado (Versionado Semántico)

Usamos **SemVer**: `MAJOR.MINOR.PATCH(-prerelease)(+metadata)`

### Formato: X.Y.Z

```
0.1.0
├── 0 = MAJOR (cambios incompatibles)
├── 1 = MINOR (nuevas funcionalidades)
└── 0 = PATCH (bug fixes)
```

### 📈 Reglas de Versionado

| Cambio | Incrementa | Ejemplo |
|--------|-----------|---------|
| Bug fixes y mejoras pequeñas | PATCH | 0.1.0 → 0.1.1 |
| Nuevas funcionalidades | MINOR | 0.1.0 → 0.2.0 |
| Cambios incompatibles | MAJOR | 0.1.0 → 1.0.0 |

### 🔤 Estados Especiales (Prerelease)

Para versiones en desarrollo, usamos sufijos:

```
0.1.0-alpha    → Versión muy temprana, inestable
0.1.0-beta     → Más estable pero en pruebas
0.1.0-rc.1     → Release Candidate (casi lista)
1.0.0          → Versión estable final
```

### 📋 Hoja de Referencia Rápida

```bash
# Versión actual
git describe --tags

# Ver todos los tags
git tag -l

# Crear nuevo tag (cuando hagas release)
git tag -a v0.2.0 -m "Release version 0.2.0"

# Ver cambios desde último tag
git log $(git describe --tags --abbrev=0)..HEAD --oneline
```

---

## 💡 Consejos para Desarrolladores

### ✍️ Al Hacer Cambios

1. **Trabaja en tu rama** (ej: `feature/nueva-funcionalidad`)
2. **Actualiza el changelog** en la sección `[Unreleased]`
3. **Sé descriptivo** pero conciso:
   - ✅ `Added: Modal de confirmación en validación de rutas`
   - ❌ `fixed stuff`

### 🔍 Antes de hacer un Pull Request

```bash
# Verifica que el changelog esté actualizado
git diff main -- CHANGELOG.md

# Lee tu changelog
cat CHANGELOG.md
```

### 📦 Al Hacer Release (Solo para Admin)

```bash
# 1. Actualizar versión en package.json (frontend)
# 2. Reemplazar [Unreleased] en CHANGELOG.md
# 3. Hacer commit
git commit -am "chore: release v0.2.0"

# 4. Crear tag
git tag -a v0.2.0 -m "Release version 0.2.0"

# 5. Hacer push
git push origin main
git push origin v0.2.0
```

---

## 📦 Estructura del Proyecto

```
recolecta_web/
├── frontend/              (React + TypeScript + Vite)
├── gin-backend/          (Go + Gin)
├── docker/               (Configuración Docker)
├── map-navigator/        (Módulo separado)
└── docker-compose.yml    (Orquestación de servicios)
```
