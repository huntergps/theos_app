import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/features/sales/services/sale_confirmation_contract.dart';

void main() {
  test('accepts only confirmation of the requested order', () {
    for (final state in ['sale', 'done']) {
      requireConfirmedSaleResponse({
        'success': true,
        'order_id': 42,
        'state': state,
      }, orderId: 42);
    }
  });

  test('business rejection is not successful HTTP confirmation', () {
    expect(
      () => requireConfirmedSaleResponse({
        'success': false,
        'error': 'Requiere aprobación de crédito',
      }, orderId: 42),
      throwsA(isA<StateError>()),
    );
  });

  test('pending actions, states and malformed responses fail closed', () {
    for (final response in <dynamic>[
      null,
      true,
      {
        'type': 'ir.actions.act_window',
        'res_model': 'credit.limit.exceeded.wizard',
      },
      {'success': true, 'order_id': 42, 'state': 'approved'},
      {'success': true, 'order_id': 42, 'state': 'waiting'},
      {'success': true, 'order_id': 43, 'state': 'sale'},
      {'success': true, 'state': 'sale'},
    ]) {
      expect(
        () => requireConfirmedSaleResponse(response, orderId: 42),
        throwsA(isA<StateError>()),
      );
    }
  });

  test('preserves a valid pending approval action', () {
    final action = <String, dynamic>{
      'type': 'ir.actions.act_window',
      'res_model': 'credit.limit.exceeded.wizard',
      'context': {'default_sale_order_id': 42, 'default_mode': 'credit'},
    };

    final result = readPendingSaleApprovalAction({
      'approval_required': true,
      'success': false,
      'order_id': 42,
      'state': 'waiting',
      'action': action,
    }, orderId: 42);

    expect(result, equals(action));
    expect(
      () => result!['new_key'] = 'must fail',
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('returns null for an ordinary rejection', () {
    expect(
      readPendingSaleApprovalAction({
        'approval_required': false,
        'success': false,
        'error': 'Requiere aprobación comercial',
      }, orderId: 42),
      isNull,
    );
  });

  test(
    'rejects pending approval with wrong order, state, success or action',
    () {
      final action = <String, dynamic>{
        'type': 'ir.actions.act_window',
        'res_model': 'credit.limit.exceeded.wizard',
        'context': {'default_sale_order_id': 42},
      };
      final cases = <Map<String, dynamic>>[
        {
          'approval_required': true,
          'success': false,
          'order_id': 43,
          'state': 'waiting',
          'action': action,
        },
        {
          'approval_required': true,
          'success': false,
          'order_id': 42,
          'state': 'sale',
          'action': action,
        },
        {
          'approval_required': true,
          'success': true,
          'order_id': 42,
          'state': 'approved',
          'action': action,
        },
        {
          'approval_required': true,
          'success': false,
          'order_id': 42,
          'state': 'approved',
        },
        {
          'approval_required': true,
          'success': false,
          'order_id': 42,
          'state': 'approved',
          'action': {
            'type': 'ir.actions.act_window',
            'res_model': 'credit.limit.exceeded.wizard',
          },
        },
      ];

      for (final response in cases) {
        expect(
          () => readPendingSaleApprovalAction(response, orderId: 42),
          throwsA(isA<StateError>()),
        );
      }
    },
  );

  test('rejects a credit wizard action belonging to another order', () {
    expect(
      () => readPendingSaleApprovalAction({
        'approval_required': true,
        'success': false,
        'order_id': 42,
        'state': 'approved',
        'action': {
          'type': 'ir.actions.act_window',
          'res_model': 'credit.limit.exceeded.wizard',
          'context': {'default_sale_order_id': 43},
        },
      }, orderId: 42),
      throwsA(isA<StateError>()),
    );
  });
}
