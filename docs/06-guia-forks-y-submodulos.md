# Guía de Forks y Submódulos — Recolecta

Esta guía explica cómo está armada tu copia del proyecto (forks + submódulos), a dónde va cada commit según dónde lo hagas, y cómo mover cambios en las dos direcciones: traer actualizaciones del equipo y, si algún día quieres, proponer tus cambios de vuelta al repo original.

## 1. Arquitectura general

Este proyecto (`233298_recolecta_web`) no es un solo repositorio: es un repo "contenedor" que usa **submódulos de git** para enlazar tres piezas de frontend/backend/mapa, más dos microservicios adicionales. Cada submódulo es, en realidad, **otro repositorio completo e independiente**, con su propio historial, sus propias ramas y sus propios remotos. El repo principal no guarda el código de los submódulos línea por línea; guarda un **puntero** (un commit SHA exacto) a cada uno.

Encima de eso, cada pieza tiene dos remotos configurados:

- **`origin`**: tu copia (fork), donde SÍ tienes permiso de escritura. Aquí es donde pusheas tu trabajo.
- **`upstream`**: el repo original del compañero que creó ese módulo. Solo lo usas para **traer** cambios (fetch/merge), nunca para pushear.

Esto te permite seguir recibiendo las actualizaciones que hace tu equipo, sin arriesgarte nunca a modificar por accidente el trabajo de otra persona.

## 2. Mapa de remotos de este proyecto

| Carpeta | `origin` (aquí pusheas) | `upstream` (de aquí traes cambios) | Rama de trabajo |
|---|---|---|---|
| `233298_recolecta_web` (raíz) | `JulioAlb2/233298_recolecta_web` (repo compartido del equipo — SÍ tienes permiso) | *(no aplica, es el repo de entrega del equipo)* | `main` / `develop` |
| `frontend` | `Yara-Molina/RecolectaWeb_Fork` | `Denzel-Santiago/RecolectaWeb` | `develop` |
| `gin-backend` | `Yara-Molina/API_recolecta` | `vicpoo/API_recolecta` | `develop` |
| `map-view` | `Yara-Molina/MapaRecolectaFork` | `Denzel-Santiago/MapaRecolecta` | `develop` |
| `modelo-reportes` | `Yara-Molina/modelo_reportes_Fork` | `aleramirez1/modelo_reportes` | `main` |
| `clasificador-reportes` | `Yara-Molina/Recolecta_GI` | *(no aplica, es un repo original tuyo)* | `main` |

Para comprobar esto en cualquier momento, dentro de cada carpeta:
```powershell
git remote -v
```

## 3. ¿A dónde va un commit? Depende de dónde lo hagas

Este es el punto que más confunde con submódulos. Todo depende de **en qué carpeta estás parada** cuando corres `git commit`.

### Caso A — Haces commit DENTRO de un submódulo (ej. `frontend`, `gin-backend`, `map-view`, `modelo-reportes`, `clasificador-reportes`)

```powershell
cd frontend
# editas archivos...
git add .
git commit -m "cambio en el frontend"
git push origin develop
```

Ese commit pertenece **únicamente al historial de ese submódulo** (en este ejemplo, a tu fork `Yara-Molina/RecolectaWeb_Fork`). El repo principal (`233298_recolecta_web`) todavía no sabe nada de este cambio — sigue apuntando al commit viejo.

**Paso extra obligatorio:** para que el repo principal "vea" tu nuevo commit del submódulo, tienes que volver a la raíz y actualizar el puntero:

```powershell
cd ..
git add frontend
git commit -m "Actualizar puntero de frontend"
git push origin main
```

Si te saltas este paso, tu cambio existe en GitHub (en tu fork) pero el repo principal seguiría clonando la versión vieja del submódulo.

### Caso B — Haces commit en la RAÍZ del repo principal (sin meterte a ningún submódulo)

Por ejemplo, si editas `docker-compose.yml`, `.gitmodules`, un archivo de `docs/`, etc.:

```powershell
cd 233298_recolecta_web
git add docker/docker.compose.yml
git commit -m "Ajustar docker-compose"
git push origin main
```

Este commit pertenece al historial del **repo principal** y se pushea a `JulioAlb2/233298_recolecta_web` — el repo compartido de tu equipo. Esto es intencional en tu caso: como tienes permiso de escritura ahí y es el repo con el que entregas junto a tu equipo, está bien que estos cambios lleguen directo ahí.

## 4. Cómo traer cambios nuevos que suba tu equipo (upstream → tu fork)

Esto aplica a `frontend`, `gin-backend`, `map-view` y `modelo-reportes` (los que tienen `upstream` configurado):

```powershell
cd gin-backend                          # o frontend, map-view, modelo-reportes
git fetch upstream
git merge upstream/develop --no-edit    # usa 'main' en vez de 'develop' para modelo-reportes
git push origin develop
```

Si sale conflicto, git te va a marcar los archivos afectados con `<<<<<<<`; ábrelos, decide qué parte del código dejar, y luego:

```powershell
git add <archivo-resuelto>
git commit
git push origin develop
```

Después de esto, **no olvides el paso del Caso A**: vuelve a la raíz del repo principal, haz `git add <carpeta-submodulo>` y commitea el puntero actualizado, si no el repo principal se sigue quedando con la versión vieja.

