# Repository Guidelines

## Project Structure & Module Organization
- `lib/` holds the Flutter application code (features, core utilities, state, UI).
- `test/` contains unit and widget tests (with subfolders like `core/` and `features/`).
- `assets/` stores bundled images, icons, and other Flutter assets.
- `../docs/` contains the living specifications and operational runbooks.
- `android/`, `ios/`, `web/`, `macos/`, `linux/`, `windows/` are platform shells.
- `build/` is generated output; do not edit or commit changes here.

## Build, Test, and Development Commands
- `flutter pub get` installs dependencies.
- `flutter run` launches the app on a connected device or emulator.
- `flutter test` runs all tests in `test/`.
- `flutter analyze` runs static analysis using `analysis_options.yaml`.
- `dart run build_runner build --delete-conflicting-outputs` regenerates code when builders are used.

## Coding Style & Naming Conventions
- Indentation: 2 spaces (Dart/Flutter standard).
- Use `UpperCamelCase` for types/widgets, `lowerCamelCase` for variables and methods.
- File names use `lower_snake_case.dart` (for example, `sales_view.dart`).
- Follow `flutter_lints` from `analysis_options.yaml`; keep analyzer warnings at zero.

## Testing Guidelines
- Framework: `flutter_test`.
- Place tests under `test/` and name files `*_test.dart`.
- Prefer unit tests for pure logic and widget tests for UI behavior.
- Run the full suite with `flutter test` before opening a PR.

## Commit & Pull Request Guidelines
- Commit messages follow Conventional Commits with scopes (examples: `feat(core): ...`, `docs: ...`).
- PRs should include a brief summary, linked issues (if any), and screenshots or recordings for UI changes.
- Call out schema or generated-code updates in the PR description.

## Configuration & Local Setup Notes
- This repo uses Flutter; ensure the correct SDK is installed and on PATH.
- If you update dependencies, commit `pubspec.lock`.

## Model Manager Architecture (`odoo_sdk` integration)

### Overview
The app uses `OdooModelManager<T>` exported by the local `odoo_sdk` package.
Concrete managers and annotated domain models live in `theos_pos_core`; the
Flutter app owns Riverpod providers and registry/lifecycle composition.

### Files Structure
```
lib/core/managers/
├── managers.dart                    # Barrel export
└── manager_providers.dart           # Providers, binding and teardown

../theos_pos_core/lib/src/
├── models/                         # Annotated domain models
└── managers/                       # Concrete model managers
```

### Usage Example

```dart
// After activating the user scope and publishing DB/client providers.
import 'package:theos_pos/core/managers/managers.dart';

final queueStore = ref.read(offlineQueueDataSourceProvider);
await initializeModelManagers(
  client: ref.read(odooClientProvider), // null only for explicit offline login
  db: ref.read(appDatabaseProvider),
  queueStore: queueStore!,
);
```

### Accessing Managers via Providers

```dart
// Read a product
final productManager = ref.read(productManagerProvider);
final product = await productManager.readLocal(123);

// Search partners
final partnerManager = ref.read(partnerManagerProvider);
final partners = await partnerManager.searchLocal(
  domain: [['active', '=', true]],
  limit: 50,
);

// Get tax by ID
final taxManager = ref.read(taxManagerProvider);
final tax = await taxManager.readLocal(1);
```

### Adding a New Model Manager

1. Create the annotated model under `../theos_pos_core/lib/src/models/`.
2. Create the concrete manager under `../theos_pos_core/lib/src/managers/`.
3. Implement the `OdooModelManager<T>` contract exported by `odoo_sdk`.
4. Export the manager from `theos_pos_core` and add its provider in
   `manager_providers.dart` when the Flutter layer needs direct access.
5. Register it in `initializeModelManagers()` and add focused tests.

### Session and synchronization invariants

- Runtime ORM authentication is API-key Bearer over `/json/2`. The sole
  exception is the native HTTPS login bootstrap: it may hold an ephemeral
  `/web/session/authenticate` cookie just long enough to run Odoo's own API-key
  wizard. Never persist that cookie or password, use it for runtime ORM calls,
  enable it on Web, add `withCredentials`, or introduce XML-RPC call sites.
- Native session restoration uses non-secret metadata plus a credential
  reference into the platform secure store. Web credentials are intentionally
  memory-only and require login after a page refresh.
- Online login, offline login and cold-start restoration must all activate the
  `SessionScope` before exposing Drift, then call `initializeModelManagers`.
- `initializeModelManagers` rebinds every singleton manager to the active
  client, scoped database and offline queue. Logout, expiration and server/user
  changes call `resetModelManagersSession` before closing Drift.
- The application runtime does not use WebSocket. Remote reconciliation is
  HTTP JSON-2: queue-first recovery plus incremental polling; Drift streams
  propagate committed local changes to the UI.
- Writes that are explicitly offline-capable enter the durable scoped queue.
  Preserve command dependencies, idempotency keys, conflict checks, retry
  backoff and dead-letter evidence when extending it.
