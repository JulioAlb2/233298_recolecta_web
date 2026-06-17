# 🚀 Guía Rápida de Inicio - Recolecta Web

Esta es una guía ultra-condensada para desarrolladores que quieren empezar **YA**.

## ⚡ 3 Comandos = Proyecto Corriendo

```bash
# 1. Clonar e inicializar
git clone <url-repo> && cd recolecta_web
git submodule update --init --recursive

# 2. Copiar .env y editar con tus valores
cp .env.example .env
# Abre .env y cambia las contraseñas

# 3. Levantar servicios (con wrapper que carga .env automáticamente)
./docker/docker-compose.sh up -d

# Alternativa: usar docker compose directamente
# docker compose -f docker/docker.compose.yml up -d
```

## ✅ Verificar que funciona

- 🌐 Abre http://localhost → Deberías ver "Recolecta Web - En Construcción"
- 🔍 http://localhost/health → Debería responder "healthy"

```bash
# Ver estado
./docker/docker-compose.sh ps

# Ver logs
./docker/docker-compose.sh logs -f

# Ejecutar tests de integridad
bash scripts/tests/redis/test_seed_integrity.sh
```

## 🧪 Pruebas de flujo de usuario (vía Docker)

Ejecuta validaciones como lo haría un usuario real, usando `docker compose exec`:

```bash
# 1) Asegura backend arriba en modo dev
docker compose --env-file .env -f docker/docker.compose.yml -f docker/docker.compose.dev.yml up -d backend

# 2) Corre tests del módulo de notificaciones dentro del contenedor
docker compose --env-file .env -f docker/docker.compose.yml -f docker/docker.compose.dev.yml exec backend \
  sh -lc "cd /app && /usr/local/go/bin/go test ./src/notificacion/..."

# 3) Smoke test API de ciudadano (registro + coordenadas) desde host
# Endpoint: POST /api/ciudadanos/register
# Endpoint: POST /api/ciudadanos/coordinates (Bearer JWT del registro)
```

### Hallazgo actual conocido

- El flujo `POST /api/usuarios` puede fallar con:
  `ERROR: relation "usuario" does not exist (SQLSTATE 42P01)`
- Este bloqueo es de esquema PostgreSQL en el módulo `usuarios` y no afecta el flujo de `ciudadanos`.

## 🔑 Credenciales (configurables en .env)

### PostgreSQL
```
Host: localhost
Port: 5432
User: <tu_usuario del .env>
Password: <tu_contraseña del .env>
Database: <nombre_base_datos del .env>
```

### Redis
```
Host: localhost
Port: 6379
Password: <tu_contraseña_redis del .env>
```

## 🛠️ Comandos Más Usados

```bash
# Levantar
docker compose -f docker/docker.compose.yml --env-file .env up -d

# Detener
docker compose -f docker/docker.compose.yml down

# Ver logs
docker compose -f docker/docker.compose.yml logs -f

# Estado
docker compose -f docker/docker.compose.yml ps

# Recrear todo (borra datos)
docker compose -f docker/docker.compose.yml down -v
docker compose -f docker/docker.compose.yml --env-file .env up -d

# PostgreSQL CLI (reemplaza valores con los de tu .env)
docker compose -f docker/docker.compose.yml exec database psql -U <usuario> -d <nombre_db>

# Redis CLI (usa tu REDIS_PASSWORD)
docker compose -f docker/docker.compose.yml exec redis sh -c 'REDISCLI_AUTH=<tu_contraseña_redis> redis-cli PING'
```

## 🌐 Exponer la API localmente con ngrok (para pruebas compartidas)

Cada desarrollador puede exponer su entorno local con una URL pública usando ngrok — sin depender de un servidor compartido.

### 1. Obtener el authtoken

1. Crear cuenta gratis en https://ngrok.com
2. Copiar el authtoken desde el dashboard

### 2. Configurar en `.env`

```env
NGROK_AUTHTOKEN=tu_token_aqui
```

### 3. Levantar el stack con ngrok

```bash
docker compose -f docker/docker.compose.yml -f docker/docker.compose.dev.yml --env-file .env up -d
```

ngrok se levanta automáticamente como servicio del compose y apunta al nginx (puerto 80).

### 4. Obtener la URL pública

```bash
# Ver la URL asignada en los logs
docker logs ngrok_tunnel

# O abrir el panel web de ngrok
# http://localhost:4040
```

La URL será algo como `https://abc123.ngrok-free.app` — compártela con tu equipo para que consuman la API directamente.

> **Nota:** Con la cuenta gratuita de ngrok la URL cambia cada vez que reinicias el contenedor. Para una URL fija necesitas cuenta de pago.

## 📚 Documentación Completa

- [README.md](README.md) - Guía completa del proyecto
- [docker/README.md](docker/README.md) - Referencia completa de Docker
- [CHANGELOG.md](CHANGELOG.md) - Historial de cambios

---

## 🔧 Comandos de Limpieza

```bash
# Detener servicios
docker compose -f docker/docker.compose.yml down

# Detener y borrar volúmenes (BORRA DATOS)
docker compose -f docker/docker.compose.yml down -v

# 🔥 LIMPIEZA COMPLETA (borra TODO: datos, imágenes, caché)
docker compose -f docker/docker.compose.yml down -v --remove-orphans
docker system prune -af --volumes

# 🔄 RESET TOTAL (limpieza + rebuild)
docker compose -f docker/docker.compose.yml down -v --remove-orphans; 
docker system prune -af --volumes; docker compose -f docker/docker.compose.yml --env-file .env up -d --build
```

**Cuándo usar limpieza completa:**
- Variables de entorno no se aplican
- Cambios en Dockerfiles no se reflejan
- Errores persistentes en contenedores
- Cambio de versiones de PostgreSQL/Redis

---

**¿Problemas?** Ve a [README.md#solución-de-problemas](README.md#-solución-de-problemas)
