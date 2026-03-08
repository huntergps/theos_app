# Propuesta: Separación de theos_pos en Paquete de Datos + Apps UI

**Fecha:** 2026-01-24
**Estado:** Propuesta
**Viabilidad:** ALTA (90%+ del código de datos es puro Dart)

---

## 1. RESUMEN EJECUTIVO

### Hallazgo Principal

El análisis del código revela que **theos_pos ya tiene una excelente separación de capas**:

| Componente | Dependencias Flutter | Extractable |
|------------|---------------------|-------------|
| 29 Managers | 0 | ✅ 100% |
| 100+ Models | 0 | ✅ 100% |
| 30+ Tables | 0 | ✅ 100% |
| 15+ Services (data) | 0 | ✅ 100% |
| Repositories | 0 | ✅ 100% |
| Screens/Widgets | Sí | ❌ Quedan en app |
| UI Providers | Sí | ❌ Quedan en app |

### Propuesta

```
ANTES (monolítico):
┌─────────────────────────────────────────┐
│              theos_pos                   │
│  ┌─────────────────────────────────────┐│
│  │ UI + Data + Models + Managers       ││
│  │ (268,516 LOC - todo mezclado)       ││
│  └─────────────────────────────────────┘│
└─────────────────────────────────────────┘

DESPUÉS (separado):
┌─────────────────────────────────────────┐
│         theos_pos_core (Dart puro)       │
│  ┌─────────────────────────────────────┐│
│  │ Models + Managers + DB + Services   ││
│  │ (~80,000 LOC - reusable)            ││
│  └─────────────────────────────────────┘│
└─────────────────────────────────────────┘
            │
            │ (dependency)
            ▼
┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐
│ theos_pos │ │ theos_web │ │ theos_cli │ │ theos_api │
│  (Flutter)│ │  (Flutter)│ │   (Dart)  │ │  (Shelf)  │
│   Full    │ │  Lite/Web │ │  Terminal │ │   REST    │
│   POS     │ │   POS     │ │   Tools   │ │  Backend  │
└───────────┘ └───────────┘ └───────────┘ └───────────┘
```

---

## 2. ARQUITECTURA PROPUESTA

### 2.1 Estructura del Paquete de Datos

