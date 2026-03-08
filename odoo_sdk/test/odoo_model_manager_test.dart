import 'package:test/test.dart';
import 'package:odoo_sdk/src/model/odoo_model_manager.dart';

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

  group('OdooModelManager', () {
    group('Initialization', () {
      test('should initialize with dependencies', () {
        expect(fixtures.manager, isNotNull);
        expect(fixtures.manager.odooModel, equals('product.product'));
        expect(fixtures.manager.tableName, equals('product_product'));
      });

      test('should report online status when client is configured', () {
        fixtures.setOnline();
        expect(fixtures.manager.isOnline, isTrue);
      });

      test('should report offline status when client is not configured', () {
        fixtures.setOffline();
        expect(fixtures.manager.isOnline, isFalse);
      });
    });

    group('Local CRUD Operations', () {
      test('readLocal returns null for non-existent record', () async {
        final result = await fixtures.manager.readLocal(999);
        expect(result, isNull);
      });

      test('upsertLocal and readLocal work correctly', () async {
        final product = TestProductFactory.create(
          id: 1,
          name: 'Test Product',
          price: 25.0,
        );

        await fixtures.manager.upsertLocal(product);
        final result = await fixtures.manager.readLocal(1);

        expect(result, isNotNull);
        expect(result!.id, equals(1));
        expect(result.name, equals('Test Product'));
        expect(result.price, equals(25.0));
      });

      test('readLocalByUuid returns record by UUID', () async {
        final product = TestProductFactory.create(
          id: 1,
          uuid: 'test-uuid-123',
          name: 'UUID Test',
        );

        await fixtures.manager.upsertLocal(product);
        final result = await fixtures.manager.readLocalByUuid('test-uuid-123');

        expect(result, isNotNull);
        expect(result!.uuid, equals('test-uuid-123'));
      });

      test('deleteLocal removes record from storage', () async {
        final product = TestProductFactory.create(id: 1);

        await fixtures.manager.upsertLocal(product);
        expect(await fixtures.manager.readLocal(1), isNotNull);

        await fixtures.manager.deleteLocal(1);
        expect(await fixtures.manager.readLocal(1), isNull);
      });

      test('searchLocal returns all records when no domain', () async {
        final products = TestProductFactory.createMany(5);
        fixtures.seedProducts(products);

        final results = await fixtures.manager.searchLocal();

        expect(results.length, equals(5));
      });

      test('searchLocal applies limit', () async {
        final products = TestProductFactory.createMany(10);
        fixtures.seedProducts(products);

        final results = await fixtures.manager.searchLocal(limit: 3);

        expect(results.length, equals(3));
      });

      test('searchLocal applies offset', () async {
        final products = TestProductFactory.createMany(10);
        fixtures.seedProducts(products);

        await fixtures.manager.searchLocal();
        final offset = await fixtures.manager.searchLocal(offset: 5);

        expect(offset.length, equals(5));
      });

      test('searchLocal filters by domain', () async {
        fixtures.seedProducts([
          TestProductFactory.create(id: 1, name: 'Apple', price: 10.0),
          TestProductFactory.create(id: 2, name: 'Banana', price: 20.0),
          TestProductFactory.create(id: 3, name: 'Cherry', price: 30.0),
        ]);

        final results = await fixtures.manager.searchLocal(
          domain: SampleDomains.priceGreaterThan(15.0),
        );

        expect(results.length, equals(2));
        expect(results.every((p) => p.price > 15.0), isTrue);
      });

      test('countLocal returns correct count', () async {
        final products = TestProductFactory.createMany(7);
        fixtures.seedProducts(products);

        final count = await fixtures.manager.countLocal();

        expect(count, equals(7));
      });

      test('getUnsyncedRecords returns only unsynced records', () async {
        fixtures.seedProducts([
          TestProductFactory.create(id: 1, isSynced: true),
          TestProductFactory.create(id: 2, isSynced: false),
          TestProductFactory.create(id: 3, isSynced: false),
        ]);

        final unsynced = await fixtures.manager.getUnsyncedRecords();

        expect(unsynced.length, equals(2));
        expect(unsynced.every((p) => !p.isSynced), isTrue);
      });
    });

    group('Online CRUD Operations', () {
      test('create saves locally and syncs to Odoo when online', () async {
        fixtures.setOnline();
        fixtures.setupCreate(resultId: 100);

        const product = TestProduct(id: 0, name: 'New Product', price: 50.0);
        final id = await fixtures.manager.create(product);

        expect(id, equals(100));

        // Verify local storage has the synced record
        final stored = await fixtures.manager.readLocal(100);
        expect(stored, isNotNull);
        expect(stored!.name, equals('New Product'));
        expect(stored.isSynced, isTrue);
      });

      test('create saves locally and queues when online sync fails', () async {
        fixtures.setOnline();
        fixtures.setupNetworkError();

        const product = TestProduct(id: 0, name: 'New Product', price: 50.0);
        final id = await fixtures.manager.create(product);

        // Should return a local (negative) ID
        expect(id, lessThan(0));

        // Should be saved locally
        final stored = await fixtures.manager.readLocal(id);
        expect(stored, isNotNull);
        expect(stored!.isSynced, isFalse);

        // Should be queued
        final queued = await fixtures.inMemoryQueueStore.getPendingOperations();
        expect(queued.length, equals(1));
        expect(queued.first.model, equals('product.product'));
        expect(queued.first.method, equals('create'));
      });

      test('create saves locally and queues when offline', () async {
        fixtures.setOffline();

        const product = TestProduct(
          id: 0,
          name: 'Offline Product',
          price: 30.0,
        );
        final id = await fixtures.manager.create(product);

        // Should return a local (negative) ID
        expect(id, lessThan(0));

        // Should be saved locally
        final stored = await fixtures.manager.readLocal(id);
        expect(stored, isNotNull);
        expect(stored!.isSynced, isFalse);

        // Should be queued
        final queued = await fixtures.inMemoryQueueStore.getPendingOperations();
        expect(queued.length, equals(1));
      });

      test('update syncs to Odoo when online', () async {
        fixtures.setOnline();
        fixtures.setupWrite(success: true);

        // Seed an existing synced product
        final original = TestProductFactory.create(
          id: 5,
          name: 'Original',
          price: 10.0,
          isSynced: true,
        );
        fixtures.seedProducts([original]);

        // Update it
        final updated = original.copyWith(name: 'Updated', price: 15.0);
        final success = await fixtures.manager.update(updated);

        expect(success, isTrue);

        // Verify it was synced
        fixtures.mockClient.verifyWriteCalled(ids: [5]);
      });

      test('update saves locally and queues when offline', () async {
        fixtures.setOffline();

        final original = TestProductFactory.create(
          id: 5,
          name: 'Original',
          isSynced: true,
        );
        fixtures.seedProducts([original]);

        final updated = original.copyWith(name: 'Updated');
        final success = await fixtures.manager.update(updated);

        expect(success, isTrue);

        // Should be queued
        final queued = await fixtures.inMemoryQueueStore.getPendingOperations();
        expect(queued.length, equals(1));
        expect(queued.first.method, equals('write'));
      });

      test('delete syncs to Odoo when online', () async {
        fixtures.setOnline();
        fixtures.setupUnlink(success: true);

        fixtures.seedProducts([TestProductFactory.create(id: 10)]);

        final success = await fixtures.manager.delete(10);

        expect(success, isTrue);
        expect(await fixtures.manager.readLocal(10), isNull);

        fixtures.mockClient.verifyUnlinkCalled(ids: [10]);
      });

      test('delete removes locally and queues when offline', () async {
        fixtures.setOffline();

        fixtures.seedProducts([TestProductFactory.create(id: 10)]);

        final success = await fixtures.manager.delete(10);

        expect(success, isTrue);
        expect(await fixtures.manager.readLocal(10), isNull);

        final queued = await fixtures.inMemoryQueueStore.getPendingOperations();
        expect(queued.length, equals(1));
        expect(queued.first.method, equals('unlink'));
      });

      test('delete with negative ID does not queue', () async {
        fixtures.setOffline();

        const localId = -12345;
        fixtures.seedProducts([
          const TestProduct(id: localId, name: 'Local', price: 10.0),
        ]);

        final success = await fixtures.manager.delete(localId);

        expect(success, isTrue);

        // Should NOT be queued (never synced to server)
        final queued = await fixtures.inMemoryQueueStore.getPendingOperations();
        expect(queued.isEmpty, isTrue);
      });
    });

    group('Read with Background Sync', () {
      test('read returns local data and triggers background sync', () async {
        fixtures.setOnline();

        // Seed local data
        final product = TestProductFactory.create(
          id: 1,
          name: 'Local Version',
          isSynced: true,
        );
        fixtures.seedProducts([product]);

        // Setup mock to return updated data
        fixtures.setupReadProducts(
          [1],
          [SampleOdooData.product(id: 1, name: 'Server Version')],
        );

        // Read should return local immediately
        final result = await fixtures.manager.read(1);

        expect(result, isNotNull);
        expect(result!.name, equals('Local Version'));

        // Give background sync time to complete
        await Future.delayed(const Duration(milliseconds: 50));

        // Now local should be updated with server version
        final updated = await fixtures.manager.readLocal(1);
        expect(updated!.name, equals('Server Version'));
      });

      test('read returns local data when offline', () async {
        fixtures.setOffline();

        final product = TestProductFactory.create(id: 1, name: 'Offline Data');
        fixtures.seedProducts([product]);

        final result = await fixtures.manager.read(1);

        expect(result, isNotNull);
        expect(result!.name, equals('Offline Data'));
      });
    });

    group('Search with Domain Validation', () {
      test('search returns local results', () async {
        fixtures.seedProducts([
          TestProductFactory.create(id: 1, name: 'A', price: 10.0),
          TestProductFactory.create(id: 2, name: 'B', price: 20.0),
          TestProductFactory.create(id: 3, name: 'C', price: 30.0),
        ]);

        final results = await fixtures.manager.search(
          domain: SampleDomains.priceGreaterThan(15.0),
          limit: 10,
        );

        expect(results.length, equals(2));
      });

      test('search with null domain returns all records', () async {
        fixtures.seedProducts(TestProductFactory.createMany(5));

        final results = await fixtures.manager.search();

        expect(results.length, equals(5));
      });
    });

    group('Batch Operations', () {
      test('createBatch creates multiple records', () async {
        final products = [
          const TestProduct(id: 0, name: 'Batch 1', price: 10.0),
          const TestProduct(id: 0, name: 'Batch 2', price: 20.0),
          const TestProduct(id: 0, name: 'Batch 3', price: 30.0),
        ];

        final ids = await fixtures.manager.createBatch(products);

        expect(ids.length, equals(3));
        expect(ids.every((id) => id < 0), isTrue); // All local IDs

        // Verify all are stored
        for (final id in ids) {
          expect(await fixtures.manager.readLocal(id), isNotNull);
        }
      });

      test('updateBatch updates multiple records', () async {
        fixtures.seedProducts([
          TestProductFactory.create(id: 1, name: 'Original 1'),
          TestProductFactory.create(id: 2, name: 'Original 2'),
        ]);

        await fixtures.manager.updateBatch([
          const TestProduct(id: 1, name: 'Updated 1', price: 100.0),
          const TestProduct(id: 2, name: 'Updated 2', price: 200.0),
        ]);

        final p1 = await fixtures.manager.readLocal(1);
        final p2 = await fixtures.manager.readLocal(2);

        expect(p1!.name, equals('Updated 1'));
        expect(p2!.name, equals('Updated 2'));
      });

      test('deleteBatch deletes multiple records', () async {
        fixtures.seedProducts([
          TestProductFactory.create(id: 1),
          TestProductFactory.create(id: 2),
          TestProductFactory.create(id: 3),
        ]);

        await fixtures.manager.deleteBatch([1, 2]);

        expect(await fixtures.manager.readLocal(1), isNull);
        expect(await fixtures.manager.readLocal(2), isNull);
        expect(await fixtures.manager.readLocal(3), isNotNull);
      });
    });

    group('Convenience Methods', () {
      test('exists returns true for existing record', () async {
        fixtures.seedProducts([TestProductFactory.create(id: 1)]);

        expect(await fixtures.manager.exists(1), isTrue);
        expect(await fixtures.manager.exists(999), isFalse);
      });

      test('existsByUuid returns true for existing UUID', () async {
        fixtures.seedProducts([
          TestProductFactory.create(id: 1, uuid: 'test-uuid'),
        ]);

        expect(await fixtures.manager.existsByUuid('test-uuid'), isTrue);
        expect(await fixtures.manager.existsByUuid('nonexistent'), isFalse);
      });

      test('findById is alias for readLocal', () async {
        fixtures.seedProducts([TestProductFactory.create(id: 1, name: 'Test')]);

        final result = await fixtures.manager.findById(1);

        expect(result, isNotNull);
        expect(result!.name, equals('Test'));
      });

      test('findByIds returns multiple records', () async {
        fixtures.seedProducts([
          TestProductFactory.create(id: 1, name: 'A'),
          TestProductFactory.create(id: 2, name: 'B'),
          TestProductFactory.create(id: 3, name: 'C'),
        ]);

        final results = await fixtures.manager.findByIds([1, 3]);

        expect(results.length, equals(2));
        expect(results.map((p) => p.name).toList(), containsAll(['A', 'C']));
      });

      test('first returns first matching record', () async {
        fixtures.seedProducts([
          TestProductFactory.create(id: 1, name: 'First', price: 10.0),
          TestProductFactory.create(id: 2, name: 'Second', price: 20.0),
        ]);

        final result = await fixtures.manager.first(
          domain: SampleDomains.priceGreaterThan(15.0),
        );

        expect(result, isNotNull);
        expect(result!.price, greaterThan(15.0));
      });

      test('first returns null when no match', () async {
        fixtures.seedProducts([TestProductFactory.create(id: 1, price: 5.0)]);

        final result = await fixtures.manager.first(
          domain: SampleDomains.priceGreaterThan(100.0),
        );

        expect(result, isNull);
      });

      test('all returns all records with pagination', () async {
        fixtures.seedProducts(TestProductFactory.createMany(10));

        final all = await fixtures.manager.all();
        expect(all.length, equals(10));

        final limited = await fixtures.manager.all(limit: 5);
        expect(limited.length, equals(5));

        final offset = await fixtures.manager.all(offset: 7);
        expect(offset.length, equals(3));
      });
    });

    group('Record Change Events', () {
      test('create emits change event', () async {
        final events = <RecordChangeEvent<TestProduct>>[];
        final subscription = fixtures.manager.recordChanges.listen(events.add);

        // Wait for subscription to be established
        await Future.delayed(const Duration(milliseconds: 5));

        await fixtures.manager.create(
          const TestProduct(id: 0, name: 'New', price: 10.0),
        );

        // Wait for events to propagate
        await Future.delayed(const Duration(milliseconds: 50));

        expect(events, isNotEmpty);
        expect(events.any((e) => e.type == ChangeType.create), isTrue);

        await subscription.cancel();
      });

      test('update emits change event', () async {
        fixtures.seedProducts([TestProductFactory.create(id: 1)]);

        final events = <RecordChangeEvent<TestProduct>>[];
        final subscription = fixtures.manager.recordChanges.listen(events.add);

        // Wait for subscription to be established
        await Future.delayed(const Duration(milliseconds: 5));

        await fixtures.manager.update(
          const TestProduct(id: 1, name: 'Updated', price: 20.0),
        );

        // Wait for events to propagate
        await Future.delayed(const Duration(milliseconds: 50));

        expect(events, isNotEmpty);
        expect(
          events.any((e) => e.type == ChangeType.update && e.id == 1),
          isTrue,
        );

        await subscription.cancel();
      });

      test('delete emits change event', () async {
        fixtures.seedProducts([TestProductFactory.create(id: 1)]);

        final events = <RecordChangeEvent<TestProduct>>[];
        final subscription = fixtures.manager.recordChanges.listen(events.add);

        // Wait for subscription to be established
        await Future.delayed(const Duration(milliseconds: 5));

        await fixtures.manager.delete(1);

        // Wait for events to propagate
        await Future.delayed(const Duration(milliseconds: 50));

        expect(events, isNotEmpty);
        expect(
          events.any((e) => e.type == ChangeType.delete && e.id == 1),
          isTrue,
        );

        await subscription.cancel();
      });
    });

    group('Cache Operations', () {
      test('create populates cache', () async {
        fixtures.setOnline();
        fixtures.setupCreate(resultId: 1);

        await fixtures.manager.create(
          const TestProduct(id: 0, name: 'Cached', price: 10.0),
        );

        // Cache is populated via _emitChange during create
        final cached = fixtures.manager.getFromCache(1);
        expect(cached, isNotNull);
        expect(cached!.name, equals('Cached'));
      });

      test('update populates cache', () async {
        fixtures.seedProducts([TestProductFactory.create(id: 1, name: 'Old')]);

        await fixtures.manager.update(
          const TestProduct(id: 1, name: 'Updated', price: 20.0),
        );

        final cached = fixtures.manager.getFromCache(1);
        expect(cached, isNotNull);
        expect(cached!.name, equals('Updated'));
      });

      test('invalidateCache removes entry', () async {
        fixtures.seedProducts([TestProductFactory.create(id: 1)]);

        // Use update to populate cache
        await fixtures.manager.update(
          const TestProduct(id: 1, name: 'Test', price: 10.0),
        );

        expect(fixtures.manager.getFromCache(1), isNotNull);

        fixtures.manager.invalidateCache(1);

        expect(fixtures.manager.getFromCache(1), isNull);
      });

      test('clearCache removes all entries', () async {
        // Create multiple products to populate cache
        for (var i = 1; i <= 3; i++) {
          fixtures.seedProducts([TestProductFactory.create(id: i)]);
          await fixtures.manager.update(
            TestProduct(id: i, name: 'Product $i', price: 10.0),
          );
        }

        // Verify cache has entries
        for (var i = 1; i <= 3; i++) {
          expect(fixtures.manager.getFromCache(i), isNotNull);
        }

        fixtures.manager.clearCache();

        for (var i = 1; i <= 3; i++) {
          expect(fixtures.manager.getFromCache(i), isNull);
        }
      });

      test('cacheStats reports correct values', () async {
        // Update multiple records to populate cache
        for (var i = 1; i <= 3; i++) {
          fixtures.seedProducts([TestProductFactory.create(id: i)]);
          await fixtures.manager.update(
            TestProduct(id: i, name: 'Product $i', price: 10.0),
          );
        }

        final stats = fixtures.manager.cacheStats;

        expect(stats.size, equals(3));
      });
    });

    group('Save Method', () {
      test('save creates new record when ID is 0', () async {
        fixtures.setOnline();
        fixtures.setupCreate(resultId: 42);

        const product = TestProduct(id: 0, name: 'To Save', price: 10.0);
        final saved = await fixtures.manager.save(product);

        expect(saved.id, equals(42));
        expect(saved.name, equals('To Save'));
      });

      test('save updates existing record when ID > 0', () async {
        fixtures.setOnline();
        fixtures.setupWrite();

        fixtures.seedProducts([TestProductFactory.create(id: 5, name: 'Old')]);

        const product = TestProduct(id: 5, name: 'New', price: 50.0);
        final saved = await fixtures.manager.save(product);

        expect(saved.id, equals(5));
        expect(saved.name, equals('New'));
      });
    });

    group('Background Error Stream', () {
      test('emits error when background sync fails', () async {
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

        expect(errors.isNotEmpty, isTrue);
        expect(errors.first.model, equals('product.product'));
        expect(errors.first.recordId, equals(1));
        expect(
          errors.first.operation,
          equals(BackgroundSyncOperation.syncRecord),
        );

        await subscription.cancel();
      });
    });
  });
}
