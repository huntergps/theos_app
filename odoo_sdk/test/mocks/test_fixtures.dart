/// Test fixtures and common test data for OdooModelManager tests.
///
/// This file provides reusable test data and setup utilities.

import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:odoo_sdk/src/sync/offline_queue.dart';

import 'mock_odoo_client.dart';
import 'mock_offline_queue.dart';
import 'test_model_manager.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Sample Odoo API Response Data
// ═══════════════════════════════════════════════════════════════════════════

/// Sample product data as returned by Odoo API.
class SampleOdooData {
  /// Single product response.
  static Map<String, dynamic> product({
    required int id,
    String? name,
    double price = 10.0,
    bool active = true,
    DateTime? writeDate,
  }) {
    return {
      'id': id,
      'name': name ?? 'Product $id',
      'list_price': price,
      'active': active,
      'write_date': (writeDate ?? DateTime.now()).toIso8601String(),
    };
  }

  /// List of products (for searchRead responses).
  static List<Map<String, dynamic>> products({
    int count = 5,
    int startId = 1,
    double basePrice = 10.0,
    bool active = true,
  }) {
    return List.generate(count, (i) {
      final id = startId + i;
      return product(
        id: id,
        name: 'Product $id',
        price: basePrice + (i * 5.0),
        active: active,
      );
    });
  }

  /// Empty list (for no results).
  static List<Map<String, dynamic>> empty() => [];

  /// Partner data (for testing different models).
  static Map<String, dynamic> partner({
    required int id,
    String? name,
    String? email,
    String? phone,
    bool active = true,
  }) {
    return {
      'id': id,
      'name': name ?? 'Partner $id',
      'email': email ?? 'partner$id@example.com',
      'phone': phone ?? '+1-555-000$id',
      'active': active,
    };
  }

