# 🏗️ Arquitectura del Proyecto theos_pos

## 📋 Tabla de Contenidos

- [Visión General](#visión-general)
- [Clean Architecture](#clean-architecture)
- [Dependency Inversion Principle](#dependency-inversion-principle)
- [Estructura de Carpetas](#estructura-de-carpetas)
- [Layers (Capas)](#layers-capas)
- [Flujo de Datos](#flujo-de-datos)
- [Patrones de Diseño](#patrones-de-diseño)
- [Guías de Uso](#guías-de-uso)
- [Testing](#testing)
- [Migración a theos_pos_core](#migración-a-theos_pos_core)

---

## Visión General

Este proyecto implementa **Clean Architecture** con **Dependency Inversion Principle (DIP)**, separando el código en capas bien definidas que promueven:

- ✅ **Testabilidad**: Interfaces permiten mocking fácil
- ✅ **Mantenibilidad**: Cambios en una capa no afectan otras
- ✅ **Escalabilidad**: Fácil agregar nuevas features
- ✅ **Reutilización**: Lógica compartida en `theos_pos_core`

### Arquitectura en 3 Capas

```
┌─────────────────────────────────────┐
│   Presentation Layer (UI)           │  ← Flutter Widgets, Riverpod
├─────────────────────────────────────┤
│   Domain Layer (Business Logic)     │  ← Repositories, Models
├─────────────────────────────────────┤
│   Data Layer (Datasources)          │  ← SQLite/Drift, API
└─────────────────────────────────────┘
```

---

## Clean Architecture

### Principios Aplicados

#### 1. Dependency Rule

**Las dependencias apuntan hacia adentro** (hacia el dominio):

```
Presentation (UI)
    ↓ depends on
Domain (Repositories) ← define interfaces
    ↑ implemented by
Data (Datasources) ← implementa interfaces
```

#### 2. Entities (Models)

Definidos en `theos_pos_core/lib/src/models/`:

```dart
@freezed
class Client with _$Client {
  const factory Client({
    required int id,
    required String name,
    String? vat,
    String? email,
  }) = _Client;
}
```

#### 3. Use Cases (Repositories)

Contienen lógica de negocio:

```dart
class ClientRepository {
  final IPartnerDatasource _datasource; // ← Interfaz, no implementación

  Future<Client?> getById(int id) async {
    return await _datasource.getPartner(id);
  }
}
```

#### 4. Interface Adapters (Datasources)

Implementan interfaces definidas en `theos_pos_core`:

```dart
// Interface (en theos_pos_core)
abstract class IPartnerDatasource {
  Future<Client?> getPartner(int id);
}

// Implementation (en theos_pos)
class PartnerDatasource implements IPartnerDatasource {
  final AppDatabase _db;

  @override
  Future<Client?> getPartner(int id) async {
    // Implementación con SQLite/Drift
  }
}
```

---

## Dependency Inversion Principle

### ¿Qué es DIP?

> "Los módulos de alto nivel no deben depender de módulos de bajo nivel. Ambos deben depender de abstracciones."

### Implementación en el Proyecto

#### ❌ Antes (Acoplamiento Fuerte)

```dart
class ClientRepository {
  final PartnerDatasource _datasource; // ← Implementación concreta

  ClientRepository(PartnerDatasource datasource);
}

// Problema: No se puede cambiar implementación sin modificar repository
// Problema: No se puede testear sin base de datos real
```

#### ✅ Después (Dependency Inversion)

```dart
class ClientRepository {
  final IPartnerDatasource _datasource; // ← Abstracción (interfaz)

  ClientRepository(IPartnerDatasource datasource);
}

// Beneficio: Se puede inyectar cualquier implementación
// Beneficio: Fácil crear mocks para testing
```

### Inyección de Dependencias con Riverpod

```dart
// Provider devuelve interfaz, no implementación
final partnerDatasourceProvider = Provider<IPartnerDatasource>((ref) {
  return PartnerDatasource(DatabaseHelper.db); // ← Implementación concreta
});

final clientRepositoryProvider = Provider((ref) {
  return ClientRepository(
    partnerDatasource: ref.read(partnerDatasourceProvider), // ← Interfaz
  );
});
```

---

## Estructura de Carpetas

### theos_pos_core (Shared/Core Package)

```
theos_pos_core/
├── lib/
│   ├── src/
│   │   ├── models/              # Entities (Domain)
│   │   │   ├── client.dart
│   │   │   ├── sale_order.dart
│   │   │   └── ...
│   │   ├── datasources/         # Interface Contracts
│   │   │   ├── partner_datasource.dart (IPartnerDatasource)
│   │   │   ├── sale_order_datasource.dart (ISaleOrderDatasource)
│   │   │   └── datasources.dart (barrel file)
│   │   └── managers/            # Business Logic
│   │       └── sale_order_manager.dart
│   └── theos_pos_core.dart      # Main export
└── pubspec.yaml
```

### theos_pos (Application)

```
theos_pos/
├── lib/
│   ├── features/                # Feature-based organization
│   │   ├── clients/
│   │   │   ├── datasources/     # Data Layer (implementations)
│   │   │   │   └── partner_datasource.dart (implements IPartnerDatasource)
│   │   │   ├── repositories/    # Domain Layer
│   │   │   │   └── client_repository.dart
│   │   │   ├── providers/       # Dependency Injection
│   │   │   │   ├── datasource_providers.dart
│   │   │   │   └── repository_providers.dart
│   │   │   └── widgets/         # Presentation Layer
│   │   │       └── client_list.dart
│   │   ├── sales/
│   │   ├── collection/
│   │   └── ...
│   └── core/
│       ├── database/            # Infrastructure
│       │   └── database.dart (Drift/SQLite)
│       └── services/            # Cross-cutting concerns
│           └── logger_service.dart
├── test/                        # Unit tests with mocks
└── pubspec.yaml
```

---

## Layers (Capas)

### 1. Presentation Layer

**Responsabilidad**: UI y manejo de eventos

**Tecnologías**: Flutter Widgets, Riverpod

**Archivos**: `lib/features/*/widgets/`

```dart
class ClientListWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(clientRepositoryProvider);

    return FutureBuilder(
      future: repository.search(''),
      builder: (context, snapshot) {
        // Render UI
      },
    );
  }
}
```

**Reglas**:
- No contiene lógica de negocio
- Solo usa Repositories, no Datasources directamente
- Maneja estado con Riverpod

---

### 2. Domain Layer

**Responsabilidad**: Lógica de negocio

**Archivos**: `lib/features/*/repositories/`

```dart
class ClientRepository extends BaseRepository {
  final IPartnerDatasource _datasource; // ← Usa interfaz

  Future<Client?> getById(int id) async {
    // 1. Get from local cache
    final localClient = await _datasource.getPartner(id);

    // 2. Refresh from Odoo if online
    if (isOnline && needsRefresh(localClient)) {
      final fresh = await refreshCreditData(id);
      return fresh;
    }

    return localClient;
  }
}
```

**Reglas**:
- Contiene lógica de negocio (offline-first, caching, etc.)
- Depende de interfaces (IXxxDatasource), no implementaciones
- No conoce detalles de SQLite, Drift, o HTTP

---

### 3. Data Layer

**Responsabilidad**: Acceso a datos

**Archivos**: `lib/features/*/datasources/`

```dart
class PartnerDatasource implements IPartnerDatasource {
  final AppDatabase _db; // ← Detalle de implementación (SQLite)

  @override
  Future<Client?> getPartner(int id) async {
    final data = await (_db.select(_db.resPartner)
          ..where((t) => t.odooId.equals(id)))
        .getSingleOrNull();

    return data != null ? Client.fromDatabase(data) : null;
  }
}
```

**Reglas**:
- Implementa interfaces definidas en `theos_pos_core`
- Conoce detalles de persistencia (SQL, HTTP, etc.)
- No contiene lógica de negocio

---

## Flujo de Datos

### Lectura (Offline-First)

```
┌─────────┐
│   UI    │ "Necesito cliente #123"
└────┬────┘
     │
     ↓ ref.read(clientRepositoryProvider)
┌─────────────┐
│ Repository  │ 1. Buscar en cache local
└─────┬───────┘
      │
      ↓ datasource.getPartner(123)
┌─────────────┐
│ Datasource  │ 2. Query SQLite
└─────┬───────┘
      │
      ↓ SELECT * FROM res_partner WHERE odoo_id = 123
┌─────────────┐
│  Database   │ 3. Retornar datos
└─────────────┘
```

### Escritura (con Sync)

```
┌─────────┐
│   UI    │ "Crear cliente nuevo"
└────┬────┘
     │
     ↓
┌─────────────┐
│ Repository  │ 1. Guardar local
└─────┬───────┘    2. Intentar sync con Odoo
      │            3. Si falla, encolar
      ↓
┌─────────────┐
│ Datasource  │ INSERT INTO res_partner ...
└─────┬───────┘
      │
      ↓
┌─────────────┐
│  Database   │ Guardado local ✓
└─────────────┘
      │
      ↓ (si online)
┌─────────────┐
│ Odoo API    │ Sync remoto
└─────────────┘
```

---

## Patrones de Diseño

### 1. Repository Pattern

**Propósito**: Abstraer acceso a datos

```dart
// Repository = Colección de objetos
class ClientRepository {
  Future<Client?> getById(int id);
  Future<List<Client>> search(String query);
  Future<void> save(Client client);
}
```

### 2. Dependency Injection

**Propósito**: Proveer dependencias desde afuera

```dart
// Con Riverpod
final datasourceProvider = Provider<IPartnerDatasource>(...);

final repositoryProvider = Provider((ref) {
  return ClientRepository(
    datasource: ref.read(datasourceProvider), // ← Inyectado
  );
});
```

### 3. Offline-First Pattern

**Propósito**: App funciona sin internet

```dart
Future<Client?> getById(int id) async {
  // 1. Local first
  final cached = await _datasource.getPartner(id);

  // 2. Refresh if online
  if (isOnline) {
    try {
      return await refreshCreditData(id);
    } catch (_) {
      return cached; // Fallback to cache
    }
  }

  return cached;
}
```

### 4. Interface Segregation

**Propósito**: Interfaces pequeñas y específicas

```dart
// ✅ Bueno: Interfaz específica
abstract class IPartnerDatasource {
  Future<Client?> getPartner(int id);
  Future<void> upsertPartner(Client partner);
}

// ❌ Malo: Interfaz muy grande
abstract class IMegaDatasource {
  // 50 métodos mezclados...
}
```

---

## Guías de Uso

### Crear un Nuevo Feature

#### 1. Definir Model en `theos_pos_core`

```dart
// theos_pos_core/lib/src/models/product.dart
@freezed
class Product with _$Product {
  const factory Product({
    required int id,
    required String name,
    double? price,
  }) = _Product;
}
```

#### 2. Definir Interface en `theos_pos_core`

```dart
// theos_pos_core/lib/src/datasources/product_datasource.dart
abstract class IProductDatasource {
  Future<Product?> getProduct(int id);
  Future<List<Product>> searchProducts(String query);
  Future<void> upsertProduct(Product product);
}
```

#### 3. Implementar Datasource en `theos_pos`

```dart
// theos_pos/lib/features/products/datasources/product_datasource.dart
import 'package:theos_pos_core/theos_pos_core.dart' show IProductDatasource, Product;

class ProductDatasource implements IProductDatasource {
  final AppDatabase _db;

  @override
  Future<Product?> getProduct(int id) async {
    // Implementación con SQLite
  }
}
```

#### 4. Crear Repository en `theos_pos`

```dart
// theos_pos/lib/features/products/repositories/product_repository.dart
class ProductRepository extends BaseRepository {
  final IProductDatasource _datasource; // ← Interfaz

  Future<Product?> getById(int id) async {
    return await _datasource.getProduct(id);
  }
}
```

#### 5. Crear Providers

```dart
// theos_pos/lib/features/products/providers/datasource_providers.dart
final productDatasourceProvider = Provider<IProductDatasource>((ref) {
  return ProductDatasource(DatabaseHelper.db);
});

// theos_pos/lib/features/products/providers/repository_providers.dart
final productRepositoryProvider = Provider((ref) {
  return ProductRepository(
    datasource: ref.read(productDatasourceProvider),
  );
});
```

#### 6. Usar en Widget

```dart
class ProductList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(productRepositoryProvider);

    return FutureBuilder(
      future: repo.search(''),
      builder: (context, snapshot) {
        // Render products
      },
    );
  }
}
```

---

## Testing

### Unit Tests con Mocks

```dart
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([IProductDatasource])
void main() {
  late MockIProductDatasource mockDatasource;
  late ProductRepository repository;

  setUp(() {
    mockDatasource = MockIProductDatasource();
    repository = ProductRepository(datasource: mockDatasource);
  });

  test('getById returns product', () async {
    // Arrange
    final testProduct = Product(id: 1, name: 'Test');
    when(mockDatasource.getProduct(1))
        .thenAnswer((_) async => testProduct);

    // Act
    final result = await repository.getById(1);

    // Assert
    expect(result?.name, equals('Test'));
    verify(mockDatasource.getProduct(1)).called(1);
  });
}
```

**Ver más**: [test/README_TESTS.md](test/README_TESTS.md)

---

## Migración a theos_pos_core

### Estado Actual

#### ✅ Migrado (100%)

- **Models**: Client, SaleOrder, CollectionSession, etc. (en `theos_pos_core`)
- **Interfaces**: 12 datasource interfaces creadas
- **Datasources**: 9 implementaciones usan interfaces
- **Repositories**: 5 repositories usan DIP

#### 📊 Estadísticas

| Componente | Migrado | Total | % |
|------------|---------|-------|---|
| Models principales | 15 | 15 | 100% |
| Datasource interfaces | 12 | 12 | 100% |
| Datasource implementations | 9 | 9 | 100% |
| Repositories con DIP | 5 | 5 | 100% |

### Documentos de Migración

- [MIGRATION_COMPLETE.md](MIGRATION_COMPLETE.md) - Resumen ejecutivo completo
- [FASE1_COMPLETE.md](FASE1_COMPLETE.md) - Detalles de migración de datasources
- [FASE2_COMPLETE.md](FASE2_COMPLETE.md) - Detalles de migración de repositories

---

## 📚 Recursos Adicionales

### Documentación del Proyecto

- [ARCHITECTURE.md](ARCHITECTURE.md) - Este documento
- [MIGRATION_COMPLETE.md](MIGRATION_COMPLETE.md) - Guía de migración
- [test/README_TESTS.md](test/README_TESTS.md) - Guía de testing

### Clean Architecture

- [The Clean Architecture (Uncle Bob)](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Flutter Clean Architecture](https://resocoder.com/2019/08/27/flutter-tdd-clean-architecture-course-1-explanation-project-structure/)

### SOLID Principles

- [Dependency Inversion Principle](https://stackify.com/dependency-inversion-principle/)
- [SOLID in Dart](https://medium.com/flutter-community/s-o-l-i-d-the-first-5-principles-of-object-oriented-design-with-dart-f31d62135b7e)

### Riverpod

- [Riverpod Documentation](https://riverpod.dev/)
- [Provider Pattern with Riverpod](https://codewithandrea.com/articles/flutter-state-management-riverpod/)

---

## ✅ Checklist para Nuevos Desarrolladores

- [ ] Leer este documento completo
- [ ] Revisar [MIGRATION_COMPLETE.md](MIGRATION_COMPLETE.md)
- [ ] Entender estructura de `theos_pos_core` vs `theos_pos`
- [ ] Revisar ejemplos de tests en `test/`
- [ ] Crear un feature simple siguiendo la guía
- [ ] Ejecutar tests con `flutter test`
- [ ] Familiarizarse con Riverpod providers

---

**Última actualización**: 2026-01-25
**Versión de arquitectura**: 2.0 (con DIP)
**Mantenedor**: Equipo theos_pos
