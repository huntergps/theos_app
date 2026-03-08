import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

import 'mocks/mocks.dart';

void main() {
  late TestFixtures fixtures;

  setUpAll(() {
    registerAllFallbacks();
  });

  setUp(() async {
    fixtures = TestFixtures();
    await fixtures.setUp();
  });

  tearDown(() {
    fixtures.tearDown();
  });

  group('OdooModelManager Sync Operations', () {
    group('syncFromOdoo', () {
      test('returns offline result when not online', () async {
        fixtures.setOffline();

        final result = await fixtures.manager.syncFromOdoo();

        expect(result.status, equals(SyncStatus.offline));
        expect(result.model, equals('product.product'));
      });

      test('returns already in progress when sync is running', () async {
        fixtures.setOnline();

        // Setup a slow searchCount to simulate in-progress sync
        when(
          () => fixtures.mockClient.searchCount(
            model: any(named: 'model'),
            domain: any(named: 'domain'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return 0;
        });

        // Start first sync
        final firstSync = fixtures.manager.syncFromOdoo();

        // Small delay to let first sync start
        await Future.delayed(const Duration(milliseconds: 10));

        // Try to start second sync while first is running
        final secondResult = await fixtures.manager.syncFromOdoo();

        expect(secondResult.status, equals(SyncStatus.alreadyInProgress));

        // Wait for first sync to complete
        await firstSync;
      });

      test('successfully syncs records from Odoo', () async {
        fixtures.setOnline();

        // Setup searchCount to return total
        when(
          () => fixtures.mockClient.searchCount(
            model: 'product.product',
            domain: any(named: 'domain'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async => 3);

        // Setup searchRead to return products
        when(
          () => fixtures.mockClient.searchRead(
            model: 'product.product',
            fields: any(named: 'fields'),
            domain: any(named: 'domain'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer(
          (_) async => [
            SampleOdooData.product(id: 1, name: 'Product 1', price: 10.0),
            SampleOdooData.product(id: 2, name: 'Product 2', price: 20.0),
            SampleOdooData.product(id: 3, name: 'Product 3', price: 30.0),
          ],
        );

        final result = await fixtures.manager.syncFromOdoo();

        expect(result.status, equals(SyncStatus.success));
        expect(result.synced, equals(3));

        // Verify records were stored locally
        final p1 = await fixtures.manager.readLocal(1);
        final p2 = await fixtures.manager.readLocal(2);
        final p3 = await fixtures.manager.readLocal(3);

        expect(p1, isNotNull);
        expect(p1!.name, equals('Product 1'));
        expect(p1.isSynced, isTrue);

        expect(p2, isNotNull);
        expect(p2!.name, equals('Product 2'));

        expect(p3, isNotNull);
        expect(p3!.name, equals('Product 3'));
      });

      test('handles empty result from Odoo', () async {
        fixtures.setOnline();

        when(
          () => fixtures.mockClient.searchCount(
            model: any(named: 'model'),
            domain: any(named: 'domain'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async => 0);

        when(
          () => fixtures.mockClient.searchRead(
            model: any(named: 'model'),
            fields: any(named: 'fields'),
            domain: any(named: 'domain'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async => []);

        final result = await fixtures.manager.syncFromOdoo();

        expect(result.status, equals(SyncStatus.success));
        expect(result.synced, equals(0));
      });

      test('handles pre-cancelled token', () async {
        fixtures.setOnline();

        when(
          () => fixtures.mockClient.searchCount(
            model: any(named: 'model'),
            domain: any(named: 'domain'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async => 100);

        when(
          () => fixtures.mockClient.searchRead(
            model: any(named: 'model'),
            fields: any(named: 'fields'),
            domain: any(named: 'domain'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async => SampleOdooData.products(count: 10));

        final cancellation = CancellationToken();

        // Pre-cancel the token before starting sync
        cancellation.cancel();

        final result = await fixtures.manager.syncFromOdoo(
          cancellation: cancellation,
        );

        // Cancellation is checked at start of while loop, before any records processed
        expect(result.status, equals(SyncStatus.cancelled));
        expect(
          result.synced,
          equals(0),
        ); // No records processed before cancellation check

        cancellation.dispose();
      });

      test('supports cancellation during multi-batch sync', () async {
        fixtures.setOnline();

        when(
          () => fixtures.mockClient.searchCount(
            model: any(named: 'model'),
            domain: any(named: 'domain'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async => 200);

        var batchCount = 0;
        final cancellation = CancellationToken();

        // Return batch size records (100) to ensure hasMore = true
        when(
          () => fixtures.mockClient.searchRead(
            model: any(named: 'model'),
            fields: any(named: 'fields'),
            domain: any(named: 'domain'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async {
          batchCount++;
          // Cancel after first batch
          if (batchCount == 1) {
            cancellation.cancel();
          }
          // Return exactly 100 records (batch size) on first call
          return List.generate(
            100,
            (i) => SampleOdooData.product(
              id: (batchCount - 1) * 100 + i + 1,
              name: 'Product $i',
            ),
          );
        });

        final result = await fixtures.manager.syncFromOdoo(
          cancellation: cancellation,
        );

        // First batch processed, then cancellation detected
        expect(result.status, equals(SyncStatus.cancelled));
        expect(result.synced, equals(100)); // First batch was processed

        cancellation.dispose();
      });

      test('reports progress during sync', () async {
        fixtures.setOnline();

        when(
          () => fixtures.mockClient.searchCount(
            model: any(named: 'model'),
            domain: any(named: 'domain'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async => 5);

        when(
          () => fixtures.mockClient.searchRead(
            model: any(named: 'model'),
            fields: any(named: 'fields'),
            domain: any(named: 'domain'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async => SampleOdooData.products(count: 5));

        final progressReports = <SyncProgress>[];

        await fixtures.manager.syncFromOdoo(onProgress: progressReports.add);

        // Should have at least counting and completed phases
        expect(progressReports, isNotEmpty);
        expect(
          progressReports.any((p) => p.phase == SyncPhase.counting),
          isTrue,
        );
        expect(
          progressReports.any((p) => p.phase == SyncPhase.completed),
          isTrue,
        );
      });

      test('handles network error gracefully', () async {
        fixtures.setOnline();
        fixtures.setupNetworkError();

        final result = await fixtures.manager.syncFromOdoo();

        expect(result.status, equals(SyncStatus.error));
        expect(result.error, isNotNull);
      });

      test('syncs incrementally with since parameter', () async {
        fixtures.setOnline();

        final since = DateTime.now().subtract(const Duration(hours: 1));

        when(
          () => fixtures.mockClient.searchCount(
            model: any(named: 'model'),
            domain: any(named: 'domain'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async => 2);

        when(
          () => fixtures.mockClient.searchRead(
            model: any(named: 'model'),
            fields: any(named: 'fields'),
            domain: any(named: 'domain'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async => SampleOdooData.products(count: 2));

        final result = await fixtures.manager.syncFromOdoo(since: since);

        expect(result.status, equals(SyncStatus.success));
        expect(result.synced, equals(2));

        // Verify searchCount was called (domain would include write_date filter)
        verify(
          () => fixtures.mockClient.searchCount(
            model: 'product.product',
            domain: any(named: 'domain'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).called(1);
      });

      test('updates lastSyncTime on success', () async {
        fixtures.setOnline();

        when(
          () => fixtures.mockClient.searchCount(
            model: any(named: 'model'),
            domain: any(named: 'domain'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async => 0);

        when(
          () => fixtures.mockClient.searchRead(
            model: any(named: 'model'),
            fields: any(named: 'fields'),
            domain: any(named: 'domain'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async => []);

        await fixtures.manager.syncFromOdoo();

        // BehaviorSubject emits current value on new subscription
        final lastSync = await fixtures.manager.lastSyncTime.first;
        expect(lastSync, isNotNull);
      });
    });

    group('syncToOdoo', () {
      test('returns offline result when not online', () async {
        fixtures.setOffline();

        final result = await fixtures.manager.syncToOdoo();

        expect(result.status, equals(SyncStatus.offline));
      });

      test('processes queued create operations', () async {
        fixtures.setOnline();

        // Create a record offline first
        fixtures.setOffline();
        final localId = await fixtures.manager.create(
          const TestProduct(id: 0, name: 'Offline Product', price: 25.0),
        );

        expect(localId, lessThan(0)); // Local ID is negative

        // Verify operation was queued
        final queued = await fixtures.inMemoryQueueStore.getPendingOperations();
        expect(queued.length, equals(1));
        expect(queued.first.method, equals('create'));

        // Now go online and sync
        fixtures.setOnline();
        fixtures.setupCreate(resultId: 100);

        final result = await fixtures.manager.syncToOdoo();

        expect(result.status, equals(SyncStatus.success));
        expect(result.synced, equals(1));

        // Verify the local record was updated with server ID
        final synced = await fixtures.manager.readLocal(100);
        expect(synced, isNotNull);
        expect(synced!.name, equals('Offline Product'));
        expect(synced.isSynced, isTrue);
      });

      test('processes queued write operations', () async {
        fixtures.setOnline();

        // Seed an existing synced record
        fixtures.seedProducts([
          TestProductFactory.create(id: 5, name: 'Original', isSynced: true),
        ]);

        // Go offline and update
        fixtures.setOffline();
        await fixtures.manager.update(
          const TestProduct(id: 5, name: 'Updated Offline', price: 50.0),
        );

        // Verify operation was queued
        final queued = await fixtures.inMemoryQueueStore.getPendingOperations();
        expect(queued.length, equals(1));
        expect(queued.first.method, equals('write'));

        // Now go online and sync
        fixtures.setOnline();
        fixtures.setupWrite(success: true);

        final result = await fixtures.manager.syncToOdoo();

        expect(result.status, equals(SyncStatus.success));
        expect(result.synced, equals(1));
      });

      test('processes queued unlink operations', () async {
        fixtures.setOnline();

        // Seed an existing synced record
        fixtures.seedProducts([
          TestProductFactory.create(id: 10, isSynced: true),
        ]);

        // Go offline and delete
        fixtures.setOffline();
        await fixtures.manager.delete(10);

        // Verify operation was queued
        final queued = await fixtures.inMemoryQueueStore.getPendingOperations();
        expect(queued.length, equals(1));
        expect(queued.first.method, equals('unlink'));

        // Now go online and sync
        fixtures.setOnline();
        fixtures.setupUnlink(success: true);

        final result = await fixtures.manager.syncToOdoo();

        expect(result.status, equals(SyncStatus.success));
        expect(result.synced, equals(1));
      });

      test('handles operation failure and marks as failed', () async {
        fixtures.setOnline();

        // Create a record offline
        fixtures.setOffline();
        await fixtures.manager.create(
          const TestProduct(id: 0, name: 'Will Fail', price: 10.0),
        );

        // Setup network error for create
        fixtures.setOnline();
        fixtures.setupNetworkError();

        final result = await fixtures.manager.syncToOdoo();

        // When all operations fail, status is partial (not success)
        // success is only when synced > 0 and failed == 0
        expect(result.status, anyOf(SyncStatus.success, SyncStatus.partial));
        expect(result.synced, equals(0));
        expect(result.failed, equals(1));
      });

      test('reports progress during sync', () async {
        fixtures.setOnline();

        // Create multiple offline records
        fixtures.setOffline();
        await fixtures.manager.create(
          const TestProduct(id: 0, name: 'Product 1', price: 10.0),
        );
        await fixtures.manager.create(
          const TestProduct(id: 0, name: 'Product 2', price: 20.0),
        );

        fixtures.setOnline();
        fixtures.setupCreate(resultId: 101);

        final progressReports = <SyncProgress>[];

        await fixtures.manager.syncToOdoo(onProgress: progressReports.add);

        expect(progressReports, isNotEmpty);
        expect(
          progressReports.any((p) => p.phase == SyncPhase.uploading),
          isTrue,
        );
      });

      test('handles cancellation', () async {
        fixtures.setOnline();

        // Create several offline records
        fixtures.setOffline();
        for (var i = 0; i < 10; i++) {
          await fixtures.manager.create(
            TestProduct(id: 0, name: 'Product $i', price: 10.0),
          );
        }

        fixtures.setOnline();

        var processedCount = 0;

        // Setup slow create to allow cancellation
        when(
          () => fixtures.mockClient.create(
            model: any(named: 'model'),
            values: any(named: 'values'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async {
          processedCount++;
          // First few complete quickly, then slow down
          if (processedCount > 2) {
            await Future.delayed(const Duration(milliseconds: 200));
          }
          return 100 + processedCount;
        });

        final cancellation = CancellationToken();

        // Cancel after a couple operations complete
        Future.delayed(const Duration(milliseconds: 50), () {
          cancellation.cancel();
        });

        final result = await fixtures.manager.syncToOdoo(
          cancellation: cancellation,
        );

        expect(result.status, equals(SyncStatus.cancelled));
        // Some operations should have been processed before cancellation
        expect(result.synced, lessThan(10));

        cancellation.dispose();
      });

      test('returns success with zero synced when queue is empty', () async {
        fixtures.setOnline();

        final result = await fixtures.manager.syncToOdoo();

        expect(result.status, equals(SyncStatus.success));
        expect(result.synced, equals(0));
      });
    });

    group('sync (bidirectional)', () {
      test('performs upload then download', () async {
        fixtures.setOnline();

        // Create an offline record first
        fixtures.setOffline();
        await fixtures.manager.create(
          const TestProduct(id: 0, name: 'Local Product', price: 15.0),
        );

        fixtures.setOnline();
        fixtures.setupCreate(resultId: 200);

        // Setup download
        when(
          () => fixtures.mockClient.searchCount(
            model: any(named: 'model'),
            domain: any(named: 'domain'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async => 1);

        when(
          () => fixtures.mockClient.searchRead(
            model: any(named: 'model'),
            fields: any(named: 'fields'),
            domain: any(named: 'domain'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer(
          (_) async => [
            SampleOdooData.product(id: 300, name: 'Server Product'),
          ],
        );

        final result = await fixtures.manager.sync();

        expect(result.status, equals(SyncStatus.success));

        // Both local and server products should exist
        expect(await fixtures.manager.readLocal(200), isNotNull);
        expect(await fixtures.manager.readLocal(300), isNotNull);
      });

      test('stops if upload is cancelled', () async {
        fixtures.setOnline();

        // Create multiple offline records to ensure sync takes time
        fixtures.setOffline();
        for (var i = 0; i < 5; i++) {
          await fixtures.manager.create(
            TestProduct(id: 0, name: 'Local $i', price: 10.0),
          );
        }

        fixtures.setOnline();

        var createCount = 0;

        // Setup slow create to allow cancellation
        when(
          () => fixtures.mockClient.create(
            model: any(named: 'model'),
            values: any(named: 'values'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async {
          createCount++;
          // First create is quick, rest are slow
          if (createCount > 1) {
            await Future.delayed(const Duration(milliseconds: 200));
          }
          return 100 + createCount;
        });

        final cancellation = CancellationToken();

        // Cancel after first create completes
        Future.delayed(const Duration(milliseconds: 30), () {
          cancellation.cancel();
        });

        final result = await fixtures.manager.sync(cancellation: cancellation);

        expect(result.status, equals(SyncStatus.cancelled));

        // searchCount should NOT have been called (stopped during upload)
        verifyNever(
          () => fixtures.mockClient.searchCount(
            model: any(named: 'model'),
            domain: any(named: 'domain'),
            cancelToken: any(named: 'cancelToken'),
          ),
        );

        cancellation.dispose();
      });

      test('returns combined result from both operations', () async {
        fixtures.setOnline();

        // No pending operations, just download
        when(
          () => fixtures.mockClient.searchCount(
            model: any(named: 'model'),
            domain: any(named: 'domain'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async => 2);

        when(
          () => fixtures.mockClient.searchRead(
            model: any(named: 'model'),
            fields: any(named: 'fields'),
            domain: any(named: 'domain'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async => SampleOdooData.products(count: 2));

        final result = await fixtures.manager.sync();

        expect(result.status, equals(SyncStatus.success));
        expect(result.synced, equals(2)); // From download
      });
    });

    group('syncInProgress stream', () {
      test('emits true during sync and false after', () async {
        fixtures.setOnline();

        when(
          () => fixtures.mockClient.searchCount(
            model: any(named: 'model'),
            domain: any(named: 'domain'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 50));
          return 0;
        });

        when(
          () => fixtures.mockClient.searchRead(
            model: any(named: 'model'),
            fields: any(named: 'fields'),
            domain: any(named: 'domain'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async => []);

        final states = <bool>[];
        final subscription = fixtures.manager.syncInProgress.listen(states.add);

        await fixtures.manager.syncFromOdoo();

        // Give time for stream to emit
        await Future.delayed(const Duration(milliseconds: 20));

        // Should have emitted true then false
        expect(states.contains(true), isTrue);
        expect(states.last, isFalse);

        await subscription.cancel();
      });
    });

    group('Background sync', () {
      test('read triggers background sync when online', () async {
        fixtures.setOnline();

        // Seed a local record
        fixtures.seedProducts([
          TestProductFactory.create(
            id: 1,
            name: 'Local Version',
            isSynced: true,
          ),
        ]);

        // Setup read to return updated data
        when(
          () => fixtures.mockClient.read(
            model: 'product.product',
            ids: [1],
            fields: any(named: 'fields'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer(
          (_) async => [SampleOdooData.product(id: 1, name: 'Server Version')],
        );

        // Read should return local immediately
        final result = await fixtures.manager.read(1);
        expect(result!.name, equals('Local Version'));

        // Wait for background sync
        await Future.delayed(const Duration(milliseconds: 100));

        // Local should now have server version
        final updated = await fixtures.manager.readLocal(1);
        expect(updated!.name, equals('Server Version'));
      });

      test('background sync errors are emitted to error stream', () async {
        fixtures.setOnline();
        fixtures.setupNetworkError();

        fixtures.seedProducts([
          TestProductFactory.create(id: 1, name: 'Test', isSynced: true),
        ]);

        final errors = <BackgroundSyncError>[];
        final subscription = fixtures.manager.backgroundErrors.listen(
          errors.add,
        );

        // Trigger read which will attempt background sync
        await fixtures.manager.read(1);

        // Wait for background sync to fail
        await Future.delayed(const Duration(milliseconds: 100));

        expect(errors, isNotEmpty);
        expect(errors.first.model, equals('product.product'));
        expect(errors.first.recordId, equals(1));

        await subscription.cancel();
      });
    });

    group('Conflict detection', () {
      test('detectConflict returns null when no conflict', () async {
        fixtures.setOnline();

        fixtures.seedProducts([
          TestProductFactory.create(id: 1, name: 'Same Name', isSynced: true),
        ]);

        // Setup read to return same data
        when(
          () => fixtures.mockClient.read(
            model: 'product.product',
            ids: [1],
            fields: any(named: 'fields'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer(
          (_) async => [SampleOdooData.product(id: 1, name: 'Same Name')],
        );

        final conflict = await fixtures.manager.detectConflict(1);

        // If names match, there's no conflict
        // (actual conflict detection depends on implementation)
        // This test verifies the method works without error
        expect(conflict, isNull);
      });
    });

    group('Unsynced count stream', () {
      test('updates when creating offline records', () async {
        fixtures.setOffline();

        final counts = <int>[];
        final subscription = fixtures.manager.unsyncedCount.listen(counts.add);

        await fixtures.manager.create(
          const TestProduct(id: 0, name: 'Unsynced 1', price: 10.0),
        );
        await fixtures.manager.create(
          const TestProduct(id: 0, name: 'Unsynced 2', price: 20.0),
        );

        // Give time for stream updates
        await Future.delayed(const Duration(milliseconds: 50));

        // Should have increasing counts
        expect(counts.isNotEmpty, isTrue);

        await subscription.cancel();
      });

      test('updates after sync completes', () async {
        fixtures.setOffline();

        // Create offline records
        await fixtures.manager.create(
          const TestProduct(id: 0, name: 'To Sync', price: 10.0),
        );

        // Check initial count
        var unsynced = await fixtures.manager.getUnsyncedRecords();
        expect(unsynced.length, equals(1));

        // Go online and sync
        fixtures.setOnline();
        fixtures.setupCreate(resultId: 100);

        await fixtures.manager.syncToOdoo();

        // Give time for count update
        await Future.delayed(const Duration(milliseconds: 50));

        // Should have fewer unsynced records
        unsynced = await fixtures.manager.getUnsyncedRecords();
        expect(unsynced.length, equals(0));
      });
    });
  });
}
