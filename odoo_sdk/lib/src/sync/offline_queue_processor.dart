/// Offline Queue Processor (Generic)
///
/// Orchestrates processing of queued offline operations with progress
/// events, retry backoff, and optional audit logging.
library;

import 'dart:async';

import 'offline_queue_types.dart';
import 'sync_types.dart';

/// Result of a processed operation.
class OfflineOperationResult {
  final SyncOperationStatus status;
  final ConflictInfo? conflict;
  final int? odooId;
  final String? errorMessage;

  const OfflineOperationResult({
    required this.status,
    this.conflict,
    this.odooId,
    this.errorMessage,
  });

  const OfflineOperationResult.success({int? odooId})
      : this(
          status: SyncOperationStatus.success,
          odooId: odooId,
        );

  const OfflineOperationResult.conflict(ConflictInfo conflict)
      : this(
          status: SyncOperationStatus.conflict,
          conflict: conflict,
        );

  const OfflineOperationResult.skipped({String? errorMessage})
      : this(
          status: SyncOperationStatus.skipped,
          errorMessage: errorMessage,
        );
}

/// Handler for processing a single offline operation.
typedef OfflineOperationHandler =
    Future<ConflictInfo?> Function(OfflineOperation op);

/// Audit logger for sync operations.
abstract class OfflineQueueAuditLogger {
  Future<void> logOperation(
    OfflineOperation op, {
    required String result, // success, conflict, skipped, error
    int? odooId,
    String? errorMessage,
  });
}

/// Processor for offline queue operations.
///
/// Orchestrates the processing of queued offline operations with support for
/// progress tracking, conflict detection, retry management, and optional
/// audit logging.
///
/// ## Usage
///
/// ```dart
/// final processor = OfflineQueueProcessor(
///   queue: myQueueStore,
///   handler: (op) async {
///     // Process operation with Odoo
///     await odooClient.call(model: op.model, method: op.method, ...);
///     return null; // No conflict
///   },
///   auditLogger: myAuditLogger,
/// );
///
/// // Listen to progress
/// processor.progressStream.listen((event) {
///   print('Progress: ${event.current}/${event.total}');
/// });
///
/// // Process queue
/// final result = await processor.processQueue();
/// print('Synced: ${result.synced}, Failed: ${result.failed}');
///
/// // Cleanup
/// processor.dispose();
/// ```
class OfflineQueueProcessor {
  final OfflineQueueStore _queue;
  final OfflineOperationHandler _handler;
  final OfflineQueueAuditLogger? _auditLogger;
  final bool _removeOnSuccess;
  final bool _removeOnConflict;
  final bool _removeOnSkipped;

  final _progressController =
      StreamController<SyncProgressEvent>.broadcast();

  /// Mutex de PROCESO (compartido por TODAS las instancias de
  /// [OfflineQueueProcessor], no solo por instancia).
  ///
  /// Por qué es necesario incluso con `markOperationProcessing`: el patrón
  /// "SELECT snapshot, después marcar" no es atómico. Si dos llamadas a
  /// [processQueue] arrancan en el mismo tick de Dart (ej. dos instancias de
  /// `OfflineSyncService` — una porque `ref.invalidate(offlineSyncServiceProvider)`
  /// se disparó mientras la sync anterior seguía en curso), AMBAS pueden
  /// completar su `getPendingOperations()` ANTES de que cualquiera alcance a
  /// marcar una sola fila como 'processing' — el filtro de status no
  /// protege un snapshot que ya fue tomado. Este lock serializa TODAS las
  /// llamadas a processQueue() del proceso, cerrando esa ventana por
  /// completo (en vez de depender de una condición de carrera favorable).
  static Future<void> _globalLock = Future.value();

  /// Creates a new [OfflineQueueProcessor].
  ///
  /// [queue] The queue store to read pending operations from.
  /// [handler] Function to process each operation. Returns [ConflictInfo] if
  ///   a conflict is detected, or null on success.
  /// [auditLogger] Optional logger for recording sync results.
  /// [removeOnSuccess] Whether to remove operations after successful sync.
  ///   Defaults to true.
  /// [removeOnConflict] Whether to remove operations that result in conflicts.
  ///   Defaults to false (keeps them for manual resolution).
  /// [removeOnSkipped] Whether to remove skipped operations.
  ///   Defaults to false.
  OfflineQueueProcessor({
    required OfflineQueueStore queue,
    required OfflineOperationHandler handler,
    OfflineQueueAuditLogger? auditLogger,
    bool removeOnSuccess = true,
    bool removeOnConflict = false,
    bool removeOnSkipped = false,
  })  : _queue = queue,
        _handler = handler,
        _auditLogger = auditLogger,
        _removeOnSuccess = removeOnSuccess,
        _removeOnConflict = removeOnConflict,
        _removeOnSkipped = removeOnSkipped;

