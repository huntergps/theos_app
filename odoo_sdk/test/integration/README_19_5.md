# Odoo 19.5 read-only smoke slots

The integration smoke test has five opt-in slots for deployed Odoo 19.5
databases: `NEWERP`, `EPR2`, `PVISION`, `JB`, and `DEJAVU`.

Configure a slot with environment variables (the test skips unconfigured
slots):

```text
NEWERP_BASE_URL=https://...
NEWERP_API_KEY=...
NEWERP_DATABASE=...
```

Use the equivalent prefix for the other slots. Do not commit these values or
print them in CI logs. Run from `odoo_sdk/`:

```bash
dart test test/integration/odoo_capabilities_smoke_test.dart
```

The 19.5 checks use only `fields_get` and assert the required schema:

- `l10n.ec.bank`: `name`, `code`, `tipo`, `active`
- `l10n_ec_collection_box.sale.order.payment`: `l10n_ec_bank_id`, `bank_name_ec`
- `l10n_ec_collection_box.sale.order.payment.wizard.line`:
  `l10n_ec_bank_id`, `bank_name_ec`
- `sale.order.line`: `product_uom_id`
- `res.partner.bank`: `account_number`, `bank_name`
- `l10n_ec.cash.out`: `cash_out_uuid`
- `account.advance`: `external_id`, `advance_line_ids`
- `account.advance.line`: `journal_id`, `amount`, `advance_method_line_id`

The wizard-line `line_type` field is probed with `hasField` and reported, but
is intentionally not required because deployed 19.5 databases differ.

No write, create, unlink, or workflow operation is performed. The test does
not claim that `ir.module.module.latest_version` is authoritative for the
server's 19.5 minor release; it verifies the deployed field contract instead.
