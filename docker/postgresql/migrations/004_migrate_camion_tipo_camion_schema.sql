\c proyecto_recolecta;

-- =============================================================================
-- Migración 004: alinear tablas camion y tipo_camion con el backend Gin
-- Idempotente: solo aplica cambios si detecta el esquema legado (columna id).
-- =============================================================================

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'tipo_camion'
          AND column_name = 'id'
    ) THEN
        RAISE NOTICE 'Migrando tabla tipo_camion...';

        ALTER TABLE tipo_camion
            ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL;

        UPDATE tipo_camion
        SET created_at = CURRENT_TIMESTAMP
        WHERE created_at IS NULL;

        ALTER TABLE camion DROP CONSTRAINT IF EXISTS fk_tipo_camion;

        ALTER TABLE tipo_camion RENAME COLUMN id TO tipo_camion_id;

        CREATE SEQUENCE IF NOT EXISTS tipo_camion_tipo_camion_id_seq;
        PERFORM setval(
            'tipo_camion_tipo_camion_id_seq',
            COALESCE((SELECT MAX(tipo_camion_id) FROM tipo_camion), 1)
        );
        ALTER TABLE tipo_camion
            ALTER COLUMN tipo_camion_id SET DEFAULT nextval('tipo_camion_tipo_camion_id_seq');
        ALTER SEQUENCE tipo_camion_tipo_camion_id_seq OWNED BY tipo_camion.tipo_camion_id;

        RAISE NOTICE 'tipo_camion migrada correctamente.';
    ELSE
        RAISE NOTICE 'tipo_camion ya usa el esquema nuevo. Sin cambios.';
    END IF;
END $$;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'camion'
          AND column_name = 'id'
    ) THEN
        RAISE NOTICE 'Migrando tabla camion...';

        ALTER TABLE historial_asignacion DROP CONSTRAINT IF EXISTS fk_camion_historial;
        ALTER TABLE registro_mantenimiento DROP CONSTRAINT IF EXISTS fk_camion_afectado;
        ALTER TABLE registro_asignacion_ruta DROP CONSTRAINT IF EXISTS fk_camion_asignado_ruta;
        ALTER TABLE camion DROP CONSTRAINT IF EXISTS fk_tipo_camion;

        ALTER TABLE camion RENAME COLUMN id TO camion_id;
        ALTER TABLE camion RENAME COLUMN tipo_id TO tipo_camion_id;
        ALTER TABLE camion RENAME COLUMN rentado TO es_rentado;

        ALTER TABLE camion
            ADD COLUMN IF NOT EXISTS disponibilidad_id INTEGER NOT NULL DEFAULT 1,
            ADD COLUMN IF NOT EXISTS nombre_disponibilidad VARCHAR(50) NOT NULL DEFAULT 'DISPONIBLE',
            ADD COLUMN IF NOT EXISTS color_disponibilidad VARCHAR(20) NOT NULL DEFAULT '#22c55e',
            ADD COLUMN IF NOT EXISTS eliminado BOOLEAN NOT NULL DEFAULT FALSE;

        UPDATE camion
        SET eliminado = (deleted_at IS NOT NULL);

        UPDATE camion
        SET nombre_disponibilidad = CASE
            WHEN UPPER(TRIM(estado)) IN ('DISPONIBLE') THEN 'DISPONIBLE'
            WHEN UPPER(TRIM(estado)) IN ('EN_RUTA', 'EN RUTA') THEN 'EN_RUTA'
            WHEN UPPER(TRIM(estado)) IN ('MANTENIMIENTO') THEN 'MANTENIMIENTO'
            WHEN UPPER(TRIM(estado)) IN ('FUERA_SERVICIO', 'FUERA DE SERVICIO') THEN 'FUERA_SERVICIO'
            ELSE 'DISPONIBLE'
        END;

        UPDATE camion
        SET disponibilidad_id = CASE nombre_disponibilidad
            WHEN 'DISPONIBLE' THEN 1
            WHEN 'EN_RUTA' THEN 2
            WHEN 'MANTENIMIENTO' THEN 3
            WHEN 'FUERA_SERVICIO' THEN 4
            ELSE 1
        END;

        UPDATE camion
        SET color_disponibilidad = CASE nombre_disponibilidad
            WHEN 'DISPONIBLE' THEN '#22c55e'
            WHEN 'EN_RUTA' THEN '#f59e0b'
            WHEN 'MANTENIMIENTO' THEN '#ef4444'
            WHEN 'FUERA_SERVICIO' THEN '#6b7280'
            ELSE '#22c55e'
        END;

        ALTER TABLE camion DROP COLUMN IF EXISTS estado;
        ALTER TABLE camion DROP COLUMN IF EXISTS deleted_at;

        ALTER TABLE camion
            ADD CONSTRAINT fk_tipo_camion
            FOREIGN KEY (tipo_camion_id) REFERENCES tipo_camion(tipo_camion_id);

        ALTER TABLE historial_asignacion
            ADD CONSTRAINT fk_camion_historial
            FOREIGN KEY (id_camion) REFERENCES camion(camion_id);

        ALTER TABLE registro_mantenimiento
            ADD CONSTRAINT fk_camion_afectado
            FOREIGN KEY (camion_id) REFERENCES camion(camion_id);

        ALTER TABLE registro_asignacion_ruta
            ADD CONSTRAINT fk_camion_asignado_ruta
            FOREIGN KEY (camion_id) REFERENCES camion(camion_id);

        RAISE NOTICE 'camion migrada correctamente.';
    ELSE
        RAISE NOTICE 'camion ya usa el esquema nuevo. Sin cambios.';
    END IF;
END $$;

-- Tabla auxiliar usada por el endpoint /api/estado-camion/
CREATE TABLE IF NOT EXISTS estado_camion (
    estado_id SERIAL PRIMARY KEY,
    camion_id INTEGER NOT NULL,
    estado VARCHAR(50) NOT NULL,
    observaciones VARCHAR(255),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'fk_estado_camion_camion'
    ) THEN
        ALTER TABLE estado_camion
            ADD CONSTRAINT fk_estado_camion_camion
            FOREIGN KEY (camion_id) REFERENCES camion(camion_id);
    END IF;
END $$;

INSERT INTO schema_version (script_name, type, checksum, description)
VALUES (
    '004_migrate_camion_tipo_camion_schema.sql',
    'migration',
    '004_camion_tipo_camion_v1',
    'Alinea camion y tipo_camion con el backend Gin'
)
ON CONFLICT (script_name, checksum) DO NOTHING;