## 5. Cómo subir tus propios cambios (tu fork)

Ya lo viste arriba (Caso A). En resumen, el flujo de trabajo del día a día es:

1. Entras al submódulo donde vas a trabajar.
2. Confirmas en qué rama estás (`git branch --show-current`) — normalmente `develop` (o `main` para los microservicios).
3. Programas, haces `commit`.
4. `git push origin <tu-rama>` — esto sube a **tu fork**, nunca al original.
5. Regresas a la raíz del repo principal, `git add <carpeta>`, `commit`, `push origin main` — para que el repo principal quede apuntando a tu nuevo commit.

## 6. ¿Y si quiero proponer mis cambios de vuelta al repo ORIGINAL?

Aquí es importante ser claros: **nunca vas a hacer `git push upstream ...`** — lo más seguro es que ni siquiera tengas permiso de escritura ahí, y aunque lo tuvieras, no es la forma correcta de colaborar en un modelo de forks.

La manera correcta es un **Pull Request (PR)** en GitHub:

1. Asegúrate de que tu cambio ya esté pusheado en tu fork (`git push origin develop`).
2. Entra a GitHub, a la página de tu fork (por ejemplo `github.com/Yara-Molina/API_recolecta`).
3. GitHub normalmente muestra un aviso tipo "*This branch is 2 commits ahead of vicpoo:develop*" con un botón **"Contribute" → "Open pull request"**. Si no te aparece, ve directo a la página del repo original (`github.com/vicpoo/API_recolecta`) y da clic en **"New pull request"**, luego selecciona como origen tu fork y tu rama.
4. Describe qué hiciste y por qué, y envía el PR.
5. El dueño del repo original (vicpoo, Denzel-Santiago o aleramirez1, según el caso) revisa, comenta y decide si lo mergea a su repo.

Esto aplica igual para el repo principal si algún día quisieras proponerle algo directamente al equipo — aunque en tu caso ya tienes permiso de push directo en `JulioAlb2/233298_recolecta_web`, así que no necesitas PR ahí, solo `git push origin main` normal.

## 7. Caso especial: `clasificador-reportes`

Este submódulo es un repositorio **propio tuyo** (no es fork de nadie). Por eso solo tiene `origin` y no tiene `upstream`: no hay ningún repo "original" del cual traer cambios, porque tú eres la autora original. Aquí simplemente trabajas y pusheas normal, sin preocuparte por sincronizar nada externo.

## 8. Errores comunes que ya nos topamos (y cómo resolverlos)

**"Cientos de archivos aparecen modificados sin que yo haya tocado nada"**
Casi siempre es diferencia de fin de línea (CRLF de Windows vs LF de git), no cambios reales. Verifica con:
```powershell
git diff --ignore-space-at-eol --stat
```
Si sale vacío, es solo ruido — puedes descartarlo con `git reset --hard HEAD` sin miedo.

**`fatal: Unable to create '.../index.lock': File exists`**
Un comando de git anterior se interrumpió y dejó un archivo de bloqueo. Ciérra cualquier editor/terminal que tenga el repo abierto y bórralo:
```powershell
Remove-Item -Force .git\index.lock -ErrorAction SilentlyContinue
```
Si el error es sobre un submódulo, el lock real vive en la carpeta del repo principal, no en la del submódulo:
```powershell
Remove-Item -Force ..\.git\modules\<nombre-submodulo>\index.lock -ErrorAction SilentlyContinue
```

**Un submódulo queda en "HEAD detached" (sin rama)**
Es normal después de `git submodule update`. Para ponerlo en una rama de verdad:
```powershell
git checkout -B develop origin/develop
```

**`git submodule add` clona una versión vieja / sin mis últimos archivos**
`git submodule add` clona **desde GitHub**, no desde tu carpeta local. Si acabas de crear un archivo (como un Dockerfile) y todavía no lo has pusheado a tu fork, el submódulo nuevo no lo va a traer. Orden correcto siempre: primero `push` a tu fork, después `git submodule add`.

**`develop` o mi rama nueva no tienen los últimos cambios, aunque `main` sí**
Puede pasar que algunos commits se suban directo a `main` y `develop` se quede atrás. Revisa la diferencia:
```powershell
git rev-list --left-right --count origin/main...origin/develop
```
Si el resultado es algo como `3  0` (main tiene 3 de más, develop 0), es un fast-forward simple:
```powershell
git checkout develop
git merge --ff-only origin/main
git push origin develop
```

## 9. Chuleta rápida

| Quiero... | Comando |
|---|---|
| Ver a dónde apunta cada remoto | `git remote -v` |
| Traer cambios del equipo | `git fetch upstream && git merge upstream/develop --no-edit` |
| Subir mi trabajo a mi fork | `git push origin develop` |
| Actualizar el puntero en el repo principal | `cd ..` → `git add <carpeta>` → `git commit` → `git push origin main` |
| Proponer mi cambio al repo original | Push a tu fork → abrir Pull Request en GitHub |
| Ver si estoy al día con el original | `git fetch upstream && git rev-list --left-right --count HEAD...upstream/develop` |
