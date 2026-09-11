# Organización interna y lecturas locales — R08, R09, E03

Fecha: 2026-09-11. Integración y revisión: Codex.

## Entregado

- R08: `theos_panel/lib/ui/components/fields/` y `records/` agrupan los
  componentes existentes. Se conservan exports de compatibilidad y se documenta
  ownership en `ui/README.md`. Ningún paquete/dependencia nuevo ni cambio visual.
- R09: `EditableDraftStore.list/watchList` con IDs estables, paginación keyset
  acotada, separación scope/empresa/lease y errores explícitos por JSON corrupto.
- E03: caché de consulta Envases en tabla aditiva propia del runtime, nunca
  inventario editable. Copia completa versionada, observable y recuperable tras
  reabrir; diferencia no descargado de descargado vacío. Fallos remotos conservan
  la copia previa. Comparación transaccional evita sobreescritura por otro refresh.
- `cachedAt` es fecha LOCAL de recuperación UTC, no fecha/hora del servidor.

## Evidencia ejecutada por el integrador

- Panel: `flutter test --no-pub --concurrency=1 test/ui` — 16 pasan.
- Panel: `flutter analyze --no-pub lib/ui` — sin incidencias.
- Runtime: `flutter test --no-pub --concurrency=1 test/sales/editable_draft_listing_test.dart`
  — 6 pasan (incluye corrupción, cancelación y cambio de scope).
- Runtime: pruebas existentes `editable_draft_store_test.dart` — 6 pasan.
- Runtime: `flutter test --no-pub --concurrency=1 test/envases/envases_dashboard_cache_test.dart`
  — 7 pasan, usando esquema del owner real y SQLite temporal.
- Runtime: pruebas `envases_dashboard_reader_test.dart` — 6 pasan.
- Analyze dirigido a cache, owner, drafts y sus dos tests — sin incidencias.

Drift avisa de múltiples AppDatabase en fixtures que abren dos conexiones o
cambian scope; no se silenció el aviso. No se usó ERP2 ni un simulador.

## Pendientes explícitos

R06 aún requiere navegación multi-borrador y tratamiento explícito del legado.
E03 no conecta por sí solo una pantalla ni comprueba instalación/ACL de Odoo.
La paginación remota agregada no garantiza instantánea ante cambios concurrentes.
No hay movimientos offline de envases ni prueba E2E de la app en este bloque.
El desglose por tercero debe usar `l10n_ec.envases.saldo.tercero`, no quants
filtrados por tercero: ver corrección en `ENVASES_BACKEND_HANDOFF_REVIEW.md`.
