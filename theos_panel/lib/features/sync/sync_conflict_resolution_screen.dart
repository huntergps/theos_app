import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:odoo_widgets/odoo_widgets.dart';
// `odoo_sdk` is a dev_dependency of this package on purpose: production code
// under `lib/` only sees the sync/offline types `orbi_runtime` chooses to
// re-export, never the SDK directly. That is the same boundary every other
// screen in this app respects, so this file imports through it too.
import 'package:orbi_runtime/orbi_runtime.dart'
    show ConflictInfo, OfflineOperation, OfflineQueueStore, OfflineReplayPolicy;

import '../../ui/fluent/orbi_page.dart';

/// SYN-03 — "Resolver conflicto": centro de sincronización y recuperación.
///
/// Cierra el hallazgo `Parcial` de
/// `docs/orbi_panel/reports/SCREEN_CORRESPONDENCE_AUDIT_2026_09_11.md` para
/// SYN-03: hasta ahora `onOpenConflicts` sólo abría un `AlertDialog` fijo.
///
/// Regla que gobierna todo este archivo (ver
/// `docs/orbi_panel/decisions/B01-paridad-fiscal-offline-identidad-y-numeracion.md`,
/// sección 3): una operación cuya respuesta se perdió y que no tiene un
/// identificador durable que permita confirmarla en el servidor **no es
/// "enviada" ni "fallida"**. Es incierta, y esta pantalla nunca le ofrece un
/// botón de reintento directo — eso es exactamente lo que podría duplicar un
/// documento fiscal. La única vía de reintento automático que reconoce la
/// cola (`OfflineReplayPolicy.retrySafe`) exige un contrato de reconciliación
/// verificable; sin él, la política es `manualAfterAmbiguous` y así se
/// presenta aquí: "Incierta", con las mismas dos acciones manuales que un
/// conflicto de datos, nunca con un tercer botón que la reencole.

/// Cómo se debe presentar cada fila de revisión. Nunca colapsar esto a un
/// binario correcto/incorrecto: ver el comentario de archivo.
enum SyncReviewKind {
  /// El servidor confirmó un valor que difiere del que se encoló localmente.
  conflict,

  /// La respuesta del envío nunca llegó y el comando no lleva un marcador
  /// durable con el que reconciliar contra el servidor
  /// (`OfflineReplayPolicy.manualAfterAmbiguous`). Resolverlo requiere una
  /// persona, nunca un reenvío automático.
  uncertain,

  /// Se reintentó bajo un contrato de servidor verificable y aun así no tuvo
  /// éxito tras agotar los reintentos.
  failed,
}

/// Diferencia de un campo entre el valor local y el valor del servidor.
final class SyncFieldDiff {
  const SyncFieldDiff({
    required this.field,
    required this.localValue,
    required this.serverValue,
  });

  final String field;
  final Object? localValue;
  final Object? serverValue;

  bool get differs => _display(localValue) != _display(serverValue);

  String get statusLabel => differs ? 'Diferente' : 'Sin cambios';
}

String _display(Object? value) => value == null ? '—' : value.toString();

/// Una fila de la pantalla de revisión: un conflicto con datos comparables o
/// una operación en cola cuyo estado no se pudo confirmar.
final class SyncReviewItem {
  const SyncReviewItem({
    required this.operationId,
    required this.model,
    this.recordId,
    required this.commandLabel,
    required this.kind,
    this.fields = const [],
    this.reason,
    this.retryCount = 0,
    this.createdAt,
  });

  final int operationId;
  final String model;
  final int? recordId;
  final String commandLabel;
  final SyncReviewKind kind;
  final List<SyncFieldDiff> fields;
  final String? reason;
  final int retryCount;
  final DateTime? createdAt;

  String get documentLabel => recordId == null ? model : '$model #$recordId';
}

/// Decisión que una persona toma sobre una fila de revisión. Ninguna de las
/// dos reenvía la operación al servidor: ambas la mantienen fuera del drenado
/// automático hasta nueva indicación.
enum SyncReviewDecision { reviewWithSupervisor, keepPending }

/// Puerto que alimenta la pantalla. La implementación real compone datos que
/// ya existen en la cola (`OfflineQueueStore`); esta interfaz no inventa
/// ningún campo ni método de servidor.
abstract interface class SyncConflictPort {
  List<SyncReviewItem> get items;
  Stream<List<SyncReviewItem>> get changes;
  Future<void> decide(int operationId, SyncReviewDecision decision);
  void dispose();
}

