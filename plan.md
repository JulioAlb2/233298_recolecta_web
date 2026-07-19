# Plan de Implementación: Ordenamiento Flotante y Sincronización por Lotes para Puntos de Recolección

Este plan detalla la implementación conjunta de **Floating Ordering (Orden Flotante)** y el **Patrón B de Sincronización (Modo Borrador con IDs Temporales)**, logrando que el orden de las paradas viva de forma 100% independiente de `json_ruta` en la base de datos PostgreSQL. Esto sirve directamente tanto a la aplicación móvil como a la web de administración.

---

## 🏗️ Resumen del Diseño Técnico

### 1. Base de Datos y Entidades
* Añadimos una columna `orden` de tipo `DOUBLE PRECISION` a la tabla `punto_recoleccion`.
* Los puntos de una ruta se consultan con `ORDER BY orden ASC, id ASC`.

### 2. Sincronización en un Solo Paso (`POST /api/puntos-recoleccion/sync`)
El frontend realiza múltiples ediciones en memoria (añadir, reordenar, borrar) usando IDs temporales para los nuevos puntos. Al dar clic en "Guardar", envía una única petición de sincronización con:
* **Puntos Nuevos**: Datos de los puntos creados en el cliente (con su `orden` calculado).
* **Puntos Actualizados**: Lista de `{punto_id, orden}` para actualizar los puntos existentes que cambiaron de posición.
* **Puntos Eliminados**: Lista de IDs de puntos que deben borrarse físicamente o mediante soft-delete.

El backend ejecuta estas tres acciones dentro de una **única transacción SQL** asegurando consistencia.

---

## 💻 Guía de Implementación del Frontend (UX & Estado)

Para interactuar con la API transaccional, el frontend mantendrá un estado unificado en memoria ("Borrador") que no altera el servidor hasta hacer clic en **Guardar Recorrido**.

### 1. Modelos del Frontend
```typescript
interface PuntoRecoleccion {
  punto_id: number | string; // Puede ser un número real o un ID temporal 'temp_xxx'
  ruta_id: number;
  cp: string;
  lat: number;
  lon: number;
  orden: number;
  eliminado?: boolean;
}
```

### 2. Gestión del Estado en React (Modo Borrador)
El panel mantendrá las listas de cambios acumulados:
```typescript
const [puntos, setPuntos] = useState<PuntoRecoleccion[]>([]);
const [puntosEliminados, setPuntosEliminados] = useState<number[]>([]); // Guarda IDs reales a borrar
```

### 3. Operaciones de Edición en UX

* **Añadir un Punto**:
  * Cuando el usuario hace clic en el mapa, generamos un ID temporal único (ej: `temp_${Date.now()}`).
  * Calculamos el valor de `orden` del nuevo punto. Si se añade al final de una lista de $N$ elementos, su orden será `(puntos[N-1].orden + 10.0)`.
  * Insertamos el objeto en el array `puntos` local.

* **Eliminar un Punto**:
  * Si el punto a eliminar tiene un ID real (numérico), lo agregamos a `puntosEliminados`.
  * Removemos el punto de la lista `puntos` local y actualizamos el mapa.

* **Arrastrar y Reordenar (Drag & Drop)**:
  * Cuando se suelta una parada en una nueva posición (índice `destIndex`), calculamos su nuevo `orden` flotante en base a sus vecinos:
    ```typescript
    let nuevoOrden = 0;
    if (destIndex === 0) {
      nuevoOrden = puntos[0].orden - 10.0;
    } else if (destIndex === puntos.length - 1) {
      nuevoOrden = puntos[puntos.length - 1].orden + 10.0;
    } else {
      const anterior = puntos[destIndex - 1].orden;
      const siguiente = puntos[destIndex].orden;
      nuevoOrden = (anterior + siguiente) / 2;
    }
    ```

### 4. Sincronización Final (Guardar)
Al dar clic en "Guardar Recorrido", construimos y enviamos el payload agrupado:
```typescript
const guardarCambios = async () => {
  const nuevos = puntos.filter(p => typeof p.punto_id === 'string' && p.punto_id.startsWith('temp_'));
  const actualizados = puntos.filter(p => typeof p.punto_id === 'number');

  const payload = {
    ruta_id: selectedRutaId,
    puntos_nuevos: nuevos.map(p => ({
      direccion: p.cp,
      lat: p.lat,
      lon: p.lon,
      orden: p.orden
    })),
    puntos_eliminados: puntosEliminados,
    puntos_actualizados: actualizados.map(p => ({
      punto_id: p.punto_id as number,
      orden: p.orden
    }))
  };

  await apiRequest('/api/puntos-recoleccion/sync', {
    method: 'POST',
    body: JSON.stringify(payload)
  });

  // Limpiar estados locales y recargar datos frescos de la BD
  setPuntosEliminados([]);
  await loadAll();
};
```

---

## 🛠️ Cambios Propuestos en el Backend

### Componente 1: Base de Datos y Modelos Go

