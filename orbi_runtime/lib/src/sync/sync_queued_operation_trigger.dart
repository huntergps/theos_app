import 'dart:async';

import '../contracts.dart';

/// El `id` del `SyncJob` que drena la cola de operaciones offline
/// (`OperationsSyncJob.id`, en `operations_sync_job.dart`). Repetido aquí en
/// vez de importar ese archivo para no acoplar este disparador —agnóstico de
/// qué hay en la cola— al adaptador concreto de operaciones.
const syncQueuedOperationJobId = 'operations';

/// Drena la cola de operaciones offline apenas se encola algo ESTANDO EN
/// LÍNEA, sin esperar el próximo filo de conectividad/primer plano
/// (`SyncAutoResyncTrigger`) ni el respaldo periódico de 5 minutos
/// (`SyncPeriodicBackupTrigger`, que además se desarma con tiempo real
/// vivo).
///
/// Falla medida el 14-sep-2026 (Orbi web contra Odoo real, "Conectado" y
/// "Tiempo real: conectado" ambos verdes): un envío y una recepción de
/// envases quedaron en la cola offline "En espera, Intentos: 0" hasta que la
/// persona pulsó "Sincronizar todo" a mano. Causa raíz: los productores
/// (`DurableEnvasesOperations`, los de cobros, presencia y preferencias)
/// siempre encolan primero —offline-first, por diseño— y
/// `OfflineQueueDataSource.queueOperation` es un INSERT que no avisa a
/// nadie. Ninguno de los disparadores existentes mira el TAMAÑO de la cola:
/// reaccionan a filos de conectividad, a vencimientos de suscripción de
/// tiempo real o a avisos del servidor, nunca al hecho simple de "algo nuevo
/// entró a la cola y hay con quién hablar".
///
/// Reacciona a SUBIDAS de [pendingCount] (el conteo total de operaciones
/// pendientes en la cola, ver
/// `OfflineQueueDataSource.watchPendingOperationCount` en
/// `theos_pos_core`) mientras haya conexión (`online`), con un `debounce`
/// corto para fundir varias subidas seguidas —una orden con varias
/// líneas, por ejemplo— en un solo pedido. El primer valor que llega de
/// [pendingCount] nunca cuenta como subida: sólo fija la línea base, igual
/// que el primer valor de una señal en `SyncAutoResyncTrigger` nunca cuenta
/// como filo.
///
/// El conteo IGUAL o MENOR nunca dispara nada —así un reintento que falla y
/// deja la operación en la misma cola (el conteo no cambia) no entra en
/// bucle pidiendo sync sin parar—, y sin conexión tampoco: al reconectar ya
/// actúa `SyncAutoResyncTrigger` por su propio filo.
///
/// Pide sólo el trabajo de operaciones (`onlyJobIds: {syncQueuedOperationJobId}`),
/// nunca los catálogos: `SyncCoordinatorImpl.requestSync` junta los pedidos
/// que llegan durante un drenaje en curso, así que pedir de más aquí sería
/// inofensivo pero innecesario.
final class SyncQueuedOperationTrigger {
  SyncQueuedOperationTrigger({
    required this._coordinator,
    required Stream<int> pendingCount,
    required Stream<bool> online,
    this.debounce = const Duration(milliseconds: 300),
  }) {
    _subscriptions.add(online.listen((value) => _online = value));
    _subscriptions.add(pendingCount.listen(_onCount));
  }

  final SyncCoordinator _coordinator;
  final Duration debounce;
  final List<StreamSubscription<void>> _subscriptions = [];
  bool _online = false;
  int? _lastCount;
  Timer? _pendingTimer;

  void _onCount(int value) {
    final previous = _lastCount;
    _lastCount = value;
    // Primer valor: sólo fija la línea base, nunca dispara. Igual o menor
    // que el anterior: nada que drenar de más (o ya se está resolviendo
    // solo), tampoco dispara. Sin conexión, esperamos al filo de
    // `SyncAutoResyncTrigger` en vez de duplicar esa lógica aquí.
    if (previous == null || value <= previous || !_online) return;
    _pendingTimer?.cancel();
    _pendingTimer = Timer(debounce, () {
      unawaited(
        _coordinator.requestSync(
          SyncReason(
            'queued_operation',
            onlyJobIds: {syncQueuedOperationJobId},
          ),
        ),
      );
    });
  }

  Future<void> dispose() async {
    _pendingTimer?.cancel();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
  }
}