/// Implementación real sobre [OfflineQueueStore].
///
/// Las filas "inciertas"/"fallidas" salen de `getDeadLetterOperations()`,
/// que ya existe en la cola real, clasificadas por
/// [OfflineReplayPolicy] (ver comentario de archivo). Las filas de
/// "conflicto" con comparación de campos requieren el [ConflictInfo] real que
/// el procesador ya produce en `OfflineQueueProcessor`/`OperationsSyncJob`;
/// hoy ese dato es efímero (sólo se cuenta, no se expone), así que este
/// puerto lo recibe como parámetro opcional en vez de fabricarlo. Conectar el
/// flujo en vivo requiere un cambio pequeño en `orbi_runtime` (fuera de esta
/// propiedad de escritura) para capturar `result.conflicts` de cada corrida;
/// se deja documentado para quien integre la ruta.
final class QueueSyncConflictPort implements SyncConflictPort {
  QueueSyncConflictPort({
    required this.queue,
    List<ConflictInfo> conflicts = const [],
    Stream<void>? refreshOn,
  }) : _conflicts = List.unmodifiable(conflicts) {
    _refreshSub = refreshOn?.listen((_) => unawaited(_reload()));
    unawaited(_reload());
  }

  final OfflineQueueStore queue;
  List<ConflictInfo> _conflicts;
  List<SyncReviewItem> _cached = const [];
  StreamSubscription<void>? _refreshSub;
  final _controller = StreamController<List<SyncReviewItem>>.broadcast();

  @override
  List<SyncReviewItem> get items => _cached;

  @override
  Stream<List<SyncReviewItem>> get changes => _controller.stream;

  Future<void> _reload() async {
    final deadLetter = await queue.getDeadLetterOperations();
    _cached = [
      for (final conflict in _conflicts) _conflictItem(conflict),
      for (final op in deadLetter) _deadLetterItem(op),
    ];
    if (!_controller.isClosed) _controller.add(_cached);
  }

  SyncReviewItem _conflictItem(ConflictInfo info) {
    final keys = {...info.localValues.keys, ...?info.serverValues?.keys};
    return SyncReviewItem(
      operationId: info.operationId,
      model: info.model,
      recordId: info.recordId,
      commandLabel: 'Comparación de datos',
      kind: SyncReviewKind.conflict,
      createdAt: info.serverWriteDate,
      fields: [
        for (final key in keys)
          SyncFieldDiff(
            field: key,
            localValue: info.localValues[key],
            serverValue: info.serverValues?[key],
          ),
      ],
    );
  }

  SyncReviewItem _deadLetterItem(OfflineOperation op) {
    final uncertain = op.replayPolicy == OfflineReplayPolicy.manualAfterAmbiguous;
    return SyncReviewItem(
      operationId: op.id,
      model: op.model,
      recordId: op.recordId,
      commandLabel: _commandLabel(op.method),
      kind: uncertain ? SyncReviewKind.uncertain : SyncReviewKind.failed,
      reason: op.lastError,
      retryCount: op.retryCount,
      createdAt: op.createdAt,
    );
  }

  // Matched against the real, stable storage names of
  // `OfflineLocalCommand` (odoo_sdk/lib/src/sync/offline_queue_types.dart).
  // That enum is not part of the `orbi_runtime` re-export surface this
  // screen is allowed to depend on from `lib/`, so the comparison is done
  // against its literal `storageName` values instead of the type itself —
  // same real command vocabulary, no new one invented here.
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
    _ => method,
  };

  @override
  Future<void> decide(int operationId, SyncReviewDecision decision) async {
    switch (decision) {
      case SyncReviewDecision.reviewWithSupervisor:
        // Transición real y ya existente: saca la fila del drenado
        // automático y la deja marcada para revisión humana. Nunca dispara
        // un reenvío: `getPendingOperations` excluye el estado `conflict`.
        await queue.markOperationConflict(operationId);
      case SyncReviewDecision.keepPending:
        // Deliberadamente NO se llama a ningún método de la cola. Reencolar
        // una fila de política manual con `markOperationPending` la volvería
        // elegible para `getPendingOperations()` y el drenado la despacharía
        // de nuevo sin reconciliar primero (`OperationsSyncJob._handle` sólo
        // reconcilia antes de despachar cuando la política es `retrySafe` o
        // el estado es `recoveryPending`). Ese es exactamente el camino de
        // duplicado que B01 señala. "Mantener pendiente" aquí significa: no
        // tocar la fila, dejarla donde está, hasta nueva indicación humana.
        break;
    }
    _conflicts = _conflicts
        .where((conflict) => conflict.operationId != operationId)
        .toList();
    await _reload();
  }

  @override
  void dispose() {
    unawaited(_refreshSub?.cancel());
    unawaited(_controller.close());
  }
}

