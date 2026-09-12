import 'package:fluent_ui/fluent_ui.dart';

import '../../app/theme/orbi_theme.dart';
import '../../ui/fluent/orbi_page.dart';
import 'collection_contracts.dart';
import '../../ui/state_labels.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({
    super.key,
    required this.shift,
    required this.pending,
    required this.capabilities,
    required this.actions,
    this.journals = const [],
    this.cashOutTypes = const [],
    this.financialActions = const [],
  });
  final CollectionShiftSnapshot shift;
  final List<CollectionPendingSale> pending;
  final CollectionCapabilitySnapshot capabilities;
  final CollectionActions actions;
  final List<CollectionJournalOption> journals;
  final List<CollectionCashOutTypeOption> cashOutTypes;
  final List<CollectionFinancialAction> financialActions;
  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  String? _busy;
  String? _error;
  // El resultado de la última acción se muestra en un `InfoBar` DENTRO del
  // árbol de widgets, nunca con `displayInfoBar` (que agenda su propio
  // `Timer` de auto-cierre a 3 segundos reales): en una prueba de widgets
  // ese temporizador sigue vivo después de que `pumpAndSettle` decide que
  // ya no hay más cuadros pendientes, y la prueba revienta con "A Timer is
  // still pending even after the widget tree was disposed". Aquí el cierre
  // lo decide la persona (botón de cerrar) o la siguiente acción.
  String? _resultMessage;
  InfoBarSeverity _resultSeverity = InfoBarSeverity.info;
  late CollectionShiftSnapshot _currentShift = widget.shift;
  int? _selected;
  bool _mixedDueConfirmed = false;
  final _amount = TextEditingController();
  final _countFields = <String, TextEditingController>{
    for (final denomination in [
      'bills100',
      'bills50',
      'bills20',
      'bills10',
      'bills5',
      'bills1',
      'coins1',
      'coins50',
      'coins25',
      'coins10',
      'coins5',
      'coins1Cent',
    ])
      denomination: TextEditingController(text: '0'),
  };
  int? _journalId;
  CollectionPaymentLineKind _lineKind = CollectionPaymentLineKind.payment;
  int? _advanceId;
  int? _creditNoteId;
  int? _cashOutTypeId;
  final List<CollectionPaymentDraft> _lines = [];
  @override
  void dispose() {
    _amount.dispose();
    for (final controller in _countFields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OrbiPage(
    title: 'Caja y cobros',
    child: LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= OrbiTheme.mediumBreakpoint;
        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _shiftCard(context),
            if (_resultMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: InfoBar(
                  title: Text(_resultMessage!),
                  severity: _resultSeverity,
                  onClose: () => setState(() => _resultMessage = null),
                ),
              ),
            if (_error != null)
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: FluentTheme.of(
                        context,
                      ).resources.systemFillColorCritical,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: wide
                  ? Row(
                      children: [
                        Expanded(child: _pendingList()),
                        const SizedBox(width: 16),
                        SizedBox(width: 360, child: _editor()),
                      ],
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          SizedBox(height: 280, child: _pendingList()),
                          const SizedBox(height: 12),
                          _editor(),
                        ],
                      ),
                    ),
            ),
          ],
        );
        return body;
      },
    ),
  );
  Widget _shiftCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 12,
        children: [
          Semantics(
            liveRegion: true,
            label: 'Turno ${shiftStateLabel(_currentShift.state)}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Turno: ${shiftStateLabel(_currentShift.state)}',
                  style: FluentTheme.of(context).typography.bodyStrong,
                ),
                if (_currentShift.differenceMinor != null)
                  Text(
                    'Diferencia reportada: ${(_currentShift.differenceMinor! / 100).toStringAsFixed(2)}',
                    style: FluentTheme.of(context).typography.body,
                  ),
              ],
            ),
          ),
          if (_currentShift.state == CollectionShiftState.opened &&
              widget.actions is CollectionShiftCountActions)
            _cashCountEditor(context),
          FilledButton(
            onPressed:
                _busy == 'shift' ||
                    _currentShift.state == CollectionShiftState.closing ||
                    _currentShift.state == CollectionShiftState.closed
                ? null
                : _toggleShift,
            child: Text(switch (_currentShift.state) {
              CollectionShiftState.opened => 'Cerrar turno',
              CollectionShiftState.closing => 'Cierre pendiente',
              CollectionShiftState.closed => 'Turno cerrado',
              _ => 'Abrir/recuperar',
            }),
          ),
        ],
      ),
    ),
  );

  Widget _cashCountEditor(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Expander(
      header: const Text('Conteo de cierre'),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Usa denominaciones; el total se calcula automáticamente.',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in _countFields.entries)
                  SizedBox(
                    width: 92,
                    child: InfoLabel(
                      label: _countLabel(entry.key),
                      child: TextBox(
                        controller: entry.value,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  String _countLabel(String key) => switch (key) {
    'bills100' => r'Billetes $100',
    'bills50' => r'Billetes $50',
    'bills20' => r'Billetes $20',
    'bills10' => r'Billetes $10',
    'bills5' => r'Billetes $5',
    'bills1' => r'Billetes $1',
    'coins1' => r'Monedas $1',
    'coins50' => r'Monedas $0.50',
    'coins25' => r'Monedas $0.25',
    'coins10' => r'Monedas $0.10',
    'coins5' => r'Monedas $0.05',
    _ => r'Monedas $0.01',
  };

  CollectionCashCount _cashCount() => CollectionCashCount(
    bills100: _count('bills100'),
    bills50: _count('bills50'),
    bills20: _count('bills20'),
    bills10: _count('bills10'),
    bills5: _count('bills5'),
    bills1: _count('bills1'),
    coins1: _count('coins1'),
    coins50: _count('coins50'),
    coins25: _count('coins25'),
    coins10: _count('coins10'),
    coins5: _count('coins5'),
    coins1Cent: _count('coins1Cent'),
    expectedBalanceMinor: _currentShift.expectedBalanceMinor ?? 0,
  );

  int _count(String key) => int.tryParse(_countFields[key]!.text) ?? -1;
  Widget _pendingList() => Card(
    child: widget.pending.isEmpty
        ? const Center(child: Text('No hay cobros pendientes.'))
        : ListView.builder(
            itemCount: widget.pending.length,
            itemBuilder: (context, i) {
              final sale = widget.pending[i];
              return ListTile.selectable(
                selected: _selected == i,
                onPressed: () => setState(() {
                  _selected = i;
                  _mixedDueConfirmed = false;
                }),
                title: Text(sale.label),
                subtitle: Text(
                  'Pendiente: ${(sale.amountMinor / 100).toStringAsFixed(2)}'
                  '${sale.route == CollectionSaleRoute.existingInvoice && sale.wizardId == null ? ' · Requiere wizard nativo' : ''}',
                ),
                trailing: const Icon(FluentIcons.chevron_right),
              );
            },
          ),
  );
  Widget _editor() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Medio de cobro',
            style: FluentTheme.of(context).typography.bodyStrong,
          ),
          const SizedBox(height: 8),
          InfoLabel(
            label: 'Tipo de línea',
            child: ComboBox<CollectionPaymentLineKind>(
              value: _lineKind,
              isExpanded: true,
              items: const [
                ComboBoxItem(
                  value: CollectionPaymentLineKind.payment,
                  child: Text('Pago'),
                ),
                ComboBoxItem(
                  value: CollectionPaymentLineKind.advance,
                  child: Text('Anticipo'),
                ),
                ComboBoxItem(
                  value: CollectionPaymentLineKind.creditNote,
                  child: Text('NC cacheada'),
                ),
              ],
              onChanged: _busy == null
                  ? (value) => setState(() {
                      _lineKind = value ?? CollectionPaymentLineKind.payment;
                      _advanceId = null;
                      _creditNoteId = null;
                    })
                  : null,
            ),
          ),
          if (_lineKind == CollectionPaymentLineKind.advance &&
              _selected != null) ...[
            const SizedBox(height: 8),
            InfoLabel(
              label: 'Anticipo',
              child: ComboBox<int>(
                value: _advanceId,
                isExpanded: true,
                items: widget.pending[_selected!].cachedAdvances
                    .map(
                      (item) => ComboBoxItem(
                        value: item.id,
                        child: Text(
                          '${item.label} · ${(item.amountMinor / 100).toStringAsFixed(2)}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _busy == null
                    ? (value) => setState(() => _advanceId = value)
                    : null,
              ),
            ),
          ],
          if (_lineKind == CollectionPaymentLineKind.creditNote &&
              _selected != null) ...[
            const SizedBox(height: 8),
            InfoLabel(
              label: 'Nota de crédito',
              child: ComboBox<int>(
                value: _creditNoteId,
                isExpanded: true,
                items: widget.pending[_selected!].cachedCreditNotes
                    .map(
                      (item) => ComboBoxItem(
                        value: item.id,
                        child: Text(
                          '${item.label} · ${(item.amountMinor / 100).toStringAsFixed(2)}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _busy == null
                    ? (value) => setState(() => _creditNoteId = value)
                    : null,
              ),
            ),
          ],
          if (_lineKind == CollectionPaymentLineKind.payment) ...[
            const SizedBox(height: 8),
            InfoLabel(
              label: 'Medio de cobro',
              child: ComboBox<int>(
                value: _journalId,
                isExpanded: true,
                items: widget.journals
                    .map(
                      (j) => ComboBoxItem(value: j.id, child: Text(j.name)),
                    )
                    .toList(),
                onChanged: _busy == null
                    ? (value) => setState(() => _journalId = value)
                    : null,
              ),
            ),
          ],
          if (widget.cashOutTypes.isNotEmpty) ...[
            const SizedBox(height: 8),
            InfoLabel(
              label: 'Tipo de salida',
              child: ComboBox<int>(
                value: _cashOutTypeId,
                isExpanded: true,
                items: widget.cashOutTypes
                    .map(
                      (type) => ComboBoxItem(
                        value: type.id,
                        child: Text(type.name),
                      ),
                    )
                    .toList(),
                onChanged: _busy == null
                    ? (value) => setState(() => _cashOutTypeId = value)
                    : null,
              ),
            ),
          ],
          const SizedBox(height: 8),
          InfoLabel(
            label: 'Monto',
            child: TextBox(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_selected != null &&
              widget.pending[_selected!].requiresDueConfirmation) ...[
            Card(
              key: const Key('mixed-due-confirmation'),
              backgroundColor: FluentTheme.of(
                context,
              ).resources.subtleFillColorSecondary,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    checked: _mixedDueConfirmed,
                    onChanged: _busy == null
                        ? (value) =>
                              setState(() => _mixedDueConfirmed = value ?? false)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: _busy == null
                          ? () => setState(
                              () => _mixedDueConfirmed = !_mixedDueConfirmed,
                            )
                          : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Confirmar monto mixto exigible'),
                          Text(
                            'Exigible calculado: ${((widget.pending[_selected!].calculatedDueMinor ?? widget.pending[_selected!].amountMinor) / 100).toStringAsFixed(2)}',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (_selected != null)
            Text(
              'Restante: ${((widget.pending[_selected!].amountMinor - collectionTotalMinor(_lines)) / 100).toStringAsFixed(2)}',
              textAlign: TextAlign.right,
            ),
          Text(
            'Medios añadidos: ${_lines.length} · Total: ${(collectionTotalMinor(_lines) / 100).toStringAsFixed(2)}',
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: _busy == null ? _addPaymentLine : null,
              child: const Text('Añadir medio'),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed:
                _busy == 'collect' ||
                    (_selected != null &&
                        widget.pending[_selected!].requiresDueConfirmation &&
                        !_mixedDueConfirmed)
                ? null
                : _collect,
            child: Text(_busy == 'collect' ? 'Procesando…' : 'Cobrar'),
          ),
          const SizedBox(height: 8),
          _financialActions(),
          const SizedBox(height: 8),
          _unavailableConfiguredActions(),
          const SizedBox(height: 8),
          _unsupportedActions(),
        ],
      ),
    ),
  );
  Widget _unsupportedActions() {
    final unavailable = CollectionCapability.values
        .where((cap) => !widget.capabilities.supports(cap))
        .map((cap) => cap.name)
        .join(', ');
    if (unavailable.isEmpty) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      label: 'Acciones no disponibles: $unavailable',
      child: Text(
        'No disponible en este alcance: $unavailable',
        style: TextStyle(
          color: FluentTheme.of(context).resources.textFillColorSecondary,
        ),
      ),
    );
  }

  Widget _financialActions() {
    if (widget.financialActions.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final action in widget.financialActions)
          OutlinedButton(
            onPressed: _busy == null ? () => _runFinancial(action) : null,
            child: Text(action.label),
          ),
      ],
    );
  }

  Widget _unavailableConfiguredActions() {
    final wired = widget.financialActions
        .map((action) => action.capability)
        .toSet();
    final labels = <CollectionCapability, String>{
      CollectionCapability.advances: 'Anticipo (requiere wizard oficial)',
      CollectionCapability.withholdings:
          'Retención (requiere confirmación fiscal)',
      CollectionCapability.creditNotes:
          'Nota de crédito (requiere líneas del wizard)',
    };
    final unavailable = labels.entries
        .where(
          (entry) =>
              widget.capabilities.supports(entry.key) &&
              !wired.contains(entry.key),
        )
        .map((entry) => entry.value)
        .toList(growable: false);
    if (unavailable.isEmpty) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      label: 'Operaciones no disponibles: ${unavailable.join(', ')}',
      child: Text(
        'No disponible en este alcance: ${unavailable.join(' · ')}',
        style: TextStyle(
          color: FluentTheme.of(context).resources.textFillColorSecondary,
        ),
      ),
    );
  }

  Future<void> _runFinancial(CollectionFinancialAction action) async {
    if (_busy != null) return;
    setState(() {
      _busy = 'financial:${action.capability.name}';
      _error = null;
    });
    try {
      final financialContext = CollectionFinancialContext(
        shift: _currentShift,
        journalId: _journalId,
        amountMinor:
            ((double.tryParse(_amount.text.replaceAll(',', '.')) ?? 0) * 100)
                .round(),
        selectedSale: _selected == null ? null : widget.pending[_selected!],
        cashOutTypeId: _cashOutTypeId,
        partnerId: _selected == null
            ? null
            : widget.pending[_selected!].partnerId,
      );
      final result = action.runWithContext == null
          ? await action.run()
          : await action.runWithContext!(financialContext);
      if (!mounted) return;
      if (result != CollectionResultState.synced &&
          result != CollectionResultState.queued &&
          result != CollectionResultState.local) {
        setState(
          () => _error =
              'La acción no se confirmó. ${collectionResultLabel(result)}.',
        );
      }
      if (mounted) {
        setState(() {
          _resultMessage = collectionResultLabel(result);
          _resultSeverity = _severityFor(result);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _toggleShift() async {
    setState(() => _busy = 'shift');
    try {
      final CollectionShiftSnapshot next;
      CollectionResultState? closeResult;
      String? closeMessage;
      if (_currentShift.state == CollectionShiftState.opened &&
          widget.actions is CollectionShiftCountActions) {
        final result = await (widget.actions as CollectionShiftCountActions)
            .closeWithCount(_currentShift, _cashCount());
        next = result.shift;
        closeResult = result.result;
        closeMessage = result.message;
      } else {
        next = _currentShift.state == CollectionShiftState.opened
            ? await widget.actions.close(_currentShift)
            : await widget.actions.open(_currentShift);
      }
      if (mounted) {
        setState(() {
          _currentShift = next;
          _error =
              closeMessage ??
              (next.state == CollectionShiftState.conflict
                  ? 'El turno requiere revisión.'
                  : null);
        });
      }
      if (mounted) {
        setState(() {
          _resultMessage = closeResult == null
              ? 'Turno: ${shiftStateLabel(next.state)}'
              : 'Cierre: ${collectionResultLabel(closeResult)}';
          _resultSeverity = closeResult == null
              ? InfoBarSeverity.info
              : _severityFor(closeResult);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _collect() async {
    if (_selected == null || _busy != null) return;
    final selectedSale = widget.pending[_selected!];
    if (selectedSale.requiresDueConfirmation && !_mixedDueConfirmed) {
      setState(
        () => _error = 'Confirma el monto mixto exigible antes de cobrar.',
      );
      return;
    }
    if (_currentShift.state != CollectionShiftState.opened) {
      setState(() => _error = 'Abre un turno antes de cobrar.');
      return;
    }
    if (_lines.isEmpty) {
      setState(() => _error = 'Añade al menos un medio de cobro.');
      return;
    }
    setState(() => _busy = 'collect');
    try {
      final batch = List<CollectionPaymentDraft>.unmodifiable(_lines);
      if (collectionTotalMinor(batch) >
          widget.pending[_selected!].amountMinor) {
        if (mounted) setState(() => _error = 'No se permite sobrepago.');
        return;
      }
      final result = await widget.actions.collect(selectedSale, batch);
      if (mounted &&
          (result == CollectionResultState.synced ||
              result == CollectionResultState.queued ||
              result == CollectionResultState.local)) {
        setState(() {
          _lines
            ..clear()
            ..addAll(batch);
          _error = null;
        });
      } else if (mounted) {
        setState(
          () => _error =
              'El cobro no se confirmó. ${collectionResultLabel(result)}.',
        );
      }
      if (mounted) {
        setState(() {
          _resultMessage = collectionResultLabel(result);
          _resultSeverity = _severityFor(result);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  InfoBarSeverity _severityFor(CollectionResultState result) =>
      switch (result) {
        CollectionResultState.synced => InfoBarSeverity.success,
        CollectionResultState.queued ||
        CollectionResultState.local => InfoBarSeverity.info,
        CollectionResultState.ambiguous ||
        CollectionResultState.conflict => InfoBarSeverity.warning,
      };

  void _addPaymentLine() {
    if (_selected == null) return;
    if (_lineKind == CollectionPaymentLineKind.payment && _journalId == null) {
      return;
    }
    if (_lineKind == CollectionPaymentLineKind.advance && _advanceId == null) {
      return;
    }
    if (_lineKind == CollectionPaymentLineKind.creditNote &&
        _creditNoteId == null) {
      return;
    }
    final parsed = double.tryParse(_amount.text.replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) return;
    final draft = CollectionPaymentDraft(
      journalId: _journalId ?? 0,
      amountMinor: (parsed * 100).round(),
      kind: _lineKind,
      advanceId: _advanceId,
      creditNoteId: _creditNoteId,
    );
    if (collectionTotalMinor([..._lines, draft]) >
        widget.pending[_selected!].amountMinor) {
      setState(() => _error = 'No se permite sobrepago.');
      return;
    }
    setState(() {
      _lines.add(draft);
      _amount.clear();
      _error = null;
    });
  }
}
