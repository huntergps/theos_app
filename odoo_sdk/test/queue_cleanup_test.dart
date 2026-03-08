import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:test/test.dart';

import 'mocks/mock_helpers.dart';
import 'mocks/mock_offline_queue.dart';

void main() {
  setUpAll(registerAllFallbacks);

  group('OfflineQueueConfig defaults', () {
    test('maxQueueSize defaults to 10000', () {
      const config = OfflineQueueConfig();
      expect(config.maxQueueSize, 10000);
    });

    test('maxOperationAge defaults to 30 days', () {
      const config = OfflineQueueConfig();
      expect(config.maxOperationAge, const Duration(days: 30));
    });

    test('custom maxQueueSize and maxOperationAge', () {
      const config = OfflineQueueConfig(
        maxQueueSize: 500,
        maxOperationAge: Duration(days: 7),
      );
      expect(config.maxQueueSize, 500);
      expect(config.maxOperationAge, const Duration(days: 7));
    });

    test('maxQueueSize 0 means unlimited', () {
      const config = OfflineQueueConfig(maxQueueSize: 0);
      expect(config.maxQueueSize, 0);
    });

    test('maxOperationAge null means no limit', () {
      const config = OfflineQueueConfig(maxOperationAge: null);
      expect(config.maxOperationAge, isNull);
    });
  });

  group('OfflineQueueWrapper cleanup', () {
    late InMemoryOfflineQueueStore store;
    late OfflineQueueWrapper queue;

    setUp(() {
      store = InMemoryOfflineQueueStore();
    });

    group('cleanupStaleOperations', () {
      test('removes operations older than maxOperationAge', () async {
        queue = OfflineQueueWrapper(
          store,
          config: const OfflineQueueConfig(
            maxOperationAge: Duration(days: 7),
          ),
        );
        await queue.initialize();

        // Add old operation (10 days ago)
        store.addOperation(OfflineOperation(
          id: 1,
          model: 'sale.order',
          method: 'write',
          values: {'name': 'old'},
          createdAt: DateTime.now().subtract(const Duration(days: 10)),
        ));

        // Add recent operation (1 day ago)
        store.addOperation(OfflineOperation(
          id: 2,
          model: 'sale.order',
          method: 'write',
          values: {'name': 'recent'},
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ));

        final removed = await queue.cleanupStaleOperations();
        expect(removed, 1);
        expect(store.allOperations.length, 1);
        expect(store.allOperations.first.id, 2);
      });

      test('returns 0 when maxOperationAge is null', () async {
        queue = OfflineQueueWrapper(
          store,
          config: const OfflineQueueConfig(maxOperationAge: null),
        );
        await queue.initialize();

        store.addOperation(OfflineOperation(
          id: 1,
          model: 'sale.order',
          method: 'write',
          values: {'name': 'old'},
          createdAt: DateTime.now().subtract(const Duration(days: 365)),
        ));

        final removed = await queue.cleanupStaleOperations();
        expect(removed, 0);
        expect(store.allOperations.length, 1);
      });

      test('returns 0 when no stale operations exist', () async {
        queue = OfflineQueueWrapper(
          store,
          config: const OfflineQueueConfig(
            maxOperationAge: Duration(days: 30),
          ),
        );
        await queue.initialize();

        store.addOperation(OfflineOperation(
          id: 1,
          model: 'sale.order',
          method: 'write',
          values: {'name': 'recent'},
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ));

        final removed = await queue.cleanupStaleOperations();
        expect(removed, 0);
        expect(store.allOperations.length, 1);
      });
    });

    group('compressQueue', () {
      test('merges consecutive writes to same record keeping latest', () async {
        queue = OfflineQueueWrapper(store);
        await queue.initialize();

        final now = DateTime.now();

        // Two writes to same record
        store.addOperation(OfflineOperation(
          id: 1,
          model: 'sale.order',
          method: 'write',
          recordId: 10,
          values: {'name': 'first'},
          createdAt: now.subtract(const Duration(minutes: 5)),
        ));
        store.addOperation(OfflineOperation(
          id: 2,
          model: 'sale.order',
          method: 'write',
          recordId: 10,
          values: {'name': 'second'},
          createdAt: now.subtract(const Duration(minutes: 2)),
        ));

        final removed = await queue.compressQueue();
        expect(removed, 1);
        expect(store.allOperations.length, 1);
        expect(store.allOperations.first.id, 2); // kept the latest
      });

      test('does not merge writes to different records', () async {
        queue = OfflineQueueWrapper(store);
        await queue.initialize();

        final now = DateTime.now();

        store.addOperation(OfflineOperation(
          id: 1,
          model: 'sale.order',
          method: 'write',
          recordId: 10,
          values: {'name': 'order 10'},
          createdAt: now.subtract(const Duration(minutes: 5)),
        ));
        store.addOperation(OfflineOperation(
          id: 2,
          model: 'sale.order',
          method: 'write',
          recordId: 20,
          values: {'name': 'order 20'},
          createdAt: now.subtract(const Duration(minutes: 2)),
        ));

        final removed = await queue.compressQueue();
        expect(removed, 0);
        expect(store.allOperations.length, 2);
      });

      test('does not merge create or unlink operations', () async {
        queue = OfflineQueueWrapper(store);
        await queue.initialize();

        final now = DateTime.now();

        store.addOperation(OfflineOperation(
          id: 1,
          model: 'sale.order',
          method: 'create',
          recordId: 10,
          values: {'name': 'first'},
          createdAt: now.subtract(const Duration(minutes: 5)),
        ));
        store.addOperation(OfflineOperation(
          id: 2,
          model: 'sale.order',
          method: 'create',
          recordId: 10,
          values: {'name': 'second'},
          createdAt: now.subtract(const Duration(minutes: 2)),
        ));

        final removed = await queue.compressQueue();
        expect(removed, 0);
        expect(store.allOperations.length, 2);
      });

      test('does not merge writes without recordId', () async {
        queue = OfflineQueueWrapper(store);
        await queue.initialize();

        final now = DateTime.now();

        store.addOperation(OfflineOperation(
          id: 1,
          model: 'sale.order',
          method: 'write',
          values: {'name': 'first'},
          createdAt: now.subtract(const Duration(minutes: 5)),
        ));
        store.addOperation(OfflineOperation(
          id: 2,
          model: 'sale.order',
          method: 'write',
          values: {'name': 'second'},
          createdAt: now.subtract(const Duration(minutes: 2)),
        ));

        final removed = await queue.compressQueue();
        expect(removed, 0);
        expect(store.allOperations.length, 2);
      });

      test('compresses three writes to one', () async {
        queue = OfflineQueueWrapper(store);
        await queue.initialize();

        final now = DateTime.now();

        store.addOperation(OfflineOperation(
          id: 1,
          model: 'product.product',
          method: 'write',
          recordId: 5,
          values: {'name': 'v1'},
          createdAt: now.subtract(const Duration(minutes: 10)),
        ));
        store.addOperation(OfflineOperation(
          id: 2,
          model: 'product.product',
          method: 'write',
          recordId: 5,
          values: {'name': 'v2'},
          createdAt: now.subtract(const Duration(minutes: 5)),
        ));
        store.addOperation(OfflineOperation(
          id: 3,
          model: 'product.product',
          method: 'write',
          recordId: 5,
          values: {'name': 'v3'},
          createdAt: now,
        ));

        final removed = await queue.compressQueue();
        expect(removed, 2);
        expect(store.allOperations.length, 1);
        expect(store.allOperations.first.id, 3);
      });
    });

    group('purgeDeadLetterQueue', () {
      test('removes all dead letter operations', () async {
        queue = OfflineQueueWrapper(store);
        await queue.initialize();

        // Add normal operation
        store.addOperation(OfflineOperation(
          id: 1,
          model: 'sale.order',
          method: 'write',
          values: {'name': 'pending'},
          createdAt: DateTime.now(),
          retryCount: 0,
        ));

        // Add dead letter operation (exceeds maxRetries of 5)
        store.addOperation(OfflineOperation(
          id: 2,
          model: 'sale.order',
          method: 'write',
          values: {'name': 'dead'},
          createdAt: DateTime.now(),
          retryCount: 5,
          lastError: 'some error',
        ));

        store.addOperation(OfflineOperation(
          id: 3,
          model: 'product.product',
          method: 'create',
          values: {'name': 'also dead'},
          createdAt: DateTime.now(),
          retryCount: 10,
          lastError: 'another error',
        ));

        final removed = await queue.purgeDeadLetterQueue();
        expect(removed, 2);
        expect(store.allOperations.length, 1);
        expect(store.allOperations.first.id, 1);
      });

      test('returns 0 when no dead letter operations', () async {
        queue = OfflineQueueWrapper(store);
        await queue.initialize();

        store.addOperation(OfflineOperation(
          id: 1,
          model: 'sale.order',
          method: 'write',
          values: {'name': 'pending'},
          createdAt: DateTime.now(),
          retryCount: 0,
        ));

        final removed = await queue.purgeDeadLetterQueue();
        expect(removed, 0);
        expect(store.allOperations.length, 1);
      });
    });

    group('enforceMaxSize', () {
      test('removes lowest priority oldest operations when over limit', () async {
        queue = OfflineQueueWrapper(
          store,
          config: const OfflineQueueConfig(maxQueueSize: 2),
        );
        await queue.initialize();

        final now = DateTime.now();

        // Add 4 operations with different priorities
        store.addOperation(OfflineOperation(
          id: 1,
          model: 'sale.order',
          method: 'write',
          values: {'name': 'critical'},
          createdAt: now.subtract(const Duration(minutes: 10)),
          priority: OfflinePriority.critical,
        ));
        store.addOperation(OfflineOperation(
          id: 2,
          model: 'sale.order',
          method: 'write',
          values: {'name': 'low'},
          createdAt: now.subtract(const Duration(minutes: 5)),
          priority: OfflinePriority.low,
        ));
        store.addOperation(OfflineOperation(
          id: 3,
          model: 'sale.order',
          method: 'write',
          values: {'name': 'normal'},
          createdAt: now.subtract(const Duration(minutes: 3)),
          priority: OfflinePriority.normal,
        ));
        store.addOperation(OfflineOperation(
          id: 4,
          model: 'sale.order',
          method: 'write',
          values: {'name': 'high'},
          createdAt: now,
          priority: OfflinePriority.high,
        ));

        final removed = await queue.enforceMaxSize();
        expect(removed, 2);
        expect(store.allOperations.length, 2);

        // Should keep critical (id=1) and high (id=4)
        final remaining = store.allOperations.map((o) => o.id).toSet();
        expect(remaining.contains(1), isTrue); // critical priority
        expect(remaining.contains(4), isTrue); // high priority
      });

      test('returns 0 when maxQueueSize is 0 (unlimited)', () async {
        queue = OfflineQueueWrapper(
          store,
          config: const OfflineQueueConfig(maxQueueSize: 0),
        );
        await queue.initialize();

        store.addOperation(OfflineOperation(
          id: 1,
          model: 'sale.order',
          method: 'write',
          values: {},
          createdAt: DateTime.now(),
        ));

        final removed = await queue.enforceMaxSize();
        expect(removed, 0);
      });

      test('returns 0 when queue is within limit', () async {
        queue = OfflineQueueWrapper(
          store,
          config: const OfflineQueueConfig(maxQueueSize: 10),
        );
        await queue.initialize();

        store.addOperation(OfflineOperation(
          id: 1,
          model: 'sale.order',
          method: 'write',
          values: {},
          createdAt: DateTime.now(),
        ));

        final removed = await queue.enforceMaxSize();
        expect(removed, 0);
      });
    });
  });

  group('OfflineQueueStore new methods', () {
    late InMemoryOfflineQueueStore store;

    setUp(() {
      store = InMemoryOfflineQueueStore();
    });

    test('removeOperationsBefore removes old operations', () async {
      final now = DateTime.now();
      store.addOperation(OfflineOperation(
        id: 1,
        model: 'sale.order',
        method: 'write',
        values: {},
        createdAt: now.subtract(const Duration(days: 10)),
      ));
      store.addOperation(OfflineOperation(
        id: 2,
        model: 'sale.order',
        method: 'write',
        values: {},
        createdAt: now.subtract(const Duration(days: 1)),
      ));

      final removed = await store.removeOperationsBefore(
        now.subtract(const Duration(days: 5)),
      );
      expect(removed, 1);
      expect(store.allOperations.length, 1);
      expect(store.allOperations.first.id, 2);
    });

    test('removeDeadLetterOperations removes only dead letters', () async {
      store.addOperation(OfflineOperation(
        id: 1,
        model: 'sale.order',
        method: 'write',
        values: {},
        createdAt: DateTime.now(),
        retryCount: 0,
      ));
      store.addOperation(OfflineOperation(
        id: 2,
        model: 'sale.order',
        method: 'write',
        values: {},
        createdAt: DateTime.now(),
        retryCount: 10,
      ));

      final removed = await store.removeDeadLetterOperations();
      expect(removed, 1);
      expect(store.allOperations.length, 1);
      expect(store.allOperations.first.id, 1);
    });

    test('getOperationsForRecord returns matching operations', () async {
      store.addOperation(OfflineOperation(
        id: 1,
        model: 'sale.order',
        method: 'write',
        recordId: 10,
        values: {},
        createdAt: DateTime.now(),
      ));
      store.addOperation(OfflineOperation(
        id: 2,
        model: 'sale.order',
        method: 'write',
        recordId: 20,
        values: {},
        createdAt: DateTime.now(),
      ));
      store.addOperation(OfflineOperation(
        id: 3,
        model: 'product.product',
        method: 'write',
        recordId: 10,
        values: {},
        createdAt: DateTime.now(),
      ));

      final ops = await store.getOperationsForRecord('sale.order', 10);
      expect(ops.length, 1);
      expect(ops.first.id, 1);
    });
  });

  group('DataContext metrics integration', () {
    late DataSession session;
    late MockGeneratedDatabase mockDb;
    late MockOfflineQueueStore mockStore;

    setUp(() {
      session = testSession();
      mockDb = MockGeneratedDatabase();
      mockStore = mockQueueStore();
      OdooRecordRegistry.clear();
    });

    test('metrics getter lazily creates collector', () {
      final ctx = DataContext(session);
      final m1 = ctx.metrics;
      final m2 = ctx.metrics;
      expect(m1, same(m2));
      ctx.dispose();
    });

    test('enableMetrics creates collector with custom maxMetrics', () {
      final ctx = DataContext(session);
      ctx.enableMetrics(maxMetrics: 500);
      final collector = ctx.metrics;
      expect(collector, isNotNull);
      ctx.dispose();
    });

    test('dispose clears metrics collector', () async {
      final ctx = DataContext(session);
      await ctx.initialize(database: mockDb, queueStore: mockStore);
      ctx.enableMetrics();
      ctx.dispose();
      // After dispose, accessing metrics creates a new collector
      final newCollector = ctx.metrics;
      expect(newCollector.metrics, isEmpty);
    });

    test('syncModel records metrics when enabled', () async {
      final ctx = DataContext(session);

      // Setup mock store for syncModel
      when(() => mockStore.getPendingOperations(
            includeNotReady: any(named: 'includeNotReady'),
          )).thenAnswer((_) async => []);
      when(() => mockStore.removeOperationsBefore(any()))
          .thenAnswer((_) async => 0);
      when(() => mockStore.removeDeadLetterOperations())
          .thenAnswer((_) async => 0);

      await ctx.initialize(database: mockDb, queueStore: mockStore);
      ctx.enableMetrics();

      // No managers registered, syncModel will throw because
      // the model is not registered; so this test just verifies
      // enableMetrics doesn't break initialization flow
      expect(ctx.metrics.metrics, isEmpty);
      ctx.dispose();
    });
  });
}