#### [MODIFY] `db_script.sql` (gin-backend/db_script.sql)
Agregar la columna `orden` a la tabla `punto_recoleccion` para instalaciones limpias (Ya migrado en la base de datos de desarrollo activa):
```diff
 CREATE TABLE IF NOT EXISTS punto_recoleccion (
   id SERIAL PRIMARY KEY,
   ruta_id INTEGER NOT NULL,
   direccion VARCHAR(255) NOT NULL,
+  orden DOUBLE PRECISION DEFAULT 0.0,
   created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
   updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
   deleted_at TIMESTAMP DEFAULT NULL
 );
```

#### [MODIFY] `PuntoRecoleccion.go` (gin-backend/src/Rutas/domain/entities/PuntoRecoleccion.go)
Agregar el campo `Orden` a la entidad:
```diff
 type PuntoRecoleccion struct {
 	PuntoID   int32     `json:"punto_id"`
 	RutaID    int32     `json:"ruta_id"`
 	CP        string    `json:"cp"`
 	Lat       float64   `json:"lat"`
 	Lon       float64   `json:"lon"`
+	Orden     float64   `json:"orden"`
 	Eliminado bool      `json:"eliminado"`
 	CreatedAt time.Time `json:"created_at"`
 }
```

---

### Componente 2: Adaptador PostgreSQL (Adaptadores e Interfaces)

#### [MODIFY] `IPuntoRecoleccion.go` (gin-backend/src/Rutas/domain/ports/IPuntoRecoleccion.go)
Agregar la función `Sync` a la interfaz del puerto:
```diff
 type IPuntoRecoleccion interface {
 	Save(p *entities.PuntoRecoleccion) (*entities.PuntoRecoleccion, error)
 	Update(id int32, p *entities.PuntoRecoleccion) (*entities.PuntoRecoleccion, error)
 	ListAll() ([]entities.PuntoRecoleccion, error)
 	GetById(id int32) (*entities.PuntoRecoleccion, error)
 	GetByRuta(rutaId int32) ([]entities.PuntoRecoleccion, error)
 	Delete(id int32) error
+	Sync(ctx context.Context, rutaID int32, nuevos []entities.PuntoRecoleccion, eliminados []int32, actualizados []entities.PuntoRecoleccion) error
 }
```

#### [MODIFY] `PostgresPuntoRecoleccion.go` (gin-backend/src/Rutas/infraestructure/adapters/PostgresPuntoRecoleccion.go)
Actualizar los métodos de lectura y escritura para incluir la columna `orden`, y cambiar el ordenamiento en `GetByRuta` para usar `ORDER BY orden ASC, id ASC`:

* **`GetByRuta`**:
```go
	sql := `
	SELECT id, ruta_id, direccion, orden, (deleted_at IS NOT NULL) AS eliminado
	FROM punto_recoleccion
	WHERE ruta_id = $1 AND deleted_at IS NULL
	ORDER BY orden ASC, id ASC
	`
```

* **Implementación de `Sync`**:
```go
func (pg *PostgresPuntoRecoleccion) Sync(
	ctx context.Context,
	rutaID int32,
	nuevos []entities.PuntoRecoleccion,
	eliminados []int32,
	actualizados []entities.PuntoRecoleccion,
) error {
	tx, err := pg.conn.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	// 1. Procesar eliminaciones
	if len(eliminados) > 0 {
		sqlDel := `UPDATE punto_recoleccion SET deleted_at = NOW() WHERE id = $1 AND deleted_at IS NULL`
		for _, id := range eliminados {
			if _, err := tx.Exec(ctx, sqlDel, id); err != nil {
				return err
			}
		}
	}

	// 2. Procesar actualizaciones de orden
	if len(actualizados) > 0 {
		sqlUpdate := `UPDATE punto_recoleccion SET orden = $1 WHERE id = $2 AND deleted_at IS NULL`
		for _, p := range actualizados {
			if _, err := tx.Exec(ctx, sqlUpdate, p.Orden, p.PuntoID); err != nil {
				return err
			}
		}
	}

	// 3. Procesar nuevos puntos
	if len(nuevos) > 0 {
		sqlIns := `INSERT INTO punto_recoleccion (ruta_id, direccion, orden, created_at) VALUES ($1, $2, $3, $4) RETURNING id`
		for i := range nuevos {
			nuevos[i].CreatedAt = time.Now()
			var newID int32
			err := tx.QueryRow(ctx, sqlIns, rutaID, nuevos[i].CP, nuevos[i].Orden, nuevos[i].CreatedAt).Scan(&newID)
			if err != nil {
				return err
			}
			nuevos[i].PuntoID = newID
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return err
	}

	// 4. Guardar coordenadas de nuevos puntos en Redis (fuera de la transacción de DB)
	rdb, err := core.ConnectRedis()
	if err == nil {
		for _, p := range nuevos {
			rdb.HSet(ctx, fmt.Sprintf("point:%d", p.PuntoID), map[string]interface{}{
				"route_id": p.RutaID,
				"lat":      p.Lat,
				"lon":      p.Lon,
				"label":    p.CP,
			})
		}
	}

	// 5. Eliminar de Redis los puntos borrados
	if err == nil && len(eliminados) > 0 {
		for _, id := range eliminados {
			rdb.Del(ctx, fmt.Sprintf("point:%d", id))
		}
	}

	return nil
}
```

