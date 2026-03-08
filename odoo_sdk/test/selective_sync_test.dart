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

  group('Selective Sync - _resolveFields logic', () {
    test('selectableFields returns all odooFields', () {
      final fields = fixtures.manager.selectableFields;

      expect(fields, equals(fixtures.manager.odooFields));
      expect(fields, contains('id'));
      expect(fields, contains('name'));
      expect(fields, contains('list_price'));
      expect(fields, contains('active'));
      expect(fields, contains('write_date'));
    });

    test('syncFromOdoo with null selectedFields fetches all odooFields',
        () async {
      fixtures.setOnline();

      when(() => fixtures.mockClient.searchCount(
            model: any(named: 'model'),
            domain: any(named: 'domain'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => 1);

      when(() => fixtures.mockClient.searchRead(
            model: any(named: 'model'),
            fields: any(named: 'fields'),
            domain: any(named: 'domain'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => [
            SampleOdooData.product(id: 1, name: 'Test Product'),
          ]);

      await fixtures.manager.syncFromOdoo();

      // Verify searchRead was called with all odooFields
      final captured = verify(() => fixtures.mockClient.searchRead(
            model: any(named: 'model'),
            fields: captureAny(named: 'fields'),
            domain: any(named: 'domain'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
            cancelToken: any(named: 'cancelToken'),
          )).captured;

      final fieldsUsed = captured.first as List<String>;
      expect(fieldsUsed, equals(fixtures.manager.odooFields));
    });

    test('syncFromOdoo with empty selectedFields fetches all odooFields',
        () async {
      fixtures.setOnline();

      when(() => fixtures.mockClient.searchCount(
            model: any(named: 'model'),
            domain: any(named: 'domain'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => 1);

      when(() => fixtures.mockClient.searchRead(
            model: any(named: 'model'),
            fields: any(named: 'fields'),
            domain: any(named: 'domain'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => [
            SampleOdooData.product(id: 1, name: 'Test Product'),
          ]);

      await fixtures.manager.syncFromOdoo(selectedFields: []);

      final captured = verify(() => fixtures.mockClient.searchRead(
            model: any(named: 'model'),
            fields: captureAny(named: 'fields'),
            domain: any(named: 'domain'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
            cancelToken: any(named: 'cancelToken'),
          )).captured;

      final fieldsUsed = captured.first as List<String>;
      expect(fieldsUsed, equals(fixtures.manager.odooFields));
    });

    test('syncFromOdoo with selectedFields intersects with odooFields',
        () async {
      fixtures.setOnline();

      when(() => fixtures.mockClient.searchCount(
            model: any(named: 'model'),
            domain: any(named: 'domain'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => 1);

      when(() => fixtures.mockClient.searchRead(
            model: any(named: 'model'),
            fields: any(named: 'fields'),
            domain: any(named: 'domain'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => [
            SampleOdooData.product(id: 1, name: 'Test Product'),
          ]);

      await fixtures.manager.syncFromOdoo(selectedFields: ['name']);

      final captured = verify(() => fixtures.mockClient.searchRead(
            model: any(named: 'model'),
            fields: captureAny(named: 'fields'),
            domain: any(named: 'domain'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
            cancelToken: any(named: 'cancelToken'),
          )).captured;

      final fieldsUsed = (captured.first as List<String>).toSet();

      // Should contain selected field plus mandatory fields
      expect(fieldsUsed, contains('name'));
      expect(fieldsUsed, contains('id'));
      expect(fieldsUsed, contains('write_date'));

      // Should NOT contain fields not selected (like list_price, active)
      expect(fieldsUsed, isNot(contains('list_price')));
      expect(fieldsUsed, isNot(contains('active')));
    });

    test('mandatory fields (id, write_date) are always included', () async {
      fixtures.setOnline();

      when(() => fixtures.mockClient.searchCount(
            model: any(named: 'model'),
            domain: any(named: 'domain'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => 1);

      when(() => fixtures.mockClient.searchRead(
            model: any(named: 'model'),
            fields: any(named: 'fields'),
            domain: any(named: 'domain'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => [
            SampleOdooData.product(id: 1, name: 'Test Product'),
          ]);

      // Only request 'active' - mandatory fields should still be included
      await fixtures.manager.syncFromOdoo(selectedFields: ['active']);

      final captured = verify(() => fixtures.mockClient.searchRead(
            model: any(named: 'model'),
            fields: captureAny(named: 'fields'),
            domain: any(named: 'domain'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
            cancelToken: any(named: 'cancelToken'),
          )).captured;

      final fieldsUsed = (captured.first as List<String>).toSet();

      // Mandatory fields are always present
      expect(fieldsUsed, contains('id'));
      expect(fieldsUsed, contains('write_date'));

      // Requested field is present
      expect(fieldsUsed, contains('active'));
    });

    test('fields not in odooFields are silently ignored', () async {
      fixtures.setOnline();

      when(() => fixtures.mockClient.searchCount(
            model: any(named: 'model'),
            domain: any(named: 'domain'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => 1);

      when(() => fixtures.mockClient.searchRead(
            model: any(named: 'model'),
            fields: any(named: 'fields'),
            domain: any(named: 'domain'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => [
            SampleOdooData.product(id: 1, name: 'Test Product'),
          ]);

      // Request a mix of valid and invalid field names
      await fixtures.manager.syncFromOdoo(
        selectedFields: ['name', 'nonexistent_field', 'another_invalid'],
      );

      final captured = verify(() => fixtures.mockClient.searchRead(
            model: any(named: 'model'),
            fields: captureAny(named: 'fields'),
            domain: any(named: 'domain'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
            cancelToken: any(named: 'cancelToken'),
          )).captured;

      final fieldsUsed = (captured.first as List<String>).toSet();

      // Valid field should be present
      expect(fieldsUsed, contains('name'));

      // Invalid fields should NOT be present
      expect(fieldsUsed, isNot(contains('nonexistent_field')));
      expect(fieldsUsed, isNot(contains('another_invalid')));

      // Mandatory fields should still be present
      expect(fieldsUsed, contains('id'));
      expect(fieldsUsed, contains('write_date'));
    });

    test('only invalid fields still includes mandatory fields', () async {
      fixtures.setOnline();

      when(() => fixtures.mockClient.searchCount(
            model: any(named: 'model'),
            domain: any(named: 'domain'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => 1);

      when(() => fixtures.mockClient.searchRead(
            model: any(named: 'model'),
            fields: any(named: 'fields'),
            domain: any(named: 'domain'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => [
            SampleOdooData.product(id: 1, name: 'Test Product'),
          ]);

      // Request only invalid field names
      await fixtures.manager.syncFromOdoo(
        selectedFields: ['nonexistent_field'],
      );

      final captured = verify(() => fixtures.mockClient.searchRead(
            model: any(named: 'model'),
            fields: captureAny(named: 'fields'),
            domain: any(named: 'domain'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
            cancelToken: any(named: 'cancelToken'),
          )).captured;

      final fieldsUsed = (captured.first as List<String>).toSet();

      // Mandatory fields should still be present
      expect(fieldsUsed, contains('id'));
      expect(fieldsUsed, contains('write_date'));

      // Invalid field should not be present
      expect(fieldsUsed, isNot(contains('nonexistent_field')));
    });
  });

  group('Selective Sync - sync() pass-through', () {
    test('sync() passes selectedFields to syncFromOdoo', () async {
      fixtures.setOnline();

      when(() => fixtures.mockClient.searchCount(
            model: any(named: 'model'),
            domain: any(named: 'domain'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => 1);

      when(() => fixtures.mockClient.searchRead(
            model: any(named: 'model'),
            fields: any(named: 'fields'),
            domain: any(named: 'domain'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => [
            SampleOdooData.product(id: 1, name: 'Test Product'),
          ]);

      await fixtures.manager.sync(selectedFields: ['name', 'active']);

      final captured = verify(() => fixtures.mockClient.searchRead(
            model: any(named: 'model'),
            fields: captureAny(named: 'fields'),
            domain: any(named: 'domain'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
            cancelToken: any(named: 'cancelToken'),
          )).captured;

      final fieldsUsed = (captured.first as List<String>).toSet();

      // Selected fields should be present
      expect(fieldsUsed, contains('name'));
      expect(fieldsUsed, contains('active'));

      // Mandatory fields should be present
      expect(fieldsUsed, contains('id'));
      expect(fieldsUsed, contains('write_date'));

      // Non-selected fields should not be present
      expect(fieldsUsed, isNot(contains('list_price')));
    });

    test('sync() without selectedFields fetches all fields', () async {
      fixtures.setOnline();

      when(() => fixtures.mockClient.searchCount(
            model: any(named: 'model'),
            domain: any(named: 'domain'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => 1);

      when(() => fixtures.mockClient.searchRead(
            model: any(named: 'model'),
            fields: any(named: 'fields'),
            domain: any(named: 'domain'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => [
            SampleOdooData.product(id: 1, name: 'Test Product'),
          ]);

      await fixtures.manager.sync();

      final captured = verify(() => fixtures.mockClient.searchRead(
            model: any(named: 'model'),
            fields: captureAny(named: 'fields'),
            domain: any(named: 'domain'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
            cancelToken: any(named: 'cancelToken'),
          )).captured;

      final fieldsUsed = captured.first as List<String>;
      expect(fieldsUsed, equals(fixtures.manager.odooFields));
    });
  });

  group('Selective Sync - integration', () {
    test('syncFromOdoo with selectedFields successfully syncs records',
        () async {
      fixtures.setOnline();

      when(() => fixtures.mockClient.searchCount(
            model: any(named: 'model'),
            domain: any(named: 'domain'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => 2);

      when(() => fixtures.mockClient.searchRead(
            model: any(named: 'model'),
            fields: any(named: 'fields'),
            domain: any(named: 'domain'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => [
            SampleOdooData.product(id: 1, name: 'Product 1', price: 10.0),
            SampleOdooData.product(id: 2, name: 'Product 2', price: 20.0),
          ]);

      final result = await fixtures.manager.syncFromOdoo(
        selectedFields: ['name', 'list_price'],
      );

      expect(result.status, equals(SyncStatus.success));
      expect(result.synced, equals(2));

      // Verify records were stored locally
      final p1 = await fixtures.manager.readLocal(1);
      final p2 = await fixtures.manager.readLocal(2);

      expect(p1, isNotNull);
      expect(p1!.name, equals('Product 1'));
      expect(p1.isSynced, isTrue);

      expect(p2, isNotNull);
      expect(p2!.name, equals('Product 2'));
    });

    test('syncFromOdoo with selectedFields works with additional domain',
        () async {
      fixtures.setOnline();

      when(() => fixtures.mockClient.searchCount(
            model: any(named: 'model'),
            domain: any(named: 'domain'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => 1);

      when(() => fixtures.mockClient.searchRead(
            model: any(named: 'model'),
            fields: any(named: 'fields'),
            domain: any(named: 'domain'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => [
            SampleOdooData.product(id: 1, name: 'Active Product'),
          ]);

      final result = await fixtures.manager.syncFromOdoo(
        selectedFields: ['name'],
        additionalDomain: [
          ['active', '=', true]
        ],
      );

      expect(result.status, equals(SyncStatus.success));
      expect(result.synced, equals(1));
    });

    test(
        'syncFromOdoo with selectedFields accepts parameter without error when offline',
        () async {
      fixtures.setOffline();

      final result = await fixtures.manager.syncFromOdoo(
        selectedFields: ['name', 'list_price'],
      );

      expect(result.status, equals(SyncStatus.offline));
    });
  });
}
