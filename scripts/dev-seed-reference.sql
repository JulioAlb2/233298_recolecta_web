-- Datos de referencia para desarrollo (DB_SEED_MODE=backend).
-- Omite empleados/ciudadanos: esos se crean por API (dev-seed-api).

BEGIN;

INSERT INTO rol (id, nombre, active) VALUES
  (1, 'Administrador', TRUE),
  (2, 'Coordinador', TRUE),
  (3, 'Operador', TRUE),
  (4, 'Conductor', TRUE),
  (5, 'Ciudadano', TRUE)
ON CONFLICT (id) DO NOTHING;

INSERT INTO colonia (id, nombre, zona, created_at) VALUES
  (1, 'Centro Histórico', 'Centro', '2024-01-15 08:00:00'),
  (2, 'Colonia Industrial', 'Norte', '2024-01-15 08:00:00'),
  (3, 'Las Palmas', 'Norte', '2024-01-15 08:00:00'),
  (4, 'Vista Hermosa', 'Sur', '2024-01-15 08:00:00'),
  (5, 'Jardines del Valle', 'Sur', '2024-01-15 08:00:00'),
  (6, 'El Mirador', 'Centro', '2024-01-15 08:00:00'),
  (7, 'Residencial San Miguel', 'Norte', '2024-01-15 08:00:00'),
  (8, 'Fraccionamiento Los Pinos', 'Sur', '2024-01-15 08:00:00')
ON CONFLICT (id) DO NOTHING;

INSERT INTO tipo_camion (tipo_camion_id, nombre, descripcion, created_at) VALUES
  (1, 'Compactador 12m³', 'Camión compactador estándar capacidad 12 metros cúbicos', '2024-01-01 00:00:00'),
  (2, 'Compactador 15m³', 'Camión compactador gran capacidad 15 metros cúbicos', '2024-01-01 00:00:00'),
  (3, 'Camión de Volteo', 'Camión de volteo para escombros y residuos voluminosos', '2024-01-01 00:00:00')
ON CONFLICT (tipo_camion_id) DO NOTHING;

INSERT INTO camion (
  camion_id, placa, modelo, tipo_camion_id, es_rentado,
  disponibilidad_id, nombre_disponibilidad, color_disponibilidad,
  eliminado, created_at, updated_at
)
VALUES
  (1, 'ABC-123-MX', 'Freightliner M2 106 2022', 1, FALSE, 1, 'DISPONIBLE', '#22c55e', FALSE, '2024-01-20 08:00:00', '2024-01-20 08:00:00'),
  (2, 'DEF-456-MX', 'International DuraStar 2021', 2, FALSE, 1, 'DISPONIBLE', '#22c55e', FALSE, '2024-01-20 08:15:00', '2024-01-20 08:15:00'),
  (3, 'GHI-789-MX', 'Kenworth T370 2023', 1, FALSE, 1, 'DISPONIBLE', '#22c55e', FALSE, '2024-01-20 08:30:00', '2024-01-20 08:30:00'),
  (4, 'JKL-012-MX', 'Volvo VHD 2020', 2, TRUE, 1, 'DISPONIBLE', '#22c55e', FALSE, '2024-02-01 09:00:00', '2024-02-01 09:00:00'),
  (5, 'MNO-345-MX', 'Peterbilt 337 2021', 1, TRUE, 1, 'DISPONIBLE', '#22c55e', FALSE, '2024-02-01 09:15:00', '2024-02-01 09:15:00'),
  (6, 'PQR-678-MX', 'Mack LR 2019', 3, TRUE, 1, 'DISPONIBLE', '#22c55e', FALSE, '2024-02-01 09:30:00', '2024-02-01 09:30:00')
ON CONFLICT (camion_id) DO NOTHING;

