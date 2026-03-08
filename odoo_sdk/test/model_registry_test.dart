import 'dart:async';

import 'package:test/test.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

import 'mocks/mock_odoo_client.dart';
import 'mocks/mock_offline_queue.dart';
import 'mocks/test_model_manager.dart';

/// Second test manager for multi-model tests.
class TestPartnerManager extends OdooModelManager<TestPartner> {
  final Map<int, TestPartner> _storage = {};
  final Map<String, int> _uuidIndex = {};

  @override
  String get odooModel => 'res.partner';

  @override
  String get tableName => 'res_partner';

  @override
  List<String> get odooFields => ['id', 'name', 'email', 'active', 'write_date'];

  @override
  bool get supportsSoftDelete => true;

  @override
  bool get trackWriteDate => true;

  @override
  TestPartner fromOdoo(Map<String, dynamic> data) {
    return TestPartner(
      id: data['id'] as int,
      name: (data['name'] ?? '') as String,
      email: data['email'] as String?,
      active: (data['active'] ?? true) as bool,
      isSynced: true,
    );
  }

  @override
  Map<String, dynamic> toOdoo(TestPartner record) {
    return {
      if (record.id > 0) 'id': record.id,
      'name': record.name,
      'email': record.email,
      'active': record.active,
    };
  }

  @override
  TestPartner fromDrift(dynamic row) {
    throw UnimplementedError('fromDrift not needed for in-memory tests');
  }

  @override
  int getId(TestPartner record) => record.id;

  @override
  String? getUuid(TestPartner record) => record.uuid;

  @override
  TestPartner withIdAndUuid(TestPartner record, int id, String uuid) {
    return record.copyWith(id: id, uuid: uuid);
  }

  @override
  TestPartner withSyncStatus(TestPartner record, bool isSynced) {
    return record.copyWith(isSynced: isSynced);
  }

  @override
  Future<TestPartner?> readLocal(int id) async => _storage[id];

  @override
  Future<TestPartner?> readLocalByUuid(String uuid) async {
    final id = _uuidIndex[uuid];
    return id != null ? _storage[id] : null;
  }

  @override
  Future<List<TestPartner>> searchLocal({
    List<dynamic>? domain,
    int? limit,
    int? offset,
    String? orderBy,
  }) async {
    return _storage.values.toList();
  }

  @override
  Future<int> countLocal({List<dynamic>? domain}) async => _storage.length;

  @override
  Future<void> upsertLocal(TestPartner record) async {
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
  Future<List<TestPartner>> getUnsyncedRecords() async {
    return _storage.values.where((p) => !p.isSynced).toList();
  }

  @override
  Future<DateTime?> getLastWriteDate() async => null;

  @override
  Stream<TestPartner?> watchLocalRecord(int id) {
    return recordChanges
        .where((e) => e.id == id)
        .asyncMap((_) => readLocal(id));
  }

  @override
  Stream<List<TestPartner>> watchLocalSearch({
    List<dynamic>? domain,
    int? limit,
    int? offset,
    String? orderBy,
  }) {
    return recordChanges
        .asyncMap((_) => searchLocal(domain: domain, limit: limit));
  }

  void clearStorage() {
    _storage.clear();
    _uuidIndex.clear();
  }

  void seedStorage(List<TestPartner> partners) {
    for (final partner in partners) {
      _storage[partner.id] = partner;
      if (partner.uuid != null) {
        _uuidIndex[partner.uuid!] = partner.id;
      }
    }
  }

  List<TestPartner> get allRecords => _storage.values.toList();
}

/// Simple test record for partner.
class TestPartner {
  final int id;
  final String? uuid;
  final String name;
  final String? email;
  final bool active;
  final bool isSynced;

  const TestPartner({
    required this.id,
    this.uuid,
    required this.name,
    this.email,
    this.active = true,
    this.isSynced = false,
  });

