import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

import 'mocks/mock_odoo_client.dart';
import 'mocks/mock_offline_queue.dart';
import 'mocks/test_model_manager.dart';

void main() {
  late TestProductManager manager;
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
    manager = TestProductManager();
    mockClient = MockOdooClient();
    mockDb = MockDatabase();
    queueStore = InMemoryOfflineQueueStore();
    queueWrapper = OfflineQueueWrapper(queueStore);
    TestProductFactory.reset();

    // Setup mock client as configured by default
    mockClient.setupConfigured();
  });

  tearDown(() {
    manager.dispose();
    queueWrapper.dispose();
    queueStore.clear();
  });

  group('Offline to Online Sync Integration', () {
    group('Create while offline, sync when online', () {
      test('creates record locally with negative ID when offline', () async {
        mockClient.setupNotConfigured(); // Simulate offline

        manager.initialize(client: mockClient, db: mockDb, queue: queueWrapper);

        const product = TestProduct(
          id: 0,
          name: 'Offline Product',
          price: 99.99,
        );

        final localId = await manager.create(product);

        // Should have negative ID
        expect(localId, lessThan(0));

        // Should be in local storage
        final stored = await manager.readLocal(localId);
        expect(stored, isNotNull);
        expect(stored!.name, 'Offline Product');
        expect(stored.isSynced, isFalse);

        // Should be queued for sync
        final pending = await queueStore.getPendingOperations();
        expect(pending.length, 1);
        expect(pending[0].model, 'product.product');
        expect(pending[0].method, 'create');
      });

      test('syncs created record when coming online', () async {
        // Start offline
        mockClient.setupNotConfigured();

        manager.initialize(client: mockClient, db: mockDb, queue: queueWrapper);

        // Create while offline
        const product = TestProduct(
          id: 0,
          name: 'Offline Product',
          price: 50.00,
        );
        await manager.create(product);

        // Verify queued
        var pending = await queueStore.getPendingOperations();
        expect(pending.length, 1);

        // Come online and setup success response
        mockClient.setupConfigured();
        mockClient.setupCreate(model: 'product.product', resultId: 100);

        // Process queue
        final result = await manager.syncToOdoo();

        expect(result.status, anyOf(SyncStatus.success, SyncStatus.partial));
        expect(result.synced, 1);

        // Queue should be empty
        pending = await queueStore.getPendingOperations();
        expect(pending, isEmpty);
      });

      test('retries failed create operation', () async {
        mockClient.setupNotConfigured();

        manager.initialize(client: mockClient, db: mockDb, queue: queueWrapper);

        // Create while offline
        const product = TestProduct(id: 0, name: 'Test', price: 10.0);
        await manager.create(product);

        // Come online but fail first attempt
        mockClient.setupConfigured();
        var callCount = 0;
        when(
          () => mockClient.create(
            model: any(named: 'model'),
            values: any(named: 'values'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            throw Exception('Network error');
          }
          return 100;
        });

        // First sync - should fail
        var result = await manager.syncToOdoo();
        expect(result.failed, 1);

        // Operation should still be in queue with retry count
        var pending = await queueStore.getPendingOperations(
          includeNotReady: true,
        );
        expect(pending.length, 1);
        expect(pending[0].retryCount, 1);

        // Reset nextRetryAt for immediate retry
        await queueStore.resetOperationRetry(pending[0].id);

        // Second sync - should succeed
        result = await manager.syncToOdoo();
        expect(result.synced, 1);

        // Queue should be empty
        pending = await queueStore.getPendingOperations();
        expect(pending, isEmpty);
      });
    });

    group('Update while offline, sync when online', () {
      test('updates record locally when offline', () async {
        // Seed a synced product
        manager.seedStorage([
          const TestProduct(
            id: 1,
            uuid: 'uuid-1',
            name: 'Original',
            price: 100.0,
            isSynced: true,
          ),
        ]);

        mockClient.setupNotConfigured();

        manager.initialize(client: mockClient, db: mockDb, queue: queueWrapper);

        // Update while offline
        const updated = TestProduct(
          id: 1,
          uuid: 'uuid-1',
          name: 'Updated Name',
          price: 150.0,
        );

        final success = await manager.update(updated);

        expect(success, isTrue);

        // Local record should be updated but marked unsynced
        final local = await manager.readLocal(1);
        expect(local!.name, 'Updated Name');
        expect(local.price, 150.0);
        expect(local.isSynced, isFalse);

        // Should be queued
        final pending = await queueStore.getPendingOperations();
        expect(pending.length, 1);
        expect(pending[0].method, 'write');
      });

      test('syncs updated record when coming online', () async {
        manager.seedStorage([
          const TestProduct(
            id: 1,
            uuid: 'uuid-1',
            name: 'Original',
            price: 100.0,
            isSynced: true,
          ),
        ]);

        mockClient.setupNotConfigured();

        manager.initialize(client: mockClient, db: mockDb, queue: queueWrapper);

        // Update while offline
        await manager.update(
          const TestProduct(
            id: 1,
            uuid: 'uuid-1',
            name: 'Updated',
            price: 200.0,
          ),
        );

        // Come online
        mockClient.setupConfigured();
        mockClient.setupWrite(model: 'product.product', result: true);

        // Sync
        final result = await manager.syncToOdoo();

        expect(result.status, anyOf(SyncStatus.success, SyncStatus.partial));

        // Queue should be empty
        final pending = await queueStore.getPendingOperations();
        expect(pending, isEmpty);
      });
    });

    group('Delete while offline, sync when online', () {
      test('deletes record locally when offline', () async {
        manager.seedStorage([
          const TestProduct(
            id: 1,
            uuid: 'uuid-1',
            name: 'To Delete',
            price: 50.0,
            isSynced: true,
          ),
        ]);

        mockClient.setupNotConfigured();

        manager.initialize(client: mockClient, db: mockDb, queue: queueWrapper);

        // Delete while offline
        final success = await manager.delete(1);

        expect(success, isTrue);

        // Record should be removed locally
        final local = await manager.readLocal(1);
        expect(local, isNull);

        // Should be queued for server deletion
        final pending = await queueStore.getPendingOperations();
        expect(pending.length, 1);
        expect(pending[0].method, 'unlink');
      });

      test('syncs delete operation when coming online', () async {
        manager.seedStorage([
          const TestProduct(
            id: 1,
            uuid: 'uuid-1',
            name: 'To Delete',
            price: 50.0,
            isSynced: true,
          ),
        ]);

        mockClient.setupNotConfigured();

        manager.initialize(client: mockClient, db: mockDb, queue: queueWrapper);

        // Delete while offline
        await manager.delete(1);

        // Come online
        mockClient.setupConfigured();
        mockClient.setupUnlink(model: 'product.product', result: true);

        // Sync
        final result = await manager.syncToOdoo();

        expect(result.status, anyOf(SyncStatus.success, SyncStatus.partial));

        // Queue should be empty
        final pending = await queueStore.getPendingOperations();
        expect(pending, isEmpty);
      });

      test('does not queue delete for local-only records', () async {
        // Create a local-only record (negative ID)
        manager.seedStorage([
          const TestProduct(
            id: -12345,
            uuid: 'local-uuid',
            name: 'Local Only',
            price: 10.0,
          ),
        ]);

        mockClient.setupNotConfigured();

        manager.initialize(client: mockClient, db: mockDb, queue: queueWrapper);

        // Delete local-only record
        await manager.delete(-12345);

        // Should NOT be queued since it was never synced
        final pending = await queueStore.getPendingOperations();
        expect(pending, isEmpty);
      });
    });

    group('Multiple operations while offline', () {
      test('processes multiple operations in order', () async {
        mockClient.setupNotConfigured();

        manager.initialize(client: mockClient, db: mockDb, queue: queueWrapper);

        // Perform multiple operations while offline
        await manager.create(
          const TestProduct(id: 0, name: 'Product 1', price: 10.0),
        );
        await manager.create(
          const TestProduct(id: 0, name: 'Product 2', price: 20.0),
        );

        // All should be queued
        var pending = await queueStore.getPendingOperations();
        expect(pending.length, 2);

        // Come online
        mockClient.setupConfigured();
        var createCount = 0;
        when(
          () => mockClient.create(
            model: any(named: 'model'),
            values: any(named: 'values'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async {
          createCount++;
          return 100 + createCount;
        });

        // Sync all
        final result = await manager.syncToOdoo();

        expect(result.synced, 2);
        expect(createCount, 2);

        // Queue should be empty
        pending = await queueStore.getPendingOperations();
        expect(pending, isEmpty);
      });

      test('handles mixed create/update/delete operations', () async {
        manager.seedStorage([
          const TestProduct(
            id: 1,
            name: 'Existing',
            price: 100.0,
            isSynced: true,
          ),
          const TestProduct(
            id: 2,
            name: 'To Delete',
            price: 50.0,
            isSynced: true,
          ),
        ]);

        mockClient.setupNotConfigured();

        manager.initialize(client: mockClient, db: mockDb, queue: queueWrapper);

        // Create new
        await manager.create(
          const TestProduct(id: 0, name: 'New', price: 30.0),
        );

        // Update existing
        await manager.update(
          const TestProduct(id: 1, name: 'Updated', price: 150.0),
        );

        // Delete
        await manager.delete(2);

        // All should be queued
        final pending = await queueStore.getPendingOperations();
        expect(pending.length, 3);

        // Come online
        mockClient.setupConfigured();
        mockClient.setupCreate(model: 'product.product', resultId: 100);
        mockClient.setupWrite(model: 'product.product', result: true);
        mockClient.setupUnlink(model: 'product.product', result: true);

        // Sync
        final result = await manager.syncToOdoo();

        expect(result.synced, 3);
      });
    });

    group('Dead letter queue handling', () {
      test('moves operation to dead letter after max retries', () async {
        mockClient.setupNotConfigured();

        manager.initialize(client: mockClient, db: mockDb, queue: queueWrapper);

        // Create while offline
        await manager.create(
          const TestProduct(id: 0, name: 'Test', price: 10.0),
        );

        // Come online but always fail
        mockClient.setupConfigured();
        when(
          () => mockClient.create(
            model: any(named: 'model'),
            values: any(named: 'values'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenThrow(Exception('Permanent failure'));

        // Fail 5 times (max retries)
        // Note: getOperationsForModel doesn't filter by retry timing,
        // so we don't need to reset - just sync 5 times
        for (int i = 0; i < 5; i++) {
          await manager.syncToOdoo();
        }

        // Should be in dead letter queue
        final deadLetter = await queueStore.getDeadLetterOperations();
        expect(deadLetter.length, 1);

        // Should not be in pending queue
        final pending = await queueStore.getPendingOperations();
        expect(pending, isEmpty);
      });

      test('can retry dead letter operations after reset', () async {
        mockClient.setupNotConfigured();

        manager.initialize(client: mockClient, db: mockDb, queue: queueWrapper);

        await manager.create(
          const TestProduct(id: 0, name: 'Test', price: 10.0),
        );

        mockClient.setupConfigured();
        when(
          () => mockClient.create(
            model: any(named: 'model'),
            values: any(named: 'values'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenThrow(Exception('Temporary failure'));

        // Fail 5 times to move to dead letter
        for (int i = 0; i < 5; i++) {
          await manager.syncToOdoo();
        }

        // Verify in dead letter
        var deadLetter = await queueStore.getDeadLetterOperations();
        expect(deadLetter.length, 1);
        final opId = deadLetter[0].id;

        // Reset the operation
        await queueStore.resetOperationRetry(opId);

        // Should be back in pending
        final pending = await queueStore.getPendingOperations();
        expect(pending.length, 1);

        // Setup success
        mockClient.setupCreate(model: 'product.product', resultId: 100);

        // Should succeed now
        final result = await manager.syncToOdoo();
        expect(result.synced, 1);

        // Dead letter should be empty
        deadLetter = await queueStore.getDeadLetterOperations();
        expect(deadLetter, isEmpty);
      });
    });

    group('Bidirectional sync', () {
      test('sync() performs upload then download', () async {
        manager.seedStorage([
          const TestProduct(
            id: -1000,
            uuid: 'local-1',
            name: 'Unsynced',
            price: 10.0,
            isSynced: false,
          ),
        ]);

        // Queue the unsynced record
        await queueStore.queueOperation(
          model: 'product.product',
          method: 'create',
          values: {'name': 'Unsynced', 'list_price': 10.0},
        );

        mockClient.setupConfigured();
        mockClient.setupCreate(model: 'product.product', resultId: 100);
        mockClient.setupSearchCount(model: 'product.product', count: 2);
        mockClient.setupSearchRead(
          model: 'product.product',
          results: [
            {
              'id': 100,
              'name': 'Synced Product',
              'list_price': 10.0,
              'active': true,
            },
            {
              'id': 101,
              'name': 'Server Product',
              'list_price': 20.0,
              'active': true,
            },
          ],
        );

        manager.initialize(client: mockClient, db: mockDb, queue: queueWrapper);

        // Full bidirectional sync
        final result = await manager.sync();

        // Should have processed both directions
        expect(result.status, anyOf(SyncStatus.success, SyncStatus.partial));

        // Server products should be in local storage
        final all = manager.allRecords;
        expect(all.any((p) => p.id == 100 || p.id == 101), isTrue);
      });
    });

    group('Progress reporting', () {
      test('reports progress during syncToOdoo', () async {
        mockClient.setupNotConfigured();

        manager.initialize(client: mockClient, db: mockDb, queue: queueWrapper);

        // Queue multiple operations
        for (int i = 0; i < 5; i++) {
          await manager.create(
            TestProduct(id: 0, name: 'Product $i', price: i * 10.0),
          );
        }

        mockClient.setupConfigured();
        var createId = 100;
        when(
          () => mockClient.create(
            model: any(named: 'model'),
            values: any(named: 'values'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async => createId++);

        final progressReports = <SyncProgress>[];

        await manager.syncToOdoo(
          onProgress: (progress) => progressReports.add(progress),
        );

        // Should have received progress reports
        expect(progressReports, isNotEmpty);
        expect(progressReports.last.phase, SyncPhase.uploading);
      });

      test('reports progress during syncFromOdoo', () async {
        mockClient.setupConfigured();
        // Need 100 records to trigger progress (default progressInterval is 50)
        mockClient.setupSearchCount(model: 'product.product', count: 100);

        // Return batches of products (100 per batch)
        when(
          () => mockClient.searchRead(
            model: 'product.product',
            fields: any(named: 'fields'),
            domain: any(named: 'domain'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((invocation) async {
          final offset = invocation.namedArguments[#offset] as int? ?? 0;
          if (offset >= 100) return [];

          // Return up to 100 items from requested offset
          final remaining = 100 - offset;
          final count = remaining < 100 ? remaining : 100;
          return List.generate(
            count,
            (i) => {
              'id': offset + i + 1,
              'name': 'Product ${offset + i + 1}',
              'list_price': 10.0 + i,
              'active': true,
            },
          );
        });

        manager.initialize(client: mockClient, db: mockDb, queue: queueWrapper);

        final progressReports = <SyncProgress>[];

        await manager.syncFromOdoo(
          onProgress: (progress) => progressReports.add(progress),
        );

        // Should have progress reports
        expect(progressReports, isNotEmpty);

        // Should have counting and downloading phases
        expect(
          progressReports.any((p) => p.phase == SyncPhase.counting),
          isTrue,
        );
        expect(
          progressReports.any((p) => p.phase == SyncPhase.downloading),
          isTrue,
        );
        expect(
          progressReports.any((p) => p.phase == SyncPhase.completed),
          isTrue,
        );
      });
    });

    group('Cancellation', () {
      test('can cancel syncFromOdoo', () async {
        mockClient.setupConfigured();
        mockClient.setupSearchCount(model: 'product.product', count: 1000);

        final token = CancellationToken();
        var batchCount = 0;

        when(
          () => mockClient.searchRead(
            model: 'product.product',
            fields: any(named: 'fields'),
            domain: any(named: 'domain'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((invocation) async {
          batchCount++;
          // Cancel after second batch for reliable test
          if (batchCount >= 2) {
            token.cancel();
          }

          return List.generate(
            100,
            (i) => {
              'id': (batchCount - 1) * 100 + i + 1,
              'name': 'Product ${(batchCount - 1) * 100 + i + 1}',
              'list_price': 10.0,
              'active': true,
            },
          );
        });

        manager.initialize(client: mockClient, db: mockDb, queue: queueWrapper);

        final result = await manager.syncFromOdoo(cancellation: token);

        expect(result.status, SyncStatus.cancelled);
        expect(batchCount, lessThanOrEqualTo(3)); // Should stop early

        token.dispose();
      });

      test('can cancel syncToOdoo', () async {
        mockClient.setupNotConfigured();

        manager.initialize(client: mockClient, db: mockDb, queue: queueWrapper);

        // Queue many operations
        for (int i = 0; i < 10; i++) {
          await manager.create(
            TestProduct(id: 0, name: 'Product $i', price: i * 10.0),
          );
        }

        mockClient.setupConfigured();
        var processCount = 0;
        when(
          () => mockClient.create(
            model: any(named: 'model'),
            values: any(named: 'values'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async {
          processCount++;
          await Future.delayed(const Duration(milliseconds: 10));
          return 100 + processCount;
        });

        final token = CancellationToken();

        // Cancel after a few operations
        Future.delayed(const Duration(milliseconds: 25), () {
          token.cancel();
        });

        final result = await manager.syncToOdoo(cancellation: token);

        expect(result.status, SyncStatus.cancelled);
        expect(processCount, lessThan(10)); // Should stop early

        token.dispose();
      });
    });

    group('Connectivity changes', () {
      test('create syncs immediately when online', () async {
        mockClient.setupConfigured();
        mockClient.setupCreate(model: 'product.product', resultId: 100);

        manager.initialize(client: mockClient, db: mockDb, queue: queueWrapper);

        const product = TestProduct(id: 0, name: 'Online Product', price: 50.0);
        final id = await manager.create(product);

        // Should return server ID when online
        expect(id, 100);

        // Should NOT be queued since sync succeeded
        final pending = await queueStore.getPendingOperations();
        expect(pending, isEmpty);

        // Local storage should have synced record with server ID
        final stored = await manager.readLocal(100);
        expect(stored, isNotNull);
        expect(stored!.isSynced, isTrue);
      });

      test('create queues when sync fails while online', () async {
        mockClient.setupConfigured();
        when(
          () => mockClient.create(
            model: any(named: 'model'),
            values: any(named: 'values'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenThrow(Exception('Network error'));

        manager.initialize(client: mockClient, db: mockDb, queue: queueWrapper);

        const product = TestProduct(id: 0, name: 'Failed Product', price: 50.0);
        final id = await manager.create(product);

        // Should return local ID
        expect(id, lessThan(0));

        // Should be queued for retry
        final pending = await queueStore.getPendingOperations();
        expect(pending.length, 1);
      });

      test('update syncs immediately when online', () async {
        manager.seedStorage([
          const TestProduct(
            id: 1,
            name: 'Original',
            price: 100.0,
            isSynced: true,
          ),
        ]);

        mockClient.setupConfigured();
        mockClient.setupWrite(model: 'product.product', result: true);

        manager.initialize(client: mockClient, db: mockDb, queue: queueWrapper);

        await manager.update(
          const TestProduct(id: 1, name: 'Updated', price: 150.0),
        );

        // Should NOT be queued since sync succeeded
        final pending = await queueStore.getPendingOperations();
        expect(pending, isEmpty);

        // Local record should be synced
        final stored = await manager.readLocal(1);
        expect(stored!.isSynced, isTrue);
      });

      test('isOnline reflects client configuration', () async {
        mockClient.setupNotConfigured();

        manager.initialize(client: mockClient, db: mockDb, queue: queueWrapper);

        expect(manager.isOnline, isFalse);

        // Reconfigure as online
        mockClient.setupConfigured();

        expect(manager.isOnline, isTrue);
      });
    });

    group('Queue statistics', () {
      test('tracks queue statistics correctly', () async {
        mockClient.setupNotConfigured();

        manager.initialize(client: mockClient, db: mockDb, queue: queueWrapper);

        // Create some operations
        await manager.create(
          const TestProduct(id: 0, name: 'Product 1', price: 10.0),
        );
        await manager.create(
          const TestProduct(id: 0, name: 'Product 2', price: 20.0),
        );

        var stats = await queueStore.getRetryStats();
        expect(stats['total'], 2);
        expect(stats['ready'], 2);

        // Fail one operation
        final pending = await queueStore.getPendingOperations();
        await queueStore.markOperationFailed(pending[0].id, 'Test error');

        stats = await queueStore.getRetryStats();
        expect(stats['total'], 2);
        expect(stats['scheduled'], 1); // Waiting for retry
      });
    });

    group('Record change events', () {
      test('emits create event on local create', () async {
        mockClient.setupNotConfigured();

        manager.initialize(client: mockClient, db: mockDb, queue: queueWrapper);

        final events = <RecordChangeEvent<TestProduct>>[];
        final subscription = manager.recordChanges.listen(events.add);

        await manager.create(
          const TestProduct(id: 0, name: 'New', price: 10.0),
        );

        await Future.delayed(const Duration(milliseconds: 10));
        subscription.cancel();

        expect(events.length, 1);
        expect(events[0].type, ChangeType.create);
      });

      test('emits update event on local update', () async {
        manager.seedStorage([
          const TestProduct(
            id: 1,
            name: 'Original',
            price: 100.0,
            isSynced: true,
          ),
        ]);

        mockClient.setupNotConfigured();

        manager.initialize(client: mockClient, db: mockDb, queue: queueWrapper);

        final events = <RecordChangeEvent<TestProduct>>[];
        final subscription = manager.recordChanges.listen(events.add);

        await manager.update(
          const TestProduct(id: 1, name: 'Updated', price: 150.0),
        );

        await Future.delayed(const Duration(milliseconds: 10));
        subscription.cancel();

        expect(events.length, 1);
        expect(events[0].type, ChangeType.update);
        expect(events[0].id, 1);
      });

      test('emits delete event on local delete', () async {
        manager.seedStorage([
          const TestProduct(
            id: 1,
            name: 'To Delete',
            price: 100.0,
            isSynced: true,
          ),
        ]);

        mockClient.setupNotConfigured();

        manager.initialize(client: mockClient, db: mockDb, queue: queueWrapper);

        final events = <RecordChangeEvent<TestProduct>>[];
        final subscription = manager.recordChanges.listen(events.add);

        await manager.delete(1);

        await Future.delayed(const Duration(milliseconds: 10));
        subscription.cancel();

        expect(events.length, 1);
        expect(events[0].type, ChangeType.delete);
        expect(events[0].id, 1);
      });
    });

    group('Unsynced records tracking', () {
      test('counts unsynced records correctly', () async {
        manager.seedStorage([
          const TestProduct(id: 1, name: 'Synced', price: 10.0, isSynced: true),
          const TestProduct(
            id: 2,
            name: 'Unsynced 1',
            price: 20.0,
            isSynced: false,
          ),
          const TestProduct(
            id: 3,
            name: 'Unsynced 2',
            price: 30.0,
            isSynced: false,
          ),
        ]);

        mockClient.setupNotConfigured();

        manager.initialize(client: mockClient, db: mockDb, queue: queueWrapper);

        final unsynced = await manager.getUnsyncedRecords();
        expect(unsynced.length, 2);
        expect(unsynced.any((p) => p.name == 'Unsynced 1'), isTrue);
        expect(unsynced.any((p) => p.name == 'Unsynced 2'), isTrue);
      });
    });

    group('Error handling', () {
      test('returns offline status when not connected', () async {
        mockClient.setupNotConfigured();

        manager.initialize(client: mockClient, db: mockDb, queue: queueWrapper);

        final result = await manager.syncFromOdoo();

        expect(result.status, SyncStatus.offline);
      });

      test('returns error status on sync failure', () async {
        mockClient.setupConfigured();
        when(
          () => mockClient.searchCount(
            model: any(named: 'model'),
            domain: any(named: 'domain'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenThrow(Exception('Server error'));

        manager.initialize(client: mockClient, db: mockDb, queue: queueWrapper);

        final result = await manager.syncFromOdoo();

        expect(result.status, SyncStatus.error);
        expect(result.error, isNotNull);
      });

      test('returns alreadyInProgress when sync is running', () async {
        mockClient.setupConfigured();
        mockClient.setupSearchCount(model: 'product.product', count: 1000);

        // Slow response
        when(
          () => mockClient.searchRead(
            model: any(named: 'model'),
            fields: any(named: 'fields'),
            domain: any(named: 'domain'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return [];
        });

        manager.initialize(client: mockClient, db: mockDb, queue: queueWrapper);

        // Start first sync
        final future1 = manager.syncFromOdoo();

        // Try to start second sync immediately
        await Future.delayed(const Duration(milliseconds: 10));
        final result2 = await manager.syncFromOdoo();

        expect(result2.status, SyncStatus.alreadyInProgress);

        // Wait for first to complete
        await future1;
      });
    });
  });
}
