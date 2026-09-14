/// Router entre el adaptador general de la cola offline
/// (`OdooOfflineOperationAdapter`, `../sales/sale_runtime_adapters.dart`) y
/// `EnvasesOfflineOperationAdapter`: `OperationsSyncJob` sólo acepta UN
/// `OfflineOperationAdapter`, así que quien compone la cola necesita algo que
/// decida cuál de los dos invocar por operación — exactamente lo que
/// `envases_offline_adapter.dart` deja explícito como responsabilidad de
/// quien integra (ver su docstring de cabecera).
///
/// Enruta por (modelo, método) exactos, no sólo por modelo: `stock.picking`
/// es el modelo de «dar por perdido», y una comprobación sólo por modelo
/// desviaría a Envases cualquier otra operación futura de ventas/almacén
/// que también use `stock.picking` con un método distinto.
library;

import 'package:odoo_sdk/odoo_sdk.dart' show ConflictInfo, OfflineOperation;

import '../sync/operations_sync_job.dart';
import 'envases_operations_durable.dart'
    show
        envasesEnvioMethod,
        envasesEnvioModel,
        envasesPerdidoMethod,
        envasesPerdidoModel,
        envasesRecepcionMethod,
        envasesRecepcionModel;

/// `envases` is typed as the interface, not the concrete
/// `EnvasesOfflineOperationAdapter`: this router only ever calls through
/// `OfflineOperationAdapter`, and depending on the interface (instead of a
/// `final class`, which cannot be faked from another library) is what lets
/// its own test double the routing decision without a live Odoo client.
final class EnvasesRoutingOfflineOperationAdapter
    implements OfflineOperationAdapter {
  const EnvasesRoutingOfflineOperationAdapter({
    required this.envases,
    required this.general,
  });

  final OfflineOperationAdapter envases;
  final OfflineOperationAdapter general;

  bool _isEnvases(OfflineOperation operation) =>
      (operation.model == envasesEnvioModel &&
          operation.method == envasesEnvioMethod) ||
      (operation.model == envasesRecepcionModel &&
          operation.method == envasesRecepcionMethod) ||
      (operation.model == envasesPerdidoModel &&
          operation.method == envasesPerdidoMethod);

  @override
  Future<OperationReconciliation> reconcile(OfflineOperation operation) =>
      _isEnvases(operation)
      ? envases.reconcile(operation)
      : general.reconcile(operation);

  @override
  Future<ConflictInfo?> dispatch(OfflineOperation operation) =>
      _isEnvases(operation)
      ? envases.dispatch(operation)
      : general.dispatch(operation);
}
