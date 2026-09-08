# V01 browser database harness

The harness is `theos_panel/integration_test/runtime_database_owner_test.dart`
and is driven by `theos_panel/test_driver/integration_test.dart`. It exercises
the real `RuntimeDatabaseOwner` default factory: it writes `sync_metadata`,
closes and reopens the same `AppScope`, and verifies that a different user
scope cannot read the row.

Drift carga WASM/worker mediante `fetch()`/`Worker`, no mediante
`AssetBundle`. Por eso el host publica ambos junto a `index.html`:

`build/web/sqlite3.wasm`

`build/web/drift_worker.dart.js`

Validation performed:

* `flutter build web --release --no-wasm-dry-run` — passed; the two package
  assets above were emitted.
* `WEB_DRIVER_PORT=4444 flutter drive -d web-server --driver
  test_driver/integration_test.dart --target
  integration_test/runtime_database_owner_test.dart` — pasó en Chrome
  152.0.7977.83 con ChromeDriver 152.0.7977.82. Escribió en IndexedDB,
  cerró/reabrió el mismo scope y confirmó aislamiento frente a otro usuario.

La primera ejecución detectó una causa real: usar la ruta de asset de paquete
devolvía HTTP no exitoso al compilar WASM. La fábrica productiva quedó
corregida para usar los dos recursos raíz del host.

The harness does not use `NativeDatabase`, an in-memory factory, or a mock
browser storage backend.
