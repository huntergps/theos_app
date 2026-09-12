# Caja y Bodega — qué backend falta para las pantallas ausentes

Lectura read-only de `/Users/elmers/Documents/dev_odoo20`, 2026-09-11. No se
tocó ERP2. Alcance: 9 pantallas ausentes/parciales de CAJA y BODEGA de
`docs/orbi_panel/reports/SCREEN_CORRESPONDENCE_AUDIT_2026_09_11.md`. Cada
cita va con la ruta completa del addon desde `addons/` u `odoo/addons/` —
nunca abreviada — y archivo:línea; lo no citado es propuesta mía, marcada.

## CAJ-02 · registros de turno (pestañas órdenes/facturas/pagos)

**Muestra:** navegar pestañas de la sesión abierta, filtrar, detalle read-only.

**Existe** — `collection.session` ya trae los tres listados resueltos, todos
en `addons/l10n_ec_collection_box/models/collection_session.py`:
`order_ids`/`order_count` (`sale.order`) — `:191-199`;
`invoice_ids` (`account.move`, `move_type=out_invoice`) — `:200-205`;
`credit_note_ids` (`out_refund`, `posted`) — `:211-216`; `invoice_count` — `:217-220`;
`payment_ids` (`account.payment`, `inbound`) — `:221-226`;
`todos_los_pagos_ids` (incluye salidas) — `:237-239`; `payment_count` — `:240-243`.

**Operación:** solo lectura (`read`/`search_read`), sin método propio.
**Permisos:** citados en `docs/orbi_panel/ODOO_ACTION_BINDINGS.md:33`.
**Falta:** nada de modelo — falta transporte JSON-2 paginado. Sin bloqueo real.

## CAJ-03 · cartera

**Muestra (aprobado):** elegir VARIAS facturas de un cliente y cobrar contra ellas.

**Existe** — el único residual-por-cliente vive privado, dentro del wizard
de UNA orden, todo en
`addons/l10n_ec_collection_box/wizards/sale_order_payment_wizard.py`
(distinto de `l10n_ec_collection_box_pos/models/sale_order_payment_wizard.py`,
la fachada POS del mismo wizard): `sale_id` es `required=True` — `:79`;
`_get_move_residual_for_partner` (privado) suma `amount_residual` de un
solo `account.move` — `:713-729`; los listados de saldo vivo son
estrechos: `_compute_available_withhold_move_ids` (retención) — `:733-746`
y `_compute_available_crossing_move_ids` (`crossing_accounts`) — `:754-767`.
**Falta backend, confirmado:** no hay `action_*` que reciba
"cliente + N facturas + importe" contra cartera general. **CAJ-03 es
imposible hoy** sin un método nuevo en el servidor; usar
`crossing_move_id`/`withhold_move_id` sería un uso no soportado por el
guardacódigo (son de retención/cruce, no de cartera).

## CAJ-04-v2 · retención SRI

**Muestra:** consultar clave SRI, revisar datos descargados, registrar.

**Existe** (ya referenciado y excluido en
`theos_panel/lib/features/collection/collection_screen.dart:460`), todo en
`addons/l10n_ec_collection_box/wizards/collection_withhold_sri_import.py`:
`collection.withhold.sri.import` — `:135`;
`collection_session_id` — `:144`; `state` (draft/loaded/done) — `:148`;
`access_key` — `:152`; `action_consultar_sri()` (exige SRI en línea) — `:242`;
`action_registrar()` — `:509`.
**Permisos:** Cajero/Supervisor `crud` —
`addons/l10n_ec_collection_box/security/ir.access.csv:27-30`.
**Falta:** nada de modelo/método. Falta decisión de política offline
(`action_consultar_sri` exige conectividad real) y conectar la UI. No es
backend ausente.

## CAJ-08-v2 · cruce de cuentas

**Muestra:** identificar fuentes/destinos, aplicar, revisar, confirmar.

**Existe**, en `addons/l10n_ec_account_base/models/cross_allocation.py`:
`l10n_ec.withhold.cross` — `:8`; `supervisor_id` (obligatorio para
confirmar) — `:25`; `state` — `:27`; `action_confirm()` exige
`supervisor_id` — `:325-329`; líneas fuente/destino
`l10n_ec.withhold.cross.source.line` — `:859` y `.target.line` — `:913`.
En Caja, `addons/l10n_ec_collection_box/models/withhold_cross.py` hereda ese
modelo: `collection_session_id` cuelga el cruce de la sesión abierta —
`:17-19`; `config_id` (related a `collection_session_id.config_id`) —
`:20-23`; `cashier_id` (related a `collection_session_id.user_id`, sin
campo `user_id` propio aquí) — `:24-27`; supervisor autocompletado de
`session.supervisor_id` — `:45-50`.
**Permisos:** `account.group_account_invoice` `crud` (no un grupo de Caja) —
`addons/l10n_ec_account_base/security/ir.access.csv:4-6`. **Falta:** nada de
modelo/método; falta transporte y verificar en instancia si el Cajero
tiene ese grupo — si no, queda bloqueada por ACL, no por código.

