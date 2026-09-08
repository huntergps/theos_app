/// Offline Queue Processor (Generic)
///
/// Orchestrates processing of queued offline operations with progress
/// events, retry backoff, and optional audit logging.
library;

import 'dart:async';

import '../utils/security_utils.dart';
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
    : this(status: SyncOperationStatus.success, odooId: odooId);

  const OfflineOperationResult.conflict(ConflictInfo conflict)
    : this(status: SyncOperationStatus.conflict, conflict: conflict);

  const OfflineOperationResult.skipped({String? errorMessage})
    : this(status: SyncOperationStatus.skipped, errorMessage: errorMessage);
}

/// Handler for processing a single offline operation.
typedef OfflineOperationHandler = Future<ConflictInfo?> Function(
  OfflineOperation op,
);

/// Signals a transient/authentication failure that must retain the durable
/// operation for a later session instead of sending it to dead-letter.
final class RetryableOfflineOperationException implements Exception {
  const RetryableOfflineOperationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Audit logger for sync operations.
abstract class OfflineQueueAuditLogger {
  Future<void> logOperation(
    OfflineOperation op, {
    required String result, // success, conflict, skipped, error
    int? odooId,
    String? errorMessage,
  });

  /// Persists the actionable conflict details before the queue row is held.
  Future<void> logConflict(OfflineOperation op, ConflictInfo conflict) {
    return logOperation(op, result: 'conflict');
  }
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