  /// Stream of progress events emitted during queue processing.
  ///
  /// Each [SyncProgressEvent] contains the current operation index, total count,
  /// and status. Subscribe before calling [processQueue] to receive all events.
  Stream<SyncProgressEvent> get progressStream => _progressController.stream;

  /// Releases resources used by this processor.
  ///
  /// Closes the [progressStream]. After calling dispose, this processor
  /// should not be used again.
  void dispose() {
    _progressController.close();
  }

  /// Processes all pending operations in the queue.
  ///
  /// Iterates through each pending operation, calls the [handler] to process it,
  /// and emits progress events. Operations are removed from the queue based on
  /// the configured removal policies.
  ///
  /// [operations] Optional list of operations to process. If null, fetches
  ///   pending operations from the queue store.
  ///
  /// Returns a [QueueProcessResult] with counts of synced, failed, skipped
  /// operations, any errors, and detected conflicts.
  ///
  /// Serializado vía [_globalLock] contra CUALQUIER otra llamada a
  /// processQueue() en el proceso (de esta u otra instancia) — ver doc de
  /// [_globalLock].
  Future<QueueProcessResult> processQueue({
    List<OfflineOperation>? operations,
  }) {
    return runExclusive(() => _processQueueLocked(operations));
  }

  /// Ejecuta [action] bajo el mismo lock global de proceso que usa
  /// [processQueue] (ver [_globalLock]).
  ///
  /// Útil para OTROS caminos de despacho que no pasan por
  /// [OfflineQueueProcessor] pero necesitan la MISMA exclusión mutua para no
  /// despachar una operación en paralelo con una llamada a [processQueue] en
  /// curso (de esta u otra instancia). Caso concreto (Fase B, tarea 4): el
  /// despacho directo de una orden puntual en
  /// `OfflineSyncService._processSaleOrderQueueInternal`, que tiene su
  /// propio loop y no usa [OfflineQueueProcessor] — envolverlo con
  /// [runExclusive] cierra esa brecha sin reescribir su lógica de
  /// reintentos/errores.
  static Future<T> runExclusive<T>(Future<T> Function() action) async {
    final previousLock = _globalLock;
    final releaseLock = Completer<void>();
    _globalLock = releaseLock.future;
    await previousLock;
    try {
      return await action();
    } finally {
      releaseLock.complete();
    }
  }