## CAJ-09-v2 · contexto punto/sesión

**Muestra:** abrir acciones del turno, consultar registros, ir a cierre —
es un hub de navegación, sin datos propios.

**Existe**, en `addons/l10n_ec_collection_box/models/collection_session.py`:
`config_id` — `:55-61`; `state` — `:120-129`; "registros" = campos de
CAJ-02; "ir a cierre" = `action_session_closing_control`, citado en
`docs/orbi_panel/ODOO_ACTION_BINDINGS.md` (fila "Cierre, control y
aprobación de diferencia"). **Falta:** nada de backend, solo composición de UI.

## BOD-01 · inventario / existencias

**Muestra:** filtrar inventario, consultar disponibilidad y detalle.

**Existe (núcleo)**, en `odoo/addons/stock/models/stock_quant.py`:
`stock.quant` — `:21`; `product_id` — `:47-50`; `location_id` — `:59-62`;
`warehouse_id` (related) — `:63`; `quantity` — `:80-83`;
`reserved_quantity` — `:84-88`; `available_quantity` (compute) — `:89-92`.
**Existe (propio):** `reservado_por` (qué documento ya la tomó) —
`addons/l10n_ec_stock_base/models/stock_quant.py:9-14`; `costo_promedio`
(requiere `stock.group_stock_manager`) — `:19-27`.
**Permisos:** `stock.group_stock_user` `cru` —
`odoo/addons/stock/security/ir.access.csv:31`; lectura además a
`base.group_user` — `:32`.
**Falta backend, confirmado:** nada — el modelo cubre la lámina completa.
Falta todo el lado app: no hay mapeo Dart de `stock.quant` en `odoo_sdk` ni
`theos_pos_core` (`grep` sin resultados); único rastro de stock es
`sale.order.picking_ids` —
`theos_pos_core/lib/src/models/sales/sale_order.model.dart:203-205`.

## BOD-02 · operaciones (recepción / preparación / entrega / transferencia)

**Muestra:** menú para abrir recepción, preparación, entrega o transferencia.

**Existe — solo la salida a cliente (`outgoing`) tiene guardacódigo propio,**
todo en `addons/l10n_ec_despachos/models/stock_picking.py`: `button_validate()`
sobrescrito llama al candado antes del `super()` — `:92-96`;
`_despacho_check_cobro_previo()` — `:99-133` (la condición
`picking_type_code == 'outgoing'` está en `:120`); `_evaluar_estado_factura()`
— `:56-90`. **No existe candado para recepción ni transferencia:** el mismo
método deja pasar toda transferencia interna sin control — mismo archivo,
`:118-121` (`if picking_type_code != 'outgoing': return`). Recepción
(`incoming`) no tiene ninguna extensión en los addons revisados — sería
`stock.picking` puro del núcleo, en `odoo/addons/stock/models/stock_picking.py`:
`action_confirm()` — `:753`; `action_assign()` — `:772`;
`button_validate()` — `:1160`.
**El tablero `despacho.tarjeta` NO cubre esto:** sus etapas son de flujo de
ENTREGA (`Solicitud Despacho`, `En Taller`, `Listo para Entrega
Local/Envíos`, `Entregado`) —
`addons/l10n_ec_despachos/data/despacho_stage_data.xml:5-35` — y la tarjeta
solo nace sola para despachos a taller por defecto
(`despacho.crear_tarjeta_auto='taller'`), no para todos —
`addons/l10n_ec_despachos/models/stock_picking.py:38-47` (comentario). Usar
esas etapas como "recepción/transferencia" sería inventar un uso no soportado.
**Permisos (solo tablero de despacho):**
`group_despacho_vendedor/_tecnico/_despachador/_supervisor` —
`addons/l10n_ec_despachos/security/despacho_groups.xml:11,64,71,83`; ACL —
`addons/l10n_ec_despachos/security/ir.access.csv:2-6`. Recepción y
transferencia usarían `stock.group_stock_user` —
`odoo/addons/stock/security/ir.access.csv:8`.
**Falta backend, confirmado:** recepción/transferencia no tienen regla de
negocio propia — se apoyarían en el núcleo puro, sin decisión de producto
sobre candado/checklist/evidencia. No es "imposible"; solo `outgoing`
tiene contrato propio verificado.

## BOD-03 · preparación / entrega parcial

**Muestra:** escanear/editar cantidades, indicar faltante línea a línea.

**Existe (núcleo):** `stock.move.line.quantity` —
`odoo/addons/stock/models/stock_move_line.py:37-40`; `picked`
(compute+store) — `:43`. En
`odoo/addons/stock/wizard/stock_backorder_confirmation.py`:
`stock.backorder.confirmation.line` con `to_backorder` — `:7-13`;
`stock.backorder.confirmation` — `:17`; `process()` aplica backorder por
picking — `:49-64`; `_check_less_quantities_than_expected()` compara
`product_uom_qty` contra `move._get_picked_quantity()` — `:39-47`. El audit
ya confirma que
`theos_panel/lib/features/warehouse/warehouse_screen.dart` cubre el diálogo
"Backorder requerido" — ese tramo YA tiene transporte.
**Permisos:** `stock.group_stock_user` `cru` —
`odoo/addons/stock/security/ir.access.csv:61-62`.
**Falta backend, confirmado:** nada de modelo — `quantity` por línea y el
wizard cubren "editar cantidad"/"indicar faltante". Falta **transporte de
la edición línea a línea** (hoy solo se valida con las cantidades que YA
trae el picking) — mismo hueco de `odoo_sdk` que BOD-01/02. No hay escaneo
de código de barras contratado en ningún documento de Orbi revisado.

## BOD-04 · conteo físico

**Muestra:** capturar esperado/contado/diferencia, guardar, **enviar a
revisión** (no ejecuta ajuste automático ni aprueba revisión — lámina
aprobada, `docs/orbi_panel/APPROVED_SCREEN_INDEX.md:41`).

**Existe (núcleo, vía quant — no el `stock.inventory` viejo)**, todo en
`odoo/addons/stock/models/stock_quant.py`: `inventory_quantity` ("Counted")
— `:99-101`; `inventory_quantity_auto_apply` (compute+inverse,
`groups='stock.group_stock_user'`) — `:102-106`; `inventory_diff_quantity`
(store) — `:107-110`; `inventory_date` — `:111-113`;
`action_apply_inventory(self, date=None)` — `:465-482`: si el quant está
desactualizado abre `stock.inventory.conflict` (`:472-480`); si no, aplica
directo (`:481`) y limpia `inventory_quantity_set` (`:482`).
**Permisos:** `stock.group_stock_user` `cru` —
`odoo/addons/stock/security/ir.access.csv:31`; mismo grupo exige el
`groups=` del campo inverso (línea 105 arriba, mismo archivo).
**Falta backend, confirmado — hallazgo principal de esta ficha:** el
núcleo **no tiene un estado "contado, pendiente de revisión"** —
`action_apply_inventory` o aplica de una vez o abre el wizard de CONFLICTO
(cuando otro proceso movió la cantidad); no hay un tercer estado donde un
bodeguero guarde el conteo y un supervisor lo apruebe después. **BOD-04 es
imposible hoy sin backend nuevo:** hace falta un modelo/flag que retenga
`inventory_quantity` sin aplicar hasta que un segundo rol confirme.

## Resumen

| Pantalla | Bloqueo real |
|---|---|
| CAJ-02 | Ninguno de modelo — falta transporte/paginación |
| CAJ-03 | **Imposible hoy** — no existe cartera multi-factura |
| CAJ-04-v2 | Ninguno de modelo — política offline pendiente (SRI exige red) |
| CAJ-08-v2 | Ninguno de modelo — ACL de instancia sin verificar |
| CAJ-09-v2 | Ninguno — composición de UI sobre contratos resueltos |
| BOD-01 | Ninguno de modelo — falta todo el mapeo en `odoo_sdk` |
| BOD-02 | Solo `outgoing` con contrato propio; recepción/transferencia sin decisión de producto |
| BOD-03 | Ninguno de modelo — falta transporte de edición línea a línea |
| BOD-04 | **Imposible hoy** — no existe estado "contado, pendiente de aprobación" |

De 9 pantallas, **2 imposibles hoy sin trabajo de servidor** (CAJ-03,
BOD-04); las otras 7 tienen modelo/método suficientes — su bloqueo es
transporte Dart ausente, política offline pendiente o ACL sin verificar,
ninguna de las tres cuenta como "falta de backend".
