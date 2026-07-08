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
```

## Cambiar a ramas de desarrollo

```bash
cd frontend && git checkout develop && cd ..
cd map-view && git checkout develop && cd ..
cd gin-backend && git checkout develop && cd ..
```

## 🌐 Exponer la API localmente con ngrok (para pruebas compartidas)

Cada desarrollador puede exponer su entorno local con una URL pública usando ngrok — sin depender de un servidor compartido.

### 1. Obtener el authtoken

1. Crear cuenta gratis en [https://ngrok.com](https://ngrok.com)
2. Copiar el authtoken desde el dashboard



### 2. Configurar en `.env`

```env
NGROK_AUTHTOKEN=tu_token_aqui
NGROK_DOMAIN=tu-dominio.ngrok-free.dev
```

Reserva un dominio estático gratis en el [dashboard de ngrok](https://dashboard.ngrok.com/domains) y pégalo en `NGROK_DOMAIN`.

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

Todo los comandos se ejecutan desde la raíz del proyecto. Asegúrate de tener Docker y Docker Compose instalados.

> `DB_SEED_MODE` por defecto es `backend`: crea estructura de BD, pero no siembra usuarios por SQL.
> El seeding de usuarios para desarrollo se hace por API (ver sección siguiente).

```bash
# Levantar el servicio en modo de desarrollo en primer plano
docker compose -f docker/docker.compose.yml -f docker/docker.compose.dev.yml --env-file .env up
*Nota:* **Los servicios se levantaran en primer plano, no cierres la terminal**

# Levantar el servicio en modo de desarrollo en segundo plano
docker compose -f docker/docker.compose.yml -f docker/docker.compose.dev.yml --env-file .env up -d

# Detener si está en segundo plano
docker compose -f docker/docker.compose.yml -f docker/docker.compose.dev.yml down

# Ver logs
docker compose -f docker/docker.compose.yml -f docker/docker.compose.dev.yml logs -f

# Estado
docker compose -f docker/docker.compose.yml -f docker/docker.compose.dev.yml ps

# Recrear todo (borra datos)
docker compose -f docker/docker.compose.yml -f docker/docker.compose.dev.yml down -v
docker compose -f docker/docker.compose.yml -f docker/docker.compose.dev.yml --env-file .env up -d

# PostgreSQL CLI (reemplaza valores con los de tu .env)
docker compose -f docker/docker.compose.yml -f docker/docker.compose.dev.yml exec database psql -U <usuario> -d <nombre_db>

# Redis CLI (usa tu REDIS_PASSWORD)
docker compose -f docker/docker.compose.yml -f docker/docker.compose.dev.yml exec redis sh -c 'REDISCLI_AUTH=<tu_contraseña_redis> redis-cli PING'
```



## 🌱 Seeding de usuarios SOLO en desarrollo (por API)

Contrato actual:

- Login empleado: `POST /api/empleados/login` con `email` + `password`
- Login ciudadano: `POST /api/ciudadanos/login` con `email` + `password`
- Registro ciudadano: `POST /api/ciudadanos` requiere `fcm_token` (se guarda en Redis como `fcm:ciudadano:<id>` y también en `user:<id>.fcm_token`)

Este proyecto **no** debe sembrar usuarios de prueba en producción.

1. Define en `.env` las credenciales/valores de seed dev:

```env
ADMIN_EMAIL=admin@recolecta.mx
ADMIN_PASSWORD=tu_password_admin
SEED_EMPLEADO_PASSWORD=tu_password_empleados_dev
SEED_CIUDADANO_PASSWORD=tu_password_ciudadanos_dev
SEED_CIUDADANOS_COUNT=200
# opcional: índice inicial de usuarios seed (default 1)
SEED_CIUDADANOS_START=1
# opcional explícito (ya es default)
DB_SEED_MODE=backend
```

1. Con el stack dev levantado, ejecuta el seed por API (incluye datos de referencia con rutas GPS):

```bash
docker compose --env-file .env -f docker/docker.compose.yml -f docker/docker.compose.dev.yml --profile seed up --force-recreate dev-ensure-admin dev-seed-reference dev-seed-api
```

> Nota: `dev-seed-reference` carga colonias, camiones y rutas con `json_ruta` (lat/lng) porque `DB_SEED_MODE=backend` omite el seed SQL completo.

> Nota: `dev-ensure-admin` crea/actualiza el admin desde `.env` vía SQL (sin bootstrap interno en Gin).

> Este flujo crea empleados/ciudadanos mediante endpoints del backend y el hash de password se resuelve en backend.

Verificación rápida de tokens FCM en Redis (después del seed):

```bash
# Conteo de claves legacy
docker compose -f docker/docker.compose.yml -f docker/docker.compose.dev.yml --env-file .env \
  exec redis sh -lc 'REDISCLI_AUTH=$REDIS_PASSWORD redis-cli KEYS "fcm:ciudadano:*" | wc -l'

# Muestra de hash por ciudadano (ajusta id)
docker compose -f docker/docker.compose.yml -f docker/docker.compose.dev.yml --env-file .env \
  exec redis sh -lc 'REDISCLI_AUTH=$REDIS_PASSWORD redis-cli HGETALL user:1'
```



## 🧱 Modo normal/prod-like (build estático)

```bash
docker compose --env-file .env -f docker/docker.compose.yml up -d --build
```

Ruteo nginx:

- `/` frontend
- `/mapa/` map-view
- `/api/` backend

Fallback SPA:

- `/` → `/index.html`
- `/mapa/` → `/mapa/index.html`



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

Con `NGROK_DOMAIN` configurado, la URL será fija (por ejemplo `https://tu-dominio.ngrok-free.dev`) aunque reinicies el contenedor.

## 📚 Documentación Completa

- [README.md](README.md) - Guía completa del proyecto
- [docker/README.md](docker/README.md) - Referencia completa de Docker
- [CHANGELOG.md](CHANGELOG.md) - Historial de cambios

---



## 🔁 Si no detecta cambios (air/vite)

Ya está configurado polling para backend (`air`) y frontend/map-view (`vite`).
Si aun así falla, normalmente es por repo en `C:\...` montado en WSL.
Recomendado: mover el repo al filesystem de WSL (`/home/...`).

## 🔧 Comandos de Limpieza

```bash
# Detener servicios
docker compose -f docker/docker.compose.yml -f docker/docker.compose.dev.yml down

# Detener y borrar volúmenes (BORRA DATOS)
docker compose -f docker/docker.compose.yml -f docker/docker.compose.dev.yml down -v

# 🔥 LIMPIEZA COMPLETA (borra TODO: datos, imágenes, caché)
docker compose -f docker/docker.compose.yml -f docker/docker.compose.dev.yml down -v --remove-orphans
docker system prune -af --volumes

# 🔄 RESET TOTAL (limpieza + rebuild)
docker compose -f docker/docker.compose.yml -f docker/docker.compose.dev.yml down -v --remove-orphans; 
docker system prune -af --volumes; docker compose -f docker/docker.compose.yml -f docker/docker.compose.dev.yml --env-file .env up -d --build
```

**Cuándo usar limpieza completa:**

- Variables de entorno no se aplican
- Cambios en Dockerfiles no se reflejan
- Errores persistentes en contenedores
- Cambio de versiones de PostgreSQL/Redis

---

**¿Problemas?** Ve a [README.md#solución-de-problemas](README.md#-solución-de-problemas)