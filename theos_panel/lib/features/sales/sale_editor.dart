import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

import '../../ui/components/orbi_components.dart';
import '../clients/catalog_contracts.dart';
import '../clients/entity_picker.dart';
import '../approvals/approval_contracts.dart';
import 'sale_lines_editor.dart';

enum SalePresentation { counter, consultive }

final class SaleDraftLine {
  const SaleDraftLine({
    required this.uuid,
    required this.name,
    required this.quantity,
    this.unitPrice = 0,
    this.discount = 0,
    this.tax = 0,
    this.total = 0,
    this.amountsCalculated = false,
    this.remoteId,
    this.uomId,
    this.uomName,
    this.taxIds = const [],
  });
  final String uuid;
  final String name;
  final double quantity;
  final double unitPrice;
  final double discount;
  final double tax;
  final double total;

  /// UI pricing provenance only; it is not server authorization. Any pricing
  /// input change must reset this flag until a trusted calculation completes.
  final bool amountsCalculated;
  final int? remoteId;
  final int? uomId;
  final String? uomName;
  final List<int> taxIds;
}

final class SalePaymentTerm {
  const SalePaymentTerm({
    required this.id,
    required this.label,
    required this.installments,
  });
  final int id;
  final String label;
  final List<PaymentTermInstallment> installments;
}

abstract interface class SaleCatalogPort {
  Future<List<SalePaymentTerm>> paymentTerms();
}

final class UnavailableSaleCatalogPort implements SaleCatalogPort {
  const UnavailableSaleCatalogPort();
  @override
  Future<List<SalePaymentTerm>> paymentTerms() async => const [];
}

final class SaleDraftSnapshot {
  SaleDraftSnapshot({
    this.scopeKey = 'default',
    this.clientName = '',
    this.partnerId,
    this.note = '',
    this.lines = const [],
    List<PaymentTermInstallment>? installments,
    this.paymentTermId,
    this.baseRevision = 0,
    this.approval = SaleApprovalState.required,
    this.pendingAction = false,
    this.commandId = '',
    this.orderLocalId = 'draft',
    this.orderRemoteId,
    this.expectedVersion = 0,
  }) : installments = List.unmodifiable(
         installments ?? [PaymentTermInstallment(dueDays: 0)],
       ) {
    if (this.installments.isEmpty) {
      throw ArgumentError('payment term requires installments');
    }
  }
  final String scopeKey;
  final String clientName;
  final int? partnerId;
  final String note;
  final List<SaleDraftLine> lines;
  final List<PaymentTermInstallment> installments;
  final int? paymentTermId;
  final int baseRevision;
  final SaleApprovalState approval;
  final bool pendingAction;
  final String commandId;
  final String orderLocalId;
  final int? orderRemoteId;
  final int expectedVersion;
  SaleTermsClassification get classification => SaleDraftPayload(
    order: EntityReference(localId: 'draft'),
    installments: installments,
    total: 0,
  ).classification;
  SaleDraftSnapshot copyWith({
    String? clientName,
    int? partnerId,
    String? note,
    List<SaleDraftLine>? lines,
    List<PaymentTermInstallment>? installments,
    int? paymentTermId,
    SaleApprovalState? approval,
    bool? pendingAction,
  }) => SaleDraftSnapshot(
    scopeKey: scopeKey,
    clientName: clientName ?? this.clientName,
    partnerId: partnerId ?? this.partnerId,
    note: note ?? this.note,
    lines: List.unmodifiable(lines ?? this.lines),
    installments: installments ?? this.installments,
    paymentTermId: paymentTermId ?? this.paymentTermId,
    baseRevision: baseRevision,
    approval: approval ?? this.approval,
    pendingAction: pendingAction ?? this.pendingAction,
    commandId: commandId,
    orderLocalId: orderLocalId,
    orderRemoteId: orderRemoteId,
    expectedVersion: expectedVersion,
  );
}

