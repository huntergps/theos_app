# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Packages

| Package | Purpose |
|---------|---------|
| `odoo_sdk/` | Unified SDK: HTTP client, interceptors, model annotations, code generators, CRUD, sync, WebSocket, offline queue, multi-context data layer, Drift-reactive streams |
| `flutter_qweb/` | QWeb template engine → PDF reports (standalone, no Odoo deps) |
| `odoo_widgets/` | Reusable Flutter widgets for Odoo data |
| `theos_pos/` | POS application (Flutter) |
| `theos_pos_core/` | POS core library |

No inter-package dependencies between `odoo_sdk` and `flutter_qweb`. Each is fully independent.

## Commands

### Install dependencies

```bash
cd odoo_sdk && dart pub get
cd flutter_qweb && dart pub get
```

### Run tests

```bash
# Full test suites
cd odoo_sdk && dart test          # ~1638 tests
cd flutter_qweb && dart test      # ~101 tests

# Single file
dart test test/some_test.dart

# By tag
dart test --tags unit
dart test --tags integration

# Generator tests (MUST use path — generator tests have no Flutter deps)
cd odoo_sdk && dart test test/generators/
```

> **Warning:** `dart test` at the `odoo_sdk` root may fail if a test transitively depends on Flutter packages. Run generator tests via `dart test test/generators/` to avoid this.

### Lint / Analysis

```bash
cd odoo_sdk && dart analyze
cd flutter_qweb && dart analyze
```

Generated files (`*.g.dart`, `*.freezed.dart`, `*.odoo.g.dart`, `*.drift.g.dart`) are excluded from analysis.

### Code generation (consumer apps)

```bash
# In your app that depends on odoo_sdk
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch   # continuous
dart run build_runner clean   # reset
```

Generators defined in `odoo_sdk/build.yaml`:
- **odoo_model_builder** → `*.odoo.g.dart` — `OdooModelManager<T>` implementations, `fromOdoo()`/`toOdoo()`, global manager instance
- **drift_table_builder** → `*.drift.g.dart` — Drift table schema matching model fields

Other generated files (never edit manually):
- `*.freezed.dart` — Freezed immutable models
- `*.g.dart` — JSON serialization

## Architecture

### Odoo JSON-2 API (Odoo 19+)

```
POST https://<host>/json/2/{model}/{method}
Authorization: bearer <api_key>
X-Odoo-Database: <database>
Content-Type: application/json
```

No JSON-RPC. HTTP status codes reflect errors. Key parameter mapping:
- `ids:` → builds the recordset (`self`) for the method
- `kwargs:` → spread into body as named parameters (use this for positional args too)
- `args:` → treated as a named param `args` by the server (causes errors if misused)

### Offline-first flow

1. **Read**: local Drift DB first, background sync from Odoo.
2. **Write**: persist locally + enqueue to offline queue. Local records use **negative IDs** (e.g., `-1234567`).
3. **Sync**: bidirectional; real IDs assigned when server confirms create.
4. **WebSocket**: real-time push from Odoo triggers local refresh.
5. **Reactivity**: Drift `.watch()` streams auto-re-emit on any DB change.

Conflict resolution strategies: `serverWins`, `clientWins`, `newerWins`, `manualResolve`, `merge`, `askUser`. See `src/sync/CONFLICT_RESOLUTION.md` for the full guide.

### OdooModelManager composition

`OdooModelManager<T>` is composed of 6 mixins — each handles a distinct concern:

| Mixin | Responsibility |
|-------|---------------|
| `ManagerSyncMixin` | `syncFromOdoo()`, `syncToOdoo()`, `sync()` |
| `ManagerCacheMixin` | LRU in-memory cache |
| `ManagerWatchMixin` | Drift `.watch()` reactive streams |
| `ManagerBatchMixin` | `createBatch()`, `updateBatch()`, `deleteBatch()` |
| `ManagerConflictsMixin` | Conflict detection + resolution |
| `ManagerActionsMixin` | SmartOdooModel action handlers |

The code generator (`odoo_model_generator.dart`) produces a concrete subclass of `OdooModelManager<T>` for each model. **Generated overrides live on the Manager class** (not the model), because Dart extensions can't override mixin methods. The manager must implement SmartOdooModel integration methods (`onchangeHandlerMap`, `computedFieldNames`, `stateField`, etc.) with defaults on the base class.

### SmartOdooModel / OdooRecord delegation

