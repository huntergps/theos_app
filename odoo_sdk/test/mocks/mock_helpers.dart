import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

import 'mock_offline_queue.dart';

// Re-export mock classes from other mock files so data-layer tests
// can import just this file.
export 'mock_odoo_client.dart' show MockOdooClient, MockOdooCrudApi, MockOdooHttpClient;
export 'mock_offline_queue.dart' show MockOfflineQueueStore, MockOfflineQueue;

// ═══════════════════════════════════════════════════════════════════════════
// Data-layer specific mocks
// ═══════════════════════════════════════════════════════════════════════════

class MockGeneratedDatabase extends Mock implements GeneratedDatabase {}

// ═══════════════════════════════════════════════════════════════════════════
// Fallback values (data-layer specific)
// ═══════════════════════════════════════════════════════════════════════════

class _FakeSyncResult extends Fake implements SyncResult {}

class _FakeSyncReport extends Fake implements SyncReport {}

class _FakeModelManagerConfig extends Fake implements ModelManagerConfig {}

class _FakeOdooClient extends Fake implements OdooClient {}

class _FakeGeneratedDatabase extends Fake implements GeneratedDatabase {}

class _FakeOfflineQueueWrapper extends Fake implements OfflineQueueWrapper {}

void registerAllFallbacks() {
  registerFallbackValue(_FakeSyncResult());
  registerFallbackValue(_FakeSyncReport());
  registerFallbackValue(_FakeModelManagerConfig());
  registerFallbackValue(_FakeOdooClient());
  registerFallbackValue(_FakeGeneratedDatabase());
  registerFallbackValue(_FakeOfflineQueueWrapper());
}

// ═══════════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════════

DataSession testSession({
  String id = 'test',
  String label = 'Test',
  String baseUrl = 'https://test.example.com',
  String database = 'testdb',
  String apiKey = 'test_key',
}) {
  return DataSession(
    id: id,
    label: label,
    baseUrl: baseUrl,
    database: database,
    apiKey: apiKey,
  );
}

/// Create a mock queue store that returns empty results for all methods
/// called during OfflineQueueWrapper.initialize().
MockOfflineQueueStore mockQueueStore() {
  final store = MockOfflineQueueStore();
  when(() => store.getPendingOperations()).thenAnswer((_) async => []);
  when(() => store.getPendingCount()).thenAnswer((_) async => 0);
  when(() => store.getRetryStats()).thenAnswer(
    (_) async => <String, dynamic>{'ready': 0, 'dead_letter': 0},
  );
  when(() => store.getDeadLetterOperations()).thenAnswer((_) async => []);
  return store;
}