final class SaleEditorResult {
  const SaleEditorResult({
    required this.accepted,
    this.message,
    this.approval = SaleApprovalState.required,
    this.pendingAction = false,
    this.businessState,
    this.syncState,
    this.fiscalState,
    this.issues = const [],
  });
  final bool accepted;
  final String? message;
  final SaleApprovalState approval;
  final bool pendingAction;

  /// Runtime outcome dimensions are kept separate for callers that need to
  /// render transport/business state without inferring it from [accepted].
  final SaleOrderState? businessState;
  final OperationSyncState? syncState;
  final FiscalState? fiscalState;
  final List<OperationIssue> issues;
}

String _outcomeMessage(OperationOutcome<SaleOrderState> outcome) {
  if (outcome.hasIssues) {
    return switch (outcome.issues.first.messageKey) {
      'sale.confirmation.rejected' => 'No se pudo confirmar la venta',
      'sale.version_conflict' => 'La venta cambió y requiere revisión',
      'sale.confirmation_blocked' => 'La venta no puede confirmarse todavía',
      _ => 'No se pudo completar la operación',
    };
  }
  return switch (outcome.syncState) {
    OperationSyncState.localOnly => 'Resultado registrado localmente',
    OperationSyncState.queued => 'Venta encolada',
    OperationSyncState.sending => 'Procesando venta',
    // Synchronization is not itself commercial confirmation or invoicing.
    OperationSyncState.synced => 'Venta sincronizada',
    OperationSyncState.conflict => 'La venta requiere revisión',
    OperationSyncState.failed => 'No se pudo completar la operación',
  };
}

/// F07 injects its command adapter. The UI never calls ERP/Odoo directly.
abstract interface class SaleEditorPort {
  Future<SaleEditorResult> submit(SaleDraftSnapshot draft);
}

/// F07 command boundary; its runtime implementation owns idempotency,
/// approval and sync. This interface keeps those rules out of the widget.
abstract interface class SaleCommandPort {
  Future<SaleEditorResult> confirm(SaleDraftSnapshot draft);
}

final class RuntimeSaleEditorPort implements SaleEditorPort {
  const RuntimeSaleEditorPort(this.commands, this.capabilities);
  final RuntimeSaleCommandPort commands;
  final CapabilitySnapshot capabilities;
  @override
  Future<SaleEditorResult> submit(SaleDraftSnapshot draft) async {
    if (draft.commandId.isEmpty || draft.scopeKey != capabilities.scopeKey) {
      return const SaleEditorResult(
        accepted: false,
        message: 'Venta no configurada para el ámbito activo',
        pendingAction: true,
      );
    }
    final payload = SaleConfirmationPayload(
      order: EntityReference(
        localId: draft.orderLocalId,
        remoteId: draft.orderRemoteId,
      ),
      expectedState: SaleOrderState.draft,
      expectedVersion: draft.expectedVersion,
      approval: draft.approval,
      fsc: false,
      fullyPaid: false,
      classification: draft.classification,
    );
    final outcome = await commands.confirm(payload, commandId: draft.commandId);
    final pending = outcome.pendingAction != null;
    final approvalPending =
        outcome.pendingAction?.type == PendingActionType.approval;
    return SaleEditorResult(
      accepted: !outcome.hasIssues,
      message: _outcomeMessage(outcome),
      approval: approvalPending ? SaleApprovalState.pending : draft.approval,
      pendingAction: pending,
      businessState: outcome.businessState,
      syncState: outcome.syncState,
      fiscalState: outcome.fiscalState,
      issues: outcome.issues,
    );
  }
}

final class F07SaleEditorPort implements SaleEditorPort {
  const F07SaleEditorPort(this.commands);
  final SaleCommandPort commands;
  @override
  Future<SaleEditorResult> submit(SaleDraftSnapshot draft) =>
      commands.confirm(draft);
}

abstract interface class SaleDraftStore {
  Future<SaleDraftSnapshot?> load(String scopeKey);
  Future<void> save(SaleDraftSnapshot draft);
}

