import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart' show OdooClient;

import 'package:odoo_sdk/src/model/odoo_record.dart';
import 'package:odoo_sdk/src/model/odoo_model_manager.dart';

/// Mock OdooClient for testing.
class MockOdooClient extends Mock implements OdooClient {}

/// Mock manager for testing OdooRecord operations.
class MockOdooModelManager extends Mock
    implements OdooModelManager<TestOdooRecord> {}

/// Test record implementing OdooRecord mixin.
class TestOdooRecord with OdooRecord<TestOdooRecord> {
  @override
  final int id;

  @override
  final int odooId;

  @override
  final String? uuid;

  @override
  final bool isSynced;

  final String name;
  final double value;
  final Map<String, String>? customValidationErrors;

  const TestOdooRecord({
    required this.id,
    int? odooId,
    this.uuid,
    this.isSynced = false,
    required this.name,
    this.value = 0.0,
    this.customValidationErrors,
  }) : odooId = odooId ?? id;

  @override
  Map<String, dynamic> toOdoo() {
    return {
      if (odooId > 0) 'id': odooId,
      'name': name,
      'value': value,
    };
  }

  @override
  Map<String, String> validate() {
    final errors = <String, String>{};
    if (name.isEmpty) errors['name'] = 'Name is required';
    if (value < 0) errors['value'] = 'Value must be non-negative';
    if (customValidationErrors != null) {
      errors.addAll(customValidationErrors!);
    }
    return errors;
  }

  @override
  Map<String, String> validateFor(String action) {
    final errors = validate();
    if (action == 'confirm' && value == 0) {
      errors['value'] = 'Value must be greater than 0 to confirm';
    }
    return errors;
  }

  TestOdooRecord copyWith({
    int? id,
    int? odooId,
    String? uuid,
    bool? isSynced,
    String? name,
    double? value,
  }) {
    return TestOdooRecord(
      id: id ?? this.id,
      odooId: odooId ?? this.odooId,
      uuid: uuid ?? this.uuid,
      isSynced: isSynced ?? this.isSynced,
      name: name ?? this.name,
      value: value ?? this.value,
    );
  }
}

/// Record that uses default implementations for odooId, uuid, isSynced.
class MinimalRecord with OdooRecord<MinimalRecord> {
  @override
  final int id;

  final String name;

  const MinimalRecord({required this.id, required this.name});

  @override
  Map<String, dynamic> toOdoo() => {'name': name};
}