```
theos_pos_core/
├── lib/
│   ├── theos_pos_core.dart              # Barrel export principal
│   │
│   ├── src/
│   │   ├── database/
│   │   │   ├── database.dart            # AppDatabase Drift
│   │   │   ├── database.g.dart          # Generado
│   │   │   ├── database_helper.dart     # Helper multi-servidor
│   │   │   ├── tables/
│   │   │   │   ├── tables.dart          # Barrel
│   │   │   │   ├── sales_tables.dart
│   │   │   │   ├── product_tables.dart
│   │   │   │   ├── accounting_tables.dart
│   │   │   │   ├── collection_tables.dart
│   │   │   │   └── ...
│   │   │   ├── datasources/
│   │   │   │   ├── datasources.dart     # Barrel
│   │   │   │   ├── offline_queue_ds.dart
│   │   │   │   └── ...
│   │   │   └── repositories/
│   │   │       ├── repositories.dart    # Barrel
│   │   │       ├── base_repository.dart
│   │   │       ├── sales_repository.dart
│   │   │       └── ...
│   │   │
│   │   ├── models/
│   │   │   ├── models.dart              # Barrel export
│   │   │   ├── sales/
│   │   │   │   ├── sale_order.model.dart
│   │   │   │   ├── sale_order.model.freezed.dart
│   │   │   │   ├── sale_order_line.model.dart
│   │   │   │   └── ...
│   │   │   ├── products/
│   │   │   │   ├── product.model.dart
│   │   │   │   ├── product_category.model.dart
│   │   │   │   └── ...
│   │   │   ├── clients/
│   │   │   │   ├── partner.model.dart
│   │   │   │   └── ...
│   │   │   ├── accounting/
│   │   │   │   ├── account_move.model.dart
│   │   │   │   ├── account_payment.model.dart
│   │   │   │   └── ...
│   │   │   └── [otros dominios]/
│   │   │
│   │   ├── managers/
│   │   │   ├── managers.dart            # Barrel export
│   │   │   ├── sales/
│   │   │   │   ├── sale_order_manager.dart
│   │   │   │   ├── sale_order_line_manager.dart
│   │   │   │   └── ...
│   │   │   ├── products/
│   │   │   │   ├── product_manager.dart
│   │   │   │   ├── product_category_manager.dart
│   │   │   │   └── ...
│   │   │   ├── clients/
│   │   │   │   └── partner_manager.dart
│   │   │   └── [otros dominios]/
│   │   │
│   │   ├── services/
│   │   │   ├── services.dart            # Barrel export
│   │   │   ├── odoo_service.dart        # Cliente Odoo
│   │   │   ├── logger_service.dart      # Logging
│   │   │   ├── sales/
│   │   │   │   ├── order_service.dart
│   │   │   │   ├── payment_service.dart
│   │   │   │   └── ...
│   │   │   ├── products/
│   │   │   │   ├── catalog_service.dart
│   │   │   │   ├── stock_service.dart
│   │   │   │   └── ...
│   │   │   └── [otros dominios]/
│   │   │
│   │   ├── sync/
│   │   │   ├── sync.dart                # Barrel
│   │   │   ├── sync_coordinator.dart
│   │   │   ├── conflict_resolver.dart
│   │   │   └── offline_queue_processor.dart
│   │   │
│   │   └── utils/
│   │       ├── utils.dart               # Barrel
│   │       ├── extensions/
│   │       ├── validators/
│   │       └── helpers/
│   │
│   └── exports/                         # Exports públicos
│       ├── models.dart
│       ├── managers.dart
│       ├── services.dart
│       └── database.dart
│
├── test/
│   ├── managers/
│   ├── services/
│   ├── models/
│   └── database/
│
└── pubspec.yaml
```

### 2.2 Dependencias del Paquete Core

```yaml
# theos_pos_core/pubspec.yaml
name: theos_pos_core
description: Data layer for Theos POS - Odoo 18/19 offline-first
version: 1.0.0

environment:
  sdk: ^3.10.0

dependencies:
  # Database (Drift - Dart puro)
  drift: ^2.20.3
  sqlite3: ^2.4.0  # Para CLI/backend
  path: ^1.9.0

  # Serialización (Dart puro)
  freezed_annotation: ^3.0.0
  json_annotation: ^4.9.0

  # HTTP (Dart puro)
  dio: ^5.4.0
  dio_cookie_manager: ^3.1.1
  cookie_jar: ^4.0.8

  # WebSocket (Dart puro)
  web_socket_channel: ^3.0.3

  # Utilidades (Dart puro)
  uuid: ^4.5.2
  intl: ^0.20.2
  dartz: ^0.10.1
  rxdart: ^0.28.0
  collection: ^1.18.0

  # Paquetes locales
  odoo_offline_core:
    path: ../odoo_offline_core
  odoo_model_manager:
    path: ../odoo_model_manager

dev_dependencies:
  build_runner: ^2.10.5
  drift_dev: ^2.20.3
  freezed: ^3.0.0
  json_serializable: ^6.8.0
  test: ^1.24.0
  mocktail: ^1.0.0
```

### 2.3 Estructura de Apps Clientes

#### App Flutter Principal (theos_pos)