/// Página completa que posee un [QueueSyncConflictPort] construido sobre una
/// [OfflineQueueStore] real y lo libera junto con la página. Pensada para que
/// quien enrute hacia SYN-03 (hoy `onOpenConflicts` en `router.dart`) no
/// tenga que administrar el ciclo de vida del puerto por su cuenta.
class SyncConflictResolutionPage extends StatefulWidget {
  const SyncConflictResolutionPage({required this.queue, super.key});

  final OfflineQueueStore queue;

  @override
  State<SyncConflictResolutionPage> createState() =>
      _SyncConflictResolutionPageState();
}

class _SyncConflictResolutionPageState
    extends State<SyncConflictResolutionPage> {
  late final QueueSyncConflictPort _port = QueueSyncConflictPort(
    queue: widget.queue,
  );

  @override
  void dispose() {
    _port.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OrbiPage(
    title: 'Resolver conflicto',
    child: SyncConflictResolutionView(port: _port),
  );
}

/// Vista SYN-03. Rejilla en escritorio/tablet horizontal, lista apilada en
/// tablet vertical/teléfono — el mismo criterio de espacio real (ancho frente
/// a alto) que usa `OperationalShell`, nunca un umbral de altura fijo.
class SyncConflictResolutionView extends StatefulWidget {
  const SyncConflictResolutionView({required this.port, super.key});

  final SyncConflictPort port;

  @override
  State<SyncConflictResolutionView> createState() =>
      _SyncConflictResolutionViewState();
}

class _SyncConflictResolutionViewState
    extends State<SyncConflictResolutionView> {
  int? _selectedId;
  final Map<int, SyncReviewDecision?> _pendingSelection = {};

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SyncReviewItem>>(
      stream: widget.port.changes,
      initialData: widget.port.items,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <SyncReviewItem>[];
        if (items.isEmpty) {
          return const Center(
            child: Text('Sin conflictos ni operaciones inciertas pendientes.'),
          );
        }
        final selected = items.firstWhere(
          (item) => item.operationId == _selectedId,
          orElse: () => items.first,
        );
        return LayoutBuilder(
          builder: (context, constraints) {
            final size = MediaQuery.sizeOf(context);
            // Mismo criterio que `OrbiListing`/`OperationalShell`: la
            // relación ancho/alto decide, no un número de alto escrito a
            // mano. Un ancho generoso en una ventana en retrato (tablet
            // vertical) sigue pidiendo la composición apilada.
            final portraitNarrow =
                size.height > size.width && constraints.maxWidth < 1200;
            final wide = constraints.maxWidth >= 840 && !portraitNarrow;
            final typography = FluentTheme.of(context).typography;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Ventas · Sincronización · Resolver conflicto',
                    style: typography.caption,
                  ),
                  const SizedBox(height: 4),
                  Text('Resolver conflicto', style: typography.title),
                  const SizedBox(height: 12),
                  _itemPicker(items, selected),
                  const SizedBox(height: 16),
                  _header(context, selected),
                  const SizedBox(height: 12),
                  switch (selected.kind) {
                    SyncReviewKind.conflict => _comparisonSection(selected),
                    SyncReviewKind.uncertain ||
                    SyncReviewKind.failed => _notice(context, selected),
                  },
                  const SizedBox(height: 16),
                  _decisionPanel(context, selected, wide: wide),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _itemPicker(List<SyncReviewItem> items, SyncReviewItem selected) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          ToggleButton(
            checked: item.operationId == selected.operationId,
            onChanged: (_) => setState(() => _selectedId = item.operationId),
            child: Text('${item.documentLabel} · ${_kindLabel(item.kind)}'),
          ),
      ],
    );
  }

  Widget _header(BuildContext context, SyncReviewItem item) {
    final typography = FluentTheme.of(context).typography;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(item.documentLabel, style: typography.subtitle),
              ),
              const SizedBox(width: 8),
              _statusChip(context, item.kind),
            ],
          ),
          const SizedBox(height: 4),
          Text(item.commandLabel, style: typography.body),
          if (item.createdAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Última actualización: ${item.createdAt}',
                style: typography.caption,
              ),
            ),
        ],
      ),
    );
  }

  /// El significado por color acordado con el dueño: ámbar para lo que
  /// espera una decisión (un conflicto de datos todavía se puede resolver),
  /// rojo para lo que no tiene camino automático (incierta o fallida).
  ///
  /// `InfoBadge` es el control de Fluent para esto — ninguna forma, borde ni
  /// color se pinta a mano aquí; `severity` resuelve el color contra
  /// `FluentTheme.of(context).resources` por su cuenta (ver
  /// `info_badge.dart`).
  Widget _statusChip(BuildContext context, SyncReviewKind kind) {
    final severity = switch (kind) {
      SyncReviewKind.conflict => InfoBarSeverity.warning,
      SyncReviewKind.uncertain || SyncReviewKind.failed => InfoBarSeverity.error,
    };
    final label = _kindLabel(kind);
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: InfoBadge(source: Text(label), severity: severity),
      ),
    );
  }

  String _kindLabel(SyncReviewKind kind) => switch (kind) {
    SyncReviewKind.conflict => 'En revisión',
    SyncReviewKind.uncertain => 'Incierta',
    SyncReviewKind.failed => 'Fallida',
  };

  Widget _comparisonSection(SyncReviewItem item) {
    // `OrbiListing` owns its column-visibility state per instance; the row
    // height (52) plus its toolbar, header and spacing is what the fixed
    // height below approximates — there is no bare grid to size around
    // anymore, so the box has to be tall enough for the whole widget.
    const rowHeight = 52.0;
    final height = (item.fields.length * rowHeight + 130.0)
        .clamp(220.0, 480.0)
        .toDouble();
    final typography = FluentTheme.of(context).typography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Comparación de datos', style: typography.bodyStrong),
        const SizedBox(height: 8),
        SizedBox(
          height: height,
          child: OrbiListing<SyncFieldDiff>(
            key: ValueKey(item.operationId),
            rows: item.fields,
            storageKey: 'sync-conflict-fields',
            emptyMessage: 'Sin campos que comparar',
            columns: [
              OrbiColumn<SyncFieldDiff>(
                key: 'field',
                label: 'Campo',
                value: (field) => field.field,
                alwaysVisible: true,
              ),
              OrbiColumn<SyncFieldDiff>(
                key: 'local',
                label: 'Valor en ORBI (local)',
                value: (field) => _display(field.localValue),
              ),
              OrbiColumn<SyncFieldDiff>(
                key: 'server',
                label: 'Valor en Odoo (servidor)',
                value: (field) => _display(field.serverValue),
              ),
              OrbiColumn<SyncFieldDiff>(
                key: 'status',
                label: 'Estado',
                value: (field) => field.statusLabel,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// El `InfoBar` propio de Fluent, no un contenedor pintado a mano: resuelve
  /// fondo, borde e icono por su cuenta a partir de `severity`.
  Widget _notice(BuildContext context, SyncReviewItem item) {
    final uncertain = item.kind == SyncReviewKind.uncertain;
    return InfoBar(
      title: Text(uncertain ? 'Incierta' : 'Fallida'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            uncertain
                ? 'Respuesta incierta: no llegó confirmación del servidor '
                      'y este comando no tiene un identificador que permita '
                      'saber si ya se aplicó. No se puede reintentar sin '
                      'riesgo de duplicar el documento.'
                : 'Se agotaron los reintentos automáticos verificables. '
                      'Requiere revisión manual antes de continuar.',
          ),
          if (item.reason != null) ...[
            const SizedBox(height: 8),
            Text(item.reason!, style: FluentTheme.of(context).typography.caption),
          ],
        ],
      ),
      severity: InfoBarSeverity.error,
      isLong: true,
    );
  }

  Widget _decisionPanel(
    BuildContext context,
    SyncReviewItem item, {
    required bool wide,
  }) {
    final typography = FluentTheme.of(context).typography;
    if (wide) {
      final current = _pendingSelection[item.operationId];
      return Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Acciones disponibles', style: typography.bodyStrong),
            RadioGroup<SyncReviewDecision>(
              groupValue: current,
              onChanged: (value) => setState(
                () => _pendingSelection[item.operationId] = value,
              ),
              child: const Column(
                children: [
                  RadioButton<SyncReviewDecision>(
                    value: SyncReviewDecision.reviewWithSupervisor,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Revisar con supervisor'),
                        Text(
                          'Enviar para revisión y mantener el documento en '
                          'estado pendiente.',
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),
                  RadioButton<SyncReviewDecision>(
                    value: SyncReviewDecision.keepPending,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Mantener pendiente'),
                        Text(
                          'Conservar el estado actual sin aplicar cambios '
                          'hasta nueva indicación.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Button(
                  onPressed: () => setState(
                    () => _pendingSelection[item.operationId] = null,
                  ),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: current == null
                      ? null
                      : () => _commit(item.operationId, current),
                  child: const Text('Guardar decisión'),
                ),
              ],
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Acciones disponibles', style: typography.bodyStrong),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () => _commit(
            item.operationId,
            SyncReviewDecision.reviewWithSupervisor,
          ),
          child: const Text('Revisar con supervisor'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () =>
              _commit(item.operationId, SyncReviewDecision.keepPending),
          child: const Text('Mantener pendiente'),
        ),
      ],
    );
  }

  Future<void> _commit(int operationId, SyncReviewDecision decision) async {
    await widget.port.decide(operationId, decision);
    _pendingSelection.remove(operationId);
    if (mounted) setState(() {});
  }
}
