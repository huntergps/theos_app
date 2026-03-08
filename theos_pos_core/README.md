# theos_pos_core

Core data layer for Theos POS - Odoo 18/19 offline-first applications.

**Pure Dart package** - No Flutter dependencies. Can be used in:
- Flutter apps (theos_pos, theos_mobile, etc.)
- Dart CLI tools
- Dart backend servers (Shelf)

## Features

- **Models**: 50+ Freezed models for Odoo entities (SaleOrder, Product, Partner, etc.)
- **Managers**: 30 OdooModelManager implementations with CRUD + sync + cache
- **Database**: Drift ORM with 75+ tables and 51 schema versions
- **Services**: Tax calculation, business logic services
- **Offline-first**: OfflineQueue, sync coordination, conflict resolution

## Installation

```yaml
dependencies:
  theos_pos_core:
    path: ../theos_pos_core
```

## Usage

### In Flutter App

```dart
import 'package:theos_pos_core/theos_pos_core.dart';
import 'package:drift_flutter/drift_flutter.dart';

void main() async {
  // Create database with Flutter executor
  final db = AppDatabase(driftDatabase(name: 'theos_pos'));

  // Initialize DatabaseHelper
  await DatabaseHelper.initializeWithDatabase(db, databaseName: 'theos_pos');

  // Use managers
  final orders = await SaleOrderManager(db).getAll();
}
```

### In CLI Tool

```dart
import 'package:theos_pos_core/theos_pos_core.dart';
import 'package:drift/native.dart';

void main() async {
  // Create database with native SQLite
  final db = AppDatabase(NativeDatabase.memory());

  // Initialize and use
  await DatabaseHelper.initializeWithDatabase(db);
  final products = await ProductManager(db).search('laptop');
}
```

## Package Structure

```
lib/
├── theos_pos_core.dart      # Main barrel export
└── src/
    ├── database/
    │   ├── database.dart     # AppDatabase (Drift)
    │   ├── tables/           # 22 table definition files
    │   ├── datasources/      # Data access objects
    │   └── repositories/     # Repository implementations
    ├── models/
    │   ├── sales/            # SaleOrder, SaleOrderLine
    │   ├── products/         # Product, ProductCategory
    │   ├── clients/          # Partner (Client)
    │   ├── collection/       # CollectionSession, Payment
    │   └── ...               # 15 feature modules
    ├── managers/
    │   ├── sales/            # SaleOrderManager
    │   ├── products/         # ProductManager
    │   └── ...               # 15 feature modules
    ├── services/
    │   └── taxes/            # TaxCalculatorService
    └── utils/
        └── precision_config.dart
```

## Dependencies

- `drift` - SQLite ORM (pure Dart)
- `freezed_annotation` - Immutable models
- `odoo_offline_core` - Odoo HTTP/WebSocket client
- `odoo_model_manager` - OdooModelManager base class

## Building

```bash
# Get dependencies
dart pub get

# Generate code (Drift, Freezed)
dart run build_runner build --delete-conflicting-outputs

# Analyze
dart analyze lib/
```

## Related Packages

- `theos_pos` - Main Flutter POS application
- `odoo_offline_core` - Odoo client infrastructure
- `odoo_model_manager` - Code generation and manager base

## License

Proprietary - Theos Systems
