# Cobros: catálogos de tarjetas y métodos

## Fuente canónica local

`theos_pos_core/lib/src/database/database.dart` ya registra las tablas Drift
`AccountCreditCardBrand`, `AccountCreditCardDeadline`, `AccountCardLote` y
`AccountPaymentMethodLine`; no se creó ninguna tabla. El código existente
identifica los modelos JSON-2 como:

- `account.card.brand`: `id`, `name`, `code`, `active`, `write_date`.
- `account.card.deadline`: `id`, `name`, `deadline_days`, `percentage`, `active`, `write_date`.
- `account.card.lote`: `id`, `name`, `journal_id`, `state`, `date`, `numero_lote`,
  `amount_total`, `amount_balance`, `payment_count`, `is_pos_lote`, `write_date`.
- `account.payment.method.line`: `id`, `journal_id`, `payment_method_id`,
  `name`, `code`, `payment_type`, `write_date`.

No hay tabla/modelo local separado para `account.payment.method`; se sincronizan
sus líneas reales. Las relaciones requeridas se rechazan si no contienen IDs
positivos, evitando datos inventados.

## Implementación y evidencia

`theos_pos_core/lib/src/services/catalog/payment_config_record_mapper.dart`
implementa upsert/read sobre las tablas existentes y se exporta desde el paquete.
`orbi_runtime/lib/src/read/json2_read_adapters.dart`,
`local_catalog_adapters.dart` y `runtime_catalog_composition.dart` añaden cuatro
descriptores, writers, readers y jobs serializados por el coordinador existente.

`theos_pos_core/test/services/payment_config_record_mapper_test.dart` cubre el
JSON→Drift y actualización sin duplicados. El test de runtime
`orbi_runtime/test/read/payment_config_catalog_test.dart` ejecuta los cuatro
jobs y comprueba reapertura de archivo físico.

## Odoo 19.5

La auditoría del repositorio no encontró addons Python/XML que definan o eliminen
estos modelos; solo hay referencias Dart existentes. Por tanto no se afirma que
algún modelo haya sido eliminado en Odoo 19.5: su disponibilidad de servidor
queda sin verificar hasta consultar una instancia/manifest de módulos instalada.