INSERT INTO ruta (id, nombre, descripcion, colonia_id, json_ruta, created_at) VALUES
  (1, 'Ruta Norte A', 'Cobertura Colonia Industrial y Las Palmas', 2,
   '{"zona":"Norte","turno":"matutino","puntos":[{"id":"PR-NA-001","orden":1,"lat":16.6420,"lng":-93.1180,"nombre":"Esq. Calle Industrial / Av. Las Palmas"},{"id":"PR-NA-002","orden":2,"lat":16.6395,"lng":-93.1210,"nombre":"Esq. Calle 3a Nte. / Calle Industrial"},{"id":"PR-NA-003","orden":3,"lat":16.6370,"lng":-93.1155,"nombre":"Esq. Calle 2a Nte. / Pte. Las Palmas"},{"id":"PR-NA-004","orden":4,"lat":16.6345,"lng":-93.1130,"nombre":"Esq. Calle 1a Nte. / Pte. Las Palmas"},{"id":"PR-NA-005","orden":5,"lat":16.6325,"lng":-93.1095,"nombre":"Esq. Av. Las Palmas / Central"}]}',
   '2024-02-01 08:00:00'),
  (2, 'Ruta Norte B', 'Cobertura Residencial San Miguel', 7,
   '{"zona":"Norte","turno":"vespertino","puntos":[{"id":"PR-NB-001","orden":1,"lat":16.6510,"lng":-93.1080,"nombre":"Esq. Residencial San Miguel / 4a Nte."},{"id":"PR-NB-002","orden":2,"lat":16.6480,"lng":-93.1055,"nombre":"Esq. 3a Nte. / Calle San Miguel"},{"id":"PR-NB-003","orden":3,"lat":16.6455,"lng":-93.1030,"nombre":"Esq. 2a Nte. / Calle San Miguel"},{"id":"PR-NB-004","orden":4,"lat":16.6430,"lng":-93.1010,"nombre":"Esq. 1a Nte. / Calle San Miguel"},{"id":"PR-NB-005","orden":5,"lat":16.6405,"lng":-93.0985,"nombre":"Esq. San Miguel / Oriente"}]}',
   '2024-02-01 08:15:00'),
  (3, 'Ruta Centro', 'Centro histórico, mercado, Parque Santa Ana y salida UP Chiapas', 1,
   '{"zona":"Centro","turno":"matutino","puntos":[{"id":"WP-CE-001","orden":1,"lat":16.628922,"lng":-93.100664,"nombre":"Inicio — Calle Central Norte (zona Laredo Texas)"},{"id":"WP-CE-002","orden":2,"lat":16.627726,"lng":-93.101096,"nombre":"Calle Central Norte"},{"id":"PR-CE-003","orden":3,"lat":16.625228,"lng":-93.101940,"nombre":"Panificadora La Hojaldra — 2da Av. Nte. Pte. 140, Mercado"},{"id":"WP-CE-004","orden":4,"lat":16.623187,"lng":-93.102687,"nombre":"Calle Central Sur"},{"id":"WP-CE-005","orden":5,"lat":16.622878,"lng":-93.101299,"nombre":"Av. Central Oriente"},{"id":"WP-CE-006","orden":6,"lat":16.621451,"lng":-93.102664,"nombre":"Calle 2a Sur Oriente"},{"id":"WP-CE-007","orden":7,"lat":16.620668,"lng":-93.100036,"nombre":"Calle 2a Sur Oriente"},{"id":"WP-CE-008","orden":8,"lat":16.620039,"lng":-93.100080,"nombre":"Calle 4a Oriente Sur"},{"id":"WP-CE-009","orden":9,"lat":16.622976,"lng":-93.101747,"nombre":"Real Alitas Suchiapa — Av. Central Oriente 236"},{"id":"PR-CE-010","orden":10,"lat":16.623653,"lng":-93.102547,"nombre":"Parque Santa Ana — panificadora, punto recolección"},{"id":"WP-CE-011","orden":11,"lat":16.617881,"lng":-93.097090,"nombre":"Acceso CHIS-133 (Tuxtla–Portillo Zaragoza)"},{"id":"WP-CE-012","orden":12,"lat":16.614764,"lng":-93.090879,"nombre":"Fin — Universidad Politécnica de Chiapas (Km 21+500)"}]}',
   '2024-02-01 08:30:00'),
  (4, 'Ruta Sur A', 'Cobertura Vista Hermosa y Jardines del Valle', 4,
   '{"zona":"Sur","turno":"matutino","puntos":[{"id":"PR-SA-001","orden":1,"lat":16.6185,"lng":-93.0950,"nombre":"Esq. Vista Hermosa / Av. Sur"},{"id":"PR-SA-002","orden":2,"lat":16.6162,"lng":-93.0925,"nombre":"Esq. Jardines del Valle / 1a Sur"},{"id":"PR-SA-003","orden":3,"lat":16.6140,"lng":-93.0910,"nombre":"Esq. 2a Sur / Calle Valle"},{"id":"PR-SA-004","orden":4,"lat":16.6120,"lng":-93.0935,"nombre":"Esq. Calle Valle / 3a Sur"},{"id":"PR-SA-005","orden":5,"lat":16.6145,"lng":-93.0960,"nombre":"Esq. 3a Sur / Av. Vista"}]}',
   '2024-02-01 08:45:00'),
  (5, 'Ruta Sur B', 'Cobertura Fraccionamiento Los Pinos', 8,
   '{"zona":"Sur","turno":"vespertino","puntos":[{"id":"PR-SB-001","orden":1,"lat":16.6115,"lng":-93.1050,"nombre":"Esq. Los Pinos / Calle Sur"},{"id":"PR-SB-002","orden":2,"lat":16.6090,"lng":-93.1080,"nombre":"Esq. Fracc. Los Pinos / 2a Nte."},{"id":"PR-SB-003","orden":3,"lat":16.6068,"lng":-93.1110,"nombre":"Esq. 2a Nte. / Calle Pinos"},{"id":"PR-SB-004","orden":4,"lat":16.6085,"lng":-93.1140,"nombre":"Esq. Calle Pinos / Calle Sur"},{"id":"PR-SB-005","orden":5,"lat":16.6110,"lng":-93.1120,"nombre":"Esq. Calle Sur / Av. Los Pinos"}]}',
   '2024-02-01 09:00:00')