---

### Componente 3: Aplicación y Rutas del Backend

#### [NEW] `SyncPuntosRecoleccionUseCase.go` (gin-backend/src/Rutas/application/SyncPuntosRecoleccionUseCase.go)
```go
package application

import (
	"context"
	"github.com/vicpoo/API_recolecta/src/Rutas/domain/entities"
	"github.com/vicpoo/API_recolecta/src/Rutas/domain/ports"
)

type SyncPuntosRecoleccionUseCase struct {
	repo ports.IPuntoRecoleccion
}

func NewSyncPuntosRecoleccionUseCase(repo ports.IPuntoRecoleccion) *SyncPuntosRecoleccionUseCase {
	return &SyncPuntosRecoleccionUseCase{repo: repo}
}

func (uc *SyncPuntosRecoleccionUseCase) Execute(
	ctx context.Context,
	rutaID int32,
	nuevos []entities.PuntoRecoleccion,
	eliminados []int32,
	actualizados []entities.PuntoRecoleccion,
) error {
	return uc.repo.Sync(ctx, rutaID, nuevos, eliminados, actualizados)
}
```

#### [NEW] `syncPuntosRecoleccion_controller.go` (gin-backend/src/Rutas/infraestructure/controllers/syncPuntosRecoleccion_controller.go)
```go
package controllers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/vicpoo/API_recolecta/src/Rutas/application"
	"github.com/vicpoo/API_recolecta/src/Rutas/domain/entities"
	"github.com/vicpoo/API_recolecta/src/core"
)

type SyncPuntosRecoleccionController struct {
	uc *application.SyncPuntosRecoleccionUseCase
}

func NewSyncPuntosRecoleccionController(uc *application.SyncPuntosRecoleccionUseCase) *SyncPuntosRecoleccionController {
	return &SyncPuntosRecoleccionController{uc: uc}
}

type SyncRequest struct {
	RutaID           int32                 `json:"ruta_id" binding:"required"`
	PuntosNuevos     []PuntoNuevoInput     `json:"puntos_nuevos"`
	PuntosEliminados []int32               `json:"puntos_eliminados"`
	PuntosActualizados []PuntoActualizadoInput `json:"puntos_actualizados"`
}

type PuntoNuevoInput struct {
	Direccion string  `json:"direccion" binding:"required"`
	Lat       float64 `json:"lat" binding:"required"`
	Lon       float64 `json:"lon" binding:"required"`
	Orden     float64 `json:"orden"`
}

type PuntoActualizadoInput struct {
	PuntoID int32   `json:"punto_id" binding:"required"`
	Orden   float64 `json:"orden"`
}

func (ctrl *SyncPuntosRecoleccionController) Run(ctx *gin.Context) {
	var req SyncRequest
	if err := ctx.ShouldBindJSON(&req); err != nil {
		core.RespondBadRequest(ctx, "JSON inválido", map[string]string{"detail": err.Error()})
		return
	}

	var nuevos []entities.PuntoRecoleccion
	for _, n := range req.PuntosNuevos {
		nuevos = append(nuevos, entities.PuntoRecoleccion{
			RutaID: req.RutaID,
			CP:     n.Direccion,
			Lat:    n.Lat,
			Lon:    n.Lon,
			Orden:  n.Orden,
		})
	}

	var actualizados []entities.PuntoRecoleccion
	for _, u := range req.PuntosActualizados {
		actualizados = append(actualizados, entities.PuntoRecoleccion{
			PuntoID: u.PuntoID,
			Orden:   u.Orden,
		})
	}

	err := ctrl.uc.Execute(ctx.Request.Context(), req.RutaID, nuevos, req.PuntosEliminados, actualizados)
	if err != nil {
		core.RespondInternalServerError(ctx, "Error sincronizando puntos de recolección", err)
		return
	}

	ctx.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Puntos de recolección sincronizados correctamente",
	})
}
```

---

## 📈 Plan de Verificación

### Pruebas de Red y Base de Datos (Manual)
1. **Llamar al Sync Endpoint**: Enviar un JSON de prueba con un punto nuevo, una eliminación y una actualización:
   ```json
   {
     "ruta_id": 1,
     "puntos_nuevos": [
       { "direccion": "Calle Falsa 123", "lat": 19.43, "lon": -99.13, "orden": 15.0 }
     ],
     "puntos_eliminados": [14],
     "puntos_actualizados": [
       { "punto_id": 15, "orden": 10.0 },
       { "punto_id": 18, "orden": 20.0 }
     ]
   }
   ```
2. **Validar SQL**: Verificar en la base de datos que el punto `14` tenga `deleted_at IS NOT NULL`, que los puntos `15` y `18` tengan los nuevos valores de `orden`, y que se haya creado un registro nuevo con `orden = 15.0`.
3. **Validar Lectura**: Consultar `GET /api/puntos-recoleccion/ruta/1` y verificar que los elementos se devuelvan ordenados estrictamente por el campo `orden`.
