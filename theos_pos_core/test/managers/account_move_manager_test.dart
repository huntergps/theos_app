import 'package:test/test.dart';
import 'package:theos_pos_core/src/models/invoices/account_move.model.dart';


void main() {
  late AccountMoveManager manager;

  setUp(() {
    manager = AccountMoveManager();
  });

  // ===========================================================================
  // 1. Metadata
  // ===========================================================================
  group('metadata', () {
    test('odooModel is account.move', () {
      expect(manager.odooModel, equals('account.move'));
    });

    test('tableName is account_moves', () {
      expect(manager.tableName, equals('account_moves'));
    });

    test('odooFields contains key fields', () {
      final fields = manager.odooFields;

      // Key fields that must be present for core functionality
      expect(fields, contains('id'));
      expect(fields, contains('name'));
      expect(fields, contains('state'));
      expect(fields, contains('partner_id'));
      expect(fields, contains('amount_total'));
      expect(fields, contains('write_date'));
      expect(fields, contains('move_type'));
      expect(fields, contains('payment_state'));
      expect(fields, contains('invoice_date'));
      expect(fields, contains('invoice_date_due'));
      expect(fields, contains('journal_id'));
      expect(fields, contains('company_id'));
      expect(fields, contains('currency_id'));
      expect(fields, contains('amount_untaxed'));
      expect(fields, contains('amount_tax'));
      expect(fields, contains('amount_residual'));
      expect(fields, contains('ref'));
      expect(fields, contains('partner_vat'));
    });

    test('odooFields contains Ecuador localization fields', () {
      final fields = manager.odooFields;

      expect(fields, contains('l10n_ec_authorization_number'));
      expect(fields, contains('l10n_latam_document_number'));
      expect(fields, contains('l10n_latam_document_type_id'));
    });
  });

  // ===========================================================================
  // 2. fromOdoo
  // ===========================================================================
  group('fromOdoo', () {
    test('converts typical Odoo JSON with many2one fields', () {
      final odooData = <String, dynamic>{
        'id': 100,
        'name': 'INV/2024/0001',
        'ref': 'SO042',
        'move_type': 'out_invoice',
        'state': 'posted',
        'payment_state': 'paid',
        'date': '2024-06-15',
        'invoice_date': '2024-06-15',
        'invoice_date_due': '2024-07-15',
        'partner_id': [10, 'Cliente Test'],
        'partner_vat': '0992345678001',
        'journal_id': [1, 'Diario de Ventas'],
        'company_id': [1, 'Mi Empresa'],
        'currency_id': [2, 'USD'],
        'amount_untaxed': 100.0,
        'amount_tax': 15.0,
        'amount_total': 115.0,
        'amount_residual': 0.0,
        'write_date': '2024-06-15 10:30:00',
      };

      final move = manager.fromOdoo(odooData);

      expect(move.id, equals(100));
      expect(move.name, equals('INV/2024/0001'));
      expect(move.ref, equals('SO042'));
      expect(move.moveType, equals('out_invoice'));
      expect(move.state, equals('posted'));
      expect(move.paymentState, equals('paid'));
      expect(move.date, isNotNull);
      expect(move.invoiceDate, isNotNull);
      expect(move.invoiceDateDue, isNotNull);
      expect(move.partnerId, equals(10));
      expect(move.partnerName, equals('Cliente Test'));
      expect(move.partnerVat, equals('0992345678001'));
      expect(move.journalId, equals(1));
      expect(move.journalName, equals('Diario de Ventas'));
      expect(move.companyId, equals(1));
      expect(move.currencyId, equals(2));
      expect(move.currencySymbol, equals('USD'));
      expect(move.amountUntaxed, equals(100.0));
      expect(move.amountTax, equals(15.0));
      expect(move.amountTotal, equals(115.0));
      expect(move.amountResidual, equals(0.0));
      expect(move.writeDate, isNotNull);
    });

    test('handles false/null many2one fields gracefully', () {
      final data = <String, dynamic>{
        'id': 5,
        'name': 'INV/005',
        'partner_id': false,
        'journal_id': false,
        'company_id': false,
        'currency_id': false,
        'partner_vat': false,
        'invoice_date': false,
        'invoice_date_due': false,
        'ref': false,
        'write_date': false,
      };

      final move = manager.fromOdoo(data);

      expect(move.id, equals(5));
      expect(move.partnerId, isNull);
      expect(move.partnerName, isNull);
      expect(move.journalId, isNull);
      expect(move.journalName, isNull);
      expect(move.companyId, isNull);
      expect(move.currencyId, isNull);
      expect(move.partnerVat, isNull);
      expect(move.invoiceDate, isNull);
      expect(move.invoiceDateDue, isNull);
      expect(move.ref, isNull);
    });

    test('handles missing optional fields with defaults', () {
      final data = <String, dynamic>{
        'id': 6,
        'name': 'INV/006',
      };

      final move = manager.fromOdoo(data);

      expect(move.amountUntaxed, equals(0.0));
      expect(move.amountTax, equals(0.0));
      expect(move.amountTotal, equals(0.0));
      expect(move.amountResidual, equals(0.0));
      // Generated fromOdoo defaults to empty string when field is missing
      expect(move.moveType, equals(''));
      expect(move.state, equals(''));
    });

    test('handles partner_id as integer (not Many2one)', () {
      final data = <String, dynamic>{
        'id': 7,
        'name': 'INV/007',
        'partner_id': 42,
      };

      final move = manager.fromOdoo(data);
      expect(move.partnerId, equals(42));
      expect(move.partnerName, isNull);
    });

    test('parses credit note move_type correctly', () {
      final data = <String, dynamic>{
        'id': 8,
        'name': 'RINV/2024/0001',
        'move_type': 'out_refund',
        'state': 'posted',
      };

      final move = manager.fromOdoo(data);
      expect(move.moveType, equals('out_refund'));
      expect(move.state, equals('posted'));
    });
  });

  // ===========================================================================
  // 3. toOdoo
  // ===========================================================================
  group('toOdoo', () {
    test('converts AccountMove to Odoo map with writable fields', () {
      final move = AccountMove(
        id: 100,
        name: 'INV/2024/0001',
        moveType: 'out_invoice',
        partnerId: 10,
        invoiceDate: DateTime(2024, 6, 15),
        invoiceDateDue: DateTime(2024, 7, 15),
      );

      final odooMap = manager.toOdoo(move);

      expect(odooMap['name'], equals('INV/2024/0001'));
      expect(odooMap['move_type'], equals('out_invoice'));
      expect(odooMap['partner_id'], equals(10));
      expect(odooMap['invoice_date'], isA<String>());
      expect(odooMap['invoice_date'], contains('2024-06-15'));
      expect(odooMap['invoice_date_due'], isA<String>());
      expect(odooMap['invoice_date_due'], contains('2024-07-15'));
    });

    test('includes all fields in Odoo map (null date fields included)', () {
      const move = AccountMove(
        id: 1,
        name: 'INV/001',
        moveType: 'out_invoice',
        partnerId: 10,
      );

      final odooMap = manager.toOdoo(move);

      expect(odooMap.containsKey('name'), isTrue);
      expect(odooMap.containsKey('move_type'), isTrue);
      expect(odooMap.containsKey('partner_id'), isTrue);
      // Generated toOdoo includes all fields, even null ones
      expect(odooMap.containsKey('invoice_date'), isTrue);
      expect(odooMap.containsKey('invoice_date_due'), isTrue);
    });

    test('includes all fields in toOdoo output', () {
      const move = AccountMove(
        id: 100,
        name: 'INV/2024/0001',
        moveType: 'out_invoice',
        state: 'posted',
        partnerId: 10,
        amountUntaxed: 100.0,
        amountTax: 15.0,
        amountTotal: 115.0,
        amountResidual: 0.0,
      );

      final odooMap = manager.toOdoo(move);

      // Generated toOdoo includes all fields
      expect(odooMap.containsKey('name'), isTrue);
      expect(odooMap.containsKey('state'), isTrue);
      expect(odooMap.containsKey('amount_untaxed'), isTrue);
      expect(odooMap.containsKey('amount_total'), isTrue);
      expect(odooMap.containsKey('partner_id'), isTrue);
    });
  });

  // ===========================================================================
  // 4. Record manipulation
  // ===========================================================================
  group('record manipulation', () {
    late AccountMove sampleMove;

    setUp(() {
      sampleMove = const AccountMove(
        id: 100,
        name: 'INV/2024/0001',
        moveType: 'out_invoice',
        state: 'posted',
        partnerId: 10,
        partnerName: 'Cliente Test',
        amountTotal: 115.0,
      );
    });

    test('getId returns record.id', () {
      expect(manager.getId(sampleMove), equals(100));
    });

    test('getId returns 0 for new records', () {
      const newMove = AccountMove(
        id: 0,
        name: '',
        moveType: 'out_invoice',
      );
      expect(manager.getId(newMove), equals(0));
    });

    test('getUuid always returns null (invoices have no UUID)', () {
      expect(manager.getUuid(sampleMove), isNull);
    });

    test('getUuid returns null for any record', () {
      const anotherMove = AccountMove(
        id: 200,
        name: 'INV/2024/0002',
      );
      expect(manager.getUuid(anotherMove), isNull);
    });

    test('withIdAndUuid returns a copy with new id, ignores uuid', () {
      final updated = manager.withIdAndUuid(sampleMove, 999, 'some-uuid');

      expect(updated.id, equals(999));
      // Other fields remain unchanged
      expect(updated.name, equals('INV/2024/0001'));
      expect(updated.moveType, equals('out_invoice'));
      expect(updated.state, equals('posted'));
      expect(updated.partnerId, equals(10));
      expect(updated.partnerName, equals('Cliente Test'));
      expect(updated.amountTotal, equals(115.0));
    });

    test('withIdAndUuid does not mutate the original record', () {
      manager.withIdAndUuid(sampleMove, 999, 'some-uuid');

      expect(sampleMove.id, equals(100));
    });

    test('withSyncStatus returns the same record (no isSynced field)', () {
      final result = manager.withSyncStatus(sampleMove, true);

      expect(result.id, equals(sampleMove.id));
      expect(result.name, equals(sampleMove.name));
      expect(result.moveType, equals(sampleMove.moveType));
      expect(result.state, equals(sampleMove.state));
      expect(result.partnerId, equals(sampleMove.partnerId));
      expect(result.amountTotal, equals(sampleMove.amountTotal));
    });

    test('withSyncStatus with false also returns same record', () {
      final result = manager.withSyncStatus(sampleMove, false);

      expect(result.id, equals(sampleMove.id));
      expect(result.name, equals(sampleMove.name));
    });

    test('readLocalByUuid throws when no database is initialized', () async {
      expect(
        () => manager.readLocalByUuid('any-uuid'),
        throwsStateError,
      );
    });

    test('readLocalByUuid throws for empty string too', () async {
      expect(
        () => manager.readLocalByUuid(''),
        throwsStateError,
      );
    });
  });
}
