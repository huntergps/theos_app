import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

void main() {
  test('button_validate is complete only after server state is done', () async {
    final done = await interpretWarehouseValidationResponse(
      true,
      readState: () async => [
        {'id': 7, 'state': 'done'},
      ],
    );
    expect(done.state, WarehouseValidationState.completed);

    final assigned = await interpretWarehouseValidationResponse(
      true,
      readState: () async => [
        {'id': 7, 'state': 'assigned'},
      ],
    );
    expect(assigned.state, WarehouseValidationState.rejected);

    final rejected = await interpretWarehouseValidationResponse(
      false,
      readState: () async => throw StateError('must not read after rejection'),
    );
    expect(rejected.state, WarehouseValidationState.rejected);
  });

  test('unknown action is never treated as completed', () async {
    final result = await interpretWarehouseValidationResponse(const {
      'type': 'ir.actions.act_window',
      'res_model': 'stock.picking',
    }, readState: () async => throw StateError('must not read unknown action'));
    expect(result.state, WarehouseValidationState.rejected);
  });

  test('backorder resolution rechecks the warehouse capability', () async {
    final port = RuntimeWarehouseOperationPort(
      runtime: SessionRuntime(),
      capabilities: CapabilitySnapshot(
        scopeKey: 'scope',
        companyId: 1,
        revision: 1,
        fetchedAt: DateTime.utc(2026),
        permissions: const [],
      ),
    );
    final result = await port.resolveBackorder(
      pending: const WarehouseValidationResult(
        state: WarehouseValidationState.backorderRequired,
        message: 'backorder',
        action: {'res_id': 12},
      ),
      confirm: true,
    );
    expect(result.state, WarehouseValidationState.rejected);
    expect(result.message, contains('Autoridad insuficiente'));
  });
}
