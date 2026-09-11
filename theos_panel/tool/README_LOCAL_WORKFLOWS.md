# Local workflow harness

This is a dev-only web entrypoint. It uses the real `OrbiApp`, production
`GoRouter`, login screen, Riverpod auth controller, `SessionRuntime`, Drift
database owner and Envases cache. It does not replace `main.dart` and does not
modify production router or package configuration.

Build from `theos_panel/`:

```sh
flutter build web --no-pub --target dev/local_workflows.dart \
  --output build/local_workflows
```

Serve `build/local_workflows` with the existing static web server workflow. The
Drift web assets (`sqlite3.wasm` and `drift_worker.dart.js`) must be published
beside `index.html`, as required by the runtime database owner.

The login form accepts only these fictitious local-demo values:

- Server: `https://orbi.invalid`
- Database: `local_workflow`
- User: `demo`
- Password: `orbi-demo`

Successful login activates a real local scope for user `7`, grants only the
demo capabilities `seller` and `envases_read`, and seeds the real Envases and
sales catalog caches through completed local DTO/catalog writers. The catalog
contains clearly fictitious products, customers, and payment terms so the sale
editor can search and add a product through its normal reactive controllers.
No catalog success, sale confirmation, synchronization, Odoo client, network
request, ERP data, or credential is faked or implied. The UI is marked `LOCAL
TEST` by this documentation and is not evidence of an end-to-end production
workflow.
