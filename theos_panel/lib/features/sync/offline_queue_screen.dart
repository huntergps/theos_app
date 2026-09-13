import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:orbi_runtime/orbi_runtime.dart' show OfflineOperation, OfflineQueueStore;

import '../../ui/components/orbi_components.dart';
import '../../ui/fluent/orbi_page.dart';

/// SYN-04 — "Cola Offline": qué está esperando enviarse a Odoo, por qué, y
/// qué se puede hacer al respecto sin arriesgar un documento duplicado.
///
/// `odoo_sdk` no se importa aquí (aunque hoy sea dependencia directa del
/// paquete): la comparación de estado/política se hace contra el
/// `storageValue` textual, el mismo truco que ya usa
/// `sync_conflict_resolution_screen.dart` para no tocar el tipo
/// `OfflineOperationStatus`/`OfflineReplayPolicy`, que `orbi_runtime` no
/// reexporta a propósito.
const String _statusRecoveryPending = 'recovery_pending';
const String _policyManualAfterAmbiguous = 'manual_after_ambiguous';

/// En qué grupo cae una operación de la cola, para la pantalla.
///
/// 🔴 [recoveryPending] deliberadamente NO ofrece "Reintentar": si la
/// política resultara ser `manual_after_ambiguous`, reencolarla a mano con
/// `resetOperationRetry` (que la pone en `pending`) le haría perder la marca
/// `recovery_pending` que `OfflineQueueProcessor` necesita para mandarla a
/// revisión manual en vez de despacharla de nuevo — exactamente el camino
/// que puede duplicar un cobro. La sincronización automática ya la resuelve
/// sola en su próximo ciclo (reconciliar si es segura, o marcarla para
/// revisión si no lo es).
enum OfflineQueueBucket { pending, recoveryPending, retrySafeFailing, manualAfterAmbiguous }

/// Una fila real de la cola, ya traducida para la pantalla.
final class OfflineQueueEntryView {
  const OfflineQueueEntryView({
    required this.operationId,
    required this.documentLabel,
    required this.commandLabel,
    required this.createdAt,
    required this.attempts,
    required this.lastError,
    required this.bucket,
  });

  final int operationId;
  final String documentLabel;
  final String commandLabel;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;
  final OfflineQueueBucket bucket;

  /// Sólo las `retry_safe` — orden del dueño. Ni las que ya están en
  /// recuperación ni las inciertas ofrecen este botón (ver el comentario del
  /// enum).
  bool get canRetry => bucket == OfflineQueueBucket.retrySafeFailing;

  bool get isUncertain => bucket == OfflineQueueBucket.manualAfterAmbiguous;
}

final class OfflineQueueSnapshot {
  const OfflineQueueSnapshot({this.entries = const [], this.isSyncing = false});

  final List<OfflineQueueEntryView> entries;
  final bool isSyncing;

  bool get isEmpty => entries.isEmpty;

  int countOf(OfflineQueueBucket bucket) =>
      entries.where((entry) => entry.bucket == bucket).length;
}

/// Puerto que alimenta la pantalla. La implementación real
/// ([RuntimeOfflineQueuePort]) es la única que toca `OfflineQueueStore`.
abstract interface class OfflineQueuePort {
  Future<OfflineQueueSnapshot> load();

  /// Sólo debe invocarse sobre una fila con [OfflineQueueEntryView.canRetry].
  Future<void> retry(int operationId);

  Future<void> discard(int operationId);
}

/// Implementación real sobre la `OfflineQueueStore` viva del scope — la
/// MISMA que usa `OperationsSyncJob` (nunca una segunda instancia).
final class RuntimeOfflineQueuePort implements OfflineQueuePort {
  RuntimeOfflineQueuePort({required this.queue, this.isSyncing = false});

  final OfflineQueueStore queue;
  final bool isSyncing;

