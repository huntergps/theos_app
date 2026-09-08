# B01 · paridad backend y fiscal offline

Estado al 2026-09-08: `in_progress`. La integración sigue siendo native-first:
no se creó una tabla de recibos ni un circuito contable paralelo.

## Resuelto en runtime

- Salidas usan `l10n_ec.cash.out.cash_out_type_id`, `cash_flow=out`, UUID y
  `action_confirm`; nunca escriben el related `cash_out_type`.
- Depósitos aceptan sólo `cash/check/mixed`, validan componentes y cheques, y
  encolan `action_create_accounting_entry` después del `create`. Sólo quedan
  contabilizados localmente cuando Odoo confirma un `move_id`.
- Las líneas de retención se persisten en `sale_order_withhold_line`, se
  sincronizan antes del wizard y una línea fallida impide aplicar el cobro.
- `cashInvoice` conserva `sequential`, `emission_date`, `access_key` y UUID;
  un diario numerado por cliente rechaza identidad fiscal incompleta.
- La reconciliación de cobro exige evidencia nativa: factura publicada/pagada,
  marcador de colección y monto, o líneas oficiales del wizard.
- Anticipo, turno, conteo y cierre usan `account.advance`,
  `collection.session.cash` y `collection.session` existentes.
- `PaymentTransactionCollectionPort` invoca únicamente
  `payment.transaction.action_l10n_ec_enviar_a_caja` y reconcilia por
  `l10n_ec_payment_transaction_id`; no crea línea, pago, factura ni sesión.

## Evidencia local

- Productores, replay y adaptadores: 34 pruebas focales correctas.
- Adaptador `payment.transaction`: 7 pruebas, incluido reintento con la
  transacción ya cancelada y línea nativa existente.
- `orbi_runtime`: análisis limpio; `git diff --check` limpio.

## Bloqueos restantes

1. Odoo 19.5 no ofrece reserva/lease de rangos fiscales offline. El high-water
   local actual es seguro sólo con un punto de emisión/diario exclusivo por
   dispositivo. Compartirlo entre dispositivos requiere una extensión backend
   autorizada; el control de conflicto al replay llega demasiado tarde para un
   comprobante ya impreso.
2. Falta certificar en ERP2 depósito contabilizado, retención ordenada,
   transferencia de `payment.transaction`, secuencia, cierre y los cuatro
   flujos con vendedor, cajero, supervisor y bodega reales.
3. El arnés V01 necesita cuatro fixtures prefijadas y credenciales externas de
   los cuatro actores; sólo vendedor/cajera han sido identificados. Admin no
   puede sustituir la prueba de permisos.

`newerp` permaneció excluido.
