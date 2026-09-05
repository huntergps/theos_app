import 'package:test/test.dart';
import 'package:theos_pos_core/src/models/advances/advance.model.dart';
import 'package:theos_pos_core/src/models/company/company.model.dart';
import 'package:theos_pos_core/src/models/prices/pricelist.model.dart';

void main() {
  group('ERP2 field contracts', () {
    test('company manager uses current ERP2 names only', () {
      final fields = companyManager.odooFields;

      expect(fields, contains('pedir_datos_consumidor_final'));
      expect(fields, isNot(contains('pedir_end_customer_data')));
      expect(fields, isNot(contains('reservation_warehouse_id')));
      expect(Company.odooFields, contains('pedir_datos_consumidor_final'));
      expect(Company.odooFields, isNot(contains('pedir_end_customer_data')));
      expect(Company.odooFields, isNot(contains('reservation_warehouse_id')));
    });

    test('company parser maps the current end-customer flag', () {
      final company = companyManager.fromOdoo({
        'id': 1,
        'name': 'ERP2',
        'pedir_datos_consumidor_final': true,
      });

      expect(company.pedirEndCustomerData, isTrue);
      expect(company.reservationWarehouseId, isNull);
    });

    test('advance line keeps derived journal type local', () {
      final manager = AdvanceLineManager();

      expect(manager.odooFields, isNot(contains('journal_type')));
      expect(
        manager.toOdoo(
          const AdvanceLine(
            id: 1,
            journalId: 2,
            journalType: 'cash',
            amount: 10,
          ),
        ),
        isNot(contains('journal_type')),
      );
    });

    test('pricelist item keeps ERP2-removed fields local', () {
      expect(pricelistItemManager.odooFields, isNot(contains('sequence')));
      expect(pricelistItemManager.odooFields, isNot(contains('uom_id')));

      final item = pricelistItemManager.fromOdoo({
        'id': 7,
        'pricelist_id': [3, 'Public Pricelist'],
        'applied_on': '3_global',
        'compute_price': 'fixed',
        'base': 'list_price',
      });

      expect(item.id, 7);
      expect(item.pricelistId, 3);
      expect(item.sequence, 5);
      expect(item.uomId, isNull);
    });
  });
}