  @override
  Future<OfflineQueueSnapshot> load() async {
    final pending = await queue.getPendingOperations(includeNotReady: true);
    final deadLetter = await queue.getDeadLetterOperations();
    final entries = <OfflineQueueEntryView>[
      for (final op in pending) _view(op, _bucketForPending(op)),
      for (final op in deadLetter) _view(op, _bucketForDeadLetter(op)),
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return OfflineQueueSnapshot(entries: entries, isSyncing: isSyncing);
  }

  @override
  Future<void> retry(int operationId) => queue.resetOperationRetry(operationId);

  @override
  Future<void> discard(int operationId) => queue.removeOperation(operationId);

  static OfflineQueueBucket _bucketForPending(OfflineOperation op) {
    if (op.status.storageValue == _statusRecoveryPending) {
      return OfflineQueueBucket.recoveryPending;
    }
    if (op.retryCount > 0) return OfflineQueueBucket.retrySafeFailing;
    return OfflineQueueBucket.pending;
  }

  static OfflineQueueBucket _bucketForDeadLetter(OfflineOperation op) =>
      op.replayPolicy.storageValue == _policyManualAfterAmbiguous
          ? OfflineQueueBucket.manualAfterAmbiguous
          : OfflineQueueBucket.retrySafeFailing;

  static OfflineQueueEntryView _view(OfflineOperation op, OfflineQueueBucket bucket) =>
      OfflineQueueEntryView(
        operationId: op.id,
        documentLabel: op.recordId == null ? op.model : '${op.model} #${op.recordId}',
        commandLabel: _commandLabel(op.method),
        createdAt: op.createdAt,
        attempts: op.retryCount,
        lastError: op.lastError,
        bucket: bucket,
      );

  // Vocabulario real de `OfflineLocalCommand` (odoo_sdk), comparado por su
  // `storageName` literal — igual razón que arriba: ese enum no forma parte
  // de la superficie que `orbi_runtime` reexporta a `lib/`.
  static String _commandLabel(String method) => switch (method) {
    'session_create_and_open' || 'session_open' => 'Apertura de turno',
    'session_closing_control' => 'Control de cierre de turno',
    'session_close' => 'Cierre de turno',
    'payment_create' => 'Registro de pago',
    'payment_wizard_apply' => 'Aplicación de cobro',
    'partner_create' => 'Creación de cliente',
    'order_confirm' => 'Confirmación de pedido',
    'invoice_create_with_payments' => 'Emisión de factura',
    'invoice_collect_existing' => 'Cobro de factura existente',
    'create' => 'Creación',
    'write' => 'Actualización',
    'unlink' => 'Eliminación',
    _ => method,
  };
}

class OfflineQueueScreen extends StatefulWidget {
  const OfflineQueueScreen({required this.port, super.key});

  final OfflineQueuePort port;

