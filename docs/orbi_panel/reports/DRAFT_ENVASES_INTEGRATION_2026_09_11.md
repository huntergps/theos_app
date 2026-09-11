# Integración Envases — borrador de entrega

Fecha: 2026-09-11. Alcance: runtime/UI local y verificación estática del addon.

## Integrado

- El workspace de ventas mantiene pestañas por `draftId` durable, serializa
  initialize/create/select/close/reopen y conserva filas cerradas para reabrir.
  La barra ofrece cierre por pestaña, etiquetas estables, desplazamiento
  horizontal y selector de borradores durables.
- `orbi_envases_dashboard_cache` conserva una copia por `scope_key/company_id`.
  `EnvasesDashboardCache` distingue no cargado de vacío, observa SQLite,
  reemplaza atómicamente tras `readAll()`, conserva el valor anterior ante
  fallo y rechaza carreras cross-instance por comparación de baseline.
- `EnvasesPartnerBalanceReader` lee únicamente
  `l10n_ec.envases.saldo.tercero`, con campos/orden/filtros verificados,
  compañía y DTO estricto. No agrupa `stock.quant` por persona ni escribe
  movimientos, saldos u operaciones.
- Capability materialization añade sólo `envases_read` cuando la membresía
  efectiva contiene `l10n_ec_stock_envases.group_envases_user` o
  `l10n_ec_stock_envases.group_envases_manager`; conserva permisos existentes.
- Composición Envases requiere sesión, compañía coincidente y `envases_read`,
  reutiliza owner/lease, no hace fetch automático y conserva snapshots offline.
- Inspector legacy de sólo lectura: avisa sin importar, borrar, inferir empresa
  ni reconstruir importes ausentes. `valid` describe el formato, no su migrabilidad.

## Hallazgos backend que condicionan la integración

- `l10n_ec.envases.saldo.tercero` deriva entregas/devoluciones de
  `stock.move.line` con `state='done'`, tomando el tercero de
  `stock.picking.partner_id` (`models/envases_saldo_tercero.py:97-145`).
- Las ubicaciones de custodia son compartidas por almacén/rol
  (`stock_warehouse.py:120-174`; `stock_location.py:185-219`).
- El panel agregado sigue siendo compatible: suma `stock.quant` por rol y
  producto/empresa (`envases_panel.py:78-105`).
- Revalidación posterior del 11/09: el otro trabajo backend añadió ACL de
  lectura de `l10n_ec.envases.saldo.tercero` en `security/ir.access.csv` y
  `_accion_saldo_tercero` ahora agrupa por `partner_id` en ese modelo.
  Corrige los dos hallazgos anteriores; inspección de fuentes, no prueba
  de instalación en servidor ni autorización para tocar ERP2.

## Evidencia y pendientes

- Tests propios: cache 7, partner reader 4, capability 3, composición 3 y
  barra responsive 1; análisis dirigido sin errores.
- Integrador ejecutó 88 pruebas de ventas, borradores, rutas, catálogos y Envases:
  todas pasaron; análisis dirigido de ocho rutas de código/tests sin incidencias.
- Codec v2 conserva procedencia de cálculo; v1 mantiene cifras históricas pero
  no las declara calculadas. Cambio de cliente/líneas invalida esa procedencia.
  Confirmar/solicitar aprobación con importes pendientes no genera comandos.
- Navegador local: login digitado campo a campo, crear/cambiar borrador y
  recuperar cliente/nota verificados visualmente; dashboard cache visible.
  Recarga durable comprobada y edición en teléfono capturada en
  `evidence/2026-09-11/sales-phone.png`; evidencia final de cuatro tamaños
  sigue pendiente. Sin E2E financiero/Odoo; ver informe de brecha de precios.
  Esto no declara R06/R07/E05 completos ni paridad visual total.
