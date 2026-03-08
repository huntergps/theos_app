import 'package:test/test.dart';
import 'package:theos_pos_core/src/models/sales/sale_order.model.dart';

void main() {
  group('SaleOrderState - Labels', () {
    test('each state has a non-empty label', () {
      for (final state in SaleOrderState.values) {
        expect(state.label, isNotEmpty, reason: '$state should have a label');
      }
    });

    test('draft label is Cotización', () {
      expect(SaleOrderState.draft.label, equals('Cotización'));
    });

    test('sale label is Orden de venta', () {
      expect(SaleOrderState.sale.label, equals('Orden de venta'));
    });

    test('cancel label is Cancelado', () {
      expect(SaleOrderState.cancel.label, equals('Cancelado'));
    });
  });

  group('SaleOrderState - toOdooString', () {
    test('draft maps to "draft"', () {
      expect(SaleOrderState.draft.toOdooString(), equals('draft'));
    });

    test('waitingApproval maps to "waiting"', () {
      expect(SaleOrderState.waitingApproval.toOdooString(), equals('waiting'));
    });

    test('sale maps to "sale"', () {
      expect(SaleOrderState.sale.toOdooString(), equals('sale'));
    });

    test('all states produce non-empty strings', () {
      for (final state in SaleOrderState.values) {
        expect(state.toOdooString(), isNotEmpty);
      }
    });
  });

  group('SaleOrderStateExtension - fromString', () {
    test('parses English state names', () {
      expect(SaleOrderStateExtension.fromString('draft'), equals(SaleOrderState.draft));
      expect(SaleOrderStateExtension.fromString('sent'), equals(SaleOrderState.sent));
      expect(SaleOrderStateExtension.fromString('sale'), equals(SaleOrderState.sale));
      expect(SaleOrderStateExtension.fromString('cancel'), equals(SaleOrderState.cancel));
      expect(SaleOrderStateExtension.fromString('done'), equals(SaleOrderState.done));
      expect(SaleOrderStateExtension.fromString('approved'), equals(SaleOrderState.approved));
      expect(SaleOrderStateExtension.fromString('rejected'), equals(SaleOrderState.rejected));
    });

    test('parses Spanish state names', () {
      expect(SaleOrderStateExtension.fromString('cotización'), equals(SaleOrderState.draft));
      expect(SaleOrderStateExtension.fromString('cotizacion'), equals(SaleOrderState.draft));
      expect(SaleOrderStateExtension.fromString('enviado'), equals(SaleOrderState.sent));
      expect(SaleOrderStateExtension.fromString('cancelado'), equals(SaleOrderState.cancel));
      expect(SaleOrderStateExtension.fromString('aprobado'), equals(SaleOrderState.approved));
      expect(SaleOrderStateExtension.fromString('rechazado'), equals(SaleOrderState.rejected));
    });

    test('parses waiting_approval variants', () {
      expect(SaleOrderStateExtension.fromString('waiting'), equals(SaleOrderState.waitingApproval));
      expect(SaleOrderStateExtension.fromString('waiting_approval'), equals(SaleOrderState.waitingApproval));
      expect(SaleOrderStateExtension.fromString('esperando aprobación'), equals(SaleOrderState.waitingApproval));
    });

    test('null defaults to draft', () {
      expect(SaleOrderStateExtension.fromString(null), equals(SaleOrderState.draft));
    });

    test('false defaults to draft', () {
      expect(SaleOrderStateExtension.fromString(false), equals(SaleOrderState.draft));
    });

    test('unknown string defaults to draft', () {
      expect(SaleOrderStateExtension.fromString('unknown_state'), equals(SaleOrderState.draft));
    });

    test('case insensitive parsing', () {
      expect(SaleOrderStateExtension.fromString('DRAFT'), equals(SaleOrderState.draft));
      expect(SaleOrderStateExtension.fromString('Sale'), equals(SaleOrderState.sale));
      expect(SaleOrderStateExtension.fromString('CANCEL'), equals(SaleOrderState.cancel));
    });

    test('roundtrip: toOdooString -> fromString', () {
      for (final state in SaleOrderState.values) {
        final odooStr = state.toOdooString();
        final parsed = SaleOrderStateExtension.fromString(odooStr);
        expect(parsed, equals(state), reason: '$state -> "$odooStr" should roundtrip');
      }
    });
  });
}
