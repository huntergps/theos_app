# ERP2 JSON-2 verification harness

`scripts/verify_orbi_erp2.py` is a contract probe, not an ERP migration or a
production smoke test. It does not contact a server unless explicitly run.

Read-only use:

```sh
ERP2_URL=https://erp2.example.invalid ERP2_API_KEY='...' \
  python3 scripts/verify_orbi_erp2.py
```

The key is read only from the environment and is never written to evidence or
stdout. The harness rejects hostnames containing `newerp`. It checks the
JSON-2 read shapes needed by users, partners, products, payment terms, taxes,
pricelists, warehouses, journals and orders, and records expected actors
(seller/cashier/approver/view-all/offline operator) and scenarios (cash,
credit, mixed, FSC cash, approval and offline replay).

Writes are disabled unless both conditions hold:

```sh
ERP2_URL=https://erp2.tecnosmart.com.ec ERP2_API_KEY='...' \
  python3 scripts/verify_orbi_erp2.py \
  --allow-test-writes --host erp2.tecnosmart.com.ec
```

The current harness performs only the read contract checks; it contains no
destructive cleanup. Any future test write must use an `ORBI-TEST` prefix and
an explicit, non-destructive cleanup query. Never use production credentials,
passwords, or the `newerp` host.