final class MemorySaleDraftStore implements SaleDraftStore {
  final Map<String, SaleDraftSnapshot> _values = {};
  @override
  Future<SaleDraftSnapshot?> load(String scopeKey) async => _values[scopeKey];
  @override
  Future<void> save(SaleDraftSnapshot draft) async =>
      _values[draft.scopeKey] = draft;
}

final class SharedPreferencesSaleDraftStore implements SaleDraftStore {
  const SharedPreferencesSaleDraftStore(this.preferences);
  final SharedPreferences preferences;
  String _key(String scope) => 'orbi.sale_draft.${Uri.encodeComponent(scope)}';
  @override
  Future<SaleDraftSnapshot?> load(String scopeKey) async {
    final raw = preferences.getString(_key(scopeKey));
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return SaleDraftSnapshot(
      scopeKey: scopeKey,
      clientName: map['clientName'] as String? ?? '',
      partnerId: (map['partnerId'] as num?)?.toInt(),
      note: map['note'] as String? ?? '',
      paymentTermId: (map['paymentTermId'] as num?)?.toInt(),
      installments: ((map['installments'] as List<dynamic>?) ?? const [])
          .map((v) => PaymentTermInstallment(dueDays: (v as num).toInt()))
          .toList(),
      lines: ((map['lines'] as List<dynamic>?) ?? const []).map((v) {
        final item = v as Map<String, dynamic>;
        return SaleDraftLine(
          uuid: item['uuid'] as String,
          name: item['name'] as String,
          quantity: (item['quantity'] as num).toDouble(),
          unitPrice: (item['unitPrice'] as num?)?.toDouble() ?? 0,
          remoteId: (item['remoteId'] as num?)?.toInt(),
          uomId: (item['uomId'] as num?)?.toInt(),
          uomName: item['uomName'] as String?,
          taxIds: ((item['taxIds'] as List?) ?? const [])
              .whereType<num>()
              .map((v) => v.toInt())
              .toList(),
        );
      }).toList(),
      approval: SaleApprovalState.values.byName(
        map['approval'] as String? ?? 'required',
      ),
      pendingAction: map['pendingAction'] as bool? ?? false,
      commandId: map['commandId'] as String? ?? '',
      orderLocalId: map['orderLocalId'] as String? ?? 'draft',
      orderRemoteId: (map['orderRemoteId'] as num?)?.toInt(),
      expectedVersion: (map['expectedVersion'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<void> save(SaleDraftSnapshot draft) async => preferences.setString(
    _key(draft.scopeKey),
    jsonEncode({
      'clientName': draft.clientName,
      'partnerId': draft.partnerId,
      'note': draft.note,
      'paymentTermId': draft.paymentTermId,
      'installments': draft.installments.map((i) => i.dueDays).toList(),
      'lines': draft.lines
          .map(
            (l) => {
              'uuid': l.uuid,
              'name': l.name,
              'quantity': l.quantity,
              'unitPrice': l.unitPrice,
              'remoteId': l.remoteId,
              'uomId': l.uomId,
              'uomName': l.uomName,
              'taxIds': l.taxIds,
            },
          )
          .toList(),
      'approval': draft.approval.name,
      'pendingAction': draft.pendingAction,
      'commandId': draft.commandId,
      'orderLocalId': draft.orderLocalId,
      'orderRemoteId': draft.orderRemoteId,
      'expectedVersion': draft.expectedVersion,
    }),
  );
}

final class UnavailableSaleCommandPort implements SaleCommandPort {
  const UnavailableSaleCommandPort();
  @override
  Future<SaleEditorResult> confirm(SaleDraftSnapshot draft) async =>
      const SaleEditorResult(
        accepted: false,
        message: 'Comandos de venta no configurados',
        pendingAction: true,
      );
}

final class LocalSaleEditorPort extends F07SaleEditorPort {
  LocalSaleEditorPort() : super(const UnavailableSaleCommandPort());
}

final class SaleDraftController {
  SaleDraftController({
    required this.port,
    required this.store,
    this.repository,
    this.approvalPort,
    this.capabilities,
    this.offline = false,
    this.scopeKey = 'default',
    SaleDraftSnapshot? initial,
  }) : _draft =
           initial ??
           SaleDraftSnapshot(scopeKey: scopeKey, commandId: _newCommandId());
  final SaleEditorPort port;
  final SaleDraftStore store;
  final SaleDraftRepository? repository;
  final ApprovalPort? approvalPort;
  final CapabilitySnapshot? capabilities;
  final bool offline;
  final String scopeKey;
  SaleDraftSnapshot _draft;
  bool _busy = false;
  bool _disposed = false;
  int _editGeneration = 0;
  Future<void> _saveTail = Future<void>.value();
  final List<SaleDraftSnapshot> _pendingSaves = [];
  bool _saving = false;
  Object? _saveError;
  Object? _restoreError;
  Future<void> _restoreTail = Future<void>.value();
  bool _restoring = false;
  final _changes = StreamController<SaleDraftSnapshot>.broadcast();
  SaleDraftSnapshot get draft => _draft;
  bool get busy => _busy;
  Object? get saveError => _restoreError ?? _saveError;
  Stream<SaleDraftSnapshot> get changes => _changes.stream;
  Future<void> restore() {
    _restoring = true;
    _restoreTail = _restore();
    return _restoreTail;
  }

  Future<void> _restore() async {
    try {
      if (_disposed || _editGeneration != 0) return;
      final generation = _editGeneration;
      final saved = await store.load(scopeKey);
      if (_disposed || generation != _editGeneration) return;
      _restoreError = null;
      if (saved != null) {
        _draft = saved;
        _publish();
      }
    } catch (error) {
      _restoreError = error;
      _publish();
    } finally {
      _restoring = false;
    }
  }

  static String _newCommandId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return 'sale-${base64UrlEncode(bytes).replaceAll('=', '')}';
  }

  void update({
    String? clientName,
    int? partnerId,
    String? note,
    List<SaleDraftLine>? lines,
    List<PaymentTermInstallment>? installments,
    int? paymentTermId,
  }) {
    if (_disposed || _busy) return;
    final clientChanged =
        (clientName != null && clientName != _draft.clientName) ||
        (partnerId != null && partnerId != _draft.partnerId);
    // Any changed line collection must be recalculated, even if a caller
    // accidentally carries over the previous provenance flag.
    final linesChanged = lines != null && !_sameLines(lines);
    final invalidateAmounts = clientChanged || linesChanged;
    final nextLines = invalidateAmounts
        ? (lines ?? _draft.lines)
              .map(_withUncalculatedAmounts)
              .toList(growable: false)
        : lines;
    _draft = _draft.copyWith(
      clientName: clientName,
      partnerId: partnerId,
      note: note,
      lines: nextLines,
      installments: installments,
      paymentTermId: paymentTermId,
    );
    _editGeneration++;
    _queueSave(_draft);
    _publish();
  }

  bool _sameLines(List<SaleDraftLine> lines) {
    if (lines.length != _draft.lines.length) return false;
    for (var index = 0; index < lines.length; index++) {
      final current = _draft.lines[index];
      final next = lines[index];
      if (current.uuid != next.uuid ||
          current.name != next.name ||
          current.quantity != next.quantity ||
          current.unitPrice != next.unitPrice ||
          current.discount != next.discount ||
          current.tax != next.tax ||
          current.total != next.total ||
          current.remoteId != next.remoteId ||
          current.uomId != next.uomId ||
          current.uomName != next.uomName ||
          !_sameInts(current.taxIds, next.taxIds)) {
        return false;
      }
    }
    return true;
  }

  static bool _sameInts(List<int> first, List<int> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  static SaleDraftLine _withUncalculatedAmounts(SaleDraftLine line) =>
      SaleDraftLine(
        uuid: line.uuid,
        name: line.name,
        quantity: line.quantity,
        unitPrice: line.unitPrice,
        discount: line.discount,
        tax: line.tax,
        total: line.total,
        remoteId: line.remoteId,
        uomId: line.uomId,
        uomName: line.uomName,
        taxIds: line.taxIds,
      );

  void _queueSave(SaleDraftSnapshot snapshot) {
    _pendingSaves.add(snapshot);
    if (_saving) return;
    _saving = true;
    _saveTail = _drainSaves();
  }

  Future<void> _drainSaves() async {
    try {
      while (_pendingSaves.isNotEmpty) {
        await _saveSnapshot(_pendingSaves.removeAt(0));
      }
    } finally {
      _saving = false;
    }
  }

  Future<void> _saveSnapshot(SaleDraftSnapshot snapshot) async {
    try {
      await store.save(snapshot);
      _saveError = null;
    } catch (error) {
      _saveError = error;
    }
    _publish();
  }

  Future<void> flush() async {
    if (_restoring) await _restoreTail;
    if (_saving) await _saveTail;
    final error = _restoreError ?? _saveError;
    if (error != null) throw error;
  }

  Future<SaleEditorResult> submit() async {
    if (_disposed || _busy) {
      return const SaleEditorResult(
        accepted: false,
        message: 'Operación en curso',
      );
    }
    _busy = true;
    _publish();
    try {
      if (_draft.lines.any((line) => !line.amountsCalculated)) {
        return const SaleEditorResult(
          accepted: false,
          message: 'Importes pendientes de cálculo. El borrador se conserva.',
        );
      }
      try {
        await flush();
      } catch (_) {
        return const SaleEditorResult(
          accepted: false,
          message: 'No se pudo guardar el borrador',
        );
      }
      if (repository != null) {
        await _persistDraft();
      }
      final result = await port.submit(_draft);
      _draft = _draft.copyWith(
        approval: result.approval,
        pendingAction: result.pendingAction,
      );
      _queueSave(_draft);
      try {
        await flush();
      } catch (_) {
        // The service result remains authoritative; saveError is observable.
      }
      _publish();
      return result;
    } finally {
      _busy = false;
      _publish();
    }
  }

  Future<ApprovalResult> requestApproval() async {
    if (_disposed || _busy) {
      return const ApprovalResult(
        accepted: false,
        message: 'Operación en curso',
      );
    }
    if (approvalPort == null || capabilities == null) {
      return const ApprovalResult(
        accepted: false,
        message: 'Aprobaciones no configuradas',
      );
    }
    _busy = true;
    _publish();
    try {
      if (_draft.lines.any((line) => !line.amountsCalculated)) {
        return const ApprovalResult(
          accepted: false,
          message: 'Importes pendientes de cálculo. El borrador se conserva.',
        );
      }
      try {
        await flush();
      } catch (_) {
        return const ApprovalResult(
          accepted: false,
          message: 'No se pudo guardar el borrador',
        );
      }
      if (repository != null) await _persistDraft();
      final result = await approvalPort!.performAction(
        request: ApprovalRequest(
          commandId: _draft.commandId,
          orderDisplayName: _draft.orderLocalId,
          saleOrderRemoteId: _draft.orderRemoteId,
          terms: switch (_draft.classification) {
            SaleTermsClassification.cash => ApprovalTerms.cash,
            SaleTermsClassification.credit => ApprovalTerms.credit,
            SaleTermsClassification.mixed => ApprovalTerms.mixed,
          },
          fsc: false,
          status: ApprovalStatus.requested,
          partnerId: _draft.partnerId,
          paymentTermId: _draft.paymentTermId,
        ),
        action: ApprovalAction.commercialRequest,
        snapshot: capabilities!,
        offline: offline,
      );
      _draft = _draft.copyWith(
        approval: result.accepted
            ? SaleApprovalState.pending
            : SaleApprovalState.pending,
        pendingAction: true,
      );
      _queueSave(_draft);
      try {
        await flush();
      } catch (_) {
        // The approval result remains authoritative; saveError is observable.
      }
      _publish();
      return result;
    } finally {
      _busy = false;
      _publish();
    }
  }

  Future<void> _persistDraft() => repository!.save(
    SaleDraftRecord(
      commandId: _draft.commandId,
      name: _draft.orderLocalId,
      lines: _draft.lines
          .map(
            (line) => SaleDraftLineRecord(
              lineUuid: line.uuid,
              product: SaleCatalogProduct(
                localId: line.uuid,
                name: line.name,
                price: line.unitPrice,
                remoteId: line.remoteId,
                uomId: line.uomId,
                uomName: line.uomName,
                taxIds: line.taxIds,
              ),
              quantity: line.quantity,
              discount: line.discount,
              tax: line.tax,
            ),
          )
          .toList(growable: false),
      partnerId: _draft.partnerId,
      partnerName: _draft.clientName,
      note: _draft.note,
      paymentTermId: _draft.paymentTermId,
    ),
  );

  void _publish() {
    if (!_disposed && !_changes.isClosed) _changes.add(_draft);
  }

  Future<void> dispose() async {
    _disposed = true;
    await _changes.close();
  }
}

class SaleEditorScreen extends StatefulWidget {
  const SaleEditorScreen({
    super.key,
    required this.controller,
    this.presentation = SalePresentation.consultive,
    this.catalog = const UnavailableSaleCatalogPort(),
    this.clients,
    this.products,
    this.canSelectWarehouse = false,
  });
  final SaleDraftController controller;
  final SalePresentation presentation;
  final SaleCatalogPort catalog;
  final CatalogController<SaleCatalogPartner>? clients;
  final CatalogController<SaleCatalogProduct>? products;
  final bool canSelectWarehouse;
  @override
  State<SaleEditorScreen> createState() => _SaleEditorScreenState();
}

class _SaleEditorScreenState extends State<SaleEditorScreen> {
  late final TextEditingController _note = TextEditingController(
    text: widget.controller.draft.note,
  );
  // Owned explicitly (not left to ExpansionTile's default) because
  // `initiallyExpanded` is only read once, at the tile's own initState. A
  // note restored asynchronously after that point would otherwise stay
  // hidden behind a collapsed, unmounted section forever.
  final ExpansibleController _notesController = ExpansibleController();
  late final FormGroup _saleForm = FormGroup({
    'client': FormControl<String>(
      value: widget.controller.draft.clientName,
      validators: [Validators.required],
    ),
  });
  late final StreamSubscription<dynamic> _clientChanges;
  late StreamSubscription<SaleDraftSnapshot> _draftChanges;
  late Future<List<SalePaymentTerm>> _terms;
  @override
  void initState() {
    super.initState();
    _terms = widget.catalog.paymentTerms();
    _clientChanges = _saleForm
        .control('client')
        .valueChanges
        .listen(
          (value) =>
              widget.controller.update(clientName: value as String? ?? ''),
        );
    _draftChanges = widget.controller.changes.listen(_syncFields);
    unawaited(widget.controller.restore());
  }

  @override
  void dispose() {
    _clientChanges.cancel();
    _draftChanges.cancel();
    _saleForm.dispose();
    _note.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SaleEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    _draftChanges.cancel();
    _draftChanges = widget.controller.changes.listen(_syncFields);
    _syncFields(widget.controller.draft);
    unawaited(widget.controller.restore());
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<SaleDraftSnapshot>(
    stream: widget.controller.changes,
    initialData: widget.controller.draft,
    builder: (context, snapshot) {
      final draft = snapshot.data ?? widget.controller.draft;
      return OrbiPageShell(
        title: widget.presentation == SalePresentation.counter
            ? 'Venta mostrador'
            : 'Venta consultiva',
        child: LayoutBuilder(
          builder: (context, c) => _layout(context, c.maxWidth, draft),
        ),
      );
    },
  );

  void _syncFields(SaleDraftSnapshot draft) {
    final client = _saleForm.control('client');
    if (client.value != draft.clientName) {
      client.updateValue(draft.clientName, emitEvent: false);
    }
    // A restored/updated note must surface even if the section was
    // collapsed (or not yet mounted) when this snapshot arrived.
    if (draft.note.isNotEmpty && !_notesController.isExpanded) {
      _notesController.expand();
    }
    if (_note.text == draft.note) return;
    final offset = _note.selection.baseOffset.clamp(0, draft.note.length);
    _note.value = TextEditingValue(
      text: draft.note,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  Widget _layout(BuildContext context, double width, SaleDraftSnapshot draft) {
    final form = _form(context, draft);
    final summary = _summary(context, draft);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final banner = widget.controller.saveError == null
        ? null
        : const MaterialBanner(
            content: Text(
              'Cambios aún no guardados. Mantén esta pantalla abierta y revisa almacenamiento.',
            ),
            actions: [SizedBox.shrink()],
          );
    if (width >= (scale >= 1.5 ? 1120 : 840)) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ?banner,
            _form(context, draft, includeLines: false),
            const SizedBox(height: 16),
            _linesEditor(context, draft, constrainGrid: true),
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: (420 * scale).clamp(360.0, width).toDouble(),
                ),
                child: summary,
              ),
            ),
          ],
        ),
      );
    }
    return ListView(
      children: [?banner, form, const SizedBox(height: 16), summary],
    );
  }

