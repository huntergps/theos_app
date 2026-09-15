import 'dart:async';

import '../contracts.dart';

/// El `id` del `SyncJob` que drena la cola de operaciones offline
/// (`OperationsSyncJob.id`, en `operations_sync_job.dart`). Repetido aquí en
/// vez de importar ese archivo para no acoplar este disparador —agnóstico de
/// qué hay en la cola— al adaptador concreto de operaciones. Hay una prueba
/// (`sync_queued_operation_job_id_test.dart`) que falla si este valor se
/// desincroniza del `id` real.
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
/// nadie. Ninguno de los disparadores existentes mira la cola en sí:
/// reaccionan a filos de conectividad, a vencimientos de suscripción de
/// tiempo real o a avisos del servidor, nunca al hecho simple de "algo nuevo
/// entró a la cola y hay con quién hablar".
///
/// 🔴 Revisión del 14-sep-2026: la primera versión de esta clase reaccionaba
/// a SUBIDAS de un `Stream<int>` con el conteo total de pendientes
/// (`OfflineQueueDataSource.watchPendingOperationCount`, ya retirado). Se
/// descartó por un hueco medido: Drift junta en una sola notificación las
/// actualizaciones de tabla que ocurren dentro de la misma transacción, así
/// que si en la misma transacción sale una operación (se borra o cambia de
/// estado, por ejemplo porque el drenaje la resolvió) y entra una nueva, el
/// conteo total emite el MISMO número — la subida y la bajada se cancelan
/// antes de llegar al stream, y la operación nueva se queda sin disparar
/// nada. Por eso ahora escucha [queuedInserts]
/// (`OfflineQueueDataSource.watchQueuedInserts`): un evento por cada INSERT
/// de verdad en `offline_queue`, que nunca se cancela contra los borrados
/// simultáneos de esa misma transacción.
///
/// Cada emisión de [queuedInserts] mientras haya conexión (`online`)
/// (re)arma un `debounce` corto —para fundir varias inserciones seguidas,
/// una orden con varias líneas, por ejemplo, en un solo pedido— y al
/// vencer pide un único drenaje. Sin conexión no dispara nada: al
/// reconectar ya actúa `SyncAutoResyncTrigger` por su propio filo.
///
/// Pide sólo el trabajo de operaciones (`onlyJobIds: {syncQueuedOperationJobId}`),
/// nunca los catálogos: `SyncCoordinatorImpl.requestSync` junta los pedidos
/// que llegan durante un drenaje en curso, así que pedir de más aquí sería
/// inofensivo pero innecesario.
final class SyncQueuedOperationTrigger {
  SyncQueuedOperationTrigger({
    required this._coordinator,
    required Stream<void> queuedInserts,
    required Stream<bool> online,
    this.debounce = const Duration(milliseconds: 300),
  }) {
    _subscriptions.add(online.listen((value) => _online = value));
    _subscriptions.add(queuedInserts.listen((_) => _onInsert()));
  }

  final SyncCoordinator _coordinator;
  final Duration debounce;
  final List<StreamSubscription<void>> _subscriptions = [];
  bool _online = false;
  Timer? _pendingTimer;

  void _onInsert() {
    // Sin conexión esperamos al filo de `SyncAutoResyncTrigger` en vez de
    // duplicar esa lógica aquí — pedir un drenaje sin red no logra nada.
    if (!_online) return;
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
