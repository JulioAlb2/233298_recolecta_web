-- =============================================================================
-- SEED DE CONFIGURACIÓN ESTÁTICA - Roles del Sistema
-- =============================================================================
BEGIN;

-- 1. ROLES DEL SISTEMA
-- Schema: id, nombre, active
INSERT INTO rol (id, nombre, active) VALUES
  (1, 'Administrador', TRUE),
  (2, 'Coordinador', TRUE),
  (3, 'Operador', TRUE),
  (4, 'Conductor', TRUE),
  (5, 'Ciudadano', TRUE)
ON CONFLICT (id) DO NOTHING;

COMMIT;
