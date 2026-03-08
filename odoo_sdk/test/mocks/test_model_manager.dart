import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

/// Simple test record class for testing OdooModelManager.
class TestProduct {
  final int id;
  final String? uuid;
  final String name;
  final double price;
  final bool active;
  final bool isSynced;
  final DateTime? writeDate;

  const TestProduct({
    required this.id,
    this.uuid,
    required this.name,
    required this.price,
    this.active = true,
    this.isSynced = false,
    this.writeDate,
  });

  TestProduct copyWith({
    int? id,
    String? uuid,
    String? name,
    double? price,
    bool? active,
    bool? isSynced,
    DateTime? writeDate,
  }) {
    return TestProduct(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      price: price ?? this.price,
      active: active ?? this.active,
      isSynced: isSynced ?? this.isSynced,
      writeDate: writeDate ?? this.writeDate,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestProduct &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          uuid == other.uuid &&
          name == other.name &&
          price == other.price &&
          active == other.active &&
          isSynced == other.isSynced;

  @override
  int get hashCode =>
      id.hashCode ^
      uuid.hashCode ^
      name.hashCode ^
      price.hashCode ^
      active.hashCode ^
      isSynced.hashCode;

  @override
  String toString() =>
      'TestProduct(id: $id, uuid: $uuid, name: $name, price: $price, active: $active, synced: $isSynced)';
}

/// Mock GeneratedDatabase for testing.
class MockDatabase extends Mock implements GeneratedDatabase {}

/// Concrete implementation of OdooModelManager for testing.
///
/// This allows testing the base OdooModelManager functionality without
/// needing generated code. Uses an in-memory store for local operations.
///
/// Usage:
/// ```dart
/// final manager = TestProductManager();
/// manager.initialize(
///   client: mockClient,
///   db: mockDb,
///   queue: mockQueue,
/// );
///
/// // Test CRUD operations
/// final id = await manager.create(TestProduct(id: 0, name: 'Test', price: 10.0));
/// final product = await manager.read(id);
/// ```
class TestProductManager extends OdooModelManager<TestProduct> {
  // In-memory storage
  final Map<int, TestProduct> _storage = {};
  final Map<String, int> _uuidIndex = {};

  @override
  String get odooModel => 'product.product';

  @override
  String get tableName => 'product_product';

  @override
  List<String> get odooFields => [
        'id',
        'name',
        'list_price',
        'active',
        'write_date',
      ];

  @override
  bool get supportsSoftDelete => true;

  @override
  bool get trackWriteDate => true;

  // ═══════════════════════════════════════════════════════════════════════════
  // Abstract Method Implementations
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  TestProduct fromOdoo(Map<String, dynamic> data) {
    return TestProduct(
      id: data['id'] as int,
      name: (data['name'] ?? '') as String,
      price: (data['list_price'] ?? 0.0) is int
          ? (data['list_price'] as int).toDouble()
          : (data['list_price'] ?? 0.0) as double,
      active: (data['active'] ?? true) as bool,
      isSynced: true,
      writeDate: data['write_date'] != null
          ? DateTime.tryParse(data['write_date'] as String)
          : null,
    );
  }

  @override
  Map<String, dynamic> toOdoo(TestProduct record) {
    return {
      if (record.id > 0) 'id': record.id,
      'name': record.name,
      'list_price': record.price,
      'active': record.active,
    };
  }

  @override
  TestProduct fromDrift(dynamic row) {
    // In test context, this would convert from drift row
    // For testing, we just return from storage
    throw UnimplementedError('fromDrift not needed for in-memory tests');
  }

  @override
  int getId(TestProduct record) => record.id;

  @override
  String? getUuid(TestProduct record) => record.uuid;

  @override
  TestProduct withIdAndUuid(TestProduct record, int id, String uuid) {
    return record.copyWith(id: id, uuid: uuid);
  }

  @override
  TestProduct withSyncStatus(TestProduct record, bool isSynced) {
    return record.copyWith(isSynced: isSynced);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Local Database Operations (In-Memory Implementation)
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<TestProduct?> readLocal(int id) async {
    return _storage[id];
  }

  @override
  Future<TestProduct?> readLocalByUuid(String uuid) async {
    final id = _uuidIndex[uuid];
    if (id == null) return null;
    return _storage[id];
  }

  @override
  Future<List<TestProduct>> searchLocal({
    List<dynamic>? domain,
    int? limit,
    int? offset,
    String? orderBy,
  }) async {
    var results = _storage.values.toList();

    // Apply simple domain filtering for testing
    if (domain != null) {
      for (final clause in domain) {
        if (clause is List && clause.length >= 3) {
          final field = clause[0] as String;
          final operator = clause[1] as String;
          final value = clause[2];

          results = results.where((p) {
            switch (field) {
              case 'name':
                return _matchOperator(p.name, operator, value);
              case 'active':
                return _matchOperator(p.active, operator, value);
              case 'list_price':
                return _matchOperator(p.price, operator, value);
              default:
                return true;
            }
          }).toList();
        }
      }
    }

    // Apply ordering
    if (orderBy != null) {
      final parts = orderBy.split(' ');
      final field = parts[0];
      final desc = parts.length > 1 && parts[1].toUpperCase() == 'DESC';

      results.sort((a, b) {
        int compare;
        switch (field) {
          case 'name':
            compare = a.name.compareTo(b.name);
            break;
          case 'list_price':
            compare = a.price.compareTo(b.price);
            break;
          case 'id':
            compare = a.id.compareTo(b.id);
            break;
          default:
            compare = 0;
        }
        return desc ? -compare : compare;
      });
    }

    // Apply offset
    if (offset != null && offset > 0) {
      if (offset >= results.length) {
        results = [];
      } else {
        results = results.sublist(offset);
      }
    }

    // Apply limit
    if (limit != null && limit < results.length) {
      results = results.sublist(0, limit);
    }

    return results;
  }

  bool _matchOperator(dynamic fieldValue, String operator, dynamic value) {
    switch (operator) {
      case '=':
        return fieldValue == value;
      case '!=':
        return fieldValue != value;
      case '>':
        return (fieldValue as Comparable).compareTo(value) > 0;
      case '>=':
        return (fieldValue as Comparable).compareTo(value) >= 0;
      case '<':
        return (fieldValue as Comparable).compareTo(value) < 0;
      case '<=':
        return (fieldValue as Comparable).compareTo(value) <= 0;
      case 'like':
      case 'ilike':
        final pattern = (value as String)
            .replaceAll('%', '.*')
            .replaceAll('_', '.');
        return RegExp(pattern, caseSensitive: operator == 'like')
            .hasMatch(fieldValue.toString());
      case 'in':
        return (value as List).contains(fieldValue);
      case 'not in':
        return !(value as List).contains(fieldValue);
      default:
        return true;
    }
  }

  @override
  Future<int> countLocal({List<dynamic>? domain}) async {
    final results = await searchLocal(domain: domain);
    return results.length;
  }

  @override
  Future<void> upsertLocal(TestProduct record) async {
    _storage[record.id] = record;
    if (record.uuid != null) {
      _uuidIndex[record.uuid!] = record.id;
    }
  }

  @override
  Future<void> deleteLocal(int id) async {
    final record = _storage.remove(id);
    if (record?.uuid != null) {
      _uuidIndex.remove(record!.uuid);
    }
  }

  @override
  Future<List<TestProduct>> getUnsyncedRecords() async {
    return _storage.values.where((p) => !p.isSynced).toList();
  }

  @override
  Future<DateTime?> getLastWriteDate() async {
    DateTime? latest;
    for (final record in _storage.values) {
      if (record.writeDate != null) {
        if (latest == null || record.writeDate!.isAfter(latest)) {
          latest = record.writeDate;
        }
      }
    }
    return latest;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Reactive Watch (in-memory fallback — delegates to recordChanges stream)
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Stream<TestProduct?> watchLocalRecord(int id) {
    return recordChanges
        .where((e) => e.id == id)
        .asyncMap((_) => readLocal(id));
  }

  @override
  Stream<List<TestProduct>> watchLocalSearch({
    List<dynamic>? domain,
    int? limit,
    int? offset,
    String? orderBy,
  }) {
    return recordChanges
        .asyncMap((_) => searchLocal(domain: domain, limit: limit, offset: offset, orderBy: orderBy));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Test Helpers
  // ═══════════════════════════════════════════════════════════════════════════

  /// Clear all in-memory storage.
  void clearStorage() {
    _storage.clear();
    _uuidIndex.clear();
  }

  /// Get all records in storage (for test assertions).
  List<TestProduct> get allRecords => _storage.values.toList();

  /// Get storage map (for test assertions).
  Map<int, TestProduct> get storage => Map.unmodifiable(_storage);

  /// Seed storage with test data.
  void seedStorage(List<TestProduct> products) {
    for (final product in products) {
      _storage[product.id] = product;
      if (product.uuid != null) {
        _uuidIndex[product.uuid!] = product.id;
      }
    }
  }
}

/// Factory for creating test products.
class TestProductFactory {
  static int _counter = 1;

  /// Create a product with auto-incrementing ID.
  static TestProduct create({
    int? id,
    String? uuid,
    String? name,
    double? price,
    bool active = true,
    bool isSynced = false,
  }) {
    final productId = id ?? _counter++;
    return TestProduct(
      id: productId,
      uuid: uuid,
      name: name ?? 'Product $productId',
      price: price ?? (productId * 10.0),
      active: active,
      isSynced: isSynced,
    );
  }

  /// Create a product with a negative (local) ID.
  static TestProduct createLocal({
    String? uuid,
    String? name,
    double? price,
    bool active = true,
  }) {
    final localId = -DateTime.now().millisecondsSinceEpoch % 1000000000;
    return TestProduct(
      id: localId,
      uuid: uuid ?? 'local-$localId',
      name: name ?? 'Local Product',
      price: price ?? 99.99,
      active: active,
      isSynced: false,
    );
  }

  /// Create multiple products.
  static List<TestProduct> createMany(int count, {double basePrice = 10.0}) {
    return List.generate(count, (i) {
      final id = _counter++;
      return TestProduct(
        id: id,
        name: 'Product $id',
        price: basePrice + (i * 5.0),
        active: true,
        isSynced: false,
      );
    });
  }

  /// Reset the counter (for test isolation).
  static void reset() {
    _counter = 1;
  }
}

/// Fake TestProduct for mocktail registerFallbackValue.
class FakeTestProduct extends Fake implements TestProduct {
  @override
  int get id => 1;

  @override
  String? get uuid => 'fake-uuid';

  @override
  String get name => 'Fake Product';

  @override
  double get price => 10.0;

  @override
  bool get active => true;

  @override
  bool get isSynced => false;

  @override
  DateTime? get writeDate => null;
}

/// Register fallback values for test mocks.
void registerTestModelFallbacks() {
  registerFallbackValue(FakeTestProduct());
  registerFallbackValue(const TestProduct(id: 0, name: '', price: 0));
}