  Widget _form(
    BuildContext context,
    SaleDraftSnapshot draft, {
    bool includeLines = true,
  }) => ReactiveForm(
    formGroup: _saleForm,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final fields = <Widget>[
              SizedBox(
                width: 280,
                child: OrbiReactiveTextField(
                  control: _saleForm.control('client') as FormControl<String>,
                  label: 'Cliente',
                ),
              ),
              if (widget.clients != null)
                OutlinedButton.icon(
                  key: const Key('sale-client-picker-button'),
                  onPressed: _openClientPicker,
                  icon: const Icon(Icons.search),
                  label: Text(
                    draft.clientName.isEmpty
                        ? 'Buscar cliente'
                        : 'Cambiar cliente',
                  ),
                ),
              SizedBox(
                width: 240,
                child: FutureBuilder<List<SalePaymentTerm>>(
                  future: _terms,
                  builder: (context, snapshot) {
                    final terms = snapshot.data ?? const <SalePaymentTerm>[];
                    if (terms.isEmpty) {
                      return const Text('Términos no configurados');
                    }
                    return DropdownButtonFormField<int>(
                      initialValue:
                          terms.any((t) => t.id == draft.paymentTermId)
                          ? draft.paymentTermId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Término de pago',
                        hintText: 'Seleccionar término',
                      ),
                      items: [
                        for (final term in terms)
                          DropdownMenuItem(
                            value: term.id,
                            child: Text(term.label),
                          ),
                      ],
                      onChanged: (value) {
                        final term = terms.firstWhere((t) => t.id == value);
                        widget.controller.update(
                          paymentTermId: value,
                          installments: term.installments,
                        );
                      },
                    );
                  },
                ),
              ),
              if (widget.canSelectWarehouse)
                const SizedBox(
                  width: 180,
                  child: TextField(
                    decoration: InputDecoration(labelText: 'Almacén'),
                  ),
                ),
              Text('Clasificación: ${draft.classification.name}'),
            ];
            if (constraints.maxWidth < 840) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final field in fields) ...[
                    field,
                    const SizedBox(height: 12),
                  ],
                ],
              );
            }
            return Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: fields,
            );
          },
        ),
        ExpansionTile(
          controller: _notesController,
          tilePadding: EdgeInsets.zero,
          title: const Text('Notas'),
          initiallyExpanded: _note.text.isNotEmpty,
          children: [
            TextField(
              controller: _note,
              onChanged: (v) => widget.controller.update(note: v),
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Notas'),
            ),
          ],
        ),
        if (includeLines) ...[
          const SizedBox(height: 16),
          _linesEditor(context, draft),
        ],
      ],
    ),
  );

  Widget _linesEditor(
    BuildContext context,
    SaleDraftSnapshot draft, {
    bool constrainGrid = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Productos', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      if (constrainGrid)
        SizedBox(height: 360, child: _saleLinesEditor(draft))
      else
        _saleLinesEditor(draft),
    ],
  );

  Future<void> _openClientPicker() async {
    final clients = widget.clients;
    if (clients == null) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Seleccionar cliente'),
        content: SizedBox(
          width: 520,
          height: 360,
          child: EntityPicker<SaleCatalogPartner>(
            controller: clients,
            label: 'Buscar cliente',
            entityName: 'cliente',
            onSelected: (entity) {
              widget.controller.update(
                clientName: entity.title,
                partnerId: entity.value?.remoteId,
              );
              Navigator.of(dialogContext).pop();
            },
          ),
        ),
      ),
    );
  }

  Widget _saleLinesEditor(SaleDraftSnapshot draft) => SaleLinesEditor(
    draft: draft,
    products: widget.products,
    onAddProduct: _addProduct,
    onRemoveLine: _removeLine,
    onQuantityChanged: _setQuantity,
  );
  void _addProduct(CatalogEntity<SaleCatalogProduct> product) {
    if (widget.controller.draft.lines.any(
      (line) => line.uuid == product.uuid,
    )) {
      return;
    }
    widget.controller.update(
      lines: [
        ...widget.controller.draft.lines,
        SaleDraftLine(
          uuid: product.uuid,
          name: product.title,
          quantity: 1,
          unitPrice: product.value?.price ?? 0,
          remoteId: product.value?.remoteId,
          uomId: product.value?.uomId,
          uomName: product.value?.uomName,
          taxIds: product.value?.taxIds ?? const [],
        ),
      ],
    );
  }

  void _removeLine(String uuid) => widget.controller.update(
    lines: widget.controller.draft.lines
        .where((line) => line.uuid != uuid)
        .toList(),
  );
  void _setQuantity(String uuid, double quantity) {
    if (quantity <= 0) return _removeLine(uuid);
    widget.controller.update(
      lines: [
        for (final current in widget.controller.draft.lines)
          current.uuid == uuid
              ? SaleDraftLine(
                  uuid: current.uuid,
                  name: current.name,
                  quantity: quantity,
                  unitPrice: current.unitPrice,
                  discount: current.discount,
                  tax: current.tax,
                  total: current.total,
                  remoteId: current.remoteId,
                  uomId: current.uomId,
                  uomName: current.uomName,
                  taxIds: current.taxIds,
                )
              : current,
      ],
    );
  }

  Widget _summary(BuildContext context, SaleDraftSnapshot draft) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Resumen', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            draft.clientName.isEmpty ? 'Cliente pendiente' : draft.clientName,
          ),
          if (draft.pendingAction)
            const Text('Acción pendiente: aprobación comercial'),
          if (draft.approval == SaleApprovalState.rejected)
            const Text('La aprobación fue rechazada; revisa la cotización.'),
          const SizedBox(height: 16),
          if (draft.approval == SaleApprovalState.required)
            FilledButton.icon(
              onPressed:
                  widget.controller.busy || widget.controller.saveError != null
                  ? null
                  : () => widget.controller.requestApproval(),
              icon: const Icon(Icons.send),
              label: const Text('Solicitar aprobación'),
            ),
          FilledButton.icon(
            onPressed:
                widget.controller.busy ||
                    widget.controller.saveError != null ||
                    draft.approval != SaleApprovalState.approved
                ? null
                : () => widget.controller.submit(),
            icon: const Icon(Icons.check),
            label: Text(widget.controller.busy ? 'Guardando…' : 'Continuar'),
          ),
        ],
      ),
    ),
  );
}
