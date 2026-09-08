import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../../ui/components/orbi_components.dart';
import '../clients/catalog_contracts.dart';
import '../clients/entity_picker.dart';
import '../approvals/approval_contracts.dart';

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
  });
  final bool accepted;
  final String? message;
  final SaleApprovalState approval;
  final bool pendingAction;
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
    return SaleEditorResult(
      accepted: !outcome.hasIssues,
      message: outcome.hasIssues
          ? 'Aprobación comercial pendiente'
          : 'Venta encolada',
      approval: pending
          ? SaleApprovalState.pending
          : SaleApprovalState.approved,
      pendingAction: pending,
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
  final _changes = StreamController<SaleDraftSnapshot>.broadcast();
  SaleDraftSnapshot get draft => _draft;
  bool get busy => _busy;
  Stream<SaleDraftSnapshot> get changes => _changes.stream;
  Future<void> restore() async {
    final saved = await store.load(scopeKey);
    if (saved != null) {
      _draft = saved;
      _publish();
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
    _draft = _draft.copyWith(
      clientName: clientName,
      partnerId: partnerId,
      note: note,
      lines: lines,
      installments: installments,
      paymentTermId: paymentTermId,
    );
    unawaited(store.save(_draft));
    _publish();
  }

  Future<SaleEditorResult> submit() async {
    if (_busy) {
      return const SaleEditorResult(
        accepted: false,
        message: 'Operación en curso',
      );
    }
    _busy = true;
    _publish();
    try {
      if (repository != null) {
        await _persistDraft();
      }
      final result = await port.submit(_draft);
      _draft = _draft.copyWith(
        approval: result.approval,
        pendingAction: result.pendingAction,
      );
      await store.save(_draft);
      _publish();
      return result;
    } finally {
      _busy = false;
      _publish();
    }
  }

  Future<ApprovalResult> requestApproval() async {
    if (_busy) {
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
      await store.save(_draft);
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
    if (!_changes.isClosed) _changes.add(_draft);
  }

  Future<void> dispose() => _changes.close();
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
  late final FormGroup _saleForm = FormGroup({
    'client': FormControl<String>(
      value: widget.controller.draft.clientName,
      validators: [Validators.required],
    ),
  });
  late final StreamSubscription<dynamic> _clientChanges = _saleForm
      .control('client')
      .valueChanges
      .listen(
        (value) => widget.controller.update(clientName: value as String? ?? ''),
      );
  late Future<List<SalePaymentTerm>> _terms;
  @override
  void initState() {
    super.initState();
    _terms = widget.catalog.paymentTerms();
    unawaited(widget.controller.restore());
  }

  @override
  void dispose() {
    _clientChanges.cancel();
    _saleForm.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<SaleDraftSnapshot>(
    stream: widget.controller.changes,
    initialData: widget.controller.draft,
    builder: (context, snapshot) => OrbiPageShell(
      title: widget.presentation == SalePresentation.counter
          ? 'Venta mostrador'
          : 'Venta consultiva',
      child: LayoutBuilder(
        builder: (context, c) => _layout(
          context,
          c.maxWidth,
          snapshot.data ?? widget.controller.draft,
        ),
      ),
    ),
  );
  Widget _layout(BuildContext context, double width, SaleDraftSnapshot draft) {
    final form = _form(context, draft);
    final summary = _summary(context, draft);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    if (width >= (scale >= 1.5 ? 1120 : 840)) {
      final summaryWidth = (360 * scale).clamp(360.0, width * .42).toDouble();
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: SingleChildScrollView(child: form)),
          const SizedBox(width: 24),
          SizedBox(
            width: summaryWidth,
            child: SingleChildScrollView(child: summary),
          ),
        ],
      );
    }
    return ListView(children: [form, const SizedBox(height: 16), summary]);
  }

  Widget _form(BuildContext context, SaleDraftSnapshot draft) => ReactiveForm(
    formGroup: _saleForm,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OrbiReactiveTextField(
          control: _saleForm.control('client') as FormControl<String>,
          label: 'Cliente',
        ),
        if (widget.clients != null)
          SizedBox(
            height: 260,
            child: EntityPicker<SaleCatalogPartner>(
              controller: widget.clients!,
              label: 'Buscar cliente',
              entityName: 'cliente',
              onSelected: (entity) => widget.controller.update(
                clientName: entity.title,
                partnerId: entity.value?.remoteId,
              ),
            ),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          onChanged: (v) => widget.controller.update(note: v),
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Notas'),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<SalePaymentTerm>>(
          future: _terms,
          builder: (context, snapshot) {
            final terms = snapshot.data ?? const <SalePaymentTerm>[];
            if (terms.isEmpty) return const Text('Términos no configurados');
            return DropdownButtonFormField<int>(
              initialValue: terms.any((t) => t.id == draft.paymentTermId)
                  ? draft.paymentTermId
                  : null,
              decoration: const InputDecoration(
                labelText: 'Término de pago',
                hintText: 'Seleccionar término',
              ),
              items: [
                for (final term in terms)
                  DropdownMenuItem(value: term.id, child: Text(term.label)),
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
        if (widget.canSelectWarehouse)
          const TextField(decoration: InputDecoration(labelText: 'Almacén')),
        Text('Clasificación: ${draft.classification.name}'),
        const SizedBox(height: 16),
        Text('Productos', style: Theme.of(context).textTheme.titleMedium),
        if (widget.products != null)
          SizedBox(
            height: 260,
            child: EntityPicker<SaleCatalogProduct>(
              controller: widget.products!,
              label: 'Buscar producto',
              entityName: 'producto',
            ),
          ),
        if (widget.products != null)
          StreamBuilder<CatalogSnapshot<SaleCatalogProduct>>(
            stream: widget.products!.changes,
            initialData: widget.products!.snapshot,
            builder: (context, snapshot) {
              final selected = widget.products!.selected;
              return Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: selected == null
                      ? null
                      : () => _addProduct(selected),
                  icon: const Icon(Icons.add),
                  label: const Text('Añadir producto'),
                ),
              );
            },
          ),
        const SizedBox(height: 8),
        if (draft.lines.isEmpty)
          const OrbiEmptyState(
            title: 'Sin productos',
            message: 'Añade productos para continuar.',
          ),
        for (final line in draft.lines)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(line.name),
                  Text(
                    'Cantidad ${line.quantity} · Precio ${line.unitPrice} · Descuento ${line.discount}% · Impuesto ${line.tax}% · Total ${line.total}',
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: 'Quitar',
                          onPressed: () => _removeLine(line.uuid),
                          icon: const Icon(Icons.delete_outline),
                        ),
                        IconButton(
                          tooltip: 'Reducir cantidad',
                          onPressed: () => _changeQuantity(line, -1),
                          icon: const Icon(Icons.remove),
                        ),
                        IconButton(
                          tooltip: 'Aumentar cantidad',
                          onPressed: () => _changeQuantity(line, 1),
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
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
  void _changeQuantity(SaleDraftLine line, double delta) {
    final quantity = line.quantity + delta;
    if (quantity <= 0) return _removeLine(line.uuid);
    widget.controller.update(
      lines: [
        for (final current in widget.controller.draft.lines)
          current.uuid == line.uuid
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
              onPressed: widget.controller.busy
                  ? null
                  : () => widget.controller.requestApproval(),
              icon: const Icon(Icons.send),
              label: const Text('Solicitar aprobación'),
            ),
          FilledButton.icon(
            onPressed:
                widget.controller.busy ||
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