- `SmartOdooModel` is a mixin on the **model class** — but it accesses its manager via `OdooRecordRegistry.get<T>()`, not via `OdooRecord._manager` (which is private to `odoo_record.dart`).
- `OdooRecord` provides `ensureValid()` and `callActionAndRefresh()`.
- The `SmartOdooModel` mixin has its own `_managerRef` getter using the registry directly.

### Multi-context data layer

Provides isolated data contexts for multiple frontends sharing the same infrastructure:

- **DataSession** — immutable credentials (baseUrl, database, apiKey)
- **DataContext** — isolated container: own `OdooClient`, `GeneratedDatabase`, `OfflineQueueWrapper`, and 4 registries (configs, managers, fields, computes)
- **OdooDataLayer** — facade; at any time ONE context is active → its managers populate the global registry
- **DataLayerBridge** — context-aware replacement for `SmartMatrixBridge`
- **DataSyncOrchestrator** — sequential/parallel sync across multiple contexts

```dart
final layer = OdooDataLayer();
await layer.createAndInitializeContext(
  session: DataSession(id: 'pos', label: 'POS', ...),
  database: db,
  queueStore: store,
  registerModels: (ctx) {
    ctx.registerConfig<Product>(Product.config);
    ctx.registerManager<Product>(productManager);
  },
);
```

### HTTP interceptors (applied in order)

`RateLimitInterceptor` → `CompressionInterceptor` → `CacheInterceptor` → `AuthInterceptor` → `RetryInterceptor` → `MetricsInterceptor` → `LogSanitizerInterceptor`

Preset configs: `RetryConfig.production`, `CacheConfig.odooDefault`.

### Sub-libraries

- `package:odoo_sdk/odoo_sdk.dart` — Full SDK (~93 exports)
- `package:odoo_sdk/core.dart` — Networking/API layer only (~26 exports)
- `package:odoo_sdk/latam.dart` — Ecuador localization (`EcuadorVatValidator`, `SriKeyGenerator`, money rounding)

## Conventions

### Model definition pattern

```dart
@OdooModel('product.product')
@freezed
class Product with _$Product {
  const factory Product({
    @OdooId() required int id,
    @OdooString() required String name,
    @OdooFloat(odooName: 'list_price') double? listPrice,
    @OdooMany2One('product.category') int? categoryId,
    @OdooBoolean() @Default(true) bool active,
    @OdooLocalOnly() String? uuid,
  }) = _Product;
}
```

### Field annotations

Basic: `@OdooId`, `@OdooString`, `@OdooInteger`, `@OdooFloat`, `@OdooBoolean`
Dates: `@OdooDate`, `@OdooDateTime`
Relations: `@OdooMany2One`, `@OdooMany2OneName`, `@OdooOne2Many`, `@OdooMany2Many`
Special: `@OdooSelection`, `@OdooBinary`, `@OdooHtml`, `@OdooJson`, `@OdooMonetary`
Computed: `@OdooComputed`, `@OdooStoredComputed`
Advanced: `@OdooRelated`, `@OdooConstraint`, `@OdooOnchange`, `@OdooAction`
Local only: `@OdooLocalOnly` (not synced to Odoo)

`@OdooOnchange` and `@OdooConstraint` are field-level annotations (on constructor params). `@OdooStateMachine` is class-level. All defined in `odoo_field_annotations.dart`.

### Naming

| Context | Convention | Example |
|---------|-----------|---------|
| Dart class | PascalCase | `Product` |
| Odoo model | dot notation | `product.product` |
| Drift table | snake_case | `product_product` |
| Manager class | PascalCase + Manager | `ProductManager` |
| Global instance | camelCase | `productManager` |
| Dart field | camelCase | `listPrice` |
| Odoo field | snake_case (via `odooName`) | `list_price` |

### Error handling

Use the `Result<T>` type from `src/errors/result.dart` for operations that can fail. `OdooException` automatically masks credentials in logs.

### Testing

- Mocking: `mocktail` (general), `http_mock_adapter` (Dio)
- Pattern: `setUpAll(() => registerAllFallbacks())` + `setUp/tearDown` with `TestFixtures`
- Shared mocks/fixtures in `test/mocks/`
- Integration tests in `test/integration/` — require a live Odoo instance configured via `e2e_config.dart` (gitignored; stub at `e2e_config_stub.dart`)

### SDK requirements

- Dart SDK: `^3.10.0` (flutter_qweb: `>=3.0.0 <4.0.0`)
- Flutter: `>=3.10.0`

### Ecuador localization

SRI VAT validation (`EcuadorVatValidator`), electronic invoice key generation (`SriKeyGenerator`), Odoo-compatible money rounding — all in `package:odoo_sdk/latam.dart`.
