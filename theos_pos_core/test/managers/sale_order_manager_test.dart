import 'package:test/test.dart';
import 'package:theos_pos_core/src/models/sales/sale_order.model.dart';

void main() {
  late SaleOrderManager manager;

  setUp(() {
    manager = SaleOrderManager();
  });

  // ===========================================================================
  // 1. Metadata
  // ===========================================================================
  group('metadata', () {
    test('odooModel is sale.order', () {
      expect(manager.odooModel, equals('sale.order'));
    });

    test('tableName is sale_orders', () {
      expect(manager.tableName, equals('sale_orders'));
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
      expect(fields, contains('date_order'));
      expect(fields, contains('user_id'));
      expect(fields, contains('warehouse_id'));
      expect(fields, contains('pricelist_id'));
      expect(fields, contains('currency_id'));
      expect(fields, contains('payment_term_id'));
      expect(fields, contains('amount_untaxed'));
      expect(fields, contains('amount_tax'));
      expect(fields, contains('invoice_status'));
      expect(fields, contains('locked'));
    });

    test('odooFields does not contain many2one name-only fields', () {
      final fields = manager.odooFields;

      // Many2one name fields are extracted from the [id, name] tuple,
      // not requested separately
      expect(fields, isNot(contains('partner_name')));
      expect(fields, isNot(contains('user_name')));
      expect(fields, isNot(contains('team_name')));
      expect(fields, isNot(contains('company_name')));
      expect(fields, isNot(contains('warehouse_name')));
      expect(fields, isNot(contains('pricelist_name')));
      expect(fields, isNot(contains('payment_term_name')));
    });
  });

  // ===========================================================================
  // 2. fromOdoo
  // ===========================================================================
  group('fromOdoo', () {
    test('converts typical Odoo JSON with many2one fields', () {
      final odooData = <String, dynamic>{
        'id': 42,
        'name': 'SO042',
        'state': 'draft',
        'date_order': '2024-06-15 10:30:00',
        'partner_id': [10, 'Cliente Test'],
        'user_id': [2, 'Vendedor'],
        'team_id': [1, 'Equipo Ventas'],
        'company_id': [1, 'Mi Empresa'],
        'warehouse_id': [1, 'Bodega Principal'],
        'pricelist_id': [1, 'Lista Publica'],
        'currency_id': [2, 'USD'],
        'payment_term_id': [1, 'Inmediato'],
        'amount_untaxed': 100.0,
        'amount_tax': 15.0,
        'amount_total': 115.0,
        'invoice_status': 'no',
        'locked': false,
        'write_date': '2024-06-15 10:30:00',
      };

      final order = manager.fromOdoo(odooData);

      expect(order.id, equals(42));
      expect(order.name, equals('SO042'));
      expect(order.state, equals(SaleOrderState.draft));
      expect(order.dateOrder, isNotNull);
      expect(order.partnerId, equals(10));
      expect(order.partnerName, equals('Cliente Test'));
      expect(order.userId, equals(2));
      expect(order.userName, equals('Vendedor'));
      expect(order.teamId, equals(1));
      expect(order.teamName, equals('Equipo Ventas'));
      expect(order.companyId, equals(1));
      expect(order.companyName, equals('Mi Empresa'));
      expect(order.warehouseId, equals(1));
      expect(order.warehouseName, equals('Bodega Principal'));
      expect(order.pricelistId, equals(1));
      expect(order.pricelistName, equals('Lista Publica'));
      expect(order.currencyId, equals(2));
      expect(order.paymentTermId, equals(1));
      expect(order.paymentTermName, equals('Inmediato'));
      expect(order.amountUntaxed, equals(100.0));
      expect(order.amountTax, equals(15.0));
      expect(order.amountTotal, equals(115.0));
      expect(order.invoiceStatus, equals(InvoiceStatus.no));
      expect(order.locked, isFalse);
      expect(order.writeDate, isNotNull);
      // Generated fromOdoo sets isSynced to false (sync status managed separately)
      expect(order.isSynced, isFalse);
    });

    test('parses sale state correctly', () {
      final data = <String, dynamic>{
        'id': 1,
        'name': 'SO001',
        'state': 'sale',
      };
      final order = manager.fromOdoo(data);
      expect(order.state, equals(SaleOrderState.sale));
    });

    test('parses cancel state correctly', () {
      final data = <String, dynamic>{
        'id': 2,
        'name': 'SO002',
        'state': 'cancel',
      };
      final order = manager.fromOdoo(data);
      expect(order.state, equals(SaleOrderState.cancel));
    });

    test('parses waiting state correctly as waitingApproval', () {
      final data = <String, dynamic>{
        'id': 3,
        'name': 'SO003',
        'state': 'waiting',
      };
      final order = manager.fromOdoo(data);
      expect(order.state, equals(SaleOrderState.waitingApproval));
    });

    test('handles false/null many2one fields gracefully', () {
      final data = <String, dynamic>{
        'id': 5,
        'name': 'SO005',
        'state': 'draft',
        'partner_id': false,
        'user_id': false,
        'team_id': false,
        'warehouse_id': false,
      };
      final order = manager.fromOdoo(data);

      expect(order.id, equals(5));
      expect(order.partnerId, isNull);
      expect(order.userId, isNull);
      expect(order.teamId, isNull);
      expect(order.warehouseId, isNull);
    });

    test('handles missing optional fields with defaults', () {
      final data = <String, dynamic>{
        'id': 6,
        'name': 'SO006',
        'state': 'draft',
      };
      final order = manager.fromOdoo(data);

      expect(order.amountUntaxed, equals(0.0));
      expect(order.amountTax, equals(0.0));
      expect(order.amountTotal, equals(0.0));
      expect(order.locked, isFalse);
      expect(order.invoiceStatus, equals(InvoiceStatus.no));
    });

    test('parses invoice_status values correctly', () {
      final dataInvoiced = <String, dynamic>{
        'id': 7,
        'name': 'SO007',
        'state': 'sale',
        'invoice_status': 'invoiced',
      };
      expect(
        manager.fromOdoo(dataInvoiced).invoiceStatus,
        equals(InvoiceStatus.invoiced),
      );

      final dataToInvoice = <String, dynamic>{
        'id': 8,
        'name': 'SO008',
        'state': 'sale',
        'invoice_status': 'to invoice',
      };
      expect(
        manager.fromOdoo(dataToInvoice).invoiceStatus,
        equals(InvoiceStatus.toInvoice),
      );
    });
  });

  // ===========================================================================
  // 3. toOdoo
  // ===========================================================================
  group('toOdoo', () {
    test('converts SaleOrder to Odoo map with writable fields', () {
      const order = SaleOrder(
        id: 42,
        name: 'SO042',
        state: SaleOrderState.draft,
        partnerId: 10,
        userId: 2,
        teamId: 1,
        pricelistId: 1,
        paymentTermId: 1,
        note: 'Test note',
        clientOrderRef: 'REF-001',
      );

      final odooMap = manager.toOdoo(order);

      // toOdoo only sends writable fields (no id, name, state, amounts)
      expect(odooMap['partner_id'], equals(10));
      expect(odooMap['user_id'], equals(2));
      expect(odooMap['team_id'], equals(1));
      expect(odooMap['pricelist_id'], equals(1));
      expect(odooMap['payment_term_id'], equals(1));
      expect(odooMap['note'], equals('Test note'));
      expect(odooMap['client_order_ref'], equals('REF-001'));
    });

    test('includes all fields in Odoo map (null or not)', () {
      const order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.draft,
        partnerId: 10,
      );

      final odooMap = manager.toOdoo(order);

      expect(odooMap.containsKey('partner_id'), isTrue);
      expect(odooMap['partner_id'], equals(10));
      // Generated toOdoo includes all fields, even null ones
      expect(odooMap.containsKey('user_id'), isTrue);
      expect(odooMap['user_id'], isNull);
      expect(odooMap.containsKey('note'), isTrue);
      expect(odooMap['note'], isNull);
    });

    test('includes all writable fields in toOdoo output', () {
      const order = SaleOrder(
        id: 42,
        name: 'SO042',
        state: SaleOrderState.sale,
        partnerId: 10,
        amountUntaxed: 100.0,
        amountTax: 15.0,
        amountTotal: 115.0,
      );

      final odooMap = manager.toOdoo(order);

      // Generated toOdoo includes most fields (no 'id' key)
      expect(odooMap.containsKey('name'), isTrue);
      expect(odooMap.containsKey('state'), isTrue);
      expect(odooMap.containsKey('amount_untaxed'), isTrue);
      expect(odooMap.containsKey('amount_total'), isTrue);
      expect(odooMap.containsKey('partner_id'), isTrue);
    });

    test('formats date fields correctly for Odoo', () {
      final order = SaleOrder(
        id: 42,
        name: 'SO042',
        state: SaleOrderState.draft,
        partnerId: 10,
        validityDate: DateTime(2024, 12, 31),
        commitmentDate: DateTime(2024, 7, 15, 14, 0, 0),
      );

      final odooMap = manager.toOdoo(order);

      // validity_date should be date-only format
      expect(odooMap['validity_date'], isA<String>());
      expect(odooMap['validity_date'], contains('2024-12-31'));

      // commitment_date should include time
      expect(odooMap['commitment_date'], isA<String>());
    });
  });

  // ===========================================================================
  // 4. Record manipulation
  // ===========================================================================
  group('record manipulation', () {
    late SaleOrder sampleOrder;

    setUp(() {
      sampleOrder = const SaleOrder(
        id: 42,
        orderUuid: 'uuid-abc-123',
        name: 'SO042',
        state: SaleOrderState.draft,
        partnerId: 10,
        isSynced: false,
      );
    });

    test('getId returns record.id', () {
      expect(manager.getId(sampleOrder), equals(42));
    });

    test('getId returns 0 for new records', () {
      const newOrder = SaleOrder(
        id: 0,
        name: 'Nuevo',
        state: SaleOrderState.draft,
      );
      expect(manager.getId(newOrder), equals(0));
    });

    test('getUuid returns null (generated manager does not expose uuid)', () {
      expect(manager.getUuid(sampleOrder), isNull);
    });

    test('withIdAndUuid returns a copy with new id (uuid ignored)', () {
      final updated = manager.withIdAndUuid(sampleOrder, 99, 'new-uuid-456');

      expect(updated.id, equals(99));
      // Generated withIdAndUuid only sets id, preserves original orderUuid
      expect(updated.orderUuid, equals('uuid-abc-123'));
      // Other fields remain unchanged
      expect(updated.name, equals('SO042'));
      expect(updated.state, equals(SaleOrderState.draft));
      expect(updated.partnerId, equals(10));
    });

    test('withIdAndUuid does not mutate the original record', () {
      manager.withIdAndUuid(sampleOrder, 99, 'new-uuid-456');

      expect(sampleOrder.id, equals(42));
      expect(sampleOrder.orderUuid, equals('uuid-abc-123'));
    });

    test('withSyncStatus returns a copy with updated isSynced', () {
      expect(sampleOrder.isSynced, isFalse);

      final synced = manager.withSyncStatus(sampleOrder, true);
      expect(synced.isSynced, isTrue);
      // Other fields remain unchanged
      expect(synced.id, equals(42));
      expect(synced.orderUuid, equals('uuid-abc-123'));
      expect(synced.name, equals('SO042'));
    });

    test('withSyncStatus does not mutate the original record', () {
      manager.withSyncStatus(sampleOrder, true);

      expect(sampleOrder.isSynced, isFalse);
    });

    test('withSyncStatus can set synced to false', () {
      const syncedOrder = SaleOrder(
        id: 42,
        name: 'SO042',
        state: SaleOrderState.sale,
        isSynced: true,
      );

      final unsynced = manager.withSyncStatus(syncedOrder, false);
      expect(unsynced.isSynced, isFalse);
    });
  });
}
