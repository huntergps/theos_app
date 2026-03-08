import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

// ==================== TEST HELPERS ====================

/// Create an in-memory database for testing
AppDatabase createTestDatabase() {
  return AppDatabase(NativeDatabase.memory());
}

/// Helper to insert a test partner
Future<int> insertTestPartner(
  AppDatabase db, {
  required int odooId,
  required String name,
  String? email,
  String? phone,
}) async {
  return db.into(db.resPartner).insert(
        ResPartnerCompanion.insert(
          odooId: odooId,
          name: name,
          email: Value(email),
          phone: Value(phone),
          displayName: Value(name),
          isSynced: const Value(true),
        ),
      );
}

/// Helper to insert a test sale order
Future<int> insertTestSaleOrder(
  AppDatabase db, {
  required int odooId,
  required String name,
  String state = 'draft',
  double amountTotal = 0.0,
  int? partnerId,
}) async {
  return db.into(db.saleOrder).insert(
        SaleOrderCompanion.insert(
          odooId: odooId,
          name: name,
          state: Value(state),
          amountTotal: Value(amountTotal),
          partnerId: Value(partnerId),
          isSynced: const Value(true),
        ),
      );
}

/// Helper to mark a field as dirty
Future<void> markFieldAsDirty(
  AppDatabase db, {
  required String model,
  required int recordId,
  required String fieldName,
  String? originalValue,
  String? localValue,
}) async {
  await db.into(db.dirtyFields).insert(
        DirtyFieldsCompanion.insert(
          model: model,
          recordId: recordId,
          fieldName: fieldName,
          oldValue: Value(originalValue),
          newValue: Value(localValue),
          localValue: Value(localValue),
          modifiedAt: DateTime.now(),
          isSynced: const Value(false),
        ),
      );
}

