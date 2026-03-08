import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:odoo_sdk/src/model/related_record.dart';
import 'package:odoo_sdk/src/model/odoo_record.dart';
import 'package:odoo_sdk/src/model/odoo_model_manager.dart';

/// Test record class implementing OdooRecord.
class TestRecord with OdooRecord<TestRecord> {
  @override
  final int id;

  @override
  final int odooId;

  @override
  final String? uuid;

  @override
  final bool isSynced;

  final String name;

  TestRecord({
    required this.id,
    int? odooId,
    this.uuid,
    this.isSynced = true,
    required this.name,
  }) : odooId = odooId ?? id;

  @override
  Map<String, dynamic> toOdoo() => {'id': odooId, 'name': name};

  TestRecord copyWith({
    int? id,
    int? odooId,
    String? uuid,
    bool? isSynced,
    String? name,
  }) {
    return TestRecord(
      id: id ?? this.id,
      odooId: odooId ?? this.odooId,
      uuid: uuid ?? this.uuid,
      isSynced: isSynced ?? this.isSynced,
      name: name ?? this.name,
    );
  }
}

/// Mock manager for testing.
class MockTestManager extends Mock implements OdooModelManager<TestRecord> {}

void main() {
  group('RelatedRecord', () {
    group('Constructor', () {
      test('creates with id and displayName', () {
        final related = RelatedRecord<TestRecord>(
          id: 1,
          displayName: 'Test Name',
        );

        expect(related.id, 1);
        expect(related.displayName, 'Test Name');
        expect(related.hasValue, isTrue);
        expect(related.isLoaded, isFalse);
        expect(related.cached, isNull);
      });

      test('creates empty', () {
        final related = RelatedRecord<TestRecord>();

        expect(related.id, isNull);
        expect(related.displayName, isNull);
        expect(related.hasValue, isFalse);
      });

      test('creates with only id', () {
        final related = RelatedRecord<TestRecord>(id: 5);

        expect(related.id, 5);
        expect(related.displayName, isNull);
        expect(related.hasValue, isTrue);
      });

      test('creates with only displayName', () {
        final related = RelatedRecord<TestRecord>(displayName: 'Test');

        expect(related.id, isNull);
        expect(related.displayName, 'Test');
        expect(related.hasValue, isFalse);
      });
    });

    group('fromOdoo factory', () {
      test('handles null', () {
        final related = RelatedRecord<TestRecord>.fromOdoo(null);

        expect(related.id, isNull);
        expect(related.displayName, isNull);
        expect(related.hasValue, isFalse);
      });

      test('handles false', () {
        final related = RelatedRecord<TestRecord>.fromOdoo(false);

        expect(related.id, isNull);
        expect(related.displayName, isNull);
        expect(related.hasValue, isFalse);
      });

      test('handles int (ID only)', () {
        final related = RelatedRecord<TestRecord>.fromOdoo(42);

        expect(related.id, 42);
        expect(related.displayName, isNull);
        expect(related.hasValue, isTrue);
      });

      test('handles List [id, name]', () {
        final related = RelatedRecord<TestRecord>.fromOdoo([1, 'Partner Name']);

        expect(related.id, 1);
        expect(related.displayName, 'Partner Name');
        expect(related.hasValue, isTrue);
      });

      test('handles List [id] without name', () {
        final related = RelatedRecord<TestRecord>.fromOdoo([7]);

        expect(related.id, 7);
        expect(related.displayName, isNull);
        expect(related.hasValue, isTrue);
      });

      test('handles empty List', () {
        final related = RelatedRecord<TestRecord>.fromOdoo([]);

        expect(related.id, isNull);
        expect(related.displayName, isNull);
        expect(related.hasValue, isFalse);
      });

      test('handles List with null name', () {
        final related = RelatedRecord<TestRecord>.fromOdoo([3, null]);

        expect(related.id, 3);
        expect(related.displayName, isNull);
        expect(related.hasValue, isTrue);
      });

      test('handles unexpected type by returning empty', () {
        final related = RelatedRecord<TestRecord>.fromOdoo('invalid');

        expect(related.id, isNull);
        expect(related.hasValue, isFalse);
      });
    });

    group('fromIdName factory', () {
      test('creates with id and name', () {
        final related = RelatedRecord<TestRecord>.fromIdName(10, 'Test Record');

        expect(related.id, 10);
        expect(related.displayName, 'Test Record');
      });

      test('creates with null id', () {
        final related = RelatedRecord<TestRecord>.fromIdName(null, 'Test');

        expect(related.id, isNull);
        expect(related.displayName, 'Test');
        expect(related.hasValue, isFalse);
      });

      test('creates with null name', () {
        final related = RelatedRecord<TestRecord>.fromIdName(5, null);

        expect(related.id, 5);
        expect(related.displayName, isNull);
        expect(related.hasValue, isTrue);
      });
    });

    group('hasValue', () {
      test('returns true when id > 0', () {
        expect(RelatedRecord<TestRecord>(id: 1).hasValue, isTrue);
        expect(RelatedRecord<TestRecord>(id: 100).hasValue, isTrue);
      });

      test('returns false when id is null', () {
        expect(RelatedRecord<TestRecord>().hasValue, isFalse);
      });

      test('returns false when id is 0', () {
        expect(RelatedRecord<TestRecord>(id: 0).hasValue, isFalse);
      });

      test('returns false when id is negative', () {
        expect(RelatedRecord<TestRecord>(id: -1).hasValue, isFalse);
      });
    });

    group('load', () {
      late MockTestManager mockManager;

      setUp(() {
        mockManager = MockTestManager();
        OdooRecordRegistry.clear();
      });

      tearDown(() {
        OdooRecordRegistry.clear();
      });

      test('returns null when id is null', () async {
        final related = RelatedRecord<TestRecord>();

        final result = await related.load();

        expect(result, isNull);
      });

      test('returns null when id is 0', () async {
        final related = RelatedRecord<TestRecord>(id: 0);

        final result = await related.load();

        expect(result, isNull);
      });

      test('returns null when id is negative', () async {
        final related = RelatedRecord<TestRecord>(id: -5);

        final result = await related.load();

        expect(result, isNull);
      });

      test('throws when no manager registered', () async {
        final related = RelatedRecord<TestRecord>(id: 1);

        expect(
          () => related.load(),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('No manager registered'),
            ),
          ),
        );
      });

      test('loads and caches record', () async {
        final testRecord = TestRecord(id: 1, name: 'Test');
        when(
          () => mockManager.readLocal(1),
        ).thenAnswer((_) async => testRecord);
        OdooRecordRegistry.register<TestRecord>(mockManager);

        final related = RelatedRecord<TestRecord>(id: 1);

        expect(related.isLoaded, isFalse);
        expect(related.cached, isNull);

        final result = await related.load();

        expect(result, same(testRecord));
        expect(related.isLoaded, isTrue);
        expect(related.cached, same(testRecord));

        verify(() => mockManager.readLocal(1)).called(1);
      });

      test('returns cached record without reload', () async {
        final testRecord = TestRecord(id: 1, name: 'Test');
        when(
          () => mockManager.readLocal(1),
        ).thenAnswer((_) async => testRecord);
        OdooRecordRegistry.register<TestRecord>(mockManager);

        final related = RelatedRecord<TestRecord>(id: 1);

        // First load
        await related.load();

        // Second load should return cached
        final result = await related.load();

        expect(result, same(testRecord));
        verify(() => mockManager.readLocal(1)).called(1); // Only called once
      });

      test('force refresh reloads record', () async {
        final testRecord1 = TestRecord(id: 1, name: 'Test 1');
        final testRecord2 = TestRecord(id: 1, name: 'Test 2');
        when(
          () => mockManager.readLocal(1),
        ).thenAnswer((_) async => testRecord1);
        OdooRecordRegistry.register<TestRecord>(mockManager);

        final related = RelatedRecord<TestRecord>(id: 1);

        // First load
        await related.load();

        // Update mock to return different record
        when(
          () => mockManager.readLocal(1),
        ).thenAnswer((_) async => testRecord2);

        // Force refresh
        final result = await related.load(forceRefresh: true);

        expect(result, same(testRecord2));
        verify(() => mockManager.readLocal(1)).called(2);
      });

      test('returns null when record not found', () async {
        when(() => mockManager.readLocal(999)).thenAnswer((_) async => null);
        OdooRecordRegistry.register<TestRecord>(mockManager);

        final related = RelatedRecord<TestRecord>(id: 999);

        final result = await related.load();

        expect(result, isNull);
        expect(related.isLoaded, isFalse);
      });
    });

    group('clearCache', () {
      test('clears cached record', () async {
        final mockManager = MockTestManager();
        final testRecord = TestRecord(id: 1, name: 'Test');
        when(
          () => mockManager.readLocal(1),
        ).thenAnswer((_) async => testRecord);
        OdooRecordRegistry.register<TestRecord>(mockManager);

        final related = RelatedRecord<TestRecord>(id: 1);

        await related.load();
        expect(related.isLoaded, isTrue);

        related.clearCache();

        expect(related.isLoaded, isFalse);
        expect(related.cached, isNull);

        OdooRecordRegistry.clear();
      });
    });

    group('toOdoo', () {
      test('returns id', () {
        final related = RelatedRecord<TestRecord>(id: 42, displayName: 'Test');

        expect(related.toOdoo(), 42);
      });

      test('returns null when no id', () {
        final related = RelatedRecord<TestRecord>(displayName: 'Test');

        expect(related.toOdoo(), isNull);
      });
    });

    group('JSON serialization', () {
      test('toJson includes id and displayName', () {
        final related = RelatedRecord<TestRecord>(
          id: 5,
          displayName: 'Test Name',
        );

        final json = related.toJson();

        expect(json, {'id': 5, 'displayName': 'Test Name'});
      });

      test('toJson handles null values', () {
        final related = RelatedRecord<TestRecord>();

        final json = related.toJson();

        expect(json, {'id': null, 'displayName': null});
      });

      test('fromJson creates RelatedRecord', () {
        final related = RelatedRecord<TestRecord>.fromJson({
          'id': 10,
          'displayName': 'From JSON',
        });

        expect(related.id, 10);
        expect(related.displayName, 'From JSON');
      });

      test('roundtrip JSON', () {
        final original = RelatedRecord<TestRecord>(
          id: 7,
          displayName: 'Roundtrip',
        );

        final json = original.toJson();
        final restored = RelatedRecord<TestRecord>.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.displayName, original.displayName);
      });
    });

    group('toString', () {
      test('returns displayName when present', () {
        final related = RelatedRecord<TestRecord>(
          id: 1,
          displayName: 'Test Display',
        );

        expect(related.toString(), 'Test Display');
      });

      test('returns ID format when no displayName', () {
        final related = RelatedRecord<TestRecord>(id: 42);

        expect(related.toString(), 'ID: 42');
      });

      test('returns Empty when no id or displayName', () {
        final related = RelatedRecord<TestRecord>();

        expect(related.toString(), 'Empty');
      });
    });

    group('equality', () {
      test('equals when same id', () {
        final a = RelatedRecord<TestRecord>(id: 1, displayName: 'A');
        final b = RelatedRecord<TestRecord>(id: 1, displayName: 'B');

        expect(a == b, isTrue);
        expect(a.hashCode, b.hashCode);
      });

      test('not equals when different id', () {
        final a = RelatedRecord<TestRecord>(id: 1, displayName: 'Same');
        final b = RelatedRecord<TestRecord>(id: 2, displayName: 'Same');

        expect(a == b, isFalse);
      });

      test('equals when both have null id', () {
        final a = RelatedRecord<TestRecord>(displayName: 'A');
        final b = RelatedRecord<TestRecord>(displayName: 'B');

        expect(a == b, isTrue);
      });

      test('identical returns true', () {
        final a = RelatedRecord<TestRecord>(id: 1);

        expect(a == a, isTrue);
      });
    });
  });

  group('RelatedRecordParsing extension', () {
    group('getRelated', () {
      test('extracts Many2One as RelatedRecord', () {
        final data = {
          'partner_id': [1, 'Partner Name'],
        };

        final related = data.getRelated<TestRecord>('partner_id');

        expect(related.id, 1);
        expect(related.displayName, 'Partner Name');
      });

      test('handles false value', () {
        final data = {'partner_id': false};

        final related = data.getRelated<TestRecord>('partner_id');

        expect(related.hasValue, isFalse);
      });

      test('handles missing field', () {
        final data = <String, dynamic>{};

        final related = data.getRelated<TestRecord>('partner_id');

        expect(related.hasValue, isFalse);
      });
    });

    group('getRelatedId', () {
      test('extracts ID from tuple', () {
        final data = {
          'partner_id': [42, 'Name'],
        };

        expect(data.getRelatedId('partner_id'), 42);
      });

      test('extracts ID from int', () {
        final data = {'partner_id': 42};

        expect(data.getRelatedId('partner_id'), 42);
      });

      test('returns null for false', () {
        final data = {'partner_id': false};

        expect(data.getRelatedId('partner_id'), isNull);
      });

      test('returns null for null', () {
        final data = {'partner_id': null};

        expect(data.getRelatedId('partner_id'), isNull);
      });

      test('returns null for missing field', () {
        final data = <String, dynamic>{};

        expect(data.getRelatedId('partner_id'), isNull);
      });

      test('returns null for empty list', () {
        final data = {'partner_id': <dynamic>[]};

        expect(data.getRelatedId('partner_id'), isNull);
      });
    });

    group('getRelatedName', () {
      test('extracts name from tuple', () {
        final data = {
          'partner_id': [1, 'Partner Name'],
        };

        expect(data.getRelatedName('partner_id'), 'Partner Name');
      });

      test('returns null for ID only', () {
        final data = {
          'partner_id': [1],
        };

        expect(data.getRelatedName('partner_id'), isNull);
      });

      test('returns null for int value', () {
        final data = {'partner_id': 42};

        expect(data.getRelatedName('partner_id'), isNull);
      });

      test('returns null for false', () {
        final data = {'partner_id': false};

        expect(data.getRelatedName('partner_id'), isNull);
      });

      test('returns null for null', () {
        final data = {'partner_id': null};

        expect(data.getRelatedName('partner_id'), isNull);
      });

      test('converts non-string name to string', () {
        final data = {
          'partner_id': [1, 123],
        };

        expect(data.getRelatedName('partner_id'), '123');
      });
    });
  });

  group('RelatedRecordList', () {
    group('Constructor', () {
      test('creates with list of IDs', () {
        final list = RelatedRecordList<TestRecord>([1, 2, 3]);

        expect(list.ids, [1, 2, 3]);
        expect(list.length, 3);
        expect(list.isEmpty, isFalse);
        expect(list.isNotEmpty, isTrue);
        expect(list.isLoaded, isFalse);
      });

      test('creates with empty list', () {
        final list = RelatedRecordList<TestRecord>([]);

        expect(list.ids, isEmpty);
        expect(list.length, 0);
        expect(list.isEmpty, isTrue);
        expect(list.isNotEmpty, isFalse);
      });
    });

    group('fromOdoo factory', () {
      test('creates from list of IDs', () {
        final list = RelatedRecordList<TestRecord>.fromOdoo([1, 2, 3]);

        expect(list.ids, [1, 2, 3]);
      });

      test('handles null', () {
        final list = RelatedRecordList<TestRecord>.fromOdoo(null);

        expect(list.ids, isEmpty);
      });

      test('handles false', () {
        final list = RelatedRecordList<TestRecord>.fromOdoo(false);

        expect(list.ids, isEmpty);
      });

      test('filters non-int values', () {
        final list = RelatedRecordList<TestRecord>.fromOdoo([
          1,
          'invalid',
          2,
          null,
          3,
        ]);

        expect(list.ids, [1, 2, 3]);
      });

      test('handles unexpected type', () {
        final list = RelatedRecordList<TestRecord>.fromOdoo('invalid');

        expect(list.ids, isEmpty);
      });
    });

    group('cached property', () {
      test('returns unmodifiable list', () {
        final list = RelatedRecordList<TestRecord>([1, 2, 3]);

        expect(list.cached, isEmpty);
        expect(
          () => list.cached.add(TestRecord(id: 1, name: 'Test')),
          throwsUnsupportedError,
        );
      });
    });

    group('loadAll', () {
      late MockTestManager mockManager;

      setUp(() {
        mockManager = MockTestManager();
        OdooRecordRegistry.clear();
      });

      tearDown(() {
        OdooRecordRegistry.clear();
      });

      test('throws when no manager registered', () async {
        final list = RelatedRecordList<TestRecord>([1, 2]);

        expect(
          () => list.loadAll(),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('No manager registered'),
            ),
          ),
        );
      });

      test('loads all records', () async {
        final record1 = TestRecord(id: 1, name: 'Record 1');
        final record2 = TestRecord(id: 2, name: 'Record 2');

        when(() => mockManager.readLocal(1)).thenAnswer((_) async => record1);
        when(() => mockManager.readLocal(2)).thenAnswer((_) async => record2);
        OdooRecordRegistry.register<TestRecord>(mockManager);

        final list = RelatedRecordList<TestRecord>([1, 2]);

        final results = await list.loadAll();

        expect(results.length, 2);
        expect(results, contains(record1));
        expect(results, contains(record2));
        expect(list.isLoaded, isTrue);
      });

      test('returns cached without reload', () async {
        final record = TestRecord(id: 1, name: 'Record');
        when(() => mockManager.readLocal(1)).thenAnswer((_) async => record);
        OdooRecordRegistry.register<TestRecord>(mockManager);

        final list = RelatedRecordList<TestRecord>([1]);

        await list.loadAll();
        await list.loadAll();

        verify(() => mockManager.readLocal(1)).called(1);
      });

      test('force refresh reloads', () async {
        final record = TestRecord(id: 1, name: 'Record');
        when(() => mockManager.readLocal(1)).thenAnswer((_) async => record);
        OdooRecordRegistry.register<TestRecord>(mockManager);

        final list = RelatedRecordList<TestRecord>([1]);

        await list.loadAll();
        await list.loadAll(forceRefresh: true);

        verify(() => mockManager.readLocal(1)).called(2);
      });

      test('skips records not found', () async {
        final record = TestRecord(id: 1, name: 'Record');
        when(() => mockManager.readLocal(1)).thenAnswer((_) async => record);
        when(() => mockManager.readLocal(2)).thenAnswer((_) async => null);
        OdooRecordRegistry.register<TestRecord>(mockManager);

        final list = RelatedRecordList<TestRecord>([1, 2]);

        final results = await list.loadAll();

        expect(results.length, 1);
        expect(results.first, record);
      });

      test('returns unmodifiable list', () async {
        when(() => mockManager.readLocal(any())).thenAnswer((_) async => null);
        OdooRecordRegistry.register<TestRecord>(mockManager);

        final list = RelatedRecordList<TestRecord>([1]);
        final results = await list.loadAll();

        expect(
          () => results.add(TestRecord(id: 1, name: 'Test')),
          throwsUnsupportedError,
        );
      });
    });

    group('loadOne', () {
      late MockTestManager mockManager;

      setUp(() {
        mockManager = MockTestManager();
        OdooRecordRegistry.clear();
      });

      tearDown(() {
        OdooRecordRegistry.clear();
      });

      test('returns null for ID not in list', () async {
        final list = RelatedRecordList<TestRecord>([1, 2, 3]);

        final result = await list.loadOne(99);

        expect(result, isNull);
      });

      test('loads single record', () async {
        final record = TestRecord(id: 2, name: 'Record 2');
        when(() => mockManager.readLocal(2)).thenAnswer((_) async => record);
        OdooRecordRegistry.register<TestRecord>(mockManager);

        final list = RelatedRecordList<TestRecord>([1, 2, 3]);

        final result = await list.loadOne(2);

        expect(result, same(record));
        expect(list.cached, contains(record));
      });

      test('returns cached record', () async {
        final record = TestRecord(id: 2, name: 'Record 2');
        when(() => mockManager.readLocal(2)).thenAnswer((_) async => record);
        OdooRecordRegistry.register<TestRecord>(mockManager);

        final list = RelatedRecordList<TestRecord>([1, 2, 3]);

        await list.loadOne(2);
        final result = await list.loadOne(2);

        expect(result, same(record));
        verify(() => mockManager.readLocal(2)).called(1);
      });

      test('returns null when no manager and not cached', () async {
        final list = RelatedRecordList<TestRecord>([1, 2, 3]);

        // No manager registered
        final result = await list.loadOne(2);

        expect(result, isNull);
      });
    });

    group('clearCache', () {
      test('clears cached records and loaded flag', () async {
        final mockManager = MockTestManager();
        final record = TestRecord(id: 1, name: 'Record');
        when(() => mockManager.readLocal(1)).thenAnswer((_) async => record);
        OdooRecordRegistry.register<TestRecord>(mockManager);

        final list = RelatedRecordList<TestRecord>([1]);

        await list.loadAll();
        expect(list.isLoaded, isTrue);
        expect(list.cached, isNotEmpty);

        list.clearCache();

        expect(list.isLoaded, isFalse);
        expect(list.cached, isEmpty);

        OdooRecordRegistry.clear();
      });
    });

    group('toOdoo', () {
      test('returns list of IDs', () {
        final list = RelatedRecordList<TestRecord>([1, 2, 3]);

        expect(list.toOdoo(), [1, 2, 3]);
      });

      test('returns empty list', () {
        final list = RelatedRecordList<TestRecord>([]);

        expect(list.toOdoo(), <int>[]);
      });
    });

    group('toString', () {
      test('returns count of items', () {
        final list = RelatedRecordList<TestRecord>([1, 2, 3]);

        expect(list.toString(), 'RelatedRecordList(3 items)');
      });

      test('returns 0 items for empty', () {
        final list = RelatedRecordList<TestRecord>([]);

        expect(list.toString(), 'RelatedRecordList(0 items)');
      });
    });

    group('Odoo commands', () {
      test('setCommand creates replace all command', () {
        final cmd = RelatedRecordList.setCommand([1, 2, 3]);

        expect(cmd, [
          [
            6,
            0,
            [1, 2, 3],
          ],
        ]);
      });

      test('addCommand creates add link command', () {
        final cmd = RelatedRecordList.addCommand(5);

        expect(cmd, [
          [4, 5, 0],
        ]);
      });

      test('removeCommand creates unlink command', () {
        final cmd = RelatedRecordList.removeCommand(5);

        expect(cmd, [
          [3, 5, 0],
        ]);
      });

      test('deleteCommand creates delete command', () {
        final cmd = RelatedRecordList.deleteCommand(5);

        expect(cmd, [
          [2, 5, 0],
        ]);
      });

      test('createCommand creates inline create command', () {
        final cmd = RelatedRecordList.createCommand({
          'name': 'New',
          'value': 100,
        });

        expect(cmd, [
          [
            0,
            0,
            {'name': 'New', 'value': 100},
          ],
        ]);
      });

      test('updateCommand creates inline update command', () {
        final cmd = RelatedRecordList.updateCommand(5, {'name': 'Updated'});

        expect(cmd, [
          [
            1,
            5,
            {'name': 'Updated'},
          ],
        ]);
      });
    });
  });

  group('OdooRecordRegistry', () {
    setUp(() {
      OdooRecordRegistry.clear();
    });

    tearDown(() {
      OdooRecordRegistry.clear();
    });

    test('register and get manager', () {
      final manager = MockTestManager();

      OdooRecordRegistry.register<TestRecord>(manager);

      expect(OdooRecordRegistry.get<TestRecord>(), same(manager));
    });

    test('get returns null for unregistered type', () {
      expect(OdooRecordRegistry.get<TestRecord>(), isNull);
    });

    test('has returns true for registered type', () {
      final manager = MockTestManager();
      OdooRecordRegistry.register<TestRecord>(manager);

      expect(OdooRecordRegistry.has<TestRecord>(), isTrue);
    });

    test('has returns false for unregistered type', () {
      expect(OdooRecordRegistry.has<TestRecord>(), isFalse);
    });

    test('clear removes all managers', () {
      final manager = MockTestManager();
      OdooRecordRegistry.register<TestRecord>(manager);

      expect(OdooRecordRegistry.has<TestRecord>(), isTrue);

      OdooRecordRegistry.clear();

      expect(OdooRecordRegistry.has<TestRecord>(), isFalse);
    });
  });

  group('ValidationException', () {
    test('creates with map of errors', () {
      const exception = ValidationException({
        'name': 'Name is required',
        'email': 'Invalid email',
      });

      expect(exception.errors.length, 2);
      expect(exception['name'], 'Name is required');
      expect(exception['email'], 'Invalid email');
    });

    test('creates with action context', () {
      const exception = ValidationException({
        'field': 'Error',
      }, action: 'confirm');

      expect(exception.action, 'confirm');
    });

    test('single factory creates single-field error', () {
      final exception = ValidationException.single(
        'name',
        'Name is required',
        action: 'save',
      );

      expect(exception.errors, {'name': 'Name is required'});
      expect(exception.action, 'save');
    });

    test('toString formats correctly without action', () {
      const exception = ValidationException({
        'name': 'Required',
        'email': 'Invalid',
      });

      final str = exception.toString();

      expect(str, contains('ValidationException'));
      expect(str, contains('name: Required'));
      expect(str, contains('email: Invalid'));
    });

    test('toString formats correctly with action', () {
      const exception = ValidationException({
        'field': 'Error',
      }, action: 'confirm');

      expect(exception.toString(), contains('for action "confirm"'));
    });

    test('hasError checks for field', () {
      const exception = ValidationException({'name': 'Error'});

      expect(exception.hasError('name'), isTrue);
      expect(exception.hasError('email'), isFalse);
    });

    test('count returns number of errors', () {
      const exception = ValidationException({'a': '1', 'b': '2', 'c': '3'});

      expect(exception.count, 3);
    });

    test('message joins all error messages', () {
      const exception = ValidationException({
        'name': 'Required',
        'email': 'Invalid',
      });

      expect(exception.message, contains('Required'));
      expect(exception.message, contains('Invalid'));
    });

    test('fields returns all field names', () {
      const exception = ValidationException({
        'name': 'Error 1',
        'email': 'Error 2',
      });

      expect(exception.fields, containsAll(['name', 'email']));
    });

    test('firstError returns first error message', () {
      const exception = ValidationException({'name': 'First Error'});

      expect(exception.firstError, 'First Error');
    });

    test('firstError returns null for empty errors', () {
      const exception = ValidationException({});

      expect(exception.firstError, isNull);
    });

    test('firstField returns first field name', () {
      const exception = ValidationException({'name': 'Error'});

      expect(exception.firstField, 'name');
    });

    test('firstField returns null for empty errors', () {
      const exception = ValidationException({});

      expect(exception.firstField, isNull);
    });
  });

  group('OdooRecordListExtension', () {
    test('synced filters synced records', () {
      final records = [
        TestRecord(id: 1, name: 'A', isSynced: true),
        TestRecord(id: 2, name: 'B', isSynced: false),
        TestRecord(id: 3, name: 'C', isSynced: true),
      ];

      final synced = records.synced;

      expect(synced.length, 2);
      expect(synced.map((r) => r.id), containsAll([1, 3]));
    });

    test('unsynced filters unsynced records', () {
      final records = [
        TestRecord(id: 1, name: 'A', isSynced: true),
        TestRecord(id: 2, name: 'B', isSynced: false),
        TestRecord(id: 3, name: 'C', isSynced: false),
      ];

      final unsynced = records.unsynced;

      expect(unsynced.length, 2);
      expect(unsynced.map((r) => r.id), containsAll([2, 3]));
    });

    test('localOnly filters local-only records', () {
      final records = [
        TestRecord(id: 1, odooId: 1, name: 'Server'),
        TestRecord(id: 2, odooId: 0, name: 'Local 1'),
        TestRecord(id: 3, odooId: -1, name: 'Local 2'),
      ];

      final local = records.localOnly;

      expect(local.length, 2);
      expect(local.map((r) => r.id), containsAll([2, 3]));
    });

    test('findById finds by id', () {
      final records = [
        TestRecord(id: 1, name: 'A'),
        TestRecord(id: 2, name: 'B'),
        TestRecord(id: 3, name: 'C'),
      ];

      expect(records.findById(2)?.name, 'B');
    });

    test('findById finds by odooId', () {
      final records = [
        TestRecord(id: 1, odooId: 100, name: 'A'),
        TestRecord(id: 2, odooId: 200, name: 'B'),
      ];

      expect(records.findById(200)?.name, 'B');
    });

    test('findById returns null when not found', () {
      final records = [TestRecord(id: 1, name: 'A')];

      expect(records.findById(999), isNull);
    });

    test('findByUuid finds by uuid', () {
      final records = [
        TestRecord(id: 1, uuid: 'uuid-1', name: 'A'),
        TestRecord(id: 2, uuid: 'uuid-2', name: 'B'),
      ];

      expect(records.findByUuid('uuid-2')?.name, 'B');
    });

    test('findByUuid returns null when not found', () {
      final records = [TestRecord(id: 1, uuid: 'uuid-1', name: 'A')];

      expect(records.findByUuid('unknown'), isNull);
    });
  });
}