ON CONFLICT (id) DO UPDATE SET
  json_ruta   = EXCLUDED.json_ruta,
  nombre      = EXCLUDED.nombre,
  descripcion = EXCLUDED.descripcion,
  colonia_id  = EXCLUDED.colonia_id;

INSERT INTO punto_recoleccion (id, ruta_id, direccion) VALUES
  (1, 1, 'PR-NA-001'), (2, 1, 'PR-NA-002'), (3, 1, 'PR-NA-003'), (4, 1, 'PR-NA-004'), (5, 1, 'PR-NA-005'),
  (6, 2, 'PR-NB-001'), (7, 2, 'PR-NB-002'), (8, 2, 'PR-NB-003'), (9, 2, 'PR-NB-004'), (10, 2, 'PR-NB-005'),
  (11, 3, 'PR-CE-003'), (12, 3, 'PR-CE-010'),
  (16, 4, 'PR-SA-001'), (17, 4, 'PR-SA-002'), (18, 4, 'PR-SA-003'), (19, 4, 'PR-SA-004'), (20, 4, 'PR-SA-005'),
  (21, 5, 'PR-SB-001'), (22, 5, 'PR-SB-002'), (23, 5, 'PR-SB-003'), (24, 5, 'PR-SB-004'), (25, 5, 'PR-SB-005')
ON CONFLICT (id) DO NOTHING;

INSERT INTO registro_asignacion_ruta (id, ruta_id, status, camion_id, fecha_asignacion, created_at) VALUES
  (1, 1, 1, 1, CURRENT_DATE, now()),
  (2, 2, 1, 5, CURRENT_DATE, now()),
  (3, 3, 1, 2, CURRENT_DATE, now()),
  (4, 4, 1, 3, CURRENT_DATE, now()),
  (5, 5, 1, 4, CURRENT_DATE, now())
ON CONFLICT (id) DO NOTHING;

COMMIT;
