# 📋 Registro de puesta en marcha de Docker (2026-07-21)

Este documento registra, paso a paso, lo que se hizo para levantar el stack de Docker siguiendo [QUICKSTART.md](QUICKSTART.md), qué problemas se encontraron (ninguno documentado antes en QUICKSTART) y cómo se resolvieron. Sirve como referencia para el equipo si alguien más pasa por lo mismo.

## Estado inicial encontrado

Antes de empezar, ya existía un stack de Docker corriendo (de una sesión anterior, ~20h) pero:

- No había archivo `.env` en la raíz (solo `.env.example`).
- `frontend_dev` y `map_view_dev` se habían caído (`Exited (137)`, probablemente por reinicio de Docker Desktop).
- `nginx_proxy` estaba en **crash-loop** porque no podía resolver los hosts `frontend_dev` / `map_view_dev` en su `nginx.conf`.
- Submódulos (`frontend`, `gin-backend`, `map-view`) ya estaban en `develop`, y `modelo-reportes` / `clasificador-reportes` en `main` — ese paso del QUICKSTART ya estaba hecho.

## Pasos realizados

### 1. Crear `.env`

```bash
cp .env.example .env
```

Tal como indica el paso 1 de [QUICKSTART.md](QUICKSTART.md#-3-comandos--proyecto-corriendo).

### 2. Reiniciar el stack limpio

Se bajó el stack viejo (sin `-v`, para no perder los datos de Postgres/Redis) y se volvió a levantar con `--env-file .env` explícito:

```bash
docker compose -f docker/docker.compose.yml -f docker/docker.compose.dev.yml --env-file .env down
docker compose -f docker/docker.compose.yml -f docker/docker.compose.dev.yml --env-file .env up -d
```

Esto resolvió el crash-loop de `nginx_proxy`, ya que `frontend_dev` y `map_view_dev` volvieron a estar disponibles en la red interna.

### 3. Bug real encontrado y corregido: `modelo_reportes` sin `pandas`

El contenedor `modelo_reportes` (submódulo `modelo-reportes`, servicio nuevo — aún no documentado en QUICKSTART) fallaba al arrancar:

```
ModuleNotFoundError: No module named 'pandas'
```

`api/aplicar_modelo.py` importa `pandas`, pero `api/requirements.txt` no lo declaraba (solo llegaba `numpy`/`joblib` como dependencias transitivas de `scikit-learn`).

**Cambio aplicado** (commit pendiente en el fork `modelo_reportes_Fork`):

- `modelo-reportes/api/requirements.txt`: se agregó `pandas>=2.2,<3.0`.

### 4. Limitación conocida (no resuelta): artefactos de modelo faltantes

Tras el fix de `pandas`, `modelo_reportes` falló de nuevo, ahora con:

```
FileNotFoundError: [Errno 2] No such file or directory: '/app/entrenamienot/artefactos/scaler_paso2.joblib'
```

Los archivos `.joblib` (modelo entrenado) están **intencionalmente excluidos** en `modelo-reportes/.gitignore` (`**/artefactos/`, `*.joblib`) porque son artefactos generados, no código fuente. No hay datos de entrenamiento (`data/`) ni instrucciones en el repo para regenerarlos.

**No se intentó "arreglar" esto** porque requeriría datos reales de entrenamiento que no están disponibles. Se detuvo el contenedor para que no quede reiniciándose en bucle:

```bash
docker compose -f docker/docker.compose.yml -f docker/docker.compose.dev.yml --env-file .env stop modelo-reportes
```

**Pendiente para quien lo retome:** correr el pipeline en `modelo-reportes/entrenamienot/01_paso_objetivo.py` → `06_paso_resumen_final.py` con datos reales para generar los `.joblib`, o documentar de dónde obtenerlos.

### 5. `ngrok_tunnel` deshabilitado (opcional, sin token)

`ngrok_tunnel` fallaba con `ERR_NGROK_4018` (sin `NGROK_AUTHTOKEN`). Es un servicio **opcional** (solo para exponer la API con URL pública, ver sección de ngrok en QUICKSTART.md). Se detuvo:

```bash
docker compose -f docker/docker.compose.yml -f docker/docker.compose.dev.yml --env-file .env stop ngrok
```

Si en algún momento se quiere usar, hay que configurar en `.env`:
```env
NGROK_AUTHTOKEN=tu_token_de_ngrok
NGROK_DOMAIN=tu-dominio.ngrok-free.dev
```
y volver a levantarlo con `docker compose ... up -d ngrok`.

### 6. Bug real encontrado y corregido: backend hacía `panic` sin credenciales de Firebase

`gin_backend_dev` moría al arrancar (por eso `/api/*` devolvía `502` a través del proxy):

```
panic: fcm credentials file not found at '/credentials/firebase_credentials.json': stat /credentials/firebase_credentials.json: no such file or directory
```

`gin-backend/dependencies.go` crea el cliente de FCM (`NewFCMClient`) de forma **incondicional** al iniciar — si no hay credenciales, todo el backend hace panic, aunque las notificaciones push sean una funcionalidad específica. Esto no estaba resuelto porque `GOOGLE_APPLICATION_CREDENTIALS` venía vacío en `.env.example`.

**Solución aplicada** (con credenciales reales del proyecto Firebase `recolecta-2d9e9`, provistas por el usuario):

1. Se creó la carpeta `credentials/` en la raíz (ya estaba en `.gitignore` vía `/credentials`, así que es 100% local, nunca se sube a git).
2. Se colocó el archivo de cuenta de servicio: `credentials/recolecta-2d9e9-firebase-adminsdk-fbsvc-5c4bfca297.json`.
3. Se agregaron estas variables a `.env`:
   ```env
   GOOGLE_APPLICATION_CREDENTIALS=/credentials/recolecta-2d9e9-firebase-adminsdk-fbsvc-5c4bfca297.json
   FCM_CREDENTIALS_FILE=/credentials/recolecta-2d9e9-firebase-adminsdk-fbsvc-5c4bfca297.json
   FIREBASE_PROJECT_ID=recolecta-2d9e9
   ```
4. Se recreó el contenedor del backend para tomar los nuevos valores:
   ```bash
   docker compose -f docker/docker.compose.yml -f docker/docker.compose.dev.yml --env-file .env up -d backend
   ```

**Nota de seguridad:** el archivo JSON de credenciales nunca debe subirse al repositorio ni compartirse fuera del equipo — es una clave privada de la cuenta de servicio de Firebase.

**Nota para el equipo (no aplicado aquí):** sería más robusto que el backend no haga `panic` completo si faltan credenciales de FCM, sino que deshabilite solo el módulo de notificaciones push con un warning. Así el resto de la API seguiría funcionando en un entorno sin Firebase configurado. Quedó fuera de este cambio porque implica modificar lógica de arranque en Go y el usuario prefirió usar credenciales reales.

## Estado final

```
NAME                    STATUS
clasificador_reportes   Up (healthy)
frontend_dev            Up
gin_backend_dev         Up
map_view_dev            Up
nginx_proxy             Up
postgres_db             Up (healthy)
redis_cache             Up (healthy)
modelo_reportes         Detenido (falta modelo entrenado, ver punto 4)
ngrok_tunnel            Detenido (opcional, sin token, ver punto 5)
```

Verificado con curl a través de nginx:
- `GET /` → 200 (frontend)
- `GET /mapa/` → 200 (map-view)
- `GET /health` → 200 `healthy`
- `GET /api/swagger/index.html` → 200 (backend)

## Archivos modificados

| Archivo | Cambio |
|---|---|
| `.env` (nuevo, no versionado) | Copiado de `.env.example` + variables de Firebase agregadas |
| `credentials/recolecta-2d9e9-firebase-adminsdk-fbsvc-5c4bfca297.json` (nuevo, no versionado) | Credencial real de Firebase provista por el usuario |
| `modelo-reportes/api/requirements.txt` | Se agregó `pandas>=2.2,<3.0` (submódulo, fork propio — falta commit/push) |

## Pendientes sugeridos

1. Commitear y pushear el fix de `pandas` en el fork de `modelo-reportes`.
2. Generar o conseguir los artefactos `.joblib` de `modelo_reportes` (o documentar el pipeline de entrenamiento) para poder levantar ese servicio.
3. Si se quiere usar `ngrok`, agregar `NGROK_AUTHTOKEN`/`NGROK_DOMAIN` propios en `.env`.
4. Evaluar si conviene que el backend no haga `panic` total cuando faltan credenciales de FCM (mencionado en el punto 6), para que entornos sin Firebase configurado puedan levantar el resto de la API.