  /// Cuerpo real de [processQueue], ejecutado bajo [_globalLock].
  Future<QueueProcessResult> _processQueueLocked(
    List<OfflineOperation>? operations,
  ) async {
    final ops = operations ?? await _queue.getPendingOperations();
    if (ops.isEmpty) {
      return QueueProcessResult.empty;
    }

    // Sort operations by dependency order:
    // 1. Priority (lower value = higher priority: critical=0, high=1, normal=2, low=3)
    // 2. Parents before children (parentOrderId == null first)
    // 3. Creates before writes before deletes
    // 4. FIFO within same group (by createdAt)
    ops.sort((a, b) {
      // 1. Priority
      final priorityCompare = a.priority.compareTo(b.priority);
      if (priorityCompare != 0) return priorityCompare;

      // 2. Parents first
      final aIsParent = a.parentOrderId == null ? 0 : 1;
      final bIsParent = b.parentOrderId == null ? 0 : 1;
      final parentCompare = aIsParent.compareTo(bIsParent);
      if (parentCompare != 0) return parentCompare;

      // 3. Operation order: create < write < unlink
      final methodOrder = _methodSortOrder(a.method)
          .compareTo(_methodSortOrder(b.method));
      if (methodOrder != 0) return methodOrder;

      // 4. FIFO
      return a.createdAt.compareTo(b.createdAt);
    });

    // Reclama TODO el batch como 'processing' de inmediato, ANTES de
    // procesar ninguna operación.
    //
    // Antes esto se hacía una por una, adentro del loop principal, justo
    // antes de llamar al handler de cada operación. Eso dejaba una ventana
    // enorme abierta: la operación #10 de un batch de 20 seguía en
    // 'pending' (visible para getPendingOperations) mientras se procesaban
    // las 9 anteriores — si esas 9 incluían llamadas HTTP lentas, una
    // segunda llamada concurrente a processQueue() (ej. tras invalidar
    // offlineSyncServiceProvider mientras la primera sigue en curso) podía
    // tomar esa misma operación #10 y despacharla en paralelo.
    //
    // Marcando todo el batch de una vez, apenas después del snapshot, esa
    // ventana se reduce al mínimo posible con este diseño (snapshot + marca
    // en un datasource sin "claim" atómico tipo UPDATE...RETURNING).
    for (final op in ops) {
      await _queue.markOperationProcessing(op.id);
    }

    int success = 0;
    int failed = 0;
    int skipped = 0;
    final errors = <String>[];
    final conflicts = <ConflictInfo>[];

    final totalOps = ops.length;
    var currentIndex = 0;

    for (final op in ops) {
      currentIndex++;

      _progressController.add(
        SyncProgressEvent(
          operationId: op.id,
          current: currentIndex,
          total: totalOps,
          status: SyncOperationStatus.processing,
        ),
      );

      // La operación ya fue marcada 'processing' en el paso de reclamo de
      // todo el batch (ver arriba). Startup recovery en database.dart
      // resetea 'processing' → 'pending' en cada apertura de la app, así
      // que cualquier fila huérfana por un crash se auto-sana sola.

      try {
        final conflict = await _handler(op);
        if (conflict != null) {
          conflicts.add(conflict);
          await _auditLogger?.logOperation(
            op,
            result: 'conflict',
          );
          if (_removeOnConflict) {
            await _queue.removeOperation(op.id);
          } else {
            // La operación se queda en la cola para resolución manual, pero
            // debe volver a 'pending' — si se queda en 'processing', el
            // filtro de status en getPendingOperations() la esconde para
            // siempre y nunca vuelve a aparecer en la UI de conflictos.
            await _queue.markOperationPending(op.id);
          }
          _progressController.add(
            SyncProgressEvent(
              operationId: op.id,
              current: currentIndex,
              total: totalOps,
              status: SyncOperationStatus.conflict,
            ),
          );
        } else {
          await _auditLogger?.logOperation(
            op,
            result: 'success',
          );
          if (_removeOnSuccess) {
            await _queue.removeOperation(op.id);
          }
          success++;
          _progressController.add(
            SyncProgressEvent(
              operationId: op.id,
              current: currentIndex,
              total: totalOps,
              status: SyncOperationStatus.success,
            ),
          );
        }
      } on OperationSkippedException catch (e) {
        skipped++;
        await _auditLogger?.logOperation(
          op,
          result: 'skipped',
          errorMessage: e.toString(),
        );
        if (_removeOnSkipped) {
          await _queue.removeOperation(op.id);
        } else {
          // Igual que en el caso de conflicto: si no se remueve, debe volver
          // a 'pending' para no quedar invisible para siempre.
          await _queue.markOperationPending(op.id);
        }
        _progressController.add(
          SyncProgressEvent(
            operationId: op.id,
            current: currentIndex,
            total: totalOps,
            status: SyncOperationStatus.skipped,
            error: e.toString(),
          ),
        );
      } catch (e) {
        failed++;
        final errorMsg = 'Op ${op.id} (${op.model}.${op.method}): $e';
        errors.add(errorMsg);
        // markOperationFailed() debe dejar la operación en status='pending'
        // (con el backoff ya programado vía nextRetryAt) — de lo contrario
        // se queda en 'processing' para siempre y el filtro de status la
        // esconde de getPendingOperations() en el próximo ciclo.
        await _queue.markOperationFailed(op.id, e.toString());
        await _auditLogger?.logOperation(
          op,
          result: 'error',
          errorMessage: e.toString(),
        );
        _progressController.add(
          SyncProgressEvent(
            operationId: op.id,
            current: currentIndex,
            total: totalOps,
            status: SyncOperationStatus.failed,
            error: e.toString(),
          ),
        );
      }
    }

    return QueueProcessResult(
      synced: success,
      failed: failed,
      skipped: skipped,
      errors: errors,
      conflicts: conflicts,
    );
  }

  /// Sort order for operation methods: create=0, write=1, unlink=2.
  static int _methodSortOrder(String method) {
    return switch (method) {
      'create' => 0,
      'write' => 1,
      'unlink' => 2,
      _ => 1, // default to write-level
    };
  }
}
