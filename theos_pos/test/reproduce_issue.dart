import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

void main() {
  group('SaleOrderState Mapping', () {
    test('fromString maps correctly', () {
      expect(SaleOrderStateExtension.fromString('draft'), SaleOrderState.draft);
      expect(SaleOrderStateExtension.fromString('sent'), SaleOrderState.sent);
      expect(
        SaleOrderStateExtension.fromString('waiting_approval'),
        SaleOrderState.waitingApproval,
      );
      expect(
        SaleOrderStateExtension.fromString('approved'),
        SaleOrderState.approved,
      );
      expect(SaleOrderStateExtension.fromString('sale'), SaleOrderState.sale);
      expect(SaleOrderStateExtension.fromString('done'), SaleOrderState.done);
      expect(
        SaleOrderStateExtension.fromString('cancel'),
        SaleOrderState.cancel,
      );
    });

    test('fromString handles case sensitivity and unknown values', () {
      expect(
        SaleOrderStateExtension.fromString('Approved'),
        SaleOrderState.approved,
        reason: 'Should handle case mismatch',
      );
      expect(
        SaleOrderStateExtension.fromString('aprobado'),
        SaleOrderState.approved,
        reason: 'Should handle Spanish',
      );
      expect(
        SaleOrderStateExtension.fromString('unknown'),
        SaleOrderState.draft,
      );
      expect(SaleOrderStateExtension.fromString(null), SaleOrderState.draft);
    });
  });

  group('SaleOrder.fromOdoo', () {
    test('parses state correctly', () {
      final data = {
        'id': 30,
        'name': 'SO0030',
        'state': 'approved',
        'date_order': '2023-11-30 10:00:00',
        'amount_total': 100.0,
      };
      final order = saleOrderManager.fromOdoo(data);
      expect(order.state, SaleOrderState.approved);
    });

    test('parses state with unknown value', () {
      final data = {
        'id': 30,
        'name': 'SO0030',
        'state': 'Approved', // Capitalized
        'date_order': '2023-11-30 10:00:00',
        'amount_total': 100.0,
      };
      final order = saleOrderManager.fromOdoo(data);
      expect(order.state, SaleOrderState.approved);
    });
  });
}
