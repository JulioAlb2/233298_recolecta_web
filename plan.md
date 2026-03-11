## Plan: Nivelacion Seeds PostgreSQL Redis

Alinear solamente seeds y scripts (sin cambios de esquema), manteniendo Redis como fuente principal para geolocalizacion/FCM, y garantizando que los IDs y claves usadas por notificaciones sean consistentes, verificables e idempotentes con los datos base de PostgreSQL.

**Steps**
1. Fase 1 - Inventario y contrato de datos (bloqueante)
2. Documentar una matriz canonica de correlacion de entidades compartidas entre PostgreSQL y Redis: ciudadano 100..299, colonia 1..8, ruta 1..5, punto 1..25, camion 1..6.
3. Definir contrato de campos por entidad Redis para que coincida con docs y uso backend: formato de keys, nombres de fields, TTL y semantica de deduplicacion de notificaciones.
4. Formalizar el owner por dato para este alcance: PostgreSQL para identidad/transaccional; Redis para GEO + FCM + estado temporal + notificaciones.
5. Fase 2 - Correcciones del generador Redis (depende de Fase 1)
6. Ajustar docker/redis/init-scripts/generate-seed-data.sh para eliminar desalineaciones de keyspace con la documentacion vigente: truck state key, notification sent key, members del SET, nombres de fields de user/point/route.
7. Ajustar valores semanticos para mantener correlacion con seed.sql: nombres de rutas y usuarios alineados al seed SQL o map de equivalencias explicito.
8. Estandarizar metadata de seed Redis y checksum para que init-if-empty valide version de contrato (ademas de conteos).
9. Fase 3 - Validacion cruzada automatizada (depende de Fase 2)
10. Extender docker/redis/init-scripts/verify-redis.sh para comprobar no solo conteos (200/25/5), sino tambien contrato de keys/fields criticos y deduplicacion de notificaciones.
11. Agregar script de reconciliacion no destructivo en scripts/tests/redis o scripts/tests para validar coherencia PG vs Redis por IDs y cardinalidades esperadas.
12. Definir salida de validacion en formato legible para CI local: OK/ERROR por cada entidad correlacionada.
13. Fase 4 - Integracion operacional (parcialmente en paralelo con Fase 3)
14. Revisar y ajustar docker/redis/init-scripts/load-redis.sh para reducir riesgo de ejecucion con eval y registrar errores por linea/coleccion de forma auditable.
15. Confirmar secuencia de inicializacion en docker/redis/init-scripts/init-if-empty.sh para regenerar seed solo cuando checksum/metadata o contrato no cumplen.
16. Actualizar documentacion operativa en docs/03-redis-operations.md y docs/04-redis-schema.md con el contrato final y pasos de verificacion.
17. Fase 5 - Cierre y smoke tests (depende de Fase 3 y 4)
18. Ejecutar inicializacion limpia con Docker y verificar que PostgreSQL y Redis convergen en las mismas entidades compartidas (IDs y cantidades).
19. Ejecutar pruebas de flujo de notificaciones (WARN/ARRIVAL/DEPARTURE/COMEBACK) validando deduplicacion por usuario-camion-dia y expiracion temporal.
20. Registrar un reporte final de nivelacion con desalineaciones resueltas y pendientes deliberadamente fuera de alcance.

**Relevant files**
- c:/Users/RodrigoMijangos/Documents/GithubProjects/recolecta_web/docker/postgresql/seeds/seed.sql - fuente base transaccional e IDs canonicos compartidos
- c:/Users/RodrigoMijangos/Documents/GithubProjects/recolecta_web/docker/redis/init-scripts/generate-seed-data.sh - generador principal de keyspace Redis
- c:/Users/RodrigoMijangos/Documents/GithubProjects/recolecta_web/docker/redis/init-scripts/load-redis.sh - cargador del seed Redis
- c:/Users/RodrigoMijangos/Documents/GithubProjects/recolecta_web/docker/redis/init-scripts/init-if-empty.sh - control de inicializacion condicional y checksum
- c:/Users/RodrigoMijangos/Documents/GithubProjects/recolecta_web/docker/redis/init-scripts/verify-redis.sh - validaciones de integridad Redis
- c:/Users/RodrigoMijangos/Documents/GithubProjects/recolecta_web/docs/04-redis-schema.md - contrato funcional esperado del keyspace
- c:/Users/RodrigoMijangos/Documents/GithubProjects/recolecta_web/docs/05-data-lifecycle.md - flujo de negocio y semantica de notificaciones
- c:/Users/RodrigoMijangos/Documents/GithubProjects/recolecta_web/docs/03-redis-operations.md - procedimientos operativos para seed/carga/verificacion
- c:/Users/RodrigoMijangos/Documents/GithubProjects/recolecta_web/docker/postgresql/init-scripts/init-database.sh - orden de inicializacion PostgreSQL
- c:/Users/RodrigoMijangos/Documents/GithubProjects/recolecta_web/docker/postgresql/init-scripts/seed-if-empty.sh - ejecucion condicional del seed SQL

**Verification**
1. Levantar entorno limpio y correr inicializacion completa.
2. Verificar en PostgreSQL: counts esperados (roles, empleados, ciudadanos, domicilios, rutas, puntos, camiones).
3. Verificar en Redis: counts esperados (users:geo, route:points, points:ruta, truck state, notification keys).
4. Ejecutar script de reconciliacion PG vs Redis validando: rangos de IDs, cardinalidad por entidad, correspondencia ruta-punto y camion-ruta.
5. Simular envio de notificaciones para 1 usuario y 1 camion, validando deduplicacion por estado y expiracion TTL.
6. Confirmar que verify-redis reporta contrato valido y que init-if-empty no regenera seed innecesariamente.

**Decisions**
- Incluido: nivelacion de seeds/scripts y documentacion de contrato.
- Excluido: cambios de esquema en PostgreSQL, migraciones SQL y refactor de backend.
- Fuente de verdad definida para este ciclo: Redis en GEO/FCM/notificaciones temporales; PostgreSQL en identidad y datos de negocio base.

**Further Considerations**
1. Definir un archivo unico de contrato de datos (por ejemplo docs/redis-pg-contract.md) para evitar drift entre docs y scripts.
2. Decidir si los nombres descriptivos (rutas/usuarios) deben ser estrictamente iguales en ambos stores o si se acepta mapeo canonico.
3. Evaluar reemplazar eval en load-redis.sh por parseo seguro de comandos para reducir riesgo operativo.