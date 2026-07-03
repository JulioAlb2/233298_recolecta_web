# 🐳 Setup Local - Docker y Orquestación

> Guía para levantar el ambiente local con Docker Compose

## Qué hay en este repo

Este repositorio es un **meta-repo de orquestación y arquitectura** que integra:

- **docker/** — Docker Compose, configuración de servicios
- **docker/postgresql/** — Scripts de inicialización, seed, dump
- **.env** — Configuración centralizada de variables de entorno
- **.gitattributes** — Control de line endings (LF)
- Submódulos Git:
  - **[frontend/](../frontend/)** — React + TypeScript (su propio README)
  - **[gin-backend/](../gin-backend/)** — Go + Gin API (su propio README)

## Qué NO está aquí

- Código del frontend (ver [frontend/README.md](../frontend/README.md))
- Código del backend (ver [gin-backend/README.md](../gin-backend/README.md))
- Testing de frontend/backend (documentado en sus repos)

---

## 📋 Requisitos Previos

- **Docker** 20.10+
- **Docker Compose** 2.0+
- **Git** 2.30+

Verifica:
```bash
docker --version
docker-compose --version
git --version
```

---

## 🚀 Setup Local (3 pasos)

### 1. Clonar con submódulos

```bash
git clone --recurse-submodules https://github.com/RodrigoMijangos/recolecta_web.git
cd recolecta_web
```

Si ya clonaste sin submódulos:
```bash
git submodule update --init --recursive
```

### 2. Configurar variables de entorno

Copia el archivo de ejemplo:
```bash
cp .env.example .env
```

Edita `.env` con tus valores. Ejemplo mínimo:
```env
DB_USER=recolecta
DB_PASSWORD=tu_contraseña_segura
DB_NAME=proyecto_recolecta
REDIS_PASSWORD=tu_redis_password
ENVIRONMENT=development
```

Si vas a habilitar notificaciones push con Firebase Cloud Messaging, agrega tambien la ruta del archivo de credenciales:
```env
GOOGLE_APPLICATION_CREDENTIALS=C:/ruta/segura/firebase/service-account.json
```

**⚠️ Importante:**
- `.env` debe tener permisos restrictivos (no hacer commit)
- Usa `.env.example` como referencia
- En producción, usa gestión de secretos
- El archivo JSON de credenciales de Firebase no debe vivir dentro del repositorio ni versionarse

> Nota: Docker Compose realiza la interpolación de variables (ej. `${DB_USER}`) al parsear el `docker-compose.yml`. Si tu `.env` está en la raíz y el archivo de Compose está en `docker/`, usa siempre `--env-file .env` al ejecutar `docker compose` (por ejemplo `docker compose --env-file .env -f docker/docker.compose.yml up -d`) para asegurar que las variables se apliquen y evitar warnings. Alternativamente puedes copiar `.env` a `docker/.env` o usar `env_file` en el YAML.

### 3. Levantar servicios

```bash
docker compose -f docker/docker.compose.yml --env-file .env up -d
```

Ver logs:
```bash
docker compose -f docker/docker.compose.yml --env-file .env logs -f
```

### 4. Seed de desarrollo (solo DEV, por API)

En este repositorio, el modo recomendado es:
- `DB_SEED_MODE=backend` (default): PostgreSQL inicializa esquema, pero no inserta usuarios por SQL.
- El seed de usuarios se ejecuta por scripts externos (sin bootstrap interno en Gin).

Comando (desarrollo):
```bash
docker compose --env-file .env -f docker/docker.compose.yml -f docker/docker.compose.dev.yml --profile seed up dev-ensure-admin dev-seed-api
```

Qué hace cada servicio de seed:
- `dev-ensure-admin`: crea/actualiza el admin en PostgreSQL usando `.env`.
- `dev-seed-api`: hace login con ese admin y crea empleados/ciudadanos vía API.

Variables requeridas en `.env` para el seed de API:
```env
ADMIN_EMAIL=admin@recolecta.mx
ADMIN_PASSWORD=tu_password_admin
ADMIN_USERNAME=admin
SEED_EMPLEADO_PASSWORD=tu_password_empleados_dev
SEED_CIUDADANO_PASSWORD=tu_password_ciudadanos_dev
SEED_CIUDADANOS_COUNT=200
```

Contrato actual de autenticación/registro:
- Login empleado: `POST /api/empleados/login` con `{ "email", "password" }`.
- Login ciudadano: `POST /api/ciudadanos/login` con `{ "email", "password" }`.
- Registro ciudadano: `POST /api/ciudadanos` requiere `fcm_token`.
  - El backend guarda el token en Redis con clave `fcm:ciudadano:<id>`.

---

## ✅ Verificación

Después de 10–15 segundos, verifica que todo funciona:

### Acceso web
```bash
curl http://localhost
# Debería devolver HTML (página placeholder)

curl http://localhost/health
# Debería devolver "healthy"
```

### PostgreSQL
```bash
# Reemplaza <usuario> y <nombre_db> con los valores de tu .env
docker compose --env-file .env -f docker/docker.compose.yml exec -T database \
  psql -U <usuario> -d <nombre_db> -c "SELECT version();"
```

### Redis
```bash
# Reemplaza <password> con tu REDIS_PASSWORD
docker compose --env-file .env -f docker/docker.compose.yml exec redis \
  REDISCLI_AUTH=<password> redis-cli PING
# Debería responder: PONG
```

### Contenedores corriendo
```bash
docker compose --env-file .env -f docker/docker.compose.yml ps
# Deberías ver 3 contenedores "Up"
```

---

## 🔧 Servicios

### PostgreSQL (5432)
- **Imagen:** `postgres:16-alpine`
- **Container:** `postgres_db`
- **Volumen:** `postgres_data` (persistente)
- **Credenciales:** desde `.env` (`DB_USER`, `DB_PASSWORD`, `DB_NAME`)

Inicialización automática:
- `docker/postgresql/init-scripts/init-database.sh` — crea/actualiza schema y registra checksums
- `docker/postgresql/init-scripts/seed-if-empty.sh` — carga seed condicional y registra checksums
- Schema version table: `schema_version` (historial de cambios)

### Redis (6379)
- **Imagen:** `redis:7.2-alpine`
- **Container:** `redis_cache`
- **Volumen:** `redis_data` (persistente, AOF enabled)
- **Password:** desde `.env` (`REDIS_PASSWORD`)

### Nginx (80)
- **Imagen:** Build custom (`Dockerfile.nginx` para modo normal/prod, `Dockerfile.nginx.dev` para dev)
- **Container:** `nginx_proxy`
- **Puertos:** 80 (HTTP), 443 (futuro HTTPS)
- **Rutas:**
  - `/` → frontend
  - `/mapa/` → map-view
  - `/api/` → backend
- **SPA fallback (modo normal/prod):**
  - 404 en `/` vuelve a `/index.html`
  - 404 en `/mapa/` vuelve a `/mapa/index.html`

---

## 📝 Variables de Entorno

### PostgreSQL
```env
DB_HOST=db                          # Nombre del contenedor (en red Docker)
DB_PORT=5432                        # Puerto
DB_USER=recolecta                   # Usuario BD
DB_PASSWORD=tu_contraseña_segura    # Contraseña
DB_NAME=proyecto_recolecta          # Nombre BD
```

### Redis
```env
REDIS_HOST=redis                    # Nombre del contenedor
REDIS_PORT=6379                     # Puerto
REDIS_PASSWORD=tu_redis_password    # Password
```

### Aplicación
```env
ENVIRONMENT=development             # development | production
GOOGLE_APPLICATION_CREDENTIALS=C:/ruta/segura/firebase/service-account.json
```

### Firebase Cloud Messaging (opcional)
```env
GOOGLE_APPLICATION_CREDENTIALS=C:/ruta/segura/firebase/service-account.json
```

Recomendaciones:
- Descarga la cuenta de servicio de Firebase en una carpeta fuera del repositorio
- No reutilices credenciales compartidas entre ambientes
- Verifica que `.gitignore` excluya archivos JSON sensibles

## 🔔 Notificaciones Push: configuración segura

### Desarrollo local

1. Genera una cuenta de servicio en Firebase con permisos para FCM.
2. Descarga el archivo JSON en una ruta fuera de este repositorio.
3. Configura `GOOGLE_APPLICATION_CREDENTIALS` en `.env` con la ruta absoluta del archivo.
4. Reinicia los servicios o el proceso del backend para que lea la nueva variable.

Ejemplo:
```env
GOOGLE_APPLICATION_CREDENTIALS=C:/secure/firebase/recolecta-service-account.json
```

### Producción

La estrategia recomendada es no copiar credenciales a la imagen ni al repositorio.

- Guarda el `credentials.json` en un gestor externo de secretos, por ejemplo AWS Secrets Manager
- Concede acceso al secreto mediante IAM al entorno de ejecución
- Monta el secreto como archivo de solo lectura dentro del contenedor
- Define `GOOGLE_APPLICATION_CREDENTIALS` con la ruta montada dentro del contenedor, por ejemplo `/run/secrets/firebase_credentials.json`

Esto permite que la aplicación use Application Default Credentials sin hardcodear secretos.

---

## 🔄 Comandos Comunes

### Iniciar/detener
```bash
# Iniciar modo normal/prod-like (build estático frontend + map-view)
docker compose -f docker/docker.compose.yml --env-file .env up -d --build

# Iniciar modo desarrollo (HMR + debug detrás de nginx)
docker compose -f docker/docker.compose.yml -f docker/docker.compose.dev.yml --env-file .env up -d --build

# Ver estado
docker compose -f docker/docker.compose.yml --env-file .env ps

# Detener (sin eliminar datos)
docker compose -f docker/docker.compose.yml --env-file .env down

# Detener y eliminar TODOS los datos
docker compose -f docker/docker.compose.yml --env-file .env down -v
```

### Logs
```bash
# Todos los servicios
docker compose -f docker/docker.compose.yml --env-file .env logs -f
# Solo PostgreSQL
docker compose -f docker/docker.compose.yml --env-file .env logs -f database

# Últimas 50 líneas
docker compose -f docker/docker.compose.yml --env-file .env logs --tail=50 database
```

### Acceso a contenedores
```bash
# Shell en PostgreSQL
docker compose -f docker/docker.compose.yml --env-file .env exec database sh
# psql en PostgreSQL
docker compose -f docker/docker.compose.yml --env-file .env exec -T database \
  psql -U <usuario> -d <nombre_db>

# Redis CLI
docker compose -f docker/docker.compose.yml --env-file .env exec redis \
  REDISCLI_AUTH=<password> redis-cli
```

### Limpieza
```bash
# Limpiar datos detallada (solo espacios sin usar)
docker system prune

# Limpieza nuclear (⚠️ BORRA TODO)
docker compose -f docker/docker.compose.yml down -v
docker system prune -af --volumes
```

---

## 🐛 Troubleshooting

### ❌ Puerto ya en uso (5432, 6379, 80)

```bash
# Encontrar qué proceso usa el puerto
netstat -ano | findstr :5432

# Cambiar puerto en .env
DB_PORT=5433
REDIS_PORT=6380
```

Luego reinicia:
```bash
docker compose -f docker/docker.compose.yml down
docker compose -f docker/docker.compose.yml --env-file .env up -d
```

### ❌ No se puede conectar a PostgreSQL

```bash
# 1. Verificar que el contenedor está corriendo
docker compose -f docker/docker.compose.yml ps | findstr database

# 2. Verificar logs
docker compose -f docker/docker.compose.yml logs database

# 3. Probar conexión desde dentro del contenedor (usa valores de .env)
docker compose -f docker/docker.compose.yml exec -T database \
  psql -U <usuario> -d <nombre_db> -c "SELECT 1;"
```

### ❌ Hot-reload no detecta cambios (WSL + filesystem Windows)

Si Docker corre en WSL y el repo está en `C:\...` (montado como `/mnt/c/...`), los eventos de archivo pueden perderse.

Mitigación aplicada en este repo:
- `air` con polling (`poll=true`, `poll_interval=1000`)
- Vite (frontend/map-view) con polling de watch

Si persiste, mueve el repo al filesystem nativo de WSL (`/home/<usuario>/...`).

### ❌ Variables de entorno no se cargan

```bash
# Verificar que .env existe y tiene valores
Test-Path .env
Get-Content .env

# Validar que Docker Compose lee el .env
docker compose -f docker/docker.compose.yml config | grep DB_

# Recrear con .env explícito
docker compose -f docker/docker.compose.yml down -v
docker compose -f docker/docker.compose.yml --env-file .env up -d
```

### ❌ Volumen con datos viejos

PostgreSQL solo lee variables de entorno en la **primera inicialización**. Si cambiaste credenciales:

```bash
# Eliminar volumen (⚠️ BORRA DATOS)
docker compose -f docker/docker.compose.yml down -v

# Limpiar completamente
docker system prune -af --volumes

# Levantar de nuevo
docker compose -f docker/docker.compose.yml --env-file .env up -d
```

---

## � Redis - Datos de Prueba (Generación y Carga)

### 📍 Ubicación Base
**Suchiapa, Chiapas, México** (16.5896°N, -93.0547°W)

### ✨ Inicialización Automática

**Redis se inicializa automáticamente con 200 usuarios al levantar Docker Compose.**

```bash
docker compose -f docker/docker.compose.yml --env-file .env up -d redis
```

El contenedor:
1. ✅ Inicia Redis en background
2. ✅ Verifica si está vacío (DBSIZE = 0)
3. ✅ Genera un archivo de datos si no existe
4. ✅ Carga 200 usuarios + 25 puntos automáticamente
5. ✅ Reinicia Redis en foreground

**No necesitas ejecutar scripts manualmente.** Los datos se cargan solo si Redis está vacío.

### Generación Manual (opcional)

Si necesitas regenerar los datos:

```bash
# 1. Generar 200 usuarios + 25 puntos de recolección
cd docker/redis/init-scripts/
bash generate-seed-data.sh

# 2. Asegurar que Redis está corriendo
docker compose -f ../../docker.compose.yml up -d redis

# 3. Cargar datos manualmente
bash load-redis.sh redis 6379 redis_dev_pass_456
```

✅ **Resultado:** 200 usuarios distribuidos geográficamente con búsquedas geoespaciales O(log N)

### Verificación
```bash
# Validar integridad de datos
bash verify-redis.sh redis 6379 redis_dev_pass_456

# Esperado: 12 validaciones verdes ✓
```

### Datos Generados
| Entidad | Cantidad | Detalles |
|---------|----------|----------|
| Usuarios | 200 | IDs 100-299 con FCM tokens |
| Colonias | 8 | Distribuidas en Suchiapa |
| Rutas | 5 | 5 puntos cada una = 25 total |
| Comandos Redis | ~3000 | En `docker/redis/seeds/redis-seed_v2_*.txt` y symlink `redis-seed-latest.txt` |

### Estructura de Scripts
```
docker/redis/init-scripts/
├── generate-seed-data.sh    # Genera datos realistas
├── load-redis.sh            # Carga en Redis
├── verify-redis.sh          # Valida integridad
└── init-if-empty.sh         # Para Docker automático
```

### Búsquedas Geoespaciales
```bash
# Conectarse a Redis (método seguro con variable de entorno)
export REDISCLI_AUTH="redis_dev_pass_456"
redis-cli -h localhost -p 6379

# Usuarios a 1km de Suchiapa
GEORADIUS users:geo 16.5896 -93.0547 1 km WITHCOORD WITHDIST

# Distancia entre dos usuarios
GEODIST users:geo 100 101 km
```

### Limpieza y Reinicio
```bash
# ADVERTENCIA: Borra todos los datos
export REDISCLI_AUTH="redis_dev_pass_456"
redis-cli FLUSHDB

# Regenerar
bash generate-seed-data.sh
bash load-redis.sh redis 6379 redis_dev_pass_456
```

---

## 📚 Documentación Relacionada

- **BD Operations:** [02-database-operations.md](02-database-operations.md) — dump, restore, seed
- **Redis Schema:** [04-redis-schema.md](04-redis-schema.md) — estructura completa de datos
- **Redis Lifecycle:** [05-data-lifecycle.md](05-data-lifecycle.md) — flujos de datos y operaciones
- **Redis Casos de Uso:** [03-redis-operations.md](03-redis-operations.md) — benchmarks y ejemplos
- **Frontend:** [../frontend/README.md](../frontend/README.md) — React development
- **Backend:** [../gin-backend/README.md](../gin-backend/README.md) — Go API development
- **Changelog:** [../CHANGELOG.md](../CHANGELOG.md) — historial de cambios

---

**Última actualización:** 30 de Enero de 2026