```
theos_pos/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   │
│   ├── core/
│   │   ├── navigation/
│   │   │   └── app_router.dart
│   │   ├── theme/
│   │   │   ├── theme.dart
│   │   │   └── spacing.dart
│   │   ├── providers/
│   │   │   ├── core_providers.dart      # Inicializa theos_pos_core
│   │   │   └── ui_providers.dart
│   │   └── di/
│   │       └── injection.dart           # Service locator
│   │
│   ├── features/
│   │   ├── sales/
│   │   │   ├── screens/
│   │   │   ├── widgets/
│   │   │   └── providers/               # UI state only
│   │   ├── collection/
│   │   │   ├── screens/
│   │   │   ├── widgets/
│   │   │   └── providers/
│   │   └── [otros features UI]/
│   │
│   └── shared/
│       ├── screens/
│       └── widgets/
│
└── pubspec.yaml
```

```yaml
# theos_pos/pubspec.yaml
dependencies:
  flutter:
    sdk: flutter

  # Core data package
  theos_pos_core:
    path: ../theos_pos_core

  # Flutter-specific
  flutter_riverpod: ^3.0.0
  riverpod_annotation: ^4.0.0
  go_router: ^17.0.1
  fluent_ui: ^4.13.0

  # Flutter DB
  drift_flutter: ^0.2.8
  sqlite3_flutter_libs: ^0.5.0

  # UI Components
  syncfusion_flutter_datagrid: ^32.1.23
  syncfusion_flutter_pdf: ^32.1.23
```

#### App Web Lite (theos_web)

```yaml
# theos_web/pubspec.yaml
dependencies:
  flutter:
    sdk: flutter

  theos_pos_core:
    path: ../theos_pos_core

  # Web-specific
  flutter_riverpod: ^3.0.0
  go_router: ^17.0.1
  # UI más ligera para web
```

#### CLI Tools (theos_cli)

```yaml
# theos_cli/pubspec.yaml
dependencies:
  theos_pos_core:
    path: ../theos_pos_core

  # CLI-specific (Dart puro)
  args: ^2.4.0
  cli_util: ^0.4.0

  # SQLite para CLI
  sqlite3: ^2.4.0
```

```dart
// theos_cli/bin/sync.dart
import 'package:theos_pos_core/theos_pos_core.dart';

void main(List<String> args) async {
  final db = AppDatabase(NativeDatabase.memory());
  final saleManager = SaleOrderManager(db);

  // Sincronizar ventas desde línea de comandos
  final result = await saleManager.syncFromServer();
  print('Synced ${result.count} orders');
}
```

---

## 3. DIAGRAMA DE DEPENDENCIAS

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           CAPA DE APLICACIONES                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │  theos_pos  │  │  theos_web  │  │  theos_cli  │  │  theos_api  │     │
│  │  (Flutter)  │  │  (Flutter)  │  │   (Dart)    │  │  (Shelf)    │     │
│  │   Desktop   │  │    Web      │  │  Terminal   │  │   REST      │     │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘     │
│         │                │                │                │            │
│         └────────────────┴────────────────┴────────────────┘            │
│                                   │                                      │
│                                   ▼                                      │
└─────────────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────────────┐
│                          CAPA DE DATOS CORE                              │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                      theos_pos_core                              │    │
│  │                        (Dart puro)                               │    │
│  │  ┌──────────────────────────────────────────────────────────┐   │    │
│  │  │ Models   │ Managers │ Services │ Database │ Sync/Queue  │   │    │
│  │  └──────────────────────────────────────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                   │                                      │
│                                   ▼                                      │
└─────────────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────────────┐
│                         PAQUETES COMPARTIDOS                             │
│  ┌───────────────────────┐         ┌───────────────────────────────┐    │
│  │  odoo_offline_core    │         │     odoo_model_manager        │    │
│  │  (HTTP + WebSocket    │◀────────│  (OdooModelManager<T> base)   │    │
│  │   + Sync infra)       │         │                               │    │
│  └───────────────────────┘         └───────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 4. PATRÓN DE INICIALIZACIÓN

### 4.1 En App Flutter