  @override
  State<OfflineQueueScreen> createState() => _OfflineQueueScreenState();
}

class _OfflineQueueScreenState extends State<OfflineQueueScreen> {
  OfflineQueueSnapshot? _snapshot;
  bool _loading = true;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final snapshot = await widget.port.load();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _actionError = '$error';
        _loading = false;
      });
    }
  }

  Future<void> _retry(OfflineQueueEntryView entry) async {
    try {
      await widget.port.retry(entry.operationId);
    } catch (error) {
      if (mounted) setState(() => _actionError = '$error');
    }
    await _refresh();
  }

  Future<void> _confirmDiscard(OfflineQueueEntryView entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: const Text('¿Descartar esta operación?'),
        content: Text(
          'Se eliminará "${entry.documentLabel}" de la cola offline. '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          Button(
            key: const Key('queue-discard-dialog-cancel'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('queue-discard-dialog-accept'),
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(
                FluentTheme.of(dialogContext).resources.systemFillColorCritical,
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.port.discard(entry.operationId);
    } catch (error) {
      if (mounted) setState(() => _actionError = '$error');
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return OrbiPage(
      title: 'Cola Offline',
      subtitle: 'Operaciones esperando enviarse a Odoo',
      commands: [
        CommandBarButton(
          key: const Key('offline-queue-refresh-button'),
          icon: const Icon(FluentIcons.refresh),
          label: const Text('Actualizar'),
          onPressed: _loading ? null : () => unawaited(_refresh()),
        ),
      ],
      child: _loading && snapshot == null
          ? const Center(child: ProgressRing())
          : _body(context, snapshot ?? const OfflineQueueSnapshot()),
    );
  }

  Widget _body(BuildContext context, OfflineQueueSnapshot snapshot) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_actionError != null) ...[
          InfoBar(
            key: const Key('queue-action-error'),
            title: const Text('No se pudo completar la acción'),
            content: Text(_actionError!),
            severity: InfoBarSeverity.error,
            onClose: () => setState(() => _actionError = null),
          ),
          const SizedBox(height: 12),
        ],
        _counters(context, snapshot),
        const SizedBox(height: 16),
        Expanded(
          child: snapshot.isEmpty
              ? const OrbiEmptyState(
                  title: 'Todo sincronizado',
                  message: 'No hay operaciones pendientes de enviar.',
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [for (final entry in snapshot.entries) _entryCard(context, entry)],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _counters(BuildContext context, OfflineQueueSnapshot snapshot) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 800 ? 4 : constraints.maxWidth >= 500 ? 2 : 1;
        const spacing = 12.0;
        final width = (constraints.maxWidth - (columns - 1) * spacing) / columns;
        final theme = FluentTheme.of(context);
        Widget counter(String label, int count, Color color) => SizedBox(
          width: width,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$count', style: theme.typography.title?.copyWith(color: color)),
                  Text(label, style: theme.typography.caption),
                ],
              ),
            ),
          ),
        );
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            counter(
              'En espera',
              snapshot.countOf(OfflineQueueBucket.pending),
              theme.resources.textFillColorPrimary,
            ),
            counter(
              'En recuperación',
              snapshot.countOf(OfflineQueueBucket.recoveryPending),
              theme.resources.systemFillColorCaution,
            ),
            counter(
              'Reintentando',
              snapshot.countOf(OfflineQueueBucket.retrySafeFailing),
              theme.resources.systemFillColorCaution,
            ),
            counter(
              'Revisión manual',
              snapshot.countOf(OfflineQueueBucket.manualAfterAmbiguous),
              theme.resources.systemFillColorCritical,
            ),
          ],
        );
      },
    );
  }

  Widget _entryCard(BuildContext context, OfflineQueueEntryView entry) {
    final theme = FluentTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        key: Key('queue-entry-${entry.operationId}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(entry.documentLabel, style: theme.typography.bodyStrong),
                        Text(entry.commandLabel, style: theme.typography.caption),
                      ],
                    ),
                  ),
                  _bucketBadge(context, entry.bucket),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Creada: ${_formatDateTime(entry.createdAt)} · Intentos: ${entry.attempts}',
                style: theme.typography.caption,
              ),
              if (entry.isUncertain)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: InfoBar(
                    key: Key('queue-entry-${entry.operationId}-warning'),
                    title: const Text('Revisa esto en Odoo antes de continuar'),
                    content: Text(
                      'No llegó confirmación del servidor y este comando no tiene '
                      'un identificador que permita saber si ya se aplicó. '
                      'No se reintenta en automático ni con un botón genérico '
                      'para no duplicar el documento.'
                      '${entry.lastError != null ? '\n\n${entry.lastError}' : ''}',
                    ),
                    severity: InfoBarSeverity.error,
                    isLong: true,
                  ),
                )
              else if (entry.lastError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    entry.lastError!,
                    style: theme.typography.caption?.copyWith(
                      color: theme.resources.systemFillColorCritical,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (entry.canRetry)
                    Button(
                      key: Key('queue-entry-${entry.operationId}-retry'),
                      onPressed: () => _retry(entry),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(FluentIcons.refresh, size: 14),
                          SizedBox(width: 6),
                          Text('Reintentar'),
                        ],
                      ),
                    ),
                  const SizedBox(width: 8),
                  Button(
                    key: Key('queue-entry-${entry.operationId}-discard'),
                    onPressed: () => _confirmDiscard(entry),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.delete, size: 14),
                        SizedBox(width: 6),
                        Text('Descartar'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bucketBadge(BuildContext context, OfflineQueueBucket bucket) {
    final severity = switch (bucket) {
      OfflineQueueBucket.pending => InfoBarSeverity.info,
      OfflineQueueBucket.recoveryPending => InfoBarSeverity.warning,
      OfflineQueueBucket.retrySafeFailing => InfoBarSeverity.warning,
      OfflineQueueBucket.manualAfterAmbiguous => InfoBarSeverity.error,
    };
    final label = switch (bucket) {
      OfflineQueueBucket.pending => 'En espera',
      OfflineQueueBucket.recoveryPending => 'En recuperación',
      OfflineQueueBucket.retrySafeFailing => 'Reintentando',
      OfflineQueueBucket.manualAfterAmbiguous => 'Revisión manual',
    };
    return Semantics(
      label: label,
      child: ExcludeSemantics(child: InfoBadge(source: Text(label), severity: severity)),
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}