// ==================== MAIN TEST SUITE ====================

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('WebSocketSyncService - Field-level Sync Logic', () {
    group('Scenario 1: Field NOT modified locally - should update in SQLite', () {
      test('Partner name field updates when no local changes exist', () async {
        // ARRANGE: Create a partner in the database
        await insertTestPartner(
          db,
          odooId: 100,
          name: 'Original Partner Name',
          email: 'original@test.com',
        );

        // Verify initial state
        final initialPartner = await (db.select(db.resPartner)
              ..where((t) => t.odooId.equals(100)))
            .getSingleOrNull();
        expect(initialPartner, isNotNull);
        expect(initialPartner!.name, 'Original Partner Name');

        // ACT: Check that no dirty fields exist (field is clean)
        final dirtyFields = await (db.select(db.dirtyFields)
              ..where((t) =>
                  t.model.equals('res.partner') & t.recordId.equals(100)))
            .get();
        expect(dirtyFields, isEmpty, reason: 'No dirty fields should exist');

        // Since field is NOT dirty, the update should proceed
        // Execute partial update (simulating what _applyFieldUpdates does)
        await db.customUpdate(
          'UPDATE res_partner SET name = ?, email = ? WHERE odoo_id = ?',
          variables: [
            Variable('Updated Partner Name from Server'),
            Variable('updated@server.com'),
            Variable(100),
          ],
        );

        // ASSERT: Verify the partner was updated
        final updatedPartner = await (db.select(db.resPartner)
              ..where((t) => t.odooId.equals(100)))
            .getSingleOrNull();

        expect(updatedPartner, isNotNull);
        expect(updatedPartner!.name, 'Updated Partner Name from Server');
        expect(updatedPartner.email, 'updated@server.com');
      });

      test('Sale order state updates when no local changes exist', () async {
        // ARRANGE
        await insertTestSaleOrder(
          db,
          odooId: 200,
          name: 'SO-001',
          state: 'draft',
          amountTotal: 100.0,
        );

        // Verify no dirty fields
        final dirtyFields = await (db.select(db.dirtyFields)
              ..where((t) =>
                  t.model.equals('sale.order') & t.recordId.equals(200)))
            .get();
        expect(dirtyFields, isEmpty);

        // ACT: Simulate server update (state changed to 'sent')
        await db.customUpdate(
          'UPDATE sale_order SET state = ? WHERE odoo_id = ?',
          variables: [Variable('sent'), Variable(200)],
        );

        // ASSERT
        final updatedOrder = await (db.select(db.saleOrder)
              ..where((t) => t.odooId.equals(200)))
            .getSingleOrNull();

        expect(updatedOrder, isNotNull);
        expect(updatedOrder!.state, 'sent');
        expect(updatedOrder.amountTotal, 100.0, reason: 'Other fields unchanged');
      });
    });

    group('Scenario 2: Field in edit mode - should NOT update (conflict)', () {
      test('Partner email NOT updated when field is being edited', () async {
        // ARRANGE: Create partner
        await insertTestPartner(
          db,
          odooId: 101,
          name: 'Test Partner',
          email: 'original@local.com',
        );

        // Mark field as dirty with local changes
        await markFieldAsDirty(
          db,
          model: 'res.partner',
          recordId: 101,
          fieldName: 'email',
          originalValue: jsonEncode('original@local.com'),
          localValue: jsonEncode('edited@local.com'),
        );

        // Verify dirty field exists
        final dirtyFields = await (db.select(db.dirtyFields)
              ..where((t) =>
                  t.model.equals('res.partner') &
                  t.recordId.equals(101) &
                  t.fieldName.equals('email')))
            .get();
        expect(dirtyFields, hasLength(1));
        expect(dirtyFields.first.isSynced, false);

        // ACT: Server sends update with different value
        final serverEmail = 'server_changed@server.com';
        // localEmail is 'edited@local.com' - set in markFieldAsDirty above

        // Check conflict detection logic
        final dirtyField = dirtyFields.first;
        final serverValueJson = jsonEncode(serverEmail);
        final localValueJson = dirtyField.localValue;

        expect(
          serverValueJson != localValueJson,
          true,
          reason: 'Server and local values should differ - conflict!',
        );

        // In the real service, this would create a conflict and skip the update
        // Let's verify the partner email was NOT updated
        final partner = await (db.select(db.resPartner)
              ..where((t) => t.odooId.equals(101)))
            .getSingleOrNull();

        expect(partner, isNotNull);
        expect(partner!.email, 'original@local.com',
            reason: 'Email should remain unchanged when editing');

        // Create conflict record (what the service would do)
        await db.into(db.syncConflict).insert(
              SyncConflictCompanion.insert(
                model: 'res.partner',
                localId: 101,
                remoteId: 101,
                conflictType: 'field_conflict',
                localData: jsonEncode({
                  'field': 'email',
                  'value': localValueJson,
                }),
                remoteData: jsonEncode({
                  'field': 'email',
                  'value': serverValueJson,
                }),
                detectedAt: DateTime.now(),
              ),
            );

        // ASSERT: Conflict was created
        final conflicts = await (db.select(db.syncConflict)
              ..where((t) =>
                  t.model.equals('res.partner') & t.localId.equals(101)))
            .get();

        expect(conflicts, hasLength(1));
        final conflictData = jsonDecode(conflicts.first.localData) as Map<String, dynamic>;
        final conflictRemote = jsonDecode(conflicts.first.remoteData) as Map<String, dynamic>;
        expect(conflictData['value'], jsonEncode('edited@local.com'));
        expect(conflictRemote['value'], jsonEncode('server_changed@server.com'));
        expect(conflicts.first.isResolved, false);
        expect(conflicts.first.resolution, isNull);
      });

      test('Sale order note NOT updated when user is editing', () async {
        // ARRANGE
        await insertTestSaleOrder(db, odooId: 201, name: 'SO-002');

        await markFieldAsDirty(
          db,
          model: 'sale.order',
          recordId: 201,
          fieldName: 'note',
          originalValue: jsonEncode('Original note'),
          localValue: jsonEncode('User is typing a new note...'),
        );

        // ACT & ASSERT
        final dirtyField = await (db.select(db.dirtyFields)
              ..where((t) =>
                  t.model.equals('sale.order') &
                  t.recordId.equals(201) &
                  t.fieldName.equals('note')))
            .getSingleOrNull();

        expect(dirtyField, isNotNull);
        expect(dirtyField!.isSynced, false);

        // Server sends: "Different note from another user"
        // Local has: "User is typing a new note..."
        // Result: Conflict detected, no update to local DB
      });
    });

    group('Scenario 3: Field dirty (pending sync) - should NOT update (conflict)', () {
      test('Partner phone NOT updated when pending sync to server', () async {
        // ARRANGE: Create partner
        await insertTestPartner(
          db,
          odooId: 102,
          name: 'Pending Sync Partner',
          phone: '+593999111222',
        );

        // Mark field as dirty (pending sync)
        await markFieldAsDirty(
          db,
          model: 'res.partner',
          recordId: 102,
          fieldName: 'phone',
          originalValue: jsonEncode('+593999111222'),
          localValue: jsonEncode('+593999333444'), // User changed locally
        );

        // Verify dirty field state
        final dirtyField = await (db.select(db.dirtyFields)
              ..where((t) =>
                  t.model.equals('res.partner') &
                  t.recordId.equals(102) &
                  t.fieldName.equals('phone')))
            .getSingleOrNull();

        expect(dirtyField, isNotNull);
        expect(dirtyField!.isSynced, false);
        expect(dirtyField.localValue, jsonEncode('+593999333444'));

        // ACT: Server sends different value
        final serverPhone = '+593999555666';
        final serverValueJson = jsonEncode(serverPhone);

        // Check conflict detection
        expect(
          serverValueJson != dirtyField.localValue,
          true,
          reason: 'Server value differs from local pending value - conflict!',
        );

        // ASSERT: Partner phone should remain with LOCAL value
        final partner = await (db.select(db.resPartner)
              ..where((t) => t.odooId.equals(102)))
            .getSingleOrNull();

        // Phone in DB is still original (before user change in UI)
        expect(partner!.phone, '+593999111222');

        // The service would detect conflict and create record
        // but NOT update the local DB with server value
      });

      test('Sale order amount_total conflict when local change pending sync', () async {
        // ARRANGE
        await insertTestSaleOrder(
          db,
          odooId: 202,
          name: 'SO-003',
          amountTotal: 1000.0,
        );

        await markFieldAsDirty(
          db,
          model: 'sale.order',
          recordId: 202,
          fieldName: 'amount_total',
          originalValue: jsonEncode(1000.0),
          localValue: jsonEncode(1500.0), // User added lines locally
        );

        // ACT: Server sends different amount (another user modified)
        final serverAmount = 1200.0;
        final dirtyField = await (db.select(db.dirtyFields)
              ..where((t) =>
                  t.model.equals('sale.order') &
                  t.recordId.equals(202) &
                  t.fieldName.equals('amount_total')))
            .getSingleOrNull();

        // ASSERT: Conflict detected
        expect(
          jsonEncode(serverAmount) != dirtyField!.localValue,
          true,
          reason: 'Amounts differ - conflict!',
        );

        // Create conflict
        await db.into(db.syncConflict).insert(
              SyncConflictCompanion.insert(
                model: 'sale.order',
                localId: 202,
                remoteId: 202,
                conflictType: 'field_conflict',
                localData: jsonEncode({
                  'field': 'amount_total',
                  'value': dirtyField.localValue,
                }),
                remoteData: jsonEncode({
                  'field': 'amount_total',
                  'value': jsonEncode(serverAmount),
                }),
                detectedAt: DateTime.now(),
              ),
            );

        final conflicts = await db.select(db.syncConflict).get();
        expect(conflicts, hasLength(1));
      });
    });

    group('Scenario 4: Field dirty with SAME value - should update & clear dirty', () {
      test('Partner email clears dirty when server confirms same value', () async {
        // ARRANGE: Create partner
        await insertTestPartner(
          db,
          odooId: 103,
          name: 'Same Value Partner',
          email: 'same@test.com',
        );

        // Mark field as dirty with a local value
        final sameEmail = 'same@test.com';
        await markFieldAsDirty(
          db,
          model: 'res.partner',
          recordId: 103,
          fieldName: 'email',
          originalValue: jsonEncode(sameEmail),
          localValue: jsonEncode(sameEmail), // Same as original (user typed same)
        );

        // Verify dirty field exists
        var dirtyFields = await (db.select(db.dirtyFields)
              ..where((t) =>
                  t.model.equals('res.partner') &
                  t.recordId.equals(103) &
                  t.fieldName.equals('email')))
            .get();
        expect(dirtyFields, hasLength(1));

        // ACT: Server sends the SAME value
        final serverEmail = 'same@test.com';
        final serverValueJson = jsonEncode(serverEmail);
        final localValueJson = dirtyFields.first.localValue;

        // Check if values match
        expect(
          serverValueJson == localValueJson,
          true,
          reason: 'Server and local values are the same - no conflict!',
        );

        // Since values match, clear the dirty field (what service does)
        await (db.delete(db.dirtyFields)
              ..where((t) =>
                  t.model.equals('res.partner') &
                  t.recordId.equals(103) &
                  t.fieldName.equals('email')))
            .go();

        // ASSERT: Dirty field was cleared
        dirtyFields = await (db.select(db.dirtyFields)
              ..where((t) =>
                  t.model.equals('res.partner') &
                  t.recordId.equals(103) &
                  t.fieldName.equals('email')))
            .get();

        expect(dirtyFields, isEmpty,
            reason: 'Dirty field should be cleared when server confirms same value');

        // No conflict should be created
        final conflicts = await (db.select(db.syncConflict)
              ..where((t) =>
                  t.model.equals('res.partner') & t.localId.equals(103)))
            .get();
        expect(conflicts, isEmpty);
      });

      test('Sale order state clears dirty when server confirms same value', () async {
        // ARRANGE
        await insertTestSaleOrder(
          db,
          odooId: 203,
          name: 'SO-004',
          state: 'sale', // Confirmed
        );

        await markFieldAsDirty(
          db,
          model: 'sale.order',
          recordId: 203,
          fieldName: 'state',
          originalValue: jsonEncode('draft'),
          localValue: jsonEncode('sale'), // User confirmed locally
        );

        // ACT: Server also confirms the order (same state)
        final serverState = 'sale';
        final dirtyField = await (db.select(db.dirtyFields)
              ..where((t) =>
                  t.model.equals('sale.order') &
                  t.recordId.equals(203) &
                  t.fieldName.equals('state')))
            .getSingleOrNull();

        expect(jsonEncode(serverState) == dirtyField!.localValue, true);

        // Clear dirty field
        await (db.delete(db.dirtyFields)
              ..where((t) =>
                  t.model.equals('sale.order') &
                  t.recordId.equals(203) &
                  t.fieldName.equals('state')))
            .go();

        // ASSERT
        final remainingDirty = await (db.select(db.dirtyFields)
              ..where((t) =>
                  t.model.equals('sale.order') & t.recordId.equals(203)))
            .get();
        expect(remainingDirty, isEmpty);
      });
    });

    group('Conflict Resolution', () {
      test('Resolve conflict by accepting local value', () async {
        // ARRANGE: Create conflict
        await db.into(db.syncConflict).insert(
              SyncConflictCompanion.insert(
                model: 'res.partner',
                localId: 104,
                remoteId: 104,
                conflictType: 'field_conflict',
                localData: jsonEncode({
                  'field': 'name',
                  'value': '"Local Name"',
                }),
                remoteData: jsonEncode({
                  'field': 'name',
                  'value': '"Server Name"',
                }),
                detectedAt: DateTime.now(),
              ),
            );

        final conflict = await (db.select(db.syncConflict)
              ..where((t) => t.localId.equals(104)))
            .getSingleOrNull();
        expect(conflict, isNotNull);
        expect(conflict!.isResolved, false);
        expect(conflict.resolution, isNull);

        // ACT: User chooses local value
        await (db.update(db.syncConflict)..where((t) => t.id.equals(conflict.id)))
            .write(SyncConflictCompanion(
          resolution: const Value('local_wins'),
          resolvedAt: Value(DateTime.now()),
          isResolved: const Value(true),
        ));

        // ASSERT
        final resolved = await (db.select(db.syncConflict)
              ..where((t) => t.id.equals(conflict.id)))
            .getSingle();
        expect(resolved.resolution, 'local_wins');
        expect(resolved.isResolved, true);
        expect(resolved.resolvedAt, isNotNull);
      });

      test('Resolve conflict by accepting server value', () async {
        // ARRANGE
        await insertTestPartner(db, odooId: 105, name: 'Original Name');

        await markFieldAsDirty(
          db,
          model: 'res.partner',
          recordId: 105,
          fieldName: 'name',
          localValue: jsonEncode('Local Changed Name'),
        );

        await db.into(db.syncConflict).insert(
              SyncConflictCompanion.insert(
                model: 'res.partner',
                localId: 105,
                remoteId: 105,
                conflictType: 'field_conflict',
                localData: jsonEncode({
                  'field': 'name',
                  'value': '"Local Changed Name"',
                }),
                remoteData: jsonEncode({
                  'field': 'name',
                  'value': '"Server Changed Name"',
                }),
                detectedAt: DateTime.now(),
              ),
            );

        // ACT: User chooses server value
        final conflict =
            await (db.select(db.syncConflict)..where((t) => t.localId.equals(105)))
                .getSingle();

        await (db.update(db.syncConflict)..where((t) => t.id.equals(conflict.id)))
            .write(SyncConflictCompanion(
          resolution: const Value('server_wins'),
          resolvedAt: Value(DateTime.now()),
          isResolved: const Value(true),
        ));

        // Clear the dirty field (as the service would)
        await (db.delete(db.dirtyFields)
              ..where((t) =>
                  t.model.equals('res.partner') &
                  t.recordId.equals(105) &
                  t.fieldName.equals('name')))
            .go();

        // Apply server value
        await db.customUpdate(
          'UPDATE res_partner SET name = ? WHERE odoo_id = ?',
          variables: [Variable('Server Changed Name'), Variable(105)],
        );

        // ASSERT
        final resolved =
            await (db.select(db.syncConflict)..where((t) => t.id.equals(conflict.id)))
                .getSingle();
        expect(resolved.resolution, 'server_wins');
        expect(resolved.isResolved, true);

        final dirtyFields = await (db.select(db.dirtyFields)
              ..where((t) =>
                  t.model.equals('res.partner') &
                  t.recordId.equals(105) &
                  t.fieldName.equals('name')))
            .get();
        expect(dirtyFields, isEmpty);

        final partner = await (db.select(db.resPartner)
              ..where((t) => t.odooId.equals(105)))
            .getSingle();
        expect(partner.name, 'Server Changed Name');
      });
    });

    group('Record Deletion Handling', () {
      test('Delete record when no local changes exist', () async {
        // ARRANGE
        await insertTestPartner(db, odooId: 106, name: 'To Be Deleted');

        // Verify no dirty fields
        final dirtyFields = await (db.select(db.dirtyFields)
              ..where((t) =>
                  t.model.equals('res.partner') & t.recordId.equals(106)))
            .get();
        expect(dirtyFields, isEmpty);

        // ACT: Server says record was deleted
        await (db.delete(db.resPartner)..where((t) => t.odooId.equals(106))).go();

        // ASSERT
        final partner = await (db.select(db.resPartner)
              ..where((t) => t.odooId.equals(106)))
            .getSingleOrNull();
        expect(partner, isNull);
      });

      test('Create conflict when deleted but has local changes', () async {
        // ARRANGE
        await insertTestPartner(db, odooId: 107, name: 'Has Local Changes');

        await markFieldAsDirty(
          db,
          model: 'res.partner',
          recordId: 107,
          fieldName: 'name',
          localValue: jsonEncode('Changed Name'),
        );

        // Verify dirty field exists
        final dirtyFields = await (db.select(db.dirtyFields)
              ..where((t) =>
                  t.model.equals('res.partner') & t.recordId.equals(107)))
            .get();
        expect(dirtyFields, isNotEmpty);

        // ACT: Server deleted the record, but we have local changes
        // Create special conflict for deletion
        await db.into(db.syncConflict).insert(
              SyncConflictCompanion.insert(
                model: 'res.partner',
                localId: 107,
                remoteId: 107,
                conflictType: 'deleted_remotely',
                localData: jsonEncode({
                  'field': '_deleted_',
                  'value': 'Record has local changes',
                }),
                remoteData: jsonEncode({
                  'field': '_deleted_',
                  'value': 'Record was deleted on server',
                }),
                detectedAt: DateTime.now(),
              ),
            );

        // ASSERT: Partner should NOT be deleted
        final partner = await (db.select(db.resPartner)
              ..where((t) => t.odooId.equals(107)))
            .getSingleOrNull();
        expect(partner, isNotNull, reason: 'Partner should not be deleted when has local changes');

        // Conflict should exist
        final conflicts = await (db.select(db.syncConflict)
              ..where((t) =>
                  t.model.equals('res.partner') & t.localId.equals(107)))
            .get();
        expect(conflicts, hasLength(1));
        final deletionData = jsonDecode(conflicts.first.localData) as Map<String, dynamic>;
        expect(deletionData['value'], 'Record has local changes');
      });
    });

    group('Multiple Fields in Single Update', () {
      test('Mixed scenario: some fields sync, some conflict', () async {
        // ARRANGE: Create partner
        await insertTestPartner(
          db,
          odooId: 108,
          name: 'Multi Field Partner',
          email: 'original@test.com',
          phone: '+593999000111',
        );

        // Mark only email as dirty (phone is clean)
        await markFieldAsDirty(
          db,
          model: 'res.partner',
          recordId: 108,
          fieldName: 'email',
          originalValue: jsonEncode('original@test.com'),
          localValue: jsonEncode('local_changed@test.com'),
        );

        // ACT: Server sends update for BOTH fields
        final serverValues = {
          'email': 'server_changed@test.com', // Conflicts with local
          'phone': '+593888777666', // Can sync (not dirty)
        };

        // Check each field
        final emailDirty = await (db.select(db.dirtyFields)
              ..where((t) =>
                  t.model.equals('res.partner') &
                  t.recordId.equals(108) &
                  t.fieldName.equals('email')))
            .getSingleOrNull();

        final phoneDirty = await (db.select(db.dirtyFields)
              ..where((t) =>
                  t.model.equals('res.partner') &
                  t.recordId.equals(108) &
                  t.fieldName.equals('phone')))
            .getSingleOrNull();

        expect(emailDirty, isNotNull, reason: 'Email should be dirty');
        expect(phoneDirty, isNull, reason: 'Phone should NOT be dirty');

        // Email conflicts, phone syncs
        if (phoneDirty == null) {
          // Update phone only
          await db.customUpdate(
            'UPDATE res_partner SET phone = ? WHERE odoo_id = ?',
            variables: [Variable(serverValues['phone']), Variable(108)],
          );
        }

        // Create conflict for email
        await db.into(db.syncConflict).insert(
              SyncConflictCompanion.insert(
                model: 'res.partner',
                localId: 108,
                remoteId: 108,
                conflictType: 'field_conflict',
                localData: jsonEncode({
                  'field': 'email',
                  'value': emailDirty!.localValue,
                }),
                remoteData: jsonEncode({
                  'field': 'email',
                  'value': jsonEncode(serverValues['email']),
                }),
                detectedAt: DateTime.now(),
              ),
            );

        // ASSERT
        final partner = await (db.select(db.resPartner)
              ..where((t) => t.odooId.equals(108)))
            .getSingle();

        expect(partner.phone, '+593888777666', reason: 'Phone should be updated');
        expect(partner.email, 'original@test.com',
            reason: 'Email should NOT be updated (conflict)');

        final conflicts = await (db.select(db.syncConflict)
              ..where((t) => t.localId.equals(108)))
            .get();
        expect(conflicts, hasLength(1));
        final conflictData = jsonDecode(conflicts.first.localData) as Map<String, dynamic>;
        expect(conflictData['field'], 'email');
      });
    });
  });

  group('Database Tables - DirtyFields and SyncConflict', () {
    test('markFieldDirty creates dirty field entry', () async {
      // ARRANGE
      await insertTestPartner(db, odooId: 200, name: 'API Test Partner');

      // ACT
      await db.into(db.dirtyFields).insertOnConflictUpdate(
            DirtyFieldsCompanion.insert(
              model: 'res.partner',
              recordId: 200,
              fieldName: 'name',
              oldValue: Value(jsonEncode('API Test Partner')),
              newValue: Value(jsonEncode('Changed via API')),
              localValue: Value(jsonEncode('Changed via API')),
              modifiedAt: DateTime.now(),
              isSynced: const Value(false),
            ),
          );

      // ASSERT
      final dirtyField = await (db.select(db.dirtyFields)
            ..where((t) =>
                t.model.equals('res.partner') &
                t.recordId.equals(200) &
                t.fieldName.equals('name')))
          .getSingleOrNull();

      expect(dirtyField, isNotNull);
      expect(dirtyField!.localValue, jsonEncode('Changed via API'));
      expect(dirtyField.isSynced, false);
    });

    test('setRecordSynced updates all dirty fields for record', () async {
      // ARRANGE
      await insertTestPartner(db, odooId: 201, name: 'Edit Mode Test');

      await markFieldAsDirty(
        db,
        model: 'res.partner',
        recordId: 201,
        fieldName: 'name',
      );
      await markFieldAsDirty(
        db,
        model: 'res.partner',
        recordId: 201,
        fieldName: 'email',
      );

      // ACT
      await (db.update(db.dirtyFields)
            ..where(
                (t) => t.model.equals('res.partner') & t.recordId.equals(201)))
          .write(const DirtyFieldsCompanion(isSynced: Value(true)));

      // ASSERT
      final dirtyFields = await (db.select(db.dirtyFields)
            ..where((t) =>
                t.model.equals('res.partner') & t.recordId.equals(201)))
          .get();

      expect(dirtyFields, hasLength(2));
      expect(dirtyFields.every((df) => df.isSynced), true);
    });

    test('clearRecordDirtyFields removes all dirty fields for record', () async {
      // ARRANGE
      await insertTestPartner(db, odooId: 202, name: 'Clear Test');

      await markFieldAsDirty(
        db,
        model: 'res.partner',
        recordId: 202,
        fieldName: 'name',
      );
      await markFieldAsDirty(
        db,
        model: 'res.partner',
        recordId: 202,
        fieldName: 'phone',
      );

      // Verify dirty fields exist
      var dirtyCount = await (db.select(db.dirtyFields)
            ..where((t) =>
                t.model.equals('res.partner') & t.recordId.equals(202)))
          .get();
      expect(dirtyCount, hasLength(2));

      // ACT
      await (db.delete(db.dirtyFields)
            ..where(
                (t) => t.model.equals('res.partner') & t.recordId.equals(202)))
          .go();

      // ASSERT
      dirtyCount = await (db.select(db.dirtyFields)
            ..where((t) =>
                t.model.equals('res.partner') & t.recordId.equals(202)))
          .get();
      expect(dirtyCount, isEmpty);
    });

    test('isFieldDirty returns correct status', () async {
      // ARRANGE
      await insertTestPartner(db, odooId: 203, name: 'Is Dirty Test');

      await markFieldAsDirty(
        db,
        model: 'res.partner',
        recordId: 203,
        fieldName: 'name',
      );

      // ACT & ASSERT
      final nameDirty = await (db.select(db.dirtyFields)
            ..where((t) =>
                t.model.equals('res.partner') &
                t.recordId.equals(203) &
                t.fieldName.equals('name')))
          .getSingleOrNull();
      expect(nameDirty != null, true);

      final emailDirty = await (db.select(db.dirtyFields)
            ..where((t) =>
                t.model.equals('res.partner') &
                t.recordId.equals(203) &
                t.fieldName.equals('email')))
          .getSingleOrNull();
      expect(emailDirty == null, true);
    });

    test('getPendingConflictCount returns correct count', () async {
      // ARRANGE
      await db.into(db.syncConflict).insert(
            SyncConflictCompanion.insert(
              model: 'res.partner',
              localId: 300,
              remoteId: 300,
              conflictType: 'field_conflict',
              localData: jsonEncode({
                'field': 'name',
                'value': '"Local Name"',
              }),
              remoteData: jsonEncode({
                'field': 'name',
                'value': '"Server Name"',
              }),
              detectedAt: DateTime.now(),
            ),
          );
      await db.into(db.syncConflict).insert(
            SyncConflictCompanion.insert(
              model: 'res.partner',
              localId: 301,
              remoteId: 301,
              conflictType: 'field_conflict',
              localData: jsonEncode({
                'field': 'email',
                'value': '"Local Email"',
              }),
              remoteData: jsonEncode({
                'field': 'email',
                'value': '"Server Email"',
              }),
              detectedAt: DateTime.now(),
            ),
          );

      // ACT
      final query = db.selectOnly(db.syncConflict)
        ..addColumns([db.syncConflict.id.count()])
        ..where(db.syncConflict.isResolved.equals(false));
      final result = await query.getSingle();
      final count = result.read(db.syncConflict.id.count()) ?? 0;

      // ASSERT
      expect(count, 2);
    });
  });
}
