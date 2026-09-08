# B01 — auditoría de contrato backend/runtime (ERP 19.5)

Auditoría read-only del código en `/Users/elmers/Documents/dev_odoo20` y del
runtime local de Orbi. No se modificaron addons de Odoo, ni se ejecutaron
escrituras en `newerp` o ERP2.

## Resultado

**B01 debe seguir `in_progress`.** Los cuatro flujos comerciales y sus guardas
existen en Odoo; hay brechas críticas en los productores/replay offline de
colecciones y en la numeración fiscal que impiden declarar U06/V01 terminados.

## Lo que ya está cubierto por Odoo

- `l10n_ec_collection_box.sale.order.payment.wizard` es la frontera transaccional
  nativa. `action_apply()` persiste líneas y enciende
  `exige_pago_total_entrega`; `action_apply_and_create_invoice()` exige pago
  completo; `action_full_payment()` es el atajo de contado.
- `l10n_ec_collection_box_pos.models.sale_order_payment_wizard` conserva
  `pos_client_op_uuid`, savepoint y la acción idempotente de factura. No hace
  falta una tabla de recibos paralela.
- Crédito, contado, mixto y contado con FSC se clasifican por término de pago.
  `sale.order.action_confirm()`/`confirm_approved_order()` aplican aprobación,
  crédito y bloqueo; crédito/mixto facturan al confirmar, contado al cobrar.
- `approval.request._l10n_ec_procesar_facturar_sin_cobro()` publica factura,
  activa `exige_pago_total_entrega` y genera despacho; el control final de
  `stock.picking.button_validate()` solo bloquea la salida a Customers, no la
  preparación.
- `collection.session` contiene apertura, responsable, diferencia autorizada,
  depósito obligatorio y cierre. `payment.transaction.action_l10n_ec_enviar_a_caja()`
  ya evita duplicados mediante `l10n_ec_payment_transaction_id`; el runtime debe
  llamarlo, no crear una entidad financiera nueva.

## Hallazgos críticos en runtime

### 1. Salida de caja: payload incompatible

`orbi_runtime/lib/src/sales/durable_collection_producers.dart` crea el payload
con `cash_out_type`, pero Odoo define `l10n_ec.cash.out.cash_out_type_id` como
Many2one obligatorio; `cash_out_type` es un related readonly. El adaptador solo
renombra `uuid` a `cash_out_uuid`, por lo que el replay no puede crear una salida
válida. Las pruebas actuales son unitarias/fake y no llegan al `create` real.

Corrección mínima sin tocar Odoo: sincronizar/cachear `l10n_ec.cash.out.type`,
resolver por código (`expense`, `security`, `advance`, etc.) al ID autorizado y
enviar `cash_out_type_id`; no enviar el related `cash_out_type`. Mantener
`cash_out_uuid` y enlazar después `action_confirm`. Validar flujo `out`, diario,
sesión y permiso antes de encolar.

### 2. Depósito: tipos y cheques inválidos

Odoo acepta únicamente `deposit_type = cash | check | mixed` y exige
`check_count > 0` cuando `check_amount > 0`. El productor actual permite casos de
prueba con `bank` y genera siempre `check_count: 0`, incluso para un depósito de
cheques. Además envía `cash_journal_id`, que es related readonly.

Corrección mínima en runtime: validar/mapear tipos a esos tres valores, exigir
cantidad de cheques para `check`/`mixed`, calcular componentes coherentes, y
eliminar `cash_journal_id` del `create`. El productor solo crea el depósito en
borrador; no debe presentarlo como contabilizado porque todavía no encola la
acción nativa `action_create_accounting_entry`.

### 3. Cobro offline: fiscalidad incompleta en el replay genérico

`action_pos_confirm_and_invoice` ya soporta `sequential`, `emission_date`,
`access_key` y `client_op_uuid`, y los diarios marcados `numbered_by_client`
rechazan una llamada sin secuencial. El camino durable `cashInvoice` en
`sale_runtime_adapters.dart` envía líneas, sesión y UUID, pero no envía esos tres
campos fiscales. Por tanto no satisface el contrato offline cuando el diario es
numerado por la app.

Corrección mínima en runtime: aprovisionar localmente el rango exclusivo del
punto de emisión, reservar el secuencial de forma atómica, calcular fecha/clave
según el mismo algoritmo documentado y enviar los tres campos. Si la autoridad
fiscal no está aprovisionada, dejar la operación como pendiente/conflicto; no
inventar secuenciales.

### 4. Reconciliación ambigua demasiado permisiva

`_collectionApplied()` consulta `account.move` por UUID y estado no cancelado y
devuelve verdadero por la mera existencia de la factura. Eso puede marcar un
cobro como aplicado tras una respuesta ambigua aunque el pago no se haya
creado. La consulta debe exigir `l10n_ec_pos_collection_completed`, estado de
pago compatible y monto esperado; para el wizard nativo debe reconciliar por
línea/UUID de transacción/factura antes de reintentar.

## Operaciones aún no implementadas en modo offline

Anticipos, retenciones y notas de crédito están marcados como `unavailable` por
`RuntimeCollectionOperationPort`, lo cual es correcto mientras no exista un
productor durable que componga los wizards nativos. No se debe declarar U06
completo ni crear un modelo alternativo. Online deben invocar:

- `confirm.advance.wizard.action_create_advance`;
- `collection.session.withhold.wizard.action_create_withhold` y luego el wizard
  oficial de retención;
- líneas `credit_note` del wizard nativo de cobro.

## Autenticación web y evidencia ERP2

El contrato W01 sigue bloqueado hasta autorizar/implementar bootstrap de sesión
same-origin con cookie HttpOnly; no se debe presentar API key en navegador como
experiencia final. La auditoría de código no sustituye V01: todavía no hay
certificación de los cuatro flujos escritos en ERP2 con vendedor, cajero,
supervisor y bodega independientes. No usar admin como sustituto.

## Propuesta de corrección y autorización

No se requiere cambio de addon Odoo para estas brechas. El cambio autorizado
debe limitarse a `orbi_runtime`/`theos_pos_core`, con pruebas de contrato que
reproduzcan las restricciones reales: IDs de tipos de salida, tipos de depósito
y cheques, diario numerado por cliente, UUID reintentado y factura existente sin
pago. Solo si aparece una incompatibilidad real al probar ERP2 se redactará una
propuesta separada de backend con origen, destino, riesgo y prueba.