  final _progressController = StreamController<SyncProgressEvent>.broadcast();
  Future<QueueProcessResult>? _activeRun;
  bool _shutdownRequested = false;
  bool _disposed = false;

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
  }) : _queue = queue,
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
    unawaited(shutdown());
  }

  /// Stops accepting work and waits until the current queue writer is idle.
  Future<void> shutdown() async {
    _shutdownRequested = true;
    final active = _activeRun;
    if (active != null) {
      try {
        await active;
      } catch (_) {
        // The caller that started the run owns its error/result.
      }
    }
    if (!_disposed) {
      _disposed = true;
      await _progressController.close();
    }
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
    if (_shutdownRequested || _disposed) {
      return Future<QueueProcessResult>.error(
        StateError('OfflineQueueProcessor is shutting down'),
      );
    }
    final current = _activeRun;
    if (current != null) return current;

    final run = runExclusive(() => _processQueueLocked(operations));
    _activeRun = run;
    run.then(
      (_) {
        if (identical(_activeRun, run)) _activeRun = null;
      },
      onError: (Object _, StackTrace _) {
        if (identical(_activeRun, run)) _activeRun = null;
      },
    );
    return run;
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
    final source = operations ?? await _queue.getPendingOperations();
    final ops = source
        .where(
          (operation) =>
              operation.isReadyForRetry &&
              !operation.hasExceededMaxRetries &&
              operation.status != OfflineOperationStatus.processing &&
              operation.status != OfflineOperationStatus.completed &&
              operation.status != OfflineOperationStatus.deadLetter &&
              operation.status != OfflineOperationStatus.conflict,
        )
        .toList();
    if (ops.isEmpty) {
      return QueueProcessResult.empty;
    }

    // Sort by dependency before priority. A high-priority payment cannot run
    // before the normal-priority order/line it references.
    ops.sort((a, b) {
      final dependencyCompare = _dependencySortOrder(a)
          .compareTo(_dependencySortOrder(b));
      if (dependencyCompare != 0) return dependencyCompare;

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
    final claimed = <int>[];
    try {
      for (final op in ops) {
        await _queue.markOperationProcessing(op.id);
        claimed.add(op.id);
      }
    } catch (_) {
      for (final id in claimed) {
        await _queue.markOperationPending(id);
      }
      rethrow;
    }

    int success = 0;
    int failed = 0;
    int skipped = 0;
    final errors = <String>[];
    final conflicts = <ConflictInfo>[];
    final blockedDependencyKeys = <String>{};

    final totalOps = ops.length;
    var currentIndex = 0;

    for (final op in ops) {
      currentIndex++;

      _emitProgress(
        SyncProgressEvent(
          operationId: op.id,
          current: currentIndex,
          total: totalOps,
          status: SyncOperationStatus.processing,
        ),
      );

      // La operación ya fue marcada 'processing' en el paso de reclamo de
      // todo el batch (ver arriba). Startup recovery la mueve a
      // 'recovery_pending'; solo se reenvía automáticamente cuando existe
      // un contrato de reconciliación/idempotencia verificable.

      final currentOp = await _queue.getOperationById(op.id) ?? op;
      final dependencyKeys = {
        ..._dependencyKeys(op),
        ..._dependencyKeys(currentOp),
      };

      if (op.status == OfflineOperationStatus.recoveryPending &&
          currentOp.replayPolicy == OfflineReplayPolicy.manualAfterAmbiguous) {
        final message = _safeErrorMessage(
          'Recovered an operation after an interrupted dispatch without a '
          'server reconciliation contract. Manual review is required.',
        );
        failed++;
        blockedDependencyKeys.addAll(dependencyKeys);
        errors.add('Op ${currentOp.id} requires manual reconciliation');
        await _queue.markOperationDeadLetter(currentOp.id, message);
        await _auditLogger?.logOperation(
          currentOp,
          result: 'dead_letter',
          errorMessage: message,
        );
        _emitProgress(
          SyncProgressEvent(
            operationId: currentOp.id,
            current: currentIndex,
            total: totalOps,
            status: SyncOperationStatus.failed,
            error: message,
          ),
        );
        continue;
      }

      // The whole batch is claimed before dispatch to prevent concurrent
      // processors from taking later rows. If a parent/order step fails, its
      // already-claimed dependants must be released back to pending without
      // invoking their handlers or consuming a retry. Sorting alone cannot
      // provide this guarantee.
      if (dependencyKeys.any(blockedDependencyKeys.contains)) {
        skipped++;
        const message =
            'Dependency was not synchronized; operation remains pending.';
        await _queue.markOperationPending(currentOp.id);
        await _auditLogger?.logOperation(
          currentOp,
          result: 'dependency_blocked',
          errorMessage: message,
        );
        _emitProgress(
          SyncProgressEvent(
            operationId: currentOp.id,
            current: currentIndex,
            total: totalOps,
            status: SyncOperationStatus.skipped,
            error: message,
          ),
        );
        continue;
      }

      try {
        final conflict = await _handler(currentOp);
        if (conflict != null) {
          conflicts.add(conflict);
          blockedDependencyKeys.addAll(dependencyKeys);
          await _auditLogger?.logConflict(currentOp, conflict);
          if (_removeOnConflict) {
            await _queue.removeOperation(currentOp.id);
          } else {
            await _queue.markOperationConflict(currentOp.id);
          }
          _emitProgress(
            SyncProgressEvent(
              operationId: currentOp.id,
              current: currentIndex,
              total: totalOps,
              status: SyncOperationStatus.conflict,
            ),
          );
        } else {
          await _auditLogger?.logOperation(currentOp, result: 'success');
          if (_removeOnSuccess) {
            await _queue.removeOperation(currentOp.id);
          } else {
            await _queue.markOperationCompleted(currentOp.id);
          }
          success++;
          _emitProgress(
            SyncProgressEvent(
              operationId: currentOp.id,
              current: currentIndex,
              total: totalOps,
              status: SyncOperationStatus.success,
            ),
          );
        }
      } on RetryableOfflineOperationException catch (e) {
        failed++;
        blockedDependencyKeys.addAll(dependencyKeys);
        final message = _safeErrorMessage(e.message);
        errors.add('Op ${currentOp.id}: $message');
        await _queue.markOperationFailed(currentOp.id, message);
        await _auditLogger?.logOperation(
          currentOp,
          result: 'retryable_error',
          errorMessage: message,
        );
        _emitProgress(
          SyncProgressEvent(
            operationId: currentOp.id,
            current: currentIndex,
            total: totalOps,
            status: SyncOperationStatus.failed,
            error: message,
          ),
        );
      } on OperationSkippedException catch (e) {
        skipped++;
        final message = _safeErrorMessage(e.toString());
        await _auditLogger?.logOperation(
          currentOp,
          result: 'skipped',
          errorMessage: message,
        );
        if (_removeOnSkipped) {
          await _queue.removeOperation(currentOp.id);
        } else {
          await _queue.markOperationCompleted(currentOp.id);
        }
        _emitProgress(
          SyncProgressEvent(
            operationId: currentOp.id,
            current: currentIndex,
            total: totalOps,
            status: SyncOperationStatus.skipped,
            error: message,
          ),
        );
      } catch (e) {
        failed++;
        blockedDependencyKeys.addAll(dependencyKeys);
        final safeException = _safeErrorMessage(e.toString());
        final errorMsg =
            'Op ${currentOp.id} (${currentOp.model}.${currentOp.method}): '
            '$safeException';
        errors.add(errorMsg);
        final manualReconciliation =
            currentOp.replayPolicy == OfflineReplayPolicy.manualAfterAmbiguous;
        if (manualReconciliation) {
          await _queue.markOperationDeadLetter(currentOp.id, safeException);
        } else {
          await _queue.markOperationFailed(currentOp.id, safeException);
        }
        await _auditLogger?.logOperation(
          currentOp,
          result: manualReconciliation ? 'dead_letter' : 'error',
          errorMessage: safeException,
        );
        _emitProgress(
          SyncProgressEvent(
            operationId: currentOp.id,
            current: currentIndex,
            total: totalOps,
            status: SyncOperationStatus.failed,
            error: safeException,
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

  static int _dependencySortOrder(OfflineOperation operation) {
    if (operation.method ==
            OfflineLocalCommand.sessionCreateAndOpen.storageName ||
        operation.method == OfflineLocalCommand.sessionOpen.storageName ||
        (operation.model == 'res.partner' &&
            (operation.method == 'create' ||
                operation.method ==
                    OfflineLocalCommand.partnerCreate.storageName))) {
      return 0;
    }
    if (operation.model == 'sale.order' && operation.method == 'create') {
      return 10;
    }
    if (operation.model == 'sale.order.line') {
      return 20;
    }
    if (operation.model == 'sale.order' &&
        (operation.method == OfflineLocalCommand.orderConfirm.storageName ||
            operation.method.contains('confirm'))) {
      return 30;
    }
    if (operation.method ==
        OfflineLocalCommand.paymentWizardApply.storageName) {
      return 35;
    }
    if (operation.model == 'account.payment' ||
        operation.model == 'account.move' ||
        operation.method == OfflineLocalCommand.paymentCreate.storageName ||
        operation.method ==
            OfflineLocalCommand.invoiceCreateWithPayments.storageName ||
        operation.method.contains('invoice') ||
        operation.method.contains('payment')) {
      return 40;
    }
    if (operation.method ==
            OfflineLocalCommand.sessionClosingControl.storageName ||
        operation.method == OfflineLocalCommand.sessionClose.storageName) {
      return 50;
    }
    return 25;
  }

  /// Stable aliases that tie an order workflow together while its local
  /// negative ID is progressively replaced by the remote ID.
  ///
  /// Both the pre-claim snapshot and the refetched operation contribute
  /// keys. This is intentional: a successful parent handler can rewrite a
  /// child's `parentOrderId` from -10 to 42, while later operations in the
  /// same batch may still reference -10.
  static Set<String> _dependencyKeys(OfflineOperation operation) {
    final keys = <String>{};
    void addModelRecordId(Object? value) {
      if (value is num) {
        keys.add('record:${operation.model}:${value.toInt()}');
      }
    }

    // Generic create -> action/write chains (advances, cash-outs, etc.).
    addModelRecordId(operation.recordId);
    addModelRecordId(operation.values['local_id']);
    addModelRecordId(operation.values['id']);

    void addPartnerId(Object? value) {
      if (value is num) keys.add('partner-id:${value.toInt()}');
    }

    if (operation.model == 'res.partner') {
      addPartnerId(operation.recordId);
      addPartnerId(operation.values['local_id']);
    }
    addPartnerId(operation.values['partner_id']);

    void addSessionId(Object? value) {
      if (value is num) keys.add('session-id:${value.toInt()}');
    }

    if (operation.model == 'collection.session') {
      addSessionId(operation.recordId);
      addSessionId(operation.values['local_id']);
    }
    addSessionId(operation.values['collection_session_id']);

    final isOrderWorkflow =
        operation.model == 'sale.order' ||
        operation.model == 'sale.order.line' ||
        operation.model == 'account.payment' ||
        operation.model == 'account.move' ||
        operation.method == OfflineLocalCommand.orderConfirm.storageName ||
        operation.method ==
            OfflineLocalCommand.paymentWizardApply.storageName ||
        operation.method ==
            OfflineLocalCommand.invoiceCreateWithPayments.storageName ||
        operation.method == OfflineLocalCommand.paymentCreate.storageName;
    if (!isOrderWorkflow) return keys;

    void addId(Object? value) {
      if (value is int) keys.add('order-id:$value');
      if (value is num) keys.add('order-id:${value.toInt()}');
    }

    void addUuid(Object? value) {
      if (value is String && value.trim().isNotEmpty) {
        keys.add('order-uuid:${value.trim()}');
      }
    }

    addId(operation.parentOrderId);
    if (operation.model == 'sale.order') {
      addId(operation.recordId);
      addId(operation.values['local_id']);
      addUuid(operation.values['uuid']);
    }
    addId(operation.values['parent_order_id']);
    addId(operation.values['sale_id']);
    addId(operation.values['order_id']);
    addUuid(operation.values['order_uuid']);
    addUuid(operation.values['sale_order_uuid']);
    return keys;
  }

  void _emitProgress(SyncProgressEvent event) {
    if (!_progressController.isClosed) {
      _progressController.add(event);
    }
  }

  static String _safeErrorMessage(String message) {
    final sanitized = ErrorSanitizer.sanitize(message);
    const maxLength = 2000;
    return sanitized.length <= maxLength
        ? sanitized
        : '${sanitized.substring(0, maxLength)}…';
  }
}
