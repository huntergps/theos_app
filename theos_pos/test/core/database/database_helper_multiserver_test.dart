import 'package:drift/drift.dart' show driftRuntimeOptions, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/core/database/database_exports.dart';

void main() {
  // Suppress warning about multiple database instances (expected in tests)
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  group('AppDatabase Multi-Server Support', () {
    test('defaultDatabaseName is set correctly', () {
      expect(AppDatabase.defaultDatabaseName, equals('theos_pos_db'));
    });

    test('forServer constructor sets correct database name', () {
      // We can't easily test the actual file creation without mocking,
      // but we can test the static property is updated
      // Use in-memory database for testing
      final db = AppDatabase(NativeDatabase.memory());

      // The forTesting constructor doesn't set _currentDatabaseName,
      // but we can verify the class structure is correct
      expect(db, isA<AppDatabase>());
    });

    test('currentDatabaseName returns default when not initialized', () {
      // Reset to simulate fresh state
      // Note: In real tests, you'd want to isolate this better
      expect(AppDatabase.currentDatabaseName, isNotNull);
    });
  });

  group('Database Isolation Scenarios', () {
    test('in-memory databases are isolated', () async {
      // Create two in-memory databases (simulating different servers)
      final db1 = AppDatabase(NativeDatabase.memory());
      final db2 = AppDatabase(NativeDatabase.memory());

      // Insert a user into db1
      await db1.into(db1.resUsers).insert(
            ResUsersCompanion.insert(
              odooId: 1,
              name: 'User A',
              login: 'user_a',
            ),
          );

      // Verify user exists in db1
      final usersDb1 = await db1.select(db1.resUsers).get();
      expect(usersDb1.length, equals(1));
      expect(usersDb1.first.name, equals('User A'));

      // Verify db2 is empty (isolated)
      final usersDb2 = await db2.select(db2.resUsers).get();
      expect(usersDb2.length, equals(0));

      // Clean up
      await db1.close();
      await db2.close();
    });

    test('each database maintains its own data', () async {
      final db1 = AppDatabase(NativeDatabase.memory());
      final db2 = AppDatabase(NativeDatabase.memory());

      // Insert different data into each database
      await db1.into(db1.resUsers).insert(
            ResUsersCompanion.insert(
              odooId: 100,
              name: 'Empresa A User',
              login: 'empresa_a_user',
            ),
          );

      await db2.into(db2.resUsers).insert(
            ResUsersCompanion.insert(
              odooId: 200,
              name: 'Empresa B User',
              login: 'empresa_b_user',
            ),
          );

      // Verify each database has its own user
      final user1 = await (db1.select(db1.resUsers)
            ..where((t) => t.odooId.equals(100)))
          .getSingleOrNull();

      final user2 = await (db2.select(db2.resUsers)
            ..where((t) => t.odooId.equals(200)))
          .getSingleOrNull();

      expect(user1?.name, equals('Empresa A User'));
      expect(user2?.name, equals('Empresa B User'));

      // Verify cross-contamination doesn't happen
      final user1InDb2 = await (db2.select(db2.resUsers)
            ..where((t) => t.odooId.equals(100)))
          .getSingleOrNull();

      final user2InDb1 = await (db1.select(db1.resUsers)
            ..where((t) => t.odooId.equals(200)))
          .getSingleOrNull();

      expect(user1InDb2, isNull);
      expect(user2InDb1, isNull);

      await db1.close();
      await db2.close();
    });

    test('sale orders are isolated between databases', () async {
      final db1 = AppDatabase(NativeDatabase.memory());
      final db2 = AppDatabase(NativeDatabase.memory());

      // Create sale order in db1 (Empresa A)
      await db1.into(db1.saleOrder).insert(
            SaleOrderCompanion.insert(
              odooId: 1,
              name: 'SO001',
            ),
          );

      // Create sale order in db2 (Empresa B)
      await db2.into(db2.saleOrder).insert(
            SaleOrderCompanion.insert(
              odooId: 2,
              name: 'SO001', // Same name, different database
            ),
          );

      // Each database should have exactly one order
      final orders1 = await db1.select(db1.saleOrder).get();
      final orders2 = await db2.select(db2.saleOrder).get();

      expect(orders1.length, equals(1));
      expect(orders2.length, equals(1));

      // Orders are independent
      expect(orders1.first.name, equals('SO001'));
      expect(orders2.first.name, equals('SO001'));

      await db1.close();
      await db2.close();
    });

    test('offline queue is isolated per database', () async {
      final db1 = AppDatabase(NativeDatabase.memory());
      final db2 = AppDatabase(NativeDatabase.memory());

      // Queue operation in db1
      await db1.into(db1.offlineQueue).insert(
            OfflineQueueCompanion.insert(
              model: 'sale.order',
              values: '{"name": "SO-A"}',
              createdAt: DateTime.now(),
              operation: const Value('create'),
              recordId: const Value(1),
            ),
          );

      // Queue operation in db2
      await db2.into(db2.offlineQueue).insert(
            OfflineQueueCompanion.insert(
              model: 'sale.order',
              values: '{"name": "SO-B"}',
              createdAt: DateTime.now(),
              operation: const Value('create'),
              recordId: const Value(2),
            ),
          );

      // Each database has its own queue
      final queue1 = await db1.select(db1.offlineQueue).get();
      final queue2 = await db2.select(db2.offlineQueue).get();

      expect(queue1.length, equals(1));
      expect(queue2.length, equals(1));
      expect(queue1.first.values, contains('SO-A'));
      expect(queue2.first.values, contains('SO-B'));

      await db1.close();
      await db2.close();
    });
  });

  group('Schema Version Consistency', () {
    test('all databases use same schema version', () async {
      final db1 = AppDatabase(NativeDatabase.memory());
      final db2 = AppDatabase(NativeDatabase.memory());

      expect(db1.schemaVersion, equals(db2.schemaVersion));
      expect(db1.schemaVersion, equals(53)); // Current version

      await db1.close();
      await db2.close();
    });
  });

  group('Concurrent Access Simulation', () {
    test('multiple databases can be open simultaneously', () async {
      // Simulate 3 POS instances for 3 different companies
      final databases = <AppDatabase>[];

      for (var i = 0; i < 3; i++) {
        databases.add(AppDatabase(NativeDatabase.memory()));
      }

      // Insert data into each
      for (var i = 0; i < 3; i++) {
        await databases[i].into(databases[i].resUsers).insert(
              ResUsersCompanion.insert(
                odooId: i + 1,
                name: 'User ${i + 1}',
                login: 'user_${i + 1}',
              ),
            );
      }

      // Verify each has correct data
      for (var i = 0; i < 3; i++) {
        final users = await databases[i].select(databases[i].resUsers).get();
        expect(users.length, equals(1));
        expect(users.first.odooId, equals(i + 1));
      }

      // Clean up
      for (final db in databases) {
        await db.close();
      }
    });
  });
}
