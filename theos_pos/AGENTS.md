# Repository Guidelines

## Project Structure & Module Organization
- `lib/` holds the Flutter application code (features, core utilities, state, UI).
- `test/` contains unit and widget tests (with subfolders like `core/` and `features/`).
- `assets/` stores bundled images, icons, and other Flutter assets.
- `docs/` contains project documentation.
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
- Call out any migrations or generated-code updates in the PR description.

## Configuration & Local Setup Notes
- This repo uses Flutter; ensure the correct SDK is installed and on PATH.
- If you update dependencies, commit `pubspec.lock`.

## Model Manager Architecture (odoo_model_manager integration)

### Overview
The app uses `OdooModelManager<T>` from the `odoo_model_manager` package for unified model management. Each Odoo model has a concrete manager that bridges the annotated model with existing Drift tables.

### Files Structure
```
lib/core/managers/
├── managers.dart                    # Barrel export
├── manager_providers.dart           # Riverpod providers for managers
├── model_registry_integration.dart  # WebSocket integration
├── product_manager.dart             # ProductManager implementation
├── partner_manager.dart             # PartnerManager implementation
└── tax_manager.dart                 # TaxManager implementation
```

### Usage Example

```dart
// In app startup (e.g., SplashScreen or main.dart)
import 'package:theos_pos/core/managers/managers.dart';

// Initialize managers (call once after database is ready)
initializeModelManagers();

// Or use the provider
ref.read(modelRegistryInitializerProvider);

// Connect WebSocket events to ModelRegistry
ref.read(modelRegistryIntegrationProvider);
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

1. Create the model class in `odoo_model_manager/lib/models/`
2. Create `{model}_manager.dart` in `lib/core/managers/`
3. Implement all abstract methods from `OdooModelManager<T>`
4. Add provider in `manager_providers.dart`
5. Register in `initializeModelManagers()`