```dart
// theos_pos/lib/core/di/injection.dart
import 'package:theos_pos_core/theos_pos_core.dart';
import 'package:drift_flutter/drift_flutter.dart';

class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._();
  factory ServiceLocator() => _instance;
  ServiceLocator._();

  late final AppDatabase _database;
  late final SaleOrderManager _saleOrderManager;
  late final ProductManager _productManager;
  // ... otros managers

  Future<void> initialize(String dbPath) async {
    // Inicializar base de datos con driver Flutter
    _database = AppDatabase(DriftFlutterDatabase(dbPath));

    // Inicializar managers
    _saleOrderManager = SaleOrderManager(_database);
    _productManager = ProductManager(_database);
    // ...
  }

  SaleOrderManager get saleOrderManager => _saleOrderManager;
  ProductManager get productManager => _productManager;
}

// Provider para Riverpod
@Riverpod(keepAlive: true)
ServiceLocator serviceLocator(ref) => ServiceLocator();

@Riverpod(keepAlive: true)
SaleOrderManager saleOrderManager(ref) {
  return ref.watch(serviceLocatorProvider).saleOrderManager;
}
```

### 4.2 En CLI

```dart
// theos_cli/lib/src/cli_app.dart
import 'package:theos_pos_core/theos_pos_core.dart';
import 'package:sqlite3/sqlite3.dart';

class CliApp {
  late final AppDatabase _database;
  late final SaleOrderManager _saleOrderManager;

  Future<void> initialize(String dbPath) async {
    // Inicializar con sqlite3 puro (sin Flutter)
    final sqlite = sqlite3.open(dbPath);
    _database = AppDatabase(NativeDatabase.opened(sqlite));

    _saleOrderManager = SaleOrderManager(_database);
  }

  Future<void> syncOrders() async {
    final orders = await _saleOrderManager.syncFromServer();
    print('Synced ${orders.length} orders');
  }
}
```

---

## 5. BENEFICIOS

### 5.1 Reutilización de Código

| Escenario | Sin Separación | Con Separación |
|-----------|----------------|----------------|
| Nueva app web lite | Duplicar 80,000 LOC | Importar paquete |
| CLI de sincronización | Imposible | 50 LOC |
| API REST backend | Imposible | Shelf + paquete |
| Tests unitarios | Necesitan Flutter | Dart puro, más rápidos |
| Desarrollo paralelo | Conflictos | Equipos independientes |

### 5.2 Testabilidad Mejorada

```dart
// test/managers/sale_order_manager_test.dart
// Sin necesidad de Flutter test runner
import 'package:test/test.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

void main() {
  late AppDatabase db;
  late SaleOrderManager manager;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    manager = SaleOrderManager(db);
  });

  test('create order', () async {
    final order = SaleOrder(/* ... */);
    final result = await manager.create(order);
    expect(result.id, isPositive);
  });
}
```

### 5.3 Arquitectura Multi-Plataforma

```
theos_pos_core → Dart puro
    │
    ├── theos_pos (Flutter Desktop/Mobile) → POS completo
    ├── theos_web (Flutter Web) → POS web
    ├── theos_cli (Dart CLI) → Herramientas de admin
    ├── theos_api (Shelf) → Backend REST
    └── theos_worker (Dart Isolate) → Background sync
```

---

## 6. PLAN DE MIGRACIÓN

### Fase 1: Preparación (1-2 días)

```bash
# Crear estructura del paquete
mkdir -p theos_pos_core/lib/src/{database,models,managers,services,sync,utils}
mkdir -p theos_pos_core/test/{database,models,managers,services}

# Crear pubspec.yaml
touch theos_pos_core/pubspec.yaml

# Crear barrel exports
touch theos_pos_core/lib/theos_pos_core.dart
```

### Fase 2: Mover Database (1 día)

