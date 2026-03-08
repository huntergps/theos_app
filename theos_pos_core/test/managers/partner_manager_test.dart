import 'package:test/test.dart';
import 'package:theos_pos_core/src/models/clients/client.model.dart';

void main() {
  late ClientManager manager;

  setUp(() {
    manager = clientManager;
  });

  // ===========================================================================
  // 1. Metadata
  // ===========================================================================

  group('metadata', () {
    test('odooModel returns res.partner', () {
      expect(manager.odooModel, equals('res.partner'));
    });

    test('tableName returns res_partners', () {
      expect(manager.tableName, equals('res_partners'));
    });

    test('odooFields contains essential fields', () {
      final fields = manager.odooFields;
      expect(fields, contains('id'));
      expect(fields, contains('name'));
      expect(fields, contains('vat'));
      expect(fields, contains('email'));
      expect(fields, contains('phone'));
    });

    test('odooFields contains credit control fields', () {
      final fields = manager.odooFields;
      expect(fields, contains('credit_limit'));
      expect(fields, contains('credit'));
      expect(fields, contains('credit_to_invoice'));
      expect(fields, contains('total_overdue'));
      expect(fields, contains('allow_over_credit'));
      expect(fields, contains('use_partner_credit_limit'));
    });

    test('odooFields contains many2one relation fields', () {
      final fields = manager.odooFields;
      expect(fields, contains('country_id'));
      expect(fields, contains('state_id'));
      expect(fields, contains('parent_id'));
      expect(fields, contains('property_product_pricelist'));
      expect(fields, contains('property_payment_term_id'));
    });

    test('odooFields contains write_date for sync', () {
      expect(manager.odooFields, contains('write_date'));
    });
  });

  // ===========================================================================
  // 2. fromOdoo
  // ===========================================================================

  group('fromOdoo', () {
    test('converts full Odoo JSON to Client', () {
      final odooJson = <String, dynamic>{
        'id': 10,
        'name': 'Empresa Test S.A.',
        'display_name': 'Empresa Test S.A.',
        'ref': 'CLI001',
        'vat': '0992345678001',
        'email': 'test@empresa.com',
        'phone': '042123456',
        'mobile': '0991234567',
        'street': 'Av. Principal 123',
        'city': 'Guayaquil',
        'country_id': [63, 'Ecuador'],
        'state_id': [1, 'Guayas'],
        'is_company': true,
        'active': true,
        'property_product_pricelist': [1, 'Lista Publica'],
        'property_payment_term_id': [1, 'Inmediato'],
        'credit_limit': 5000.0,
        'credit': 1000.0,
        'credit_to_invoice': 500.0,
        'total_overdue': 0.0,
        'allow_over_credit': false,
        'use_partner_credit_limit': true,
        'unpaid_invoices_count': 0,
        'write_date': '2024-06-15 10:30:00',
      };

      final client = manager.fromOdoo(odooJson);

      expect(client, isA<Client>());
      expect(client.id, equals(10));
      expect(client.name, equals('Empresa Test S.A.'));
      expect(client.displayName, equals('Empresa Test S.A.'));
      expect(client.ref, equals('CLI001'));
      expect(client.vat, equals('0992345678001'));
      expect(client.email, equals('test@empresa.com'));
      expect(client.phone, equals('042123456'));
      expect(client.mobile, equals('0991234567'));
      expect(client.street, equals('Av. Principal 123'));
      expect(client.city, equals('Guayaquil'));
      expect(client.isCompany, isTrue);
      expect(client.active, isTrue);
      // Generated fromOdoo sets isSynced to false (sync status managed separately)
      expect(client.isSynced, isFalse);
    });

    test('parses many2one fields extracting id and name', () {
      final odooJson = <String, dynamic>{
        'id': 10,
        'name': 'Test',
        'country_id': [63, 'Ecuador'],
        'state_id': [1, 'Guayas'],
        'parent_id': [5, 'Parent Company'],
        'property_product_pricelist': [1, 'Lista Publica'],
        'property_payment_term_id': [2, 'Credito 30 dias'],
      };

      final client = manager.fromOdoo(odooJson);

      expect(client.countryId, equals(63));
      expect(client.countryName, equals('Ecuador'));
      expect(client.stateId, equals(1));
      expect(client.stateName, equals('Guayas'));
      expect(client.parentId, equals(5));
      expect(client.parentName, equals('Parent Company'));
      expect(client.propertyProductPricelistId, equals(1));
      expect(client.propertyPaymentTermId, equals(2));
    });

    test('handles false many2one fields as null', () {
      final odooJson = <String, dynamic>{
        'id': 10,
        'name': 'Test',
        'country_id': false,
        'state_id': false,
        'parent_id': false,
        'property_product_pricelist': false,
        'property_payment_term_id': false,
      };

      final client = manager.fromOdoo(odooJson);

      expect(client.countryId, isNull);
      expect(client.countryName, isNull);
      expect(client.stateId, isNull);
      expect(client.stateName, isNull);
      expect(client.parentId, isNull);
      expect(client.parentName, isNull);
      expect(client.propertyProductPricelistId, isNull);
      expect(client.propertyPaymentTermId, isNull);
    });

    test('handles false string fields as null', () {
      final odooJson = <String, dynamic>{
        'id': 10,
        'name': 'Test',
        'vat': false,
        'email': false,
        'phone': false,
        'mobile': false,
        'street': false,
        'ref': false,
      };

      final client = manager.fromOdoo(odooJson);

      expect(client.vat, isNull);
      expect(client.email, isNull);
      expect(client.phone, isNull);
      expect(client.mobile, isNull);
      expect(client.street, isNull);
      expect(client.ref, isNull);
    });

    test('parses credit fields correctly', () {
      final odooJson = <String, dynamic>{
        'id': 10,
        'name': 'Test',
        'credit_limit': 5000.0,
        'credit': 1000.0,
        'credit_to_invoice': 500.0,
        'total_overdue': 250.0,
        'allow_over_credit': true,
        'use_partner_credit_limit': true,
        'unpaid_invoices_count': 3,
      };

      final client = manager.fromOdoo(odooJson);

      expect(client.creditLimit, equals(5000.0));
      expect(client.credit, equals(1000.0));
      expect(client.creditToInvoice, equals(500.0));
      expect(client.totalOverdue, equals(250.0));
      expect(client.allowOverCredit, isTrue);
      expect(client.usePartnerCreditLimit, isTrue);
      expect(client.overdueInvoicesCount, equals(3));
    });

    test('parses write_date with UTC suffix', () {
      final odooJson = <String, dynamic>{
        'id': 10,
        'name': 'Test',
        'write_date': '2024-06-15 10:30:00',
      };

      final client = manager.fromOdoo(odooJson);

      expect(client.writeDate, isNotNull);
      expect(client.writeDate!.year, equals(2024));
      expect(client.writeDate!.month, equals(6));
      expect(client.writeDate!.day, equals(15));
      expect(client.writeDate!.isUtc, isTrue);
    });

    test('marks record as unsynced from fromOdoo (sync managed separately)', () {
      final odooJson = <String, dynamic>{
        'id': 10,
        'name': 'Test',
      };

      final client = manager.fromOdoo(odooJson);

      expect(client.isSynced, isFalse);
    });

    test('handles minimal JSON with only id and name', () {
      final odooJson = <String, dynamic>{
        'id': 1,
        'name': 'Minimal Partner',
      };

      final client = manager.fromOdoo(odooJson);

      expect(client.id, equals(1));
      expect(client.name, equals('Minimal Partner'));
      expect(client.vat, isNull);
      expect(client.email, isNull);
      expect(client.countryId, isNull);
    });
  });

  // ===========================================================================
  // 3. toOdoo
  // ===========================================================================

  group('toOdoo', () {
    test('converts Client to Odoo map with required fields', () {
      const client = Client(
        id: 10,
        name: 'Empresa Test S.A.',
        vat: '0992345678001',
        email: 'test@empresa.com',
        phone: '042123456',
        mobile: '0991234567',
        street: 'Av. Principal 123',
        city: 'Guayaquil',
        countryId: 63,
        stateId: 1,
        isCompany: true,
      );

      final map = manager.toOdoo(client);

      expect(map['name'], equals('Empresa Test S.A.'));
      expect(map['vat'], equals('0992345678001'));
      expect(map['email'], equals('test@empresa.com'));
      expect(map['phone'], equals('042123456'));
      expect(map['mobile'], equals('0991234567'));
      expect(map['street'], equals('Av. Principal 123'));
      expect(map['city'], equals('Guayaquil'));
      expect(map['country_id'], equals(63));
      expect(map['state_id'], equals(1));
      expect(map['is_company'], isTrue);
    });

    test('includes all fields in output (null or not)', () {
      const client = Client(
        id: 1,
        name: 'Simple Partner',
      );

      final map = manager.toOdoo(client);

      expect(map['name'], equals('Simple Partner'));
      // Generated toOdoo includes all fields, even null ones
      expect(map.containsKey('vat'), isTrue);
      expect(map['vat'], isNull);
      expect(map.containsKey('email'), isTrue);
      expect(map['email'], isNull);
      expect(map.containsKey('country_id'), isTrue);
      expect(map['country_id'], isNull);
    });

    test('does not include local-only fields like uuid and isSynced', () {
      const client = Client(
        id: 10,
        name: 'Test',
        uuid: 'abc-123',
        isSynced: false,
      );

      final map = manager.toOdoo(client);

      expect(map.containsKey('uuid'), isFalse);
      expect(map.containsKey('isSynced'), isFalse);
      expect(map.containsKey('is_synced'), isFalse);
    });

    test('does not include id in output map', () {
      const client = Client(id: 10, name: 'Test');
      final map = manager.toOdoo(client);

      expect(map.containsKey('id'), isFalse);
    });

    test('includes is_company always', () {
      const company = Client(id: 1, name: 'T', isCompany: true);
      const person = Client(id: 2, name: 'T', isCompany: false);

      expect(manager.toOdoo(company)['is_company'], isTrue);
      // Generated toOdoo always includes is_company
      expect(manager.toOdoo(person)['is_company'], isFalse);
    });

    test('sends many2one as plain int (not [id, name])', () {
      const client = Client(
        id: 1,
        name: 'Test',
        countryId: 63,
        countryName: 'Ecuador',
        stateId: 1,
        stateName: 'Guayas',
        parentId: 5,
        parentName: 'Parent',
      );

      final map = manager.toOdoo(client);

      expect(map['country_id'], equals(63));
      expect(map['state_id'], equals(1));
      expect(map['parent_id'], equals(5));
      // Name fields are not sent to Odoo (they are read-only computed fields)
      expect(map.containsKey('country_name'), isFalse);
      expect(map.containsKey('state_name'), isFalse);
      expect(map.containsKey('parent_name'), isFalse);
    });
  });

  // ===========================================================================
  // 4. Record manipulation
  // ===========================================================================

  group('record manipulation', () {
    test('getId returns record.id', () {
      const client = Client(id: 42, name: 'Test');
      expect(manager.getId(client), equals(42));
    });

    test('getId returns 0 for unsaved records', () {
      const client = Client(id: 0, name: 'New Partner');
      expect(manager.getId(client), equals(0));
    });

    test('getUuid returns record.uuid', () {
      const client = Client(id: 1, name: 'Test', uuid: 'abc-def-123');
      expect(manager.getUuid(client), equals('abc-def-123'));
    });

    test('getUuid returns null when uuid is not set', () {
      const client = Client(id: 1, name: 'Test');
      expect(manager.getUuid(client), isNull);
    });

    test('withIdAndUuid creates copy with new id and uuid', () {
      const original = Client(
        id: 0,
        name: 'Offline Partner',
        uuid: 'temp-uuid',
        isSynced: false,
      );

      final updated = manager.withIdAndUuid(original, 42, 'final-uuid');

      expect(updated.id, equals(42));
      expect(updated.uuid, equals('final-uuid'));
      // Other fields preserved
      expect(updated.name, equals('Offline Partner'));
      expect(updated.isSynced, isFalse);
    });

    test('withIdAndUuid preserves all other fields', () {
      const original = Client(
        id: 0,
        name: 'Full Partner',
        vat: '1710034065',
        email: 'test@test.com',
        phone: '042000000',
        city: 'Guayaquil',
        countryId: 63,
        countryName: 'Ecuador',
        creditLimit: 5000.0,
        usePartnerCreditLimit: true,
        isCompany: true,
        active: true,
        uuid: 'old-uuid',
        isSynced: false,
      );

      final updated = manager.withIdAndUuid(original, 99, 'new-uuid');

      expect(updated.id, equals(99));
      expect(updated.uuid, equals('new-uuid'));
      expect(updated.name, equals('Full Partner'));
      expect(updated.vat, equals('1710034065'));
      expect(updated.email, equals('test@test.com'));
      expect(updated.phone, equals('042000000'));
      expect(updated.city, equals('Guayaquil'));
      expect(updated.countryId, equals(63));
      expect(updated.countryName, equals('Ecuador'));
      expect(updated.creditLimit, equals(5000.0));
      expect(updated.usePartnerCreditLimit, isTrue);
      expect(updated.isCompany, isTrue);
      expect(updated.active, isTrue);
      expect(updated.isSynced, isFalse);
    });

    test('withSyncStatus sets isSynced to true', () {
      const unsynced = Client(id: 1, name: 'Test', isSynced: false);
      final synced = manager.withSyncStatus(unsynced, true);

      expect(synced.isSynced, isTrue);
      expect(synced.id, equals(1));
      expect(synced.name, equals('Test'));
    });

    test('withSyncStatus sets isSynced to false', () {
      const synced = Client(id: 1, name: 'Test', isSynced: true);
      final unsynced = manager.withSyncStatus(synced, false);

      expect(unsynced.isSynced, isFalse);
      expect(unsynced.id, equals(1));
      expect(unsynced.name, equals('Test'));
    });

    test('withSyncStatus preserves all other fields', () {
      const original = Client(
        id: 10,
        name: 'Partner',
        vat: '0992345678001',
        uuid: 'some-uuid',
        isSynced: false,
        creditLimit: 3000.0,
      );

      final updated = manager.withSyncStatus(original, true);

      expect(updated.isSynced, isTrue);
      expect(updated.id, equals(10));
      expect(updated.name, equals('Partner'));
      expect(updated.vat, equals('0992345678001'));
      expect(updated.uuid, equals('some-uuid'));
      expect(updated.creditLimit, equals(3000.0));
    });
  });
}
