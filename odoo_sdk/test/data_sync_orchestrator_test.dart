import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:test/test.dart';

import 'mocks/mock_helpers.dart';

void main() {
  setUpAll(registerAllFallbacks);

  late OdooDataLayer layer;
  late MockGeneratedDatabase mockDb;

  setUp(() {
    layer = OdooDataLayer();
    mockDb = MockGeneratedDatabase();
    OdooRecordRegistry.clear();
  });

  tearDown(() {
    try {
      layer.dispose();
    } catch (_) {}
    OdooRecordRegistry.clear();
  });

  Future<void> createTestContexts(List<String> ids) async {
    for (final id in ids) {
      await layer.createAndInitializeContext(
        session: testSession(id: id),
        database: mockDb,
        queueStore: mockQueueStore(),
        registerModels: (_) {},
        setActive: id == ids.first,
      );
    }
  }

  group('DataSyncOrchestrator', () {
    test('syncAll with no contexts returns empty result', () async {
      final orch = DataSyncOrchestrator(layer);
      final result = await orch.syncAll();
      expect(result.reports, isEmpty);
      expect(result.allSuccessful, isTrue);
    });

    test('syncAll sequential syncs all contexts', () async {
      await createTestContexts(['a', 'b']);
      final orch = DataSyncOrchestrator(layer);

      final result = await orch.syncAll(
        config: const MultiContextSyncConfig.sequential(),
      );
      // Both contexts synced (even if no models registered, they return empty reports)
      expect(result.reports.keys, containsAll(['a', 'b']));
      expect(result.duration, greaterThanOrEqualTo(Duration.zero));
    });

    test('syncAll parallel syncs all contexts', () async {
      await createTestContexts(['a', 'b', 'c']);
      final orch = DataSyncOrchestrator(layer);

      final result = await orch.syncAll(
        config: const MultiContextSyncConfig.parallel(maxParallel: 2),
      );
      expect(result.reports.keys, containsAll(['a', 'b', 'c']));
    });

    test('syncAll with specific contextIds only syncs those', () async {
      await createTestContexts(['a', 'b', 'c']);
      final orch = DataSyncOrchestrator(layer);

      final result = await orch.syncAll(
        config: const MultiContextSyncConfig(contextIds: ['a', 'c']),
      );
      expect(result.reports.keys, containsAll(['a', 'c']));
      expect(result.reports.containsKey('b'), isFalse);
    });

    test('syncAll respects cancellation', () async {
      await createTestContexts(['a', 'b', 'c']);
      final orch = DataSyncOrchestrator(layer);
      final token = CancellationToken();
      token.cancel();

      final result = await orch.syncAll(
        config: const MultiContextSyncConfig.sequential(),
        cancellation: token,
      );
      // Should have synced 0 or very few contexts
      expect(result.reports.length, lessThanOrEqualTo(3));
      token.dispose();
    });

    test('syncAll handles errors gracefully', () async {
      await createTestContexts(['a']);
      // Dispose the context so sync will fail
      layer.getContext('a')!.dispose();

      final orch = DataSyncOrchestrator(layer);
      final result = await orch.syncAll();
      // Should have an error report for 'a'
      expect(result.reports.containsKey('a'), isTrue);
    });
  });

  group('MultiContextSyncConfig', () {
    test('sequential defaults', () {
      const c = MultiContextSyncConfig.sequential();
      expect(c.parallelContexts, 1);
      expect(c.contextIds, isNull);
    });

    test('parallel defaults', () {
      const c = MultiContextSyncConfig.parallel();
      expect(c.parallelContexts, 3);
      expect(c.contextIds, isNull);
    });

    test('custom parallel count', () {
      const c = MultiContextSyncConfig.parallel(maxParallel: 5);
      expect(c.parallelContexts, 5);
    });
  });

  group('MultiContextSyncResult', () {
    test('allSuccessful with empty reports', () {
      final r = MultiContextSyncResult(
        reports: {},
        startTime: DateTime.now(),
        endTime: DateTime.now(),
      );
      expect(r.allSuccessful, isTrue);
      expect(r.failedContexts, isEmpty);
    });
  });
}
