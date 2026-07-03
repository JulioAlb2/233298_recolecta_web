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

## 🌐 Exponer la API localmente con ngrok (para pruebas compartidas)

Cada desarrollador puede exponer su entorno local con una URL pública usando ngrok — sin depender de un servidor compartido.

### 1. Obtener el authtoken

1. Crear cuenta gratis en https://ngrok.com
2. Copiar el authtoken desde el dashboard

### 2. Configurar en `.env`

```env
NGROK_AUTHTOKEN=tu_token_aqui
```

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