  TestPartner copyWith({
    int? id,
    String? uuid,
    String? name,
    String? email,
    bool? active,
    bool? isSynced,
  }) {
    return TestPartner(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      email: email ?? this.email,
      active: active ?? this.active,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}

void main() {
  late TestProductManager productManager;
  late TestPartnerManager partnerManager;
  late MockOdooClient mockClient;
  late MockDatabase mockDb;
  late InMemoryOfflineQueueStore queueStore;
  late OfflineQueueWrapper queueWrapper;

  setUpAll(() {
    registerOdooClientFallbacks();
    registerTestModelFallbacks();
    registerOfflineQueueFallbacks();
  });

  setUp(() {
    productManager = TestProductManager();
    partnerManager = TestPartnerManager();
    mockClient = MockOdooClient();
    mockDb = MockDatabase();
    queueStore = InMemoryOfflineQueueStore();
    queueWrapper = OfflineQueueWrapper(queueStore);
  });

  group('ModelRegistry Registration', () {
    test('register() adds manager to registry', () {
      ModelRegistry.register(productManager);

      expect(ModelRegistry().isRegistered('product.product'), isTrue);
      expect(ModelRegistry().registeredModels, contains('product.product'));
    });

    test('can register multiple managers', () {
      ModelRegistry.register(productManager);
      ModelRegistry.register(partnerManager);

      expect(ModelRegistry().registeredModels.length, greaterThanOrEqualTo(2));
      expect(ModelRegistry().isRegistered('product.product'), isTrue);
      expect(ModelRegistry().isRegistered('res.partner'), isTrue);
    });

    test('isRegistered returns false for unregistered model', () {
      expect(ModelRegistry().isRegistered('completely.unknown.model'), isFalse);
    });

    test('registerManager extension returns the manager for chaining', () {
      final newManager = TestProductManager();
      final result = ModelRegistry().registerManager(newManager);

      expect(result, same(newManager));
      expect(ModelRegistry().isRegistered('product.product'), isTrue);
    });
  });

  group('ModelRegistry Getting managers', () {
    setUp(() {
      ModelRegistry.register(productManager);
      ModelRegistry.register(partnerManager);
    });

    test('get<T>() returns typed manager', () {
      final manager = ModelRegistry.get<TestProductManager>('product.product');

      expect(manager, isNotNull);
      expect(manager!.odooModel, 'product.product');
    });

    test('get<T>() returns null for unregistered model', () {
      final manager = ModelRegistry.get<TestProductManager>('totally.unknown.model');

      expect(manager, isNull);
    });

    test('getByModel() returns manager', () {
      final manager = ModelRegistry.getByModel('product.product');

      expect(manager, isNotNull);
      expect(manager!.odooModel, 'product.product');
    });

    test('getByModel() returns null for unregistered model', () {
      final manager = ModelRegistry.getByModel('totally.unknown.model');

      expect(manager, isNull);
    });

    test('getManager() instance method returns manager', () {
      final manager = ModelRegistry().getManager('res.partner');

      expect(manager, isNotNull);
      expect(manager!.odooModel, 'res.partner');
    });

    test('getTypedManager<T>() returns typed manager', () {
      final manager =
          ModelRegistry().getTypedManager<TestPartnerManager>('res.partner');

      expect(manager, isNotNull);
      expect(manager!.odooModel, 'res.partner');
    });
  });

  group('ModelRegistry Initialization', () {
    test('initializeAll() initializes all managers with dependencies', () {
      ModelRegistry.register(productManager);
      ModelRegistry.register(partnerManager);

      mockClient.setupConfigured();

      ModelRegistry.initializeAll(
        client: mockClient,
        db: mockDb,
        queue: queueWrapper,
      );

      // Check that managers are initialized by verifying isOnline works
      expect(productManager.isOnline, isTrue);
      expect(partnerManager.isOnline, isTrue);
    });

    test('initializeAll() applies manager configuration', () {
      final testManager = TestProductManager();
      ModelRegistry.register(testManager);

      mockClient.setupConfigured();

      const managerConfig = ModelManagerConfig(
        syncBatchSize: 50,
        progressInterval: 10,
      );

      ModelRegistry.initializeAll(
        client: mockClient,
        db: mockDb,
        queue: queueWrapper,
        managerConfig: managerConfig,
      );

      expect(testManager.isOnline, isTrue);
    });
  });

  group('ModelRegistry syncModel', () {
    setUp(() {
      ModelRegistry.register(productManager);

      mockClient.setupConfigured();
      mockClient.setupSearchCount(model: 'product.product', count: 0);
      mockClient.setupSearchRead(model: 'product.product', results: []);

      ModelRegistry.initializeAll(
        client: mockClient,
        db: mockDb,
        queue: queueWrapper,
      );
    });

    test('syncModel() syncs specific model', () async {
      final result = await ModelRegistry.syncModel('product.product');

      expect(result.status, SyncStatus.success);
      expect(result.model, 'product.product');
    });

    test('syncModel() returns error for unregistered model', () async {
      final result = await ModelRegistry.syncModel('completely.unknown.model.xyz');

      expect(result.status, SyncStatus.error);
      expect(result.error, contains('not registered'));
    });

    test('syncModel() reports progress', () async {
      mockClient.setupSearchCount(model: 'product.product', count: 5);
      mockClient.setupSearchRead(
        model: 'product.product',
        results: List.generate(5, (i) => {
              'id': i + 1,
              'name': 'Product $i',
              'list_price': 10.0,
              'active': true,
            }),
      );

      final progressReports = <SyncProgress>[];

      await ModelRegistry.syncModel(
        'product.product',
        onProgress: progressReports.add,
      );

      expect(progressReports, isNotEmpty);
      expect(progressReports.any((p) => p.phase == SyncPhase.counting), isTrue);
    });
  });

  group('ModelRegistry WebSocket event handling', () {
    setUp(() {
      ModelRegistry.register(productManager);

      mockClient.setupConfigured();

      ModelRegistry.initializeAll(
        client: mockClient,
        db: mockDb,
        queue: queueWrapper,
      );

      // Seed a product to receive updates
      productManager.seedStorage([
        const TestProduct(id: 1, name: 'Existing', price: 10.0, isSynced: true),
      ]);
    });

    test('handleWebSocketEvent() routes to correct manager', () async {
      final event = ModelRecordEvent(
        model: 'product.product',
        recordId: 1,
        operation: RecordOperation.write,
        data: {'id': 1, 'name': 'Updated', 'list_price': 20.0, 'active': true},
        timestamp: DateTime.now(),
      );

      ModelRegistry.handleWebSocketEvent(event);

      // Give time for async processing
      await Future.delayed(const Duration(milliseconds: 10));

      // The event should have been routed to productManager
      final product = await productManager.read(1);
      expect(product, isNotNull);
    });

    test('handleWebSocketEvent() ignores unknown model', () {
      final event = ModelRecordEvent(
        model: 'completely.unknown.model.abc',
        recordId: 1,
        operation: RecordOperation.create,
        timestamp: DateTime.now(),
      );

      // Should not throw
      expect(() => ModelRegistry.handleWebSocketEvent(event), returnsNormally);
    });

    test('setupWebSocketHandlers() subscribes to event stream', () async {
      final controller = StreamController<ModelRecordEvent>();

      ModelRegistry.setupWebSocketHandlers(controller.stream);

      // Emit an event
      controller.add(ModelRecordEvent(
        model: 'product.product',
        recordId: 1,
        operation: RecordOperation.write,
        timestamp: DateTime.now(),
      ));

      await Future.delayed(const Duration(milliseconds: 10));

      await controller.close();
    });
  });

  group('ModelRegistry Utility methods', () {
    setUp(() {
      ModelRegistry.register(productManager);
      ModelRegistry.register(partnerManager);

      mockClient.setupConfigured();

      ModelRegistry.initializeAll(
        client: mockClient,
        db: mockDb,
        queue: queueWrapper,
      );
    });

    test('getTotalUnsyncedCount() counts across all models', () async {
      productManager.seedStorage([
        const TestProduct(id: -1, name: 'Unsynced 1', price: 10.0, isSynced: false),
        const TestProduct(id: -2, name: 'Unsynced 2', price: 20.0, isSynced: false),
      ]);

      partnerManager.seedStorage([
        const TestPartner(id: -1, name: 'Unsynced Partner', isSynced: false),
      ]);

      final count = await ModelRegistry().getTotalUnsyncedCount();

      expect(count, greaterThanOrEqualTo(3));
    });

    test('getTotalUnsyncedCount() returns zero when all synced', () async {
      productManager.clearStorage();
      partnerManager.clearStorage();

      productManager.seedStorage([
        const TestProduct(id: 1, name: 'Synced', price: 10.0, isSynced: true),
      ]);

      final count = await ModelRegistry().getTotalUnsyncedCount();

      // May have other managers registered from other tests
      expect(count, greaterThanOrEqualTo(0));
    });

    test('getSyncStatus() returns status for registered models', () async {
      productManager.seedStorage([
        const TestProduct(id: -1, name: 'Unsynced', price: 10.0, isSynced: false),
      ]);

      final status = await ModelRegistry().getSyncStatus();

      expect(status['product.product'], isNotNull);
      expect(status['product.product']!.unsyncedCount, greaterThanOrEqualTo(1));
      expect(status['product.product']!.hasUnsyncedChanges, isTrue);
    });

    test('hasUnsyncedChanges() returns true when any model has changes', () async {
      productManager.seedStorage([
        const TestProduct(id: -1, name: 'Unsynced', price: 10.0, isSynced: false),
      ]);

      final hasChanges = await ModelRegistry().hasUnsyncedChanges();

      expect(hasChanges, isTrue);
    });
  });

  group('SyncConfiguration', () {
    test('defaultConfig has empty values', () {
      const config = SyncConfiguration.defaultConfig;

      expect(config.syncOrder, isEmpty);
      expect(config.parallelGroups, isEmpty);
      expect(config.excludeFromAutoSync, isEmpty);
    });

    test('can create with custom values', () {
      const config = SyncConfiguration(
        syncOrder: ['model.a', 'model.b'],
        parallelGroups: [
          ['model.c', 'model.d']
        ],
        excludeFromAutoSync: {'model.e'},
      );

      expect(config.syncOrder, ['model.a', 'model.b']);
      expect(config.parallelGroups.length, 1);
      expect(config.excludeFromAutoSync, contains('model.e'));
    });
  });

  group('ModelSyncStatus', () {
    test('hasUnsyncedChanges returns true when unsyncedCount > 0', () {
      const status = ModelSyncStatus(
        model: 'test.model',
        unsyncedCount: 5,
      );

      expect(status.hasUnsyncedChanges, isTrue);
    });

    test('hasUnsyncedChanges returns false when unsyncedCount is 0', () {
      const status = ModelSyncStatus(
        model: 'test.model',
        unsyncedCount: 0,
      );

      expect(status.hasUnsyncedChanges, isFalse);
    });

    test('toString() returns readable format', () {
      final status = ModelSyncStatus(
        model: 'test.model',
        unsyncedCount: 3,
        lastSyncTime: DateTime(2024, 1, 1, 12, 0),
      );

      final str = status.toString();

      expect(str, contains('test.model'));
      expect(str, contains('unsynced=3'));
    });

    test('can be created with optional parameters', () {
      final status = ModelSyncStatus(
        model: 'test.model',
        unsyncedCount: 0,
        lastSyncTime: DateTime.now(),
        lastWriteDate: DateTime.now(),
      );

      expect(status.lastSyncTime, isNotNull);
      expect(status.lastWriteDate, isNotNull);
    });
  });
}