void main() {
  late MockOdooModelManager mockManager;

  setUpAll(() {
    registerFallbackValue(const TestOdooRecord(id: 0, name: ''));
  });

  setUp(() {
    OdooRecordRegistry.clear();
    mockManager = MockOdooModelManager();
  });

  tearDown(() {
    OdooRecordRegistry.clear();
  });

  group('OdooRecord Identity Properties', () {
    test('id returns record id', () {
      const record = TestOdooRecord(id: 42, name: 'Test');

      expect(record.id, 42);
    });

    test('odooId defaults to id when not specified', () {
      const record = TestOdooRecord(id: 100, name: 'Test');

      expect(record.odooId, 100);
    });

    test('odooId can be different from id', () {
      const record = TestOdooRecord(id: 1, odooId: 500, name: 'Test');

      expect(record.id, 1);
      expect(record.odooId, 500);
    });

    test('uuid can be set', () {
      const record = TestOdooRecord(
        id: 1,
        uuid: 'abc-123-def',
        name: 'Test',
      );

      expect(record.uuid, 'abc-123-def');
    });

    test('uuid is null by default', () {
      const record = TestOdooRecord(id: 1, name: 'Test');

      expect(record.uuid, isNull);
    });

    test('isSynced can be true', () {
      const record = TestOdooRecord(id: 1, name: 'Test', isSynced: true);

      expect(record.isSynced, isTrue);
    });

    test('isSynced is false by default', () {
      const record = TestOdooRecord(id: 1, name: 'Test');

      expect(record.isSynced, isFalse);
    });
  });

  group('OdooRecord Default Implementations', () {
    test('odooId defaults to id in MinimalRecord', () {
      const record = MinimalRecord(id: 99, name: 'Minimal');

      expect(record.odooId, 99);
    });

    test('uuid defaults to null in MinimalRecord', () {
      const record = MinimalRecord(id: 1, name: 'Minimal');

      expect(record.uuid, isNull);
    });

    test('isSynced defaults to true in MinimalRecord', () {
      const record = MinimalRecord(id: 1, name: 'Minimal');

      expect(record.isSynced, isTrue);
    });

    test('validate() returns empty map by default', () {
      const record = MinimalRecord(id: 1, name: 'Test');

      final errors = record.validate();

      expect(errors, isEmpty);
    });

    test('validateFor() delegates to validate() by default', () {
      const record = MinimalRecord(id: 1, name: 'Test');

      final errors = record.validateFor('confirm');

      expect(errors, isEmpty);
    });
  });

  group('OdooRecord Computed Identity Properties', () {
    test('isNew returns true when id <= 0', () {
      const record0 = TestOdooRecord(id: 0, name: 'Test');
      const recordNeg = TestOdooRecord(id: -1, name: 'Test');
      const record1 = TestOdooRecord(id: 1, name: 'Test');

      expect(record0.isNew, isTrue);
      expect(recordNeg.isNew, isTrue);
      expect(record1.isNew, isFalse);
    });

    test('isLocalOnly returns true when odooId <= 0', () {
      const localOnly = TestOdooRecord(id: 1, odooId: 0, name: 'Test');
      const localOnlyNeg = TestOdooRecord(id: 1, odooId: -1, name: 'Test');
      const synced = TestOdooRecord(id: 1, odooId: 100, name: 'Test');

      expect(localOnly.isLocalOnly, isTrue);
      expect(localOnlyNeg.isLocalOnly, isTrue);
      expect(synced.isLocalOnly, isFalse);
    });

    test('isOfflineCreated returns true when uuid is set and odooId <= 0', () {
      const offlineCreated = TestOdooRecord(
        id: 1,
        odooId: 0,
        uuid: 'abc-123',
        name: 'Test',
      );
      const syncedWithUuid = TestOdooRecord(
        id: 1,
        odooId: 100,
        uuid: 'abc-123',
        name: 'Test',
      );
      const noUuid = TestOdooRecord(id: 1, odooId: 0, name: 'Test');

      expect(offlineCreated.isOfflineCreated, isTrue);
      expect(syncedWithUuid.isOfflineCreated, isFalse);
      expect(noUuid.isOfflineCreated, isFalse);
    });

    test('hasPendingSync returns true when not synced', () {
      const unsynced = TestOdooRecord(id: 1, name: 'Test', isSynced: false);
      const synced = TestOdooRecord(id: 1, name: 'Test', isSynced: true);

      expect(unsynced.hasPendingSync, isTrue);
      expect(synced.hasPendingSync, isFalse);
    });
  });

  group('OdooRecord Manager Access', () {
    test('hasManager returns false when not registered', () {
      const record = TestOdooRecord(id: 1, name: 'Test');

      expect(record.hasManager, isFalse);
    });

    test('hasManager returns true when registered', () {
      OdooRecordRegistry.register<TestOdooRecord>(mockManager);
      const record = TestOdooRecord(id: 1, name: 'Test');

      expect(record.hasManager, isTrue);
    });

    test('_manager throws when not registered', () {
      const record = TestOdooRecord(id: 1, name: 'Test');

      expect(
        () => record.save(),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('No manager registered'),
        )),
      );
    });
  });

  group('OdooRecord CRUD - save()', () {
    setUp(() {
      OdooRecordRegistry.register<TestOdooRecord>(mockManager);
    });

    test('save() throws ValidationException on invalid record', () async {
      const record = TestOdooRecord(id: 0, name: ''); // Invalid: empty name

      await expectLater(
        record.save(),
        throwsA(isA<ValidationException>()),
      );
    });

    test('save() creates new record when isNew', () async {
      const record = TestOdooRecord(id: 0, name: 'New Record', value: 10.0);
      const savedRecord = TestOdooRecord(id: 1, name: 'New Record', value: 10.0);

      when(() => mockManager.create(any())).thenAnswer((_) async => 1);
      when(() => mockManager.readLocal(1)).thenAnswer((_) async => savedRecord);

      final result = await record.save();

      expect(result.id, 1);
      verify(() => mockManager.create(any())).called(1);
    });

    test('save() creates when isLocalOnly', () async {
      const record = TestOdooRecord(
        id: 1,
        odooId: 0,
        name: 'Local Record',
        value: 5.0,
      );
      const savedRecord = TestOdooRecord(
        id: 1,
        odooId: 100,
        name: 'Local Record',
        value: 5.0,
      );

      when(() => mockManager.create(any())).thenAnswer((_) async => 1);
      when(() => mockManager.readLocal(1)).thenAnswer((_) async => savedRecord);

      final result = await record.save();

      verify(() => mockManager.create(any())).called(1);
      expect(result.odooId, 100);
    });

    test('save() updates existing record', () async {
      const record = TestOdooRecord(
        id: 1,
        odooId: 100,
        name: 'Updated',
        value: 20.0,
      );
      const updatedRecord = TestOdooRecord(
        id: 1,
        odooId: 100,
        name: 'Updated',
        value: 20.0,
        isSynced: true,
      );

      when(() => mockManager.update(any())).thenAnswer((_) async => true);
      when(() => mockManager.readLocal(100))
          .thenAnswer((_) async => updatedRecord);

      final result = await record.save();

      verify(() => mockManager.update(any())).called(1);
      expect(result.isSynced, isTrue);
    });
  });

  group('OdooRecord CRUD - delete()', () {
    setUp(() {
      OdooRecordRegistry.register<TestOdooRecord>(mockManager);
    });

    test('delete() calls manager.delete for synced record', () async {
      const record = TestOdooRecord(id: 1, odooId: 100, name: 'Test');

      when(() => mockManager.delete(100)).thenAnswer((_) async => true);

      await record.delete();

      verify(() => mockManager.delete(100)).called(1);
    });

    test('delete() calls deleteLocal for local-only record with id > 0',
        () async {
      const record = TestOdooRecord(id: 5, odooId: 0, name: 'Local');

      when(() => mockManager.deleteLocal(5)).thenAnswer((_) async {});

      await record.delete();

      verify(() => mockManager.deleteLocal(5)).called(1);
    });

    test('delete() does nothing for new record (id <= 0)', () async {
      const record = TestOdooRecord(id: 0, odooId: 0, name: 'New');

      await record.delete();

      verifyNever(() => mockManager.delete(any()));
      verifyNever(() => mockManager.deleteLocal(any()));
    });
  });

  group('OdooRecord CRUD - refresh()', () {
    setUp(() {
      OdooRecordRegistry.register<TestOdooRecord>(mockManager);
    });

    test('refresh() returns self for new record', () async {
      const record = TestOdooRecord(id: 0, name: 'New');

      final result = await record.refresh();

      expect(identical(result, record), isTrue);
      verifyNever(() => mockManager.readLocal(any()));
    });

    test('refresh() reads by odooId for synced record', () async {
      const record = TestOdooRecord(id: 1, odooId: 100, name: 'Test');
      const refreshed = TestOdooRecord(
        id: 1,
        odooId: 100,
        name: 'Refreshed',
        isSynced: true,
      );

      when(() => mockManager.readLocal(100)).thenAnswer((_) async => refreshed);

      final result = await record.refresh();

      expect(result?.name, 'Refreshed');
      verify(() => mockManager.readLocal(100)).called(1);
    });

    test('refresh() reads by id when odooId is 0', () async {
      const record = TestOdooRecord(id: 5, odooId: 0, name: 'Local');
      const refreshed = TestOdooRecord(id: 5, odooId: 0, name: 'Refreshed');

      when(() => mockManager.readLocal(5)).thenAnswer((_) async => refreshed);

      final result = await record.refresh();

      expect(result?.name, 'Refreshed');
      verify(() => mockManager.readLocal(5)).called(1);
    });

    test('refresh() returns null when record deleted', () async {
      const record = TestOdooRecord(id: 1, odooId: 100, name: 'Test');

      when(() => mockManager.readLocal(100)).thenAnswer((_) async => null);

      final result = await record.refresh();

      expect(result, isNull);
    });
  });

  group('OdooRecord CRUD - syncFromServer()', () {
    setUp(() {
      OdooRecordRegistry.register<TestOdooRecord>(mockManager);
    });

    test('syncFromServer() returns self when offline', () async {
      const record = TestOdooRecord(id: 1, odooId: 100, name: 'Test');

      when(() => mockManager.isOnline).thenReturn(false);

      final result = await record.syncFromServer();

      expect(identical(result, record), isTrue);
    });

    test('syncFromServer() returns self when local-only', () async {
      const record = TestOdooRecord(id: 1, odooId: 0, name: 'Local');

      when(() => mockManager.isOnline).thenReturn(true);

      final result = await record.syncFromServer();

      expect(identical(result, record), isTrue);
    });

    test('syncFromServer() fetches from server when online and synced', () async {
      const record = TestOdooRecord(id: 1, odooId: 100, name: 'Test');
      const synced = TestOdooRecord(
        id: 1,
        odooId: 100,
        name: 'From Server',
        isSynced: true,
      );

      final mockClient = MockOdooClient();

      when(() => mockManager.isOnline).thenReturn(true);
      when(() => mockManager.client).thenReturn(mockClient);
      when(() => mockManager.odooModel).thenReturn('test.record');
      when(() => mockManager.odooFields).thenReturn(['id', 'name']);
      when(() => mockClient.read(
        model: any(named: 'model'),
        ids: any(named: 'ids'),
        fields: any(named: 'fields'),
      )).thenAnswer((_) async => [{'id': 100, 'name': 'From Server'}]);
      when(() => mockManager.fromOdoo(any())).thenReturn(
        const TestOdooRecord(id: 1, odooId: 100, name: 'From Server'),
      );
      when(() => mockManager.withSyncStatus(any(), any())).thenReturn(synced);
      when(() => mockManager.upsertLocal(any())).thenAnswer((_) async {});

      final result = await record.syncFromServer();

      expect(result?.name, 'From Server');
      expect(result?.isSynced, true);
    });
  });

  group('OdooRecord Actions - callAction()', () {
    setUp(() {
      OdooRecordRegistry.register<TestOdooRecord>(mockManager);
    });

    test('callAction() throws for local-only record', () async {
      const record = TestOdooRecord(id: 1, odooId: 0, name: 'Local');

      await expectLater(
        record.callAction('action_confirm'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('local-only record'),
        )),
      );
    });

    test('callAction() throws when offline', () async {
      const record = TestOdooRecord(id: 1, odooId: 100, name: 'Test');

      when(() => mockManager.isOnline).thenReturn(false);

      await expectLater(
        record.callAction('action_confirm'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('offline'),
        )),
      );
    });

    test('callAction() calls manager.callOdooAction', () async {
      const record = TestOdooRecord(id: 1, odooId: 100, name: 'Test');

      when(() => mockManager.isOnline).thenReturn(true);
      when(() => mockManager.callOdooAction(100, 'action_confirm', kwargs: null))
          .thenAnswer((_) async => {'state': 'confirmed'});

      final result = await record.callAction('action_confirm');

      expect(result, {'state': 'confirmed'});
      verify(() => mockManager.callOdooAction(100, 'action_confirm', kwargs: null))
          .called(1);
    });

    test('callAction() passes kwargs to manager', () async {
      const record = TestOdooRecord(id: 1, odooId: 100, name: 'Test');

      when(() => mockManager.isOnline).thenReturn(true);
      when(() => mockManager.callOdooAction(
            100,
            'action_custom',
            kwargs: {'force': true},
          )).thenAnswer((_) async => true);

      final result = await record.callAction(
        'action_custom',
        kwargs: {'force': true},
      );

      expect(result, true);
    });
  });

  group('OdooRecord Actions - callActionAndRefresh()', () {
    setUp(() {
      OdooRecordRegistry.register<TestOdooRecord>(mockManager);
    });

    test('callActionAndRefresh() calls action and refreshes', () async {
      const record = TestOdooRecord(id: 1, odooId: 100, name: 'Test');
      const refreshed = TestOdooRecord(
        id: 1,
        odooId: 100,
        name: 'Confirmed',
        isSynced: true,
      );

      when(() => mockManager.isOnline).thenReturn(true);
      when(() => mockManager.callOdooAction(100, 'action_confirm', kwargs: null))
          .thenAnswer((_) async => {});
      when(() => mockManager.readLocal(100)).thenAnswer((_) async => refreshed);

      final result = await record.callActionAndRefresh('action_confirm');

      expect(result.name, 'Confirmed');
    });

    test('callActionAndRefresh() throws if record deleted after action',
        () async {
      const record = TestOdooRecord(id: 1, odooId: 100, name: 'Test');

      when(() => mockManager.isOnline).thenReturn(true);
      when(() => mockManager.callOdooAction(100, 'action_archive', kwargs: null))
          .thenAnswer((_) async => {});
      when(() => mockManager.readLocal(100)).thenAnswer((_) async => null);

      await expectLater(
        record.callActionAndRefresh('action_archive'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Record not found after action'),
        )),
      );
    });
  });

  group('OdooRecord Validation', () {
    test('validate() returns empty map for valid record', () {
      const record = TestOdooRecord(id: 1, name: 'Valid', value: 10.0);

      final errors = record.validate();

      expect(errors, isEmpty);
    });

    test('validate() returns errors for invalid record', () {
      const record = TestOdooRecord(id: 1, name: '', value: -5.0);

      final errors = record.validate();

      expect(errors['name'], 'Name is required');
      expect(errors['value'], 'Value must be non-negative');
    });

    test('isValid returns true for valid record', () {
      const record = TestOdooRecord(id: 1, name: 'Valid', value: 10.0);

      expect(record.isValid, isTrue);
    });

    test('isValid returns false for invalid record', () {
      const record = TestOdooRecord(id: 1, name: '', value: 10.0);

      expect(record.isValid, isFalse);
    });

    test('validateFor() adds action-specific validation', () {
      const record = TestOdooRecord(id: 1, name: 'Test', value: 0.0);

      // Base validation passes
      expect(record.validate(), isEmpty);

      // Action-specific validation fails
      final errors = record.validateFor('confirm');
      expect(errors['value'], 'Value must be greater than 0 to confirm');
    });

    test('isValidFor() checks action-specific validation', () {
      const record = TestOdooRecord(id: 1, name: 'Test', value: 0.0);

      expect(record.isValid, isTrue);
      expect(record.isValidFor('confirm'), isFalse);
      expect(record.isValidFor('save'), isTrue);
    });

    test('ensureValid() does nothing for valid record', () {
      const record = TestOdooRecord(id: 1, name: 'Valid', value: 10.0);

      expect(() => record.ensureValid(), returnsNormally);
    });

    test('ensureValid() throws ValidationException for invalid record', () {
      const record = TestOdooRecord(id: 1, name: '', value: 10.0);

      expect(
        () => record.ensureValid(),
        throwsA(isA<ValidationException>()),
      );
    });

    test('ensureValid(forAction:) validates for specific action', () {
      const record = TestOdooRecord(id: 1, name: 'Test', value: 0.0);

      // Base validation passes
      expect(() => record.ensureValid(), returnsNormally);

      // Action validation fails
      expect(
        () => record.ensureValid(forAction: 'confirm'),
        throwsA(isA<ValidationException>().having(
          (e) => e.action,
          'action',
          'confirm',
        )),
      );
    });
  });

  group('OdooRecord toOdoo()', () {
    test('toOdoo() includes odooId when positive', () {
      const record = TestOdooRecord(
        id: 1,
        odooId: 100,
        name: 'Test',
        value: 50.0,
      );

      final data = record.toOdoo();

      expect(data['id'], 100);
      expect(data['name'], 'Test');
      expect(data['value'], 50.0);
    });

    test('toOdoo() excludes id when odooId is 0', () {
      const record = TestOdooRecord(
        id: 1,
        odooId: 0,
        name: 'New',
        value: 25.0,
      );

      final data = record.toOdoo();

      expect(data.containsKey('id'), isFalse);
      expect(data['name'], 'New');
      expect(data['value'], 25.0);
    });
  });
}
