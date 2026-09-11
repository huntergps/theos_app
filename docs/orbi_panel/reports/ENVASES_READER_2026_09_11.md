# E02 — lector de dashboard Envases

Fecha: 2026-09-11. Revisión: integrador Codex.

## Implementado

- Binding de sólo lectura de `l10n_ec.envases.panel`, según la entrega local
  revisada en `ENVASES_BACKEND_HANDOFF_REVIEW.md`.
- Adaptador al `OdooClient` existente mediante `search_read`; no endpoint nuevo.
- Dominio y contexto limitados a la empresa seleccionada; rechazo de filas ajenas.
- DTO estricto para producto, unidad, empresa y cantidades; datos inválidos no
  se convierten silenciosamente en cero. No suma productos/unidades diferentes.
- Paginación ordenada y acotada, detección de producto/empresa repetido.
  La paginación por offset NO garantiza una instantánea frente a cambios concurrentes.

## Evidencia ejecutada por el integrador

En `orbi_runtime`:

- `flutter test --no-pub --concurrency=1 test/envases/envases_dashboard_reader_test.dart`
  — 6 pruebas aprobadas con transporte inyectado y datos ficticios.
- `flutter analyze --no-pub lib/src/envases/envases_dashboard_reader.dart test/envases/envases_dashboard_reader_test.dart`
  — sin incidencias.

Prueba adicional de borradores en `theos_panel`:

- `flutter test --no-pub --concurrency=1 test/app/durable_draft_provider_test.dart`
  — 4 pruebas aprobadas: composición durable, recuperación al recrear proveedor,
  aislamiento de empresa y falta/incompatibilidad de contexto. SQLite local real.

## Límites y siguiente integración

Esto NO certifica instalación del addon, permisos en un servidor real ni E2E.
No se consultó ni modificó ERP2. Falta conectar el lector a caché observable,
composición y pantalla aprobada, con disponibilidad/capacidades del módulo.
No implementa movimientos, replay offline, facturación ni conteos de envases.
La idempotencia de escrituras y sus contratos deben verificarse antes de activarlos.
