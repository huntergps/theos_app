import 'package:test/test.dart';
import 'package:theos_pos_core/src/models/sales/sale_order_line.model.dart';

void main() {
  late SaleOrderLineManager manager;

  setUp(() {
    manager = SaleOrderLineManager();
  });

  // ===========================================================================
  // 1. Metadata
  // ===========================================================================
  group('metadata', () {
    test('odooModel is sale.order.line', () {
      expect(manager.odooModel, equals('sale.order.line'));
    });

    test('tableName is sale_order_lines', () {
      expect(manager.tableName, equals('sale_order_lines'));
    });

    test('odooFields contains key fields for core functionality', () {
      final fields = manager.odooFields;

      expect(fields, contains('id'));
      expect(fields, contains('order_id'));
      expect(fields, contains('sequence'));
      expect(fields, contains('display_type'));
      expect(fields, contains('is_downpayment'));
      expect(fields, contains('product_id'));
      expect(fields, contains('product_template_id'));
      expect(fields, contains('product_type'));
      expect(fields, contains('categ_id'));
      expect(fields, contains('name'));
      expect(fields, contains('product_uom_qty'));
      expect(fields, contains('product_uom_id'));
      expect(fields, contains('price_unit'));
      expect(fields, contains('discount'));
      expect(fields, contains('discount_amount'));
      expect(fields, contains('price_subtotal'));
      expect(fields, contains('price_tax'));
      expect(fields, contains('price_total'));
      expect(fields, contains('price_reduce_taxexcl'));
      expect(fields, contains('tax_ids'));
      expect(fields, contains('qty_delivered'));
      expect(fields, contains('customer_lead'));
      expect(fields, contains('qty_invoiced'));
      expect(fields, contains('qty_to_invoice'));
      expect(fields, contains('invoice_status'));
      expect(fields, contains('state'));
      expect(fields, contains('collapse_prices'));
      expect(fields, contains('collapse_composition'));
      expect(fields, contains('is_optional'));
      expect(fields, contains('write_date'));
    });

    test('odooFields is a hardcoded list (not from OdooFieldRegistry)', () {
      final fields = manager.odooFields;
      // Verify it is a concrete List<String> with known length
      expect(fields, isA<List<String>>());
      expect(fields.length, greaterThanOrEqualTo(28));
    });
  });

  // ===========================================================================
  // 2. fromOdoo
  // ===========================================================================
  group('fromOdoo', () {
    test('converts typical Odoo JSON with many2one and many2many fields', () {
      final odooData = <String, dynamic>{
        'id': 1,
        'x_uuid': 'uuid-abc-123',
        'order_id': [42, 'SO042'],
        'sequence': 10,
        'display_type': false,
        'is_downpayment': false,
        'product_id': [5, 'Laptop HP'],
        'product_default_code': 'LAP001',
        'product_template_id': [10, 'Template'],
        'product_type': 'consu',
        'categ_id': [1, 'Electronicos'],
        'name': '[LAP001] Laptop HP',
        'product_uom_qty': 2.0,
        'product_uom_id': [1, 'Unidades'],
        'price_unit': 999.99,
        'discount': 10.0,
        'discount_amount': 199.998,
        'price_subtotal': 1799.98,
        'price_tax': 269.99,
        'price_total': 2069.97,
        'price_reduce_taxexcl': 899.99,
        'tax_ids': [1, 2],
        'qty_delivered': 0.0,
        'customer_lead': 0.0,
        'qty_invoiced': 0.0,
        'qty_to_invoice': 2.0,
        'invoice_status': 'to invoice',
        'state': 'draft',
        'collapse_prices': false,
        'collapse_composition': false,
        'write_date': '2024-06-15 10:30:00',
      };

      final line = manager.fromOdoo(odooData);

      expect(line.id, equals(1));
      // lineUuid is a local-only field not populated by generated fromOdoo
      expect(line.orderId, equals(42));
      expect(line.sequence, equals(10));
      expect(line.displayType, equals(LineDisplayType.product));
      expect(line.isDownpayment, isFalse);
      expect(line.productId, equals(5));
      expect(line.productName, equals('Laptop HP'));
      expect(line.productCode, equals('LAP001'));
      expect(line.productTemplateId, equals(10));
      expect(line.productType, equals('consu'));
      expect(line.categId, equals(1));
      expect(line.categName, equals('Electronicos'));
      // name is preserved as-is from Odoo
      expect(line.name, equals('[LAP001] Laptop HP'));
      expect(line.productUomQty, equals(2.0));
      expect(line.productUomId, equals(1));
      expect(line.productUomName, equals('Unidades'));
      expect(line.priceUnit, equals(999.99));
      expect(line.discount, equals(10.0));
      expect(line.discountAmount, equals(199.998));
      expect(line.priceSubtotal, equals(1799.98));
      expect(line.priceTax, equals(269.99));
      expect(line.priceTotal, equals(2069.97));
      expect(line.priceReduce, equals(899.99));
      expect(line.qtyDelivered, equals(0.0));
      expect(line.customerLead, equals(0.0));
      expect(line.qtyInvoiced, equals(0.0));
      expect(line.qtyToInvoice, equals(2.0));
      expect(line.invoiceStatus, equals(LineInvoiceStatus.toInvoice));
      expect(line.orderState, equals('draft'));
      expect(line.collapsePrices, isFalse);
      expect(line.collapseComposition, isFalse);
      expect(line.writeDate, isNotNull);
      // Generated fromOdoo sets isSynced to false (sync status managed separately)
      expect(line.isSynced, isFalse);
    });

    test('parses display_type line_section correctly', () {
      final data = <String, dynamic>{
        'id': 2,
        'order_id': [42, 'SO042'],
        'name': 'Section Title',
        'display_type': 'line_section',
      };
      final line = manager.fromOdoo(data);
      expect(line.displayType, equals(LineDisplayType.lineSection));
    });

    test('parses display_type line_note correctly', () {
      final data = <String, dynamic>{
        'id': 3,
        'order_id': [42, 'SO042'],
        'name': 'A note',
        'display_type': 'line_note',
      };
      final line = manager.fromOdoo(data);
      expect(line.displayType, equals(LineDisplayType.lineNote));
    });

    test('parses display_type line_subsection correctly', () {
      final data = <String, dynamic>{
        'id': 4,
        'order_id': [42, 'SO042'],
        'name': 'Subsection',
        'display_type': 'line_subsection',
      };
      final line = manager.fromOdoo(data);
      expect(line.displayType, equals(LineDisplayType.lineSubsection));
    });

    test('handles false/null many2one fields gracefully', () {
      final data = <String, dynamic>{
        'id': 5,
        'order_id': false,
        'name': 'Line without relations',
        'display_type': false,
        'product_id': false,
        'product_template_id': false,
        'categ_id': false,
        'product_uom_id': false,
        'x_uuid': false,
        'product_default_code': false,
        'product_type': false,
      };
      final line = manager.fromOdoo(data);

      expect(line.id, equals(5));
      expect(line.orderId, equals(0));
      expect(line.productId, isNull);
      expect(line.productName, isNull);
      expect(line.productCode, isNull);
      expect(line.productTemplateId, isNull);
      expect(line.categId, isNull);
      expect(line.categName, isNull);
      expect(line.productUomId, isNull);
      expect(line.productUomName, isNull);
      expect(line.lineUuid, isNull);
      expect(line.productType, isNull);
    });

    test('handles missing optional fields with defaults', () {
      final data = <String, dynamic>{
        'id': 6,
        'order_id': [1, 'SO001'],
        'name': 'Minimal line',
      };
      final line = manager.fromOdoo(data);

      expect(line.sequence, equals(0));
      expect(line.displayType, equals(LineDisplayType.product));
      expect(line.isDownpayment, isFalse);
      expect(line.productUomQty, equals(0.0));
      expect(line.priceUnit, equals(0.0));
      expect(line.discount, equals(0.0));
      expect(line.discountAmount, equals(0.0));
      expect(line.priceSubtotal, equals(0.0));
      expect(line.priceTax, equals(0.0));
      expect(line.priceTotal, equals(0.0));
      expect(line.qtyDelivered, equals(0.0));
      expect(line.qtyInvoiced, equals(0.0));
      expect(line.qtyToInvoice, equals(0.0));
      expect(line.collapsePrices, isFalse);
      expect(line.collapseComposition, isFalse);
    });

    test('parses invoice_status values correctly', () {
      final dataToInvoice = <String, dynamic>{
        'id': 7,
        'order_id': [1, 'SO001'],
        'name': 'Line',
        'invoice_status': 'to invoice',
      };
      expect(
        manager.fromOdoo(dataToInvoice).invoiceStatus,
        equals(LineInvoiceStatus.toInvoice),
      );

      final dataInvoiced = <String, dynamic>{
        'id': 8,
        'order_id': [1, 'SO001'],
        'name': 'Line',
        'invoice_status': 'invoiced',
      };
      expect(
        manager.fromOdoo(dataInvoiced).invoiceStatus,
        equals(LineInvoiceStatus.invoiced),
      );

      final dataNo = <String, dynamic>{
        'id': 9,
        'order_id': [1, 'SO001'],
        'name': 'Line',
        'invoice_status': 'no',
      };
      expect(
        manager.fromOdoo(dataNo).invoiceStatus,
        equals(LineInvoiceStatus.no),
      );

      final dataUpselling = <String, dynamic>{
        'id': 10,
        'order_id': [1, 'SO001'],
        'name': 'Line',
        'invoice_status': 'upselling',
      };
      expect(
        manager.fromOdoo(dataUpselling).invoiceStatus,
        equals(LineInvoiceStatus.upselling),
      );
    });

    test('preserves name field as-is (no bracket stripping)', () {
      final data = <String, dynamic>{
        'id': 11,
        'order_id': [1, 'SO001'],
        'name': '[HER0049] AMPERIMETRO DE GANCHO DIGITAL',
      };
      final line = manager.fromOdoo(data);
      // Generated fromOdoo uses parseOdooStringRequired which preserves the name
      expect(line.name, equals('[HER0049] AMPERIMETRO DE GANCHO DIGITAL'));
    });

    test('extracts product name from many2one as-is', () {
      final data = <String, dynamic>{
        'id': 12,
        'order_id': [1, 'SO001'],
        'name': 'Test',
        'product_id': [5, '[LAP001] Laptop HP'],
      };
      final line = manager.fromOdoo(data);
      // extractMany2oneName returns the name as-is (no bracket stripping)
      expect(line.productName, equals('[LAP001] Laptop HP'));
    });

    test('parses is_downpayment correctly', () {
      final data = <String, dynamic>{
        'id': 13,
        'order_id': [1, 'SO001'],
        'name': 'Down payment',
        'is_downpayment': true,
      };
      final line = manager.fromOdoo(data);
      expect(line.isDownpayment, isTrue);
    });

    test('parses collapse_prices and collapse_composition correctly', () {
      final data = <String, dynamic>{
        'id': 14,
        'order_id': [1, 'SO001'],
        'name': 'Section',
        'display_type': 'line_section',
        'collapse_prices': true,
        'collapse_composition': true,
      };
      final line = manager.fromOdoo(data);
      expect(line.collapsePrices, isTrue);
      expect(line.collapseComposition, isTrue);
    });
  });

  // ===========================================================================
  // 3. Record manipulation
  // ===========================================================================
  group('record manipulation', () {
    late SaleOrderLine sampleLine;

    setUp(() {
      sampleLine = const SaleOrderLine(
        id: 1,
        lineUuid: 'uuid-abc-123',
        orderId: 42,
        sequence: 10,
        name: 'Laptop HP',
        productUomQty: 2.0,
        priceUnit: 999.99,
        isSynced: false,
      );
    });

    test('getId returns record.id', () {
      expect(manager.getId(sampleLine), equals(1));
    });

    test('getId returns 0 for new records', () {
      const newLine = SaleOrderLine(
        id: 0,
        orderId: 42,
        name: 'New line',
      );
      expect(manager.getId(newLine), equals(0));
    });

    test('getUuid returns null (generated manager does not expose uuid)', () {
      expect(manager.getUuid(sampleLine), isNull);
    });

    test('withIdAndUuid returns a copy with new id (uuid ignored)', () {
      final updated = manager.withIdAndUuid(sampleLine, 99, 'new-uuid-456');

      expect(updated.id, equals(99));
      // Generated withIdAndUuid only sets id, preserves original lineUuid
      expect(updated.lineUuid, equals('uuid-abc-123'));
      // Other fields remain unchanged
      expect(updated.orderId, equals(42));
      expect(updated.name, equals('Laptop HP'));
      expect(updated.productUomQty, equals(2.0));
      expect(updated.priceUnit, equals(999.99));
    });

    test('withIdAndUuid does not mutate the original record', () {
      manager.withIdAndUuid(sampleLine, 99, 'new-uuid-456');

      expect(sampleLine.id, equals(1));
      expect(sampleLine.lineUuid, equals('uuid-abc-123'));
    });

    test('withSyncStatus returns a copy with updated isSynced', () {
      expect(sampleLine.isSynced, isFalse);

      final synced = manager.withSyncStatus(sampleLine, true);
      expect(synced.isSynced, isTrue);
      // Other fields remain unchanged
      expect(synced.id, equals(1));
      expect(synced.orderId, equals(42));
      expect(synced.name, equals('Laptop HP'));
    });

    test('withSyncStatus does not mutate the original record', () {
      manager.withSyncStatus(sampleLine, true);

      expect(sampleLine.isSynced, isFalse);
    });

    test('withSyncStatus can set synced to false', () {
      const syncedLine = SaleOrderLine(
        id: 1,
        orderId: 42,
        name: 'Synced line',
        isSynced: true,
      );

      final unsynced = manager.withSyncStatus(syncedLine, false);
      expect(unsynced.isSynced, isFalse);
    });
  });
}