  /// List of partners.
  static List<Map<String, dynamic>> partners({int count = 3}) {
    return List.generate(count, (i) => partner(id: i + 1));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Sample Domain Filters
// ═══════════════════════════════════════════════════════════════════════════

/// Common domain filters for testing.
class SampleDomains {
  /// Active records only.
  static const List<dynamic> activeOnly = [
    ['active', '=', true]
  ];

  /// Inactive records only.
  static const List<dynamic> inactiveOnly = [
    ['active', '=', false]
  ];

  /// Search by name (exact).
  static List<dynamic> nameEquals(String name) => [
        ['name', '=', name]
      ];

  /// Search by name (contains).
  static List<dynamic> nameContains(String pattern) => [
        ['name', 'ilike', '%$pattern%']
      ];

  /// Price range.
  static List<dynamic> priceRange(double min, double max) => [
        ['list_price', '>=', min],
        ['list_price', '<=', max],
      ];

  /// Price greater than.
  static List<dynamic> priceGreaterThan(double value) => [
        ['list_price', '>', value]
      ];

  /// ID in list.
  static List<dynamic> idIn(List<int> ids) => [
        ['id', 'in', ids]
      ];

  /// Complex domain (AND conditions).
  static List<dynamic> activeAndPriceAbove(double minPrice) => [
        ['active', '=', true],
        ['list_price', '>', minPrice],
      ];
}

// ═══════════════════════════════════════════════════════════════════════════
// Test Setup Utilities
// ═══════════════════════════════════════════════════════════════════════════

/// Test fixture helper for setting up common test scenarios.
class TestFixtures {
  late MockOdooClient mockClient;
  late MockOfflineQueueStore mockQueueStore;
  late InMemoryOfflineQueueStore inMemoryQueueStore;
  late OfflineQueueWrapper queue;
  late MockDatabase mockDb;
  late TestProductManager manager;

  /// Initialize all mocks with default configuration.
  Future<void> setUp() async {
    mockClient = MockOdooClient();
    mockQueueStore = MockOfflineQueueStore();
    inMemoryQueueStore = InMemoryOfflineQueueStore();
    mockDb = MockDatabase();

    // Setup default mock behaviors
    mockClient.setupConfigured();
    mockQueueStore.setupEmptyQueue();

    // Create queue wrapper with in-memory store for realistic behavior
    queue = OfflineQueueWrapper(inMemoryQueueStore);
    await queue.initialize();

    // Create and initialize manager
    manager = TestProductManager();
    manager.initialize(
      client: mockClient,
      db: mockDb,
      queue: queue,
    );
  }

  /// Create a manager with mocked queue (for verifying queue interactions).
  Future<TestProductManager> setUpWithMockedQueue() async {
    mockClient = MockOdooClient();
    mockQueueStore = MockOfflineQueueStore();
    mockDb = MockDatabase();

    mockClient.setupConfigured();
    mockQueueStore.setupEmptyQueue();
    mockQueueStore.setupQueueOperation();
    mockQueueStore.setupRemoveOperation();

    queue = OfflineQueueWrapper(mockQueueStore);
    await queue.initialize();

    manager = TestProductManager();
    manager.initialize(
      client: mockClient,
      db: mockDb,
      queue: queue,
    );

    return manager;
  }

  /// Dispose all resources.
  void tearDown() {
    manager.dispose();
    queue.dispose();
    manager.clearStorage();
    inMemoryQueueStore.clear();
    TestProductFactory.reset();
  }

  /// Setup client as offline (not configured).
  void setOffline() {
    mockClient.setupNotConfigured();
  }

  /// Setup client as online with configured responses.
  void setOnline() {
    mockClient.setupConfigured();
  }

  /// Seed manager storage with sample products.
  void seedProducts(List<TestProduct> products) {
    manager.seedStorage(products);
  }

  /// Setup mock client to return specific products for searchRead.
  void setupSearchReadProducts(List<Map<String, dynamic>> products) {
    mockClient.setupSearchRead(
      model: 'product.product',
      results: products,
    );
  }

  /// Setup mock client to return specific products for read.
  void setupReadProducts(List<int> ids, List<Map<String, dynamic>> products) {
    mockClient.setupRead(
      model: 'product.product',
      ids: ids,
      results: products,
    );
  }

  /// Setup mock client for create operation.
  void setupCreate({required int resultId}) {
    mockClient.setupCreate(
      model: 'product.product',
      resultId: resultId,
    );
  }

  /// Setup mock client for write operation.
  void setupWrite({bool success = true}) {
    mockClient.setupWrite(
      model: 'product.product',
      result: success,
    );
  }

  /// Setup mock client for unlink operation.
  void setupUnlink({bool success = true}) {
    mockClient.setupUnlink(
      model: 'product.product',
      result: success,
    );
  }

  /// Setup network error for all operations.
  void setupNetworkError() {
    mockClient.setupNetworkError();
  }

  /// Setup server error for all operations.
  void setupServerError({int statusCode = 500}) {
    mockClient.setupServerError(statusCode: statusCode);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Registration of Fallback Values
// ═══════════════════════════════════════════════════════════════════════════

/// Register all fallback values for testing.
///
/// Call this in setUpAll() before any tests:
/// ```dart
/// setUpAll(() {
///   registerAllFallbacks();
/// });
/// ```
void registerAllFallbacks() {
  registerOdooClientFallbacks();
  registerOfflineQueueFallbacks();
  registerTestModelFallbacks();
}

// ═══════════════════════════════════════════════════════════════════════════
// Common Test Assertions
// ═══════════════════════════════════════════════════════════════════════════

/// Extension methods for common test assertions on TestProduct.
extension TestProductAssertions on TestProduct {
  /// Check if product matches expected values.
  bool matches({
    int? id,
    String? name,
    double? price,
    bool? active,
    bool? isSynced,
  }) {
    if (id != null && this.id != id) return false;
    if (name != null && this.name != name) return false;
    if (price != null && this.price != price) return false;
    if (active != null && this.active != active) return false;
    if (isSynced != null && this.isSynced != isSynced) return false;
    return true;
  }
}

/// Extension methods for verifying mock interactions.
extension MockOdooClientVerifications on MockOdooClient {
  /// Verify create was called with expected model.
  void verifyCreateCalled({String model = 'product.product'}) {
    verify(() => create(
          model: model,
          values: any(named: 'values'),
          cancelToken: any(named: 'cancelToken'),
        )).called(1);
  }

  /// Verify write was called with expected model and IDs.
  void verifyWriteCalled({
    String model = 'product.product',
    List<int>? ids,
  }) {
    verify(() => write(
          model: model,
          ids: ids ?? any(named: 'ids'),
          values: any(named: 'values'),
          cancelToken: any(named: 'cancelToken'),
        )).called(1);
  }

  /// Verify unlink was called with expected model and IDs.
  void verifyUnlinkCalled({
    String model = 'product.product',
    List<int>? ids,
  }) {
    verify(() => unlink(
          model: model,
          ids: ids ?? any(named: 'ids'),
          cancelToken: any(named: 'cancelToken'),
        )).called(1);
  }

  /// Verify searchRead was called.
  void verifySearchReadCalled({String model = 'product.product'}) {
    verify(() => searchRead(
          model: model,
          fields: any(named: 'fields'),
          domain: any(named: 'domain'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          order: any(named: 'order'),
          cancelToken: any(named: 'cancelToken'),
        )).called(1);
  }

  /// Verify read was called with expected IDs.
  void verifyReadCalled({
    String model = 'product.product',
    List<int>? ids,
  }) {
    verify(() => read(
          model: model,
          ids: ids ?? any(named: 'ids'),
          fields: any(named: 'fields'),
          cancelToken: any(named: 'cancelToken'),
        )).called(1);
  }

  /// Verify no interactions with the client.
  void verifyNoMoreInteractions() {
    verifyNoMoreInteractions();
  }
}
