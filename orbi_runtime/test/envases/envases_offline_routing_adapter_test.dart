import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/src/envases/envases_offline_routing_adapter.dart';
import 'package:orbi_runtime/src/envases/envases_operations_durable.dart';
import 'package:orbi_runtime/src/sync/operations_sync_job.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

final class _RecordingAdapter implements OfflineOperationAdapter {
  final List<String> reconciled = [];
  final List<String> dispatched = [];

  @override
  Future<OperationReconciliation> reconcile(OfflineOperation operation) async {
    reconciled.add('${operation.model}.${operation.method}');
    return const OperationNotApplied();
  }

  @override
  Future<ConflictInfo?> dispatch(OfflineOperation operation) async {
    dispatched.add('${operation.model}.${operation.method}');
    return null;
  }
}

OfflineOperation _operation({required String model, required String method}) => OfflineOperation(
  id: 1,
  model: model,
  method: method,
  values: const {},
  createdAt: DateTime.utc(2026, 9, 13),
  replayPolicy: OfflineReplayPolicy.manualAfterAmbiguous,
);

void main() {
  test('routes exactly the three envases (model, method) pairs to the envases adapter', () async {
    final envases = _RecordingAdapter();
    final general = _RecordingAdapter();
    // The real EnvasesOfflineOperationAdapter is only used as the static type
    // this router expects; routing itself never inspects its internals, so a
    // plain recording double proves the decision without a database/Odoo
    // client.
    final router = EnvasesRoutingOfflineOperationAdapter(
      envases: envases,
      general: general,
    );

    final envio = _operation(model: envasesEnvioModel, method: envasesEnvioMethod);
    final recepcion = _operation(model: envasesRecepcionModel, method: envasesRecepcionMethod);
    final perdido = _operation(model: envasesPerdidoModel, method: envasesPerdidoMethod);

    await router.dispatch(envio);
    await router.reconcile(envio);
    await router.dispatch(recepcion);
    await router.reconcile(recepcion);
    await router.dispatch(perdido);
    await router.reconcile(perdido);

    expect(envases.dispatched, [
      '$envasesEnvioModel.$envasesEnvioMethod',
      '$envasesRecepcionModel.$envasesRecepcionMethod',
      '$envasesPerdidoModel.$envasesPerdidoMethod',
    ]);
    expect(envases.reconciled.length, 3);
    expect(general.dispatched, isEmpty);
    expect(general.reconciled, isEmpty);
  });

  test('sends a sale operation to the general adapter, never to envases', () async {
    final envases = _RecordingAdapter();
    final general = _RecordingAdapter();
    final router = EnvasesRoutingOfflineOperationAdapter(
      envases: envases,
      general: general,
    );

    final saleOperation = _operation(model: 'sale.order', method: 'action_pos_confirm');
    await router.dispatch(saleOperation);
    await router.reconcile(saleOperation);

    expect(general.dispatched, ['sale.order.action_pos_confirm']);
    expect(general.reconciled, ['sale.order.action_pos_confirm']);
    expect(envases.dispatched, isEmpty);
    expect(envases.reconciled, isEmpty);
  });

  test(
    'a stock.picking operation with a DIFFERENT method than dar_por_perdido stays with the general adapter',
    () async {
      final envases = _RecordingAdapter();
      final general = _RecordingAdapter();
      final router = EnvasesRoutingOfflineOperationAdapter(
        envases: envases,
        general: general,
      );

      final otherPickingOp = _operation(model: 'stock.picking', method: 'button_validate');
      await router.dispatch(otherPickingOp);

      expect(general.dispatched, ['stock.picking.button_validate']);
      expect(envases.dispatched, isEmpty);
    },
  );
}
