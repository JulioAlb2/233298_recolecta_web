-- =============================================================================
-- SEED NIVEL PYME - Sistema de Recolección de Basura
-- =============================================================================
-- Datos coherentes para una empresa mediana con:
-- - 4 roles organizacionales
-- - 12 usuarios (admin, coordinadores, operadores, conductores)
-- - 8 colonias en 3 zonas
-- - 6 camiones (3 propios, 3 rentados)
-- - 5 rutas operativas con puntos de recolección
-- - Tipos de mantenimiento preventivo y correctivo
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. ROLES DEL SISTEMA
-- -----------------------------------------------------------------------------
-- Schema: id, nombre, active
INSERT INTO rol (id, nombre, active) VALUES
  (1, 'Administrador', TRUE),
  (2, 'Coordinador', TRUE),
  (3, 'Operador', TRUE),
  (4, 'Conductor', TRUE),
  (5, 'Ciudadano', TRUE)
ON CONFLICT (id) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 2. COLONIAS (8 colonias en 3 zonas: Norte, Centro, Sur)
-- -----------------------------------------------------------------------------
-- Schema: id, nombre, zona, created_at
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

-- -----------------------------------------------------------------------------
-- 3. EMPLEADOS (Roles 1-4)
-- -----------------------------------------------------------------------------
-- Schema: id, nombre, apellidos, mail, password, username, desactivado, rol_id
-- Nota: Se separan nombres y apellidos del seed original
INSERT INTO empleado (id, nombre, apellidos, mail, password, username, rol_id, desactivado, created_at, updated_at)
VALUES
  -- Administrador
  (1, 'Roberto', 'García Méndez', 'roberto.garcia@recolecta.mx', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe', 'rgarcia', 1, FALSE, '2024-01-10 09:00:00', '2024-01-10 09:00:00'),
  
  -- Coordinadores (gestionan rutas y mantenimiento)
  (2, 'María Elena', 'Torres', 'maria.torres@recolecta.mx', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe', 'mtorres', 2, FALSE, '2024-01-12 10:00:00', '2024-01-12 10:00:00'),
  (3, 'Carlos', 'Ramírez López', 'carlos.ramirez@recolecta.mx', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe', 'cramirez', 2, FALSE, '2024-01-12 10:30:00', '2024-01-12 10:30:00'),
  
  -- Operadores (monitoreo y validación)
  (4, 'Ana Patricia', 'Morales', 'ana.morales@recolecta.mx', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe', 'amorales', 3, FALSE, '2024-01-15 08:30:00', '2024-01-15 08:30:00'),
  (5, 'Jorge Luis', 'Sánchez', 'jorge.sanchez@recolecta.mx', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe', 'jsanchez', 3, FALSE, '2024-01-15 08:45:00', '2024-01-15 08:45:00'),
  (6, 'Patricia', 'Hernández Cruz', 'patricia.hernandez@recolecta.mx', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe', 'phernandez', 3, FALSE, '2024-01-15 09:00:00', '2024-01-15 09:00:00'),
  
  -- Conductores (6 operando camiones)
  (7, 'Juan Manuel', 'Flores', 'juan.flores@recolecta.mx', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe', 'jflores', 4, FALSE, '2024-02-01 07:00:00', '2024-02-01 07:00:00'),
  (8, 'Pedro', 'Ávila Gómez', 'pedro.avila@recolecta.mx', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe', 'pavila', 4, FALSE, '2024-02-01 07:15:00', '2024-02-01 07:15:00'),
  (9, 'Luis Alberto', 'Vargas', 'luis.vargas@recolecta.mx', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe', 'lvargas', 4, FALSE, '2024-02-01 07:30:00', '2024-02-01 07:30:00'),
  (10, 'Miguel Ángel', 'Medina', 'miguel.medina@recolecta.mx', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe', 'mmedina', 4, FALSE, '2024-02-05 07:00:00', '2024-02-05 07:00:00'),
  (11, 'José Antonio', 'Ruiz', 'jose.ruiz@recolecta.mx', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe', 'jruiz', 4, FALSE, '2024-02-05 07:15:00', '2024-02-05 07:15:00'),
  (12, 'Francisco Javier', 'Castro', 'francisco.castro@recolecta.mx', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe', 'fcastro', 4, FALSE, '2024-02-05 07:30:00', '2024-02-05 07:30:00')
ON CONFLICT (id) DO NOTHING;

  -- Usuarios comunes (Ciudadanos) x200 - IDs 100..299

  -- Ciudadanos (200 usuarios)
INSERT INTO ciudadano (id, email, alias, password) VALUES
  (100, 'user100@example.com', 'user100', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (101, 'user101@example.com', 'user101', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (102, 'user102@example.com', 'user102', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (103, 'user103@example.com', 'user103', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (104, 'user104@example.com', 'user104', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (105, 'user105@example.com', 'user105', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (106, 'user106@example.com', 'user106', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (107, 'user107@example.com', 'user107', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (108, 'user108@example.com', 'user108', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (109, 'user109@example.com', 'user109', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (110, 'user110@example.com', 'user110', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (111, 'user111@example.com', 'user111', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (112, 'user112@example.com', 'user112', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (113, 'user113@example.com', 'user113', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (114, 'user114@example.com', 'user114', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (115, 'user115@example.com', 'user115', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (116, 'user116@example.com', 'user116', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (117, 'user117@example.com', 'user117', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (118, 'user118@example.com', 'user118', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (119, 'user119@example.com', 'user119', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (120, 'user120@example.com', 'user120', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (121, 'user121@example.com', 'user121', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (122, 'user122@example.com', 'user122', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (123, 'user123@example.com', 'user123', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (124, 'user124@example.com', 'user124', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (125, 'user125@example.com', 'user125', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (126, 'user126@example.com', 'user126', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (127, 'user127@example.com', 'user127', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (128, 'user128@example.com', 'user128', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (129, 'user129@example.com', 'user129', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (130, 'user130@example.com', 'user130', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (131, 'user131@example.com', 'user131', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (132, 'user132@example.com', 'user132', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (133, 'user133@example.com', 'user133', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (134, 'user134@example.com', 'user134', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (135, 'user135@example.com', 'user135', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (136, 'user136@example.com', 'user136', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (137, 'user137@example.com', 'user137', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (138, 'user138@example.com', 'user138', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (139, 'user139@example.com', 'user139', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (140, 'user140@example.com', 'user140', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (141, 'user141@example.com', 'user141', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (142, 'user142@example.com', 'user142', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (143, 'user143@example.com', 'user143', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (144, 'user144@example.com', 'user144', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (145, 'user145@example.com', 'user145', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (146, 'user146@example.com', 'user146', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (147, 'user147@example.com', 'user147', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (148, 'user148@example.com', 'user148', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (149, 'user149@example.com', 'user149', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (150, 'user150@example.com', 'user150', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (151, 'user151@example.com', 'user151', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (152, 'user152@example.com', 'user152', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (153, 'user153@example.com', 'user153', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (154, 'user154@example.com', 'user154', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (155, 'user155@example.com', 'user155', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (156, 'user156@example.com', 'user156', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (157, 'user157@example.com', 'user157', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (158, 'user158@example.com', 'user158', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (159, 'user159@example.com', 'user159', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (160, 'user160@example.com', 'user160', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (161, 'user161@example.com', 'user161', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (162, 'user162@example.com', 'user162', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (163, 'user163@example.com', 'user163', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (164, 'user164@example.com', 'user164', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (165, 'user165@example.com', 'user165', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (166, 'user166@example.com', 'user166', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (167, 'user167@example.com', 'user167', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (168, 'user168@example.com', 'user168', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (169, 'user169@example.com', 'user169', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (170, 'user170@example.com', 'user170', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (171, 'user171@example.com', 'user171', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (172, 'user172@example.com', 'user172', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (173, 'user173@example.com', 'user173', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (174, 'user174@example.com', 'user174', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (175, 'user175@example.com', 'user175', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (176, 'user176@example.com', 'user176', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (177, 'user177@example.com', 'user177', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (178, 'user178@example.com', 'user178', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (179, 'user179@example.com', 'user179', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (180, 'user180@example.com', 'user180', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (181, 'user181@example.com', 'user181', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (182, 'user182@example.com', 'user182', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (183, 'user183@example.com', 'user183', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (184, 'user184@example.com', 'user184', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (185, 'user185@example.com', 'user185', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (186, 'user186@example.com', 'user186', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (187, 'user187@example.com', 'user187', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (188, 'user188@example.com', 'user188', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (189, 'user189@example.com', 'user189', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (190, 'user190@example.com', 'user190', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (191, 'user191@example.com', 'user191', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (192, 'user192@example.com', 'user192', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (193, 'user193@example.com', 'user193', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (194, 'user194@example.com', 'user194', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (195, 'user195@example.com', 'user195', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (196, 'user196@example.com', 'user196', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (197, 'user197@example.com', 'user197', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (198, 'user198@example.com', 'user198', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (199, 'user199@example.com', 'user199', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (200, 'user200@example.com', 'user200', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (201, 'user201@example.com', 'user201', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (202, 'user202@example.com', 'user202', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (203, 'user203@example.com', 'user203', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (204, 'user204@example.com', 'user204', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (205, 'user205@example.com', 'user205', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (206, 'user206@example.com', 'user206', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (207, 'user207@example.com', 'user207', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (208, 'user208@example.com', 'user208', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (209, 'user209@example.com', 'user209', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (210, 'user210@example.com', 'user210', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (211, 'user211@example.com', 'user211', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (212, 'user212@example.com', 'user212', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (213, 'user213@example.com', 'user213', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (214, 'user214@example.com', 'user214', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (215, 'user215@example.com', 'user215', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (216, 'user216@example.com', 'user216', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (217, 'user217@example.com', 'user217', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (218, 'user218@example.com', 'user218', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (219, 'user219@example.com', 'user219', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (220, 'user220@example.com', 'user220', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (221, 'user221@example.com', 'user221', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (222, 'user222@example.com', 'user222', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (223, 'user223@example.com', 'user223', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (224, 'user224@example.com', 'user224', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (225, 'user225@example.com', 'user225', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (226, 'user226@example.com', 'user226', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (227, 'user227@example.com', 'user227', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (228, 'user228@example.com', 'user228', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (229, 'user229@example.com', 'user229', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (230, 'user230@example.com', 'user230', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (231, 'user231@example.com', 'user231', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (232, 'user232@example.com', 'user232', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (233, 'user233@example.com', 'user233', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (234, 'user234@example.com', 'user234', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (235, 'user235@example.com', 'user235', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (236, 'user236@example.com', 'user236', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (237, 'user237@example.com', 'user237', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (238, 'user238@example.com', 'user238', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (239, 'user239@example.com', 'user239', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (240, 'user240@example.com', 'user240', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (241, 'user241@example.com', 'user241', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (242, 'user242@example.com', 'user242', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (243, 'user243@example.com', 'user243', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (244, 'user244@example.com', 'user244', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (245, 'user245@example.com', 'user245', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (246, 'user246@example.com', 'user246', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (247, 'user247@example.com', 'user247', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (248, 'user248@example.com', 'user248', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (249, 'user249@example.com', 'user249', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (250, 'user250@example.com', 'user250', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (251, 'user251@example.com', 'user251', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (252, 'user252@example.com', 'user252', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (253, 'user253@example.com', 'user253', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (254, 'user254@example.com', 'user254', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (255, 'user255@example.com', 'user255', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (256, 'user256@example.com', 'user256', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (257, 'user257@example.com', 'user257', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (258, 'user258@example.com', 'user258', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (259, 'user259@example.com', 'user259', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (260, 'user260@example.com', 'user260', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (261, 'user261@example.com', 'user261', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (262, 'user262@example.com', 'user262', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (263, 'user263@example.com', 'user263', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (264, 'user264@example.com', 'user264', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (265, 'user265@example.com', 'user265', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (266, 'user266@example.com', 'user266', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (267, 'user267@example.com', 'user267', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (268, 'user268@example.com', 'user268', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (269, 'user269@example.com', 'user269', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (270, 'user270@example.com', 'user270', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (271, 'user271@example.com', 'user271', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (272, 'user272@example.com', 'user272', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (273, 'user273@example.com', 'user273', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (274, 'user274@example.com', 'user274', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (275, 'user275@example.com', 'user275', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (276, 'user276@example.com', 'user276', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (277, 'user277@example.com', 'user277', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (278, 'user278@example.com', 'user278', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (279, 'user279@example.com', 'user279', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (280, 'user280@example.com', 'user280', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (281, 'user281@example.com', 'user281', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (282, 'user282@example.com', 'user282', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (283, 'user283@example.com', 'user283', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (284, 'user284@example.com', 'user284', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (285, 'user285@example.com', 'user285', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (286, 'user286@example.com', 'user286', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (287, 'user287@example.com', 'user287', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (288, 'user288@example.com', 'user288', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (289, 'user289@example.com', 'user289', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (290, 'user290@example.com', 'user290', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (291, 'user291@example.com', 'user291', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (292, 'user292@example.com', 'user292', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (293, 'user293@example.com', 'user293', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (294, 'user294@example.com', 'user294', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (295, 'user295@example.com', 'user295', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (296, 'user296@example.com', 'user296', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (297, 'user297@example.com', 'user297', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (298, 'user298@example.com', 'user298', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe'),
  (299, 'user299@example.com', 'user299', '$2a$10$EixZaYVK1fsbw1ZfbX3OXe')
ON CONFLICT (id) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 3.b DOMICILIOS PARA CIUDADANOS (una dirección por usuario 100..299)
-- Direcciones formateadas para que servicios de geocodificación las resuelvan fácilmente
-- -----------------------------------------------------------------------------
-- Schema: id, ciudadano_id, alias, calle, numero, colonia_id, deleted_at, created_at
INSERT INTO domicilio (id, ciudadano_id, alias, calle, numero, colonia_id, deleted_at, created_at)
SELECT
  (100 + g) AS id,
  (100 + g) AS ciudadano_id,
  'Domicilio Principal' AS alias,
  (ARRAY['Calle Olmo','Calle Lirio','Calle Roble','Avenida Reforma','Calle Cedro','Calle Laurel','Calle Magnolia','Calle Nogal','Calle Pino','Calle Sauce'])[ (g % 10) + 1 ] AS calle,
  ((100 + g) % 200 + 10)::text AS numero,
  ((g % 8) + 1) AS colonia_id,
  NULL AS deleted_at,
  now() AS created_at
FROM generate_series(0,199) g
ON CONFLICT (id) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 4. TIPOS DE CAMIÓN
-- -----------------------------------------------------------------------------
-- Schema: id, nombre, descripcion
INSERT INTO tipo_camion (id, nombre, descripcion) VALUES
  (1, 'Compactador 12m³', 'Camión compactador estándar capacidad 12 metros cúbicos'),
  (2, 'Compactador 15m³', 'Camión compactador gran capacidad 15 metros cúbicos'),
  (3, 'Camión de Volteo', 'Camión de volteo para escombros y residuos voluminosos')
ON CONFLICT (id) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 5. CAMIONES (6 unidades: 3 propios, 3 rentados)
-- -----------------------------------------------------------------------------
-- Schema: id, placa, modelo, rentado, estado, tipo_id, created_at, updated_at
INSERT INTO camion (id, placa, modelo, tipo_id, rentado, estado, created_at, updated_at)
VALUES
  -- Propios
  (1, 'ABC-123-MX', 'Freightliner M2 106 2022', 1, FALSE, 'Disponible', '2024-01-20 08:00:00', '2024-01-20 08:00:00'),
  (2, 'DEF-456-MX', 'International DuraStar 2021', 2, FALSE, 'Disponible', '2024-01-20 08:15:00', '2024-01-20 08:15:00'),
  (3, 'GHI-789-MX', 'Kenworth T370 2023', 1, FALSE, 'Disponible', '2024-01-20 08:30:00', '2024-01-20 08:30:00'),
  
  -- Rentados
  (4, 'JKL-012-MX', 'Volvo VHD 2020', 2, TRUE, 'Disponible', '2024-02-01 09:00:00', '2024-02-01 09:00:00'),
  (5, 'MNO-345-MX', 'Peterbilt 337 2021', 1, TRUE, 'Disponible', '2024-02-01 09:15:00', '2024-02-01 09:15:00'),
  (6, 'PQR-678-MX', 'Mack LR 2019', 3, TRUE, 'Disponible', '2024-02-01 09:30:00', '2024-02-01 09:30:00')
ON CONFLICT (id) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 6. HISTORIAL DE ASIGNACIÓN (conductores asignados a camiones)
-- -----------------------------------------------------------------------------
-- Schema: id, id_empleado, id_camion, fecha_asignacion, fecha_baja, created_at, updated_at
INSERT INTO historial_asignacion (id, id_empleado, id_camion, fecha_asignacion, fecha_baja, created_at, updated_at)
VALUES
  (1, 7, 1, '2024-02-10', NULL, '2024-02-10 06:00:00', '2024-02-10 06:00:00'),
  (2, 8, 2, '2024-02-10', NULL, '2024-02-10 06:00:00', '2024-02-10 06:00:00'),
  (3, 9, 3, '2024-02-10', NULL, '2024-02-10 06:00:00', '2024-02-10 06:00:00'),
  (4, 10, 4, '2024-02-15', NULL, '2024-02-15 06:00:00', '2024-02-15 06:00:00'),
  (5, 11, 5, '2024-02-15', NULL, '2024-02-15 06:00:00', '2024-02-15 06:00:00'),
  (6, 12, 6, '2024-02-15', NULL, '2024-02-15 06:00:00', '2024-02-15 06:00:00')
ON CONFLICT (id) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 7. RUTAS (5 rutas operativas con waypoints GPS en Suchiapas, Chiapas)
-- -----------------------------------------------------------------------------
-- Schema: id, nombre, descripcion, colonia_id, json_ruta, created_at
INSERT INTO ruta (id, nombre, descripcion, colonia_id, json_ruta, created_at) VALUES
  (1, 'Ruta Norte A', 'Cobertura Colonia Industrial y Las Palmas', 2,
   '{"zona":"Norte","turno":"matutino","puntos":[{"id":"PR-NA-001","orden":1,"lat":16.6420,"lng":-93.1180,"nombre":"Esq. Calle Industrial / Av. Las Palmas"},{"id":"PR-NA-002","orden":2,"lat":16.6395,"lng":-93.1210,"nombre":"Esq. Calle 3a Nte. / Calle Industrial"},{"id":"PR-NA-003","orden":3,"lat":16.6370,"lng":-93.1155,"nombre":"Esq. Calle 2a Nte. / Pte. Las Palmas"},{"id":"PR-NA-004","orden":4,"lat":16.6345,"lng":-93.1130,"nombre":"Esq. Calle 1a Nte. / Pte. Las Palmas"},{"id":"PR-NA-005","orden":5,"lat":16.6325,"lng":-93.1095,"nombre":"Esq. Av. Las Palmas / Central"}]}',
   '2024-02-01 08:00:00'),
  (2, 'Ruta Norte B', 'Cobertura Residencial San Miguel', 7,
   '{"zona":"Norte","turno":"vespertino","puntos":[{"id":"PR-NB-001","orden":1,"lat":16.6510,"lng":-93.1080,"nombre":"Esq. Residencial San Miguel / 4a Nte."},{"id":"PR-NB-002","orden":2,"lat":16.6480,"lng":-93.1055,"nombre":"Esq. 3a Nte. / Calle San Miguel"},{"id":"PR-NB-003","orden":3,"lat":16.6455,"lng":-93.1030,"nombre":"Esq. 2a Nte. / Calle San Miguel"},{"id":"PR-NB-004","orden":4,"lat":16.6430,"lng":-93.1010,"nombre":"Esq. 1a Nte. / Calle San Miguel"},{"id":"PR-NB-005","orden":5,"lat":16.6405,"lng":-93.0985,"nombre":"Esq. San Miguel / Oriente"}]}',
   '2024-02-01 08:15:00'),
  (3, 'Ruta Centro', 'Cobertura Centro Histórico y El Mirador', 1,
   '{"zona":"Centro","turno":"matutino","puntos":[{"id":"PR-CE-001","orden":1,"lat":16.6278,"lng":-93.1045,"nombre":"Esq. Calle 1a Nte. / Av. Central"},{"id":"PR-CE-002","orden":2,"lat":16.6261,"lng":-93.1038,"nombre":"Esq. Av. Central / Calle 1a Sur"},{"id":"PR-CE-003","orden":3,"lat":16.6241,"lng":-93.1025,"nombre":"Esq. Calle 1a Sur / 1a Ote."},{"id":"PR-CE-004","orden":4,"lat":16.6235,"lng":-93.0998,"nombre":"Esq. 1a Ote. / Calle 2a Sur"},{"id":"PR-CE-005","orden":5,"lat":16.6270,"lng":-93.1070,"nombre":"Esq. 1a Nte. / Av. 1a Pte."}]}',
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

-- -----------------------------------------------------------------------------
-- 8. PUNTOS DE RECOLECCIÓN (25 puntos distribuidos en 5 rutas)
-- -----------------------------------------------------------------------------
-- Schema: id, ruta_id, direccion
INSERT INTO punto_recoleccion (id, ruta_id, direccion) VALUES
  -- Ruta Norte A (5 puntos)
  (1, 1, 'PR-NA-001'),
  (2, 1, 'PR-NA-002'),
  (3, 1, 'PR-NA-003'),
  (4, 1, 'PR-NA-004'),
  (5, 1, 'PR-NA-005'),
  
  -- Ruta Norte B (5 puntos)
  (6, 2, 'PR-NB-001'),
  (7, 2, 'PR-NB-002'),
  (8, 2, 'PR-NB-003'),
  (9, 2, 'PR-NB-004'),
  (10, 2, 'PR-NB-005'),
  
  -- Ruta Centro (5 puntos)
  (11, 3, 'PR-CE-001'),
  (12, 3, 'PR-CE-002'),
  (13, 3, 'PR-CE-003'),
  (14, 3, 'PR-CE-004'),
  (15, 3, 'PR-CE-005'),
  
  -- Ruta Sur A (5 puntos)
  (16, 4, 'PR-SA-001'),
  (17, 4, 'PR-SA-002'),
  (18, 4, 'PR-SA-003'),
  (19, 4, 'PR-SA-004'),
  (20, 4, 'PR-SA-005'),
  
  -- Ruta Sur B (5 puntos)
  (21, 5, 'PR-SB-001'),
  (22, 5, 'PR-SB-002'),
  (23, 5, 'PR-SB-003'),
  (24, 5, 'PR-SB-004'),
  (25, 5, 'PR-SB-005')
ON CONFLICT (id) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 9. ASIGNACIÓN RUTA-CAMIÓN (asignaciones activas para hoy)
-- -----------------------------------------------------------------------------
-- Schema: id, ruta_id, camion_id, fecha_asignacion, created_at
INSERT INTO registro_asignacion_ruta (id, ruta_id, status, camion_id, fecha_asignacion, created_at) VALUES
  (1, 1, 1, 1, CURRENT_DATE, now()),
  (2, 2, 1, 5, CURRENT_DATE, now()),
  (3, 3, 1, 2, CURRENT_DATE, now()),
  (4, 4, 1, 3, CURRENT_DATE, now()),
  (5, 5, 1, 4, CURRENT_DATE, now())
ON CONFLICT (id) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 11. TIPOS DE MANTENIMIENTO (8 tipos comunes)
-- -----------------------------------------------------------------------------
-- Schema: id, nombre, categoria, desactivado
INSERT INTO tipo_mantenimiento (id, nombre, categoria, desactivado) VALUES
  (1, 'Cambio de Aceite', 'preventivo', FALSE),
  (2, 'Revisión de Frenos', 'preventivo', FALSE),
  (3, 'Alineación y Balanceo', 'preventivo', FALSE),
  (4, 'Cambio de Filtros', 'preventivo', FALSE),
  (5, 'Reparación Motor', 'correctivo', FALSE),
  (6, 'Reparación Transmisión', 'correctivo', FALSE),
  (7, 'Reparación Sistema Hidráulico', 'correctivo', FALSE),
  (8, 'Reemplazo Neumáticos', 'correctivo', FALSE)
ON CONFLICT (id) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 12. REGISTROS DE MANTENIMIENTO (Anteriormente Alertas)
-- -----------------------------------------------------------------------------
-- Schema: id, camion_id, tipo_mantenimiento, fecha_reporte, kilometraje, observaciones, created_at
INSERT INTO registro_mantenimiento (id, camion_id, tipo_mantenimiento, fecha_reporte, kilometraje, observaciones, created_at) VALUES
  (1, 2, 1, '2026-01-20', 15000, 'Unidad alcanzó kilometraje para servicio', '2026-01-20 10:00:00'),
  (2, 5, 2, '2026-01-22', 0, 'Conductor reportó ruido al frenar', '2026-01-22 14:30:00'),
  (3, 6, 4, '2026-01-25', 0, 'Mantenimiento trimestral', '2026-01-25 09:00:00')
ON CONFLICT (id) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 14. AVISOS GENERALES (1 aviso activo)
-- -----------------------------------------------------------------------------
-- Schema: id, enviado_por, tipo_aviso, descripcion, entidad_involucrada, estado, created_at
INSERT INTO aviso (id, enviado_por, tipo_aviso, descripcion, entidad_involucrada, estado, created_at) VALUES
  (1, 1, 'Mantenimiento Programado', 'Se realizará mantenimiento al sistema el próximo domingo de 00:00 a 06:00 hrs.', 'General', 1, '2026-01-25 08:00:00')
ON CONFLICT (id) DO NOTHING;

COMMIT;

-- =============================================================================
-- FIN DEL SEED
-- =============================================================================
-- Resumen de datos insertados:
-- - 5 roles
-- - 8 colonias (3 zonas)
-- - 12 empleados (staff)
-- - 200 ciudadanos
-- - 3 tipos de camión
-- - 6 camiones (3 propios, 3 rentados)
-- - 6 asignaciones conductor-camión activas
-- - 5 rutas operativas
-- - 25 puntos de recolección
-- - 5 asignaciones ruta-camión activas para hoy
-- - 8 tipos de mantenimiento
-- - 3 registros de mantenimiento
-- - 1 aviso general activo
-- =============================================================================