```bash
# Mover tablas y database
mv theos_pos/lib/core/database/tables/* theos_pos_core/lib/src/database/tables/
mv theos_pos/lib/core/database/database.dart theos_pos_core/lib/src/database/
mv theos_pos/lib/core/database/datasources/* theos_pos_core/lib/src/database/datasources/
mv theos_pos/lib/core/database/repositories/* theos_pos_core/lib/src/database/repositories/

# Regenerar código
cd theos_pos_core && dart run build_runner build
```

### Fase 3: Mover Models (1 día)

```bash
# Mover todos los modelos por feature
for feature in sales products clients collection invoices taxes; do
  mv theos_pos/lib/features/$feature/models/* theos_pos_core/lib/src/models/$feature/
done

# Regenerar Freezed
dart run build_runner build
```

### Fase 4: Mover Managers (1 día)

```bash
# Mover managers
for feature in sales products clients collection invoices; do
  mv theos_pos/lib/features/$feature/managers/* theos_pos_core/lib/src/managers/$feature/
done

# Actualizar imports
```

### Fase 5: Mover Services (1 día)

```bash
# Mover solo servicios de datos (no UI)
mv theos_pos/lib/features/sales/services/order_service.dart theos_pos_core/lib/src/services/sales/
mv theos_pos/lib/features/sales/services/payment_service.dart theos_pos_core/lib/src/services/sales/
# ... etc
```

### Fase 6: Actualizar theos_pos (1 día)

```yaml
# theos_pos/pubspec.yaml
dependencies:
  theos_pos_core:
    path: ../theos_pos_core
```

```dart
// Actualizar imports en toda la app
// Antes:
import '../../../core/database/database.dart';
import '../../sales/managers/sale_order_manager.dart';

// Después:
import 'package:theos_pos_core/theos_pos_core.dart';
```

### Fase 7: Tests y Validación (1-2 días)

```bash
# Tests del core
cd theos_pos_core && dart test

# Tests de la app
cd theos_pos && flutter test

# Verificar que todo compila
flutter analyze
```

---

## 7. RIESGOS Y MITIGACIONES

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| Breaking changes en imports | Alta | Medio | Script de migración automático |
| Código con dependencia Flutter oculta | Baja | Alto | Análisis estático antes de mover |
| Conflictos de versiones | Media | Medio | Pinear versiones exactas |
| Tests fallando | Media | Medio | Migrar tests junto con código |
| odoo_offline_core tiene Flutter | Alta | Alto | Separar en dos paquetes |

### Mitigación Principal: odoo_offline_core

El paquete `odoo_offline_core` actualmente tiene dependencia de Flutter. Opciones:

**Opción A:** Separar en dos paquetes
```
odoo_offline_core_dart (puro)
odoo_offline_core_flutter (extensiones Flutter)
```

**Opción B:** Hacer el paquete Dart-puro
- Remover dependencias Flutter
- Mover código Flutter-específico a theos_pos

**Recomendación:** Opción B es más limpia a largo plazo.

---

## 8. CONCLUSIÓN

### Viabilidad: ALTA ✅

La separación es **altamente viable** porque:

1. **0 dependencias Flutter** en managers, models, services de datos
2. **Arquitectura ya modular** por features
3. **Patrones claros** (Repository, Manager, Service)
4. **Tests existentes** son mayormente de lógica de datos

### Esfuerzo Estimado

| Fase | Días |
|------|------|
| Preparación | 1-2 |
| Database | 1 |
| Models | 1 |
| Managers | 1 |
| Services | 1 |
| Update App | 1 |
| Testing | 1-2 |
| **Total** | **7-10 días** |

### Recomendación

**Proceder con la separación.** Los beneficios superan ampliamente el esfuerzo:

- ✅ Múltiples apps desde un core común
- ✅ Tests más rápidos (sin Flutter)
- ✅ CLI y herramientas de admin
- ✅ Desarrollo paralelo de equipos
- ✅ Mejor mantenibilidad a largo plazo

---

*Propuesta generada el 2026-01-24*
