import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../shared/utils/formatting_utils.dart';

import '../../providers/service_providers.dart';

/// Provider para anticipos disponibles del cliente
final availableAdvancesProvider =
    FutureProvider.family<List<AvailableAdvance>, int>((ref, partnerId) async {
  final paymentService = ref.watch(paymentServiceProvider);
  return paymentService.getAvailableAdvances(partnerId);
});

/// Provider para notas de crédito disponibles del cliente
final availableCreditNotesProvider =
    FutureProvider.family<List<AvailableCreditNote>, int>((ref, partnerId) async {
  final paymentService = ref.watch(paymentServiceProvider);
  return paymentService.getAvailableCreditNotes(partnerId);
});

/// Provider para marcas de tarjeta por diario
final cardBrandsProvider =
    FutureProvider.family<List<CardBrand>, int>((ref, journalId) async {
  final paymentService = ref.watch(paymentServiceProvider);
  return paymentService.getCardBrands(journalId);
});

/// Provider para plazos de tarjeta
final cardDeadlinesProvider =
    FutureProvider.family<List<CardDeadline>, ({int journalId, CardType cardType})>(
        (ref, params) async {
  final paymentService = ref.watch(paymentServiceProvider);
  return paymentService.getCardDeadlines(params.journalId, params.cardType);
});

/// Provider para lotes de tarjeta por diario
final cardLotesProvider =
    FutureProvider.family<List<CardLote>, int>((ref, journalId) async {
  final paymentService = ref.watch(paymentServiceProvider);
  return paymentService.getOpenLotes(journalId);
});

/// Formulario completo de pago replicando el wizard de Odoo
///
/// Soporta:
/// - Tipo de pago: Pago directo, Anticipo, Nota de Crédito
/// - Campos específicos por tipo de diario (efectivo, tarjeta, cheque, transferencia)
/// - Botones rápidos de efectivo
class PaymentFormWidget extends ConsumerStatefulWidget {
  final int? partnerId;
  final double pendingAmount;
  final List<AvailableJournal> journals;
  final Function(PaymentLine) onAddPayment;

  const PaymentFormWidget({
    super.key,
    this.partnerId,
    required this.pendingAmount,
    required this.journals,
    required this.onAddPayment,
  });

  @override
  ConsumerState<PaymentFormWidget> createState() => _PaymentFormWidgetState();
}

class _PaymentFormWidgetState extends ConsumerState<PaymentFormWidget> {
  // Tipo de pago
  PaymentLineType _paymentType = PaymentLineType.payment;

  // Para pagos directos
  AvailableJournal? _selectedJournal;
  PaymentMethod? _selectedMethod;

  // Para tarjetas
  CardType _cardType = CardType.debit;
  CardBrand? _selectedCardBrand;
  CardDeadline? _selectedCardDeadline;
  CardLote? _selectedCardLote;
  DateTime _voucherDate = DateTime.now();

  // Para cheques
  DateTime _effectiveDate = DateTime.now();
  final _checkNumberController = TextEditingController();

  // Para anticipos
  AvailableAdvance? _selectedAdvance;

  // Para notas de crédito
  AvailableCreditNote? _selectedCreditNote;

  // Común
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _checkNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    // Auto-select first journal if none selected
    if (_selectedJournal == null && widget.journals.isNotEmpty) {
      _selectedJournal = widget.journals.first;
      if (_selectedJournal!.paymentMethods.isNotEmpty) {
        _selectedMethod = _selectedJournal!.paymentMethods.first;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tipo de pago selector
        _buildPaymentTypeSelector(theme),
        const SizedBox(height: Spacing.md),

        // Formulario según tipo
        if (_paymentType == PaymentLineType.payment)
          _buildDirectPaymentForm(theme)
        else if (_paymentType == PaymentLineType.advance)
          _buildAdvanceForm(theme)
        else
          _buildCreditNoteForm(theme),

        const SizedBox(height: Spacing.md),

        // Botón agregar
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _canAddPayment() ? _addPayment : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(FluentIcons.add, size: 16),
                const SizedBox(width: Spacing.xs),
                const Text('Agregar Pago'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentTypeSelector(FluentThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tipo de Abono', style: theme.typography.bodyStrong),
        const SizedBox(height: Spacing.xs),
        Row(
          children: [
            _PaymentTypeChip(
              label: 'Pago',
              icon: FluentIcons.money,
              isSelected: _paymentType == PaymentLineType.payment,
              color: Colors.green,
              onTap: () => setState(() => _paymentType = PaymentLineType.payment),
            ),
            const SizedBox(width: Spacing.sm),
            _PaymentTypeChip(
              label: 'Anticipo',
              icon: FluentIcons.circle_dollar,
              isSelected: _paymentType == PaymentLineType.advance,
              color: Colors.magenta,
              onTap: widget.partnerId != null
                  ? () => setState(() => _paymentType = PaymentLineType.advance)
                  : null,
            ),
            const SizedBox(width: Spacing.sm),
            _PaymentTypeChip(
              label: 'Nota Crédito',
              icon: FluentIcons.page_list,
              isSelected: _paymentType == PaymentLineType.creditNote,
              color: Colors.purple,
              onTap: widget.partnerId != null
                  ? () => setState(() => _paymentType = PaymentLineType.creditNote)
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDirectPaymentForm(FluentThemeData theme) {
    final isCash = _selectedJournal?.isCash ?? false;
    final isCard = _selectedJournal?.isCardJournal ?? false;
    final isCheck = _selectedMethod?.isCheck ?? false;
    final isTransfer = _selectedMethod?.isTransfer ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Journal selector
        InfoLabel(
          label: 'Método de pago',
          child: ComboBox<AvailableJournal>(
            isExpanded: true,
            value: _selectedJournal,
            items: widget.journals
                .map((j) => ComboBoxItem(
                      value: j,
                      child: Row(
                        children: [
                          Icon(
                            j.isCash
                                ? FluentIcons.money
                                : j.isCardJournal
                                    ? FluentIcons.payment_card
                                    : FluentIcons.bank,
                            size: 14,
                          ),
                          const SizedBox(width: Spacing.xs),
                          Text(j.name),
                        ],
                      ),
                    ))
                .toList(),
            onChanged: (j) {
              setState(() {
                _selectedJournal = j;
                _selectedMethod = j?.paymentMethods.isNotEmpty == true
                    ? j!.paymentMethods.first
                    : null;
                // Reset card fields
                _selectedCardBrand = null;
                _selectedCardDeadline = null;
                _selectedCardLote = null;
              });
            },
          ),
        ),

        // Payment method selector (if journal has multiple methods)
        if (_selectedJournal != null &&
            _selectedJournal!.paymentMethods.length > 1) ...[
          const SizedBox(height: Spacing.sm),
          InfoLabel(
            label: 'Forma de pago',
            child: ComboBox<PaymentMethod>(
              isExpanded: true,
              value: _selectedMethod,
              items: _selectedJournal!.paymentMethods
                  .map((m) => ComboBoxItem(
                        value: m,
                        child: Text(m.name),
                      ))
                  .toList(),
              onChanged: (m) => setState(() => _selectedMethod = m),
            ),
          ),
        ],

        // Quick cash buttons (only for cash)
        if (isCash) ...[
          const SizedBox(height: Spacing.sm),
          _buildQuickCashButtons(theme),
        ],

        // Card fields
        if (isCard) ...[
          const SizedBox(height: Spacing.sm),
          _buildCardFields(theme),
        ],

        // Check fields
        if (isCheck) ...[
          const SizedBox(height: Spacing.sm),
          _buildCheckFields(theme),
        ],

        // Transfer fields
        if (isTransfer) ...[
          const SizedBox(height: Spacing.sm),
          _buildTransferFields(theme),
        ],

        const SizedBox(height: Spacing.sm),

        // Amount input
        InfoLabel(
          label: 'Monto',
          child: TextBox(
            controller: _amountController,
            placeholder: widget.pendingAmount.toFixed(2),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefix: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text('\$'),
            ),
            suffix: IconButton(
              icon: const Icon(FluentIcons.calculator_equal_to, size: 14),
              onPressed: () {
                _amountController.text = widget.pendingAmount.toFixed(2);
              },
            ),
          ),
        ),

        // Reference (if not cash and not card)
        if (!isCash && !isCard && !isCheck) ...[
          const SizedBox(height: Spacing.sm),
          InfoLabel(
            label: 'Referencia',
            child: TextBox(
              controller: _referenceController,
              placeholder: 'Número de comprobante',
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickCashButtons(FluentThemeData theme) {
    final amounts = [1.0, 5.0, 10.0, 20.0, 50.0, 100.0];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Monto rápido:',
          style: theme.typography.caption?.copyWith(color: theme.inactiveColor),
        ),
        const SizedBox(height: Spacing.xs),
        Wrap(
          spacing: Spacing.xs,
          runSpacing: Spacing.xs,
          children: [
            // Exact amount button
            Button(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(
                  theme.accentColor.withValues(alpha: 0.1),
                ),
              ),
              onPressed: () {
                _amountController.text = widget.pendingAmount.toFixed(2);
              },
              child: Text(
                'Exacto',
                style: TextStyle(
                  color: theme.accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Quick amounts
            ...amounts.map(
              (a) => Button(
                onPressed: () {
                  _amountController.text = a.toFixed(2);
                },
                child: Text('\$${a.toInt()}'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCardFields(FluentThemeData theme) {
    final journalId = _selectedJournal?.id;
    if (journalId == null) return const SizedBox();

    final brandsAsync = ref.watch(cardBrandsProvider(journalId));
    final lotesAsync = ref.watch(cardLotesProvider(journalId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Card type selector
        InfoLabel(
          label: 'Tipo de tarjeta',
          child: RadioGroup<CardType>(
            groupValue: _cardType,
            onChanged: (v) {
              setState(() {
                _cardType = v;
                _selectedCardDeadline = null;
              });
            },
            child: Row(
              children: [
                Expanded(
                  child: RadioButton<CardType>(
                    value: CardType.debit,
                    content: const Text('Débito'),
                  ),
                ),
                Expanded(
                  child: RadioButton<CardType>(
                    value: CardType.credit,
                    content: const Text('Crédito'),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: Spacing.sm),

        // Card brand selector
        brandsAsync.when(
          loading: () => const Center(child: ProgressRing()),
          error: (_, _) => const SizedBox(),
          data: (brands) => InfoLabel(
            label: 'Marca de tarjeta',
            child: ComboBox<CardBrand>(
              isExpanded: true,
              value: _selectedCardBrand,
              placeholder: const Text('Seleccione marca'),
              items: brands
                  .map((b) => ComboBoxItem(value: b, child: Text(b.name)))
                  .toList(),
              onChanged: (b) => setState(() => _selectedCardBrand = b),
            ),
          ),
        ),

        const SizedBox(height: Spacing.sm),

        // Card deadline selector (for credit)
        if (_cardType == CardType.credit) ...[
          Consumer(
            builder: (context, ref, _) {
              final deadlinesAsync = ref.watch(
                cardDeadlinesProvider((journalId: journalId, cardType: _cardType)),
              );
              return deadlinesAsync.when(
                loading: () => const SizedBox(),
                error: (_, _) => const SizedBox(),
                data: (deadlines) => InfoLabel(
                  label: 'Plazo',
                  child: ComboBox<CardDeadline>(
                    isExpanded: true,
                    value: _selectedCardDeadline,
                    placeholder: const Text('Seleccione plazo'),
                    items: deadlines
                        .map((d) => ComboBoxItem(value: d, child: Text(d.name)))
                        .toList(),
                    onChanged: (d) => setState(() => _selectedCardDeadline = d),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: Spacing.sm),
        ],

        // Card lote selector
        lotesAsync.when(
          loading: () => const SizedBox(),
          error: (_, _) => const SizedBox(),
          data: (lotes) => lotes.isNotEmpty
              ? InfoLabel(
                  label: 'Lote',
                  child: ComboBox<CardLote>(
                    isExpanded: true,
                    value: _selectedCardLote,
                    placeholder: const Text('Seleccione lote'),
                    items: lotes
                        .map((l) => ComboBoxItem(value: l, child: Text(l.name)))
                        .toList(),
                    onChanged: (l) => setState(() => _selectedCardLote = l),
                  ),
                )
              : const SizedBox(),
        ),

        const SizedBox(height: Spacing.sm),

        // Voucher date
        InfoLabel(
          label: 'Fecha voucher',
          child: DatePicker(
            selected: _voucherDate,
            onChanged: (d) => setState(() => _voucherDate = d),
          ),
        ),

        const SizedBox(height: Spacing.sm),

        // Reference (voucher number)
        InfoLabel(
          label: 'Número de voucher',
          child: TextBox(
            controller: _referenceController,
            placeholder: 'Número de voucher',
          ),
        ),
      ],
    );
  }

  Widget _buildCheckFields(FluentThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Check number
        InfoLabel(
          label: 'Número de cheque',
          child: TextBox(
            controller: _checkNumberController,
            placeholder: 'Número de cheque',
          ),
        ),

        const SizedBox(height: Spacing.sm),

        // Effective date
        InfoLabel(
          label: 'Fecha efectiva (cobro)',
          child: DatePicker(
            selected: _effectiveDate,
            onChanged: (d) => setState(() => _effectiveDate = d),
          ),
        ),
      ],
    );
  }

  Widget _buildTransferFields(FluentThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reference
        InfoLabel(
          label: 'Referencia de transferencia',
          child: TextBox(
            controller: _referenceController,
            placeholder: 'Número de referencia',
          ),
        ),
      ],
    );
  }

  Widget _buildAdvanceForm(FluentThemeData theme) {
    if (widget.partnerId == null) {
      return _buildNoPartnerMessage(theme, 'anticipos');
    }

    final advancesAsync = ref.watch(availableAdvancesProvider(widget.partnerId!));

    return advancesAsync.when(
      loading: () => const Center(child: ProgressRing()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (advances) {
        if (advances.isEmpty) {
          return _buildNoDataMessage(
            theme,
            'No hay anticipos disponibles',
            'El cliente no tiene anticipos con saldo disponible',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoLabel(
              label: 'Anticipo a aplicar',
              child: ComboBox<AvailableAdvance>(
                isExpanded: true,
                value: _selectedAdvance,
                placeholder: const Text('Seleccione anticipo'),
                items: advances.map((a) {
                  final dateFormat = DateFormat('dd/MM/yyyy');
                  return ComboBoxItem(
                    value: a,
                    child: Row(
                      children: [
                        Expanded(child: Text(a.name)),
                        Text(
                          a.amountAvailable.toCurrency(),
                          style: TextStyle(color: Colors.green),
                        ),
                        const SizedBox(width: Spacing.xs),
                        Text(
                          dateFormat.format(a.date),
                          style: theme.typography.caption,
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (a) {
                  setState(() {
                    _selectedAdvance = a;
                    if (a != null) {
                      // Set amount to min of available and pending
                      final amountToApply = a.amountAvailable < widget.pendingAmount
                          ? a.amountAvailable
                          : widget.pendingAmount;
                      _amountController.text = amountToApply.toFixed(2);
                    }
                  });
                },
              ),
            ),

            if (_selectedAdvance != null) ...[
              const SizedBox(height: Spacing.sm),
              Container(
                padding: const EdgeInsets.all(Spacing.sm),
                decoration: BoxDecoration(
                  color: Colors.magenta.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.magenta.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(FluentIcons.info, size: 14, color: Colors.magenta),
                    const SizedBox(width: Spacing.xs),
                    Expanded(
                      child: Text(
                        'Disponible: ${_selectedAdvance!.amountAvailable.toCurrency()}',
                        style: theme.typography.body?.copyWith(
                          color: Colors.magenta,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: Spacing.sm),

            // Amount input
            InfoLabel(
              label: 'Monto a aplicar',
              child: TextBox(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Text('\$'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCreditNoteForm(FluentThemeData theme) {
    if (widget.partnerId == null) {
      return _buildNoPartnerMessage(theme, 'notas de crédito');
    }

    final creditNotesAsync =
        ref.watch(availableCreditNotesProvider(widget.partnerId!));

    return creditNotesAsync.when(
      loading: () => const Center(child: ProgressRing()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (creditNotes) {
        if (creditNotes.isEmpty) {
          return _buildNoDataMessage(
            theme,
            'No hay notas de crédito disponibles',
            'El cliente no tiene notas de crédito con saldo',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoLabel(
              label: 'Nota de crédito a aplicar',
              child: ComboBox<AvailableCreditNote>(
                isExpanded: true,
                value: _selectedCreditNote,
                placeholder: const Text('Seleccione nota de crédito'),
                items: creditNotes.map((nc) {
                  final dateFormat = DateFormat('dd/MM/yyyy');
                  return ComboBoxItem(
                    value: nc,
                    child: Row(
                      children: [
                        Expanded(child: Text(nc.name)),
                        Text(
                          nc.amountResidual.toCurrency(),
                          style: TextStyle(color: Colors.purple),
                        ),
                        if (nc.invoiceDate != null) ...[
                          const SizedBox(width: Spacing.xs),
                          Text(
                            dateFormat.format(nc.invoiceDate!),
                            style: theme.typography.caption,
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (nc) {
                  setState(() {
                    _selectedCreditNote = nc;
                    if (nc != null) {
                      // Set amount to min of available and pending
                      final amountToApply = nc.amountResidual < widget.pendingAmount
                          ? nc.amountResidual
                          : widget.pendingAmount;
                      _amountController.text = amountToApply.toFixed(2);
                    }
                  });
                },
              ),
            ),

            if (_selectedCreditNote != null) ...[
              const SizedBox(height: Spacing.sm),
              Container(
                padding: const EdgeInsets.all(Spacing.sm),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(FluentIcons.info, size: 14, color: Colors.purple),
                    const SizedBox(width: Spacing.xs),
                    Expanded(
                      child: Text(
                        'Saldo disponible: ${_selectedCreditNote!.amountResidual.toCurrency()}',
                        style: theme.typography.body?.copyWith(
                          color: Colors.purple,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: Spacing.sm),

            // Amount input
            InfoLabel(
              label: 'Monto a aplicar',
              child: TextBox(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Text('\$'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNoPartnerMessage(FluentThemeData theme, String type) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(FluentIcons.warning, color: Colors.orange),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              'Seleccione un cliente para ver $type disponibles',
              style: theme.typography.body?.copyWith(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataMessage(FluentThemeData theme, String title, String message) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: theme.inactiveColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(FluentIcons.info, size: 32, color: theme.inactiveColor),
          const SizedBox(height: Spacing.sm),
          Text(title, style: theme.typography.bodyStrong),
          Text(
            message,
            style: theme.typography.caption?.copyWith(color: theme.inactiveColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  bool _canAddPayment() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) return false;

    switch (_paymentType) {
      case PaymentLineType.payment:
        return _selectedJournal != null;
      case PaymentLineType.advance:
        return _selectedAdvance != null && amount <= _selectedAdvance!.amountAvailable;
      case PaymentLineType.creditNote:
        return _selectedCreditNote != null &&
            amount <= _selectedCreditNote!.amountResidual;
    }
  }

  void _addPayment() {
    final amount = double.tryParse(_amountController.text) ?? widget.pendingAmount;
    if (amount <= 0) return;

    final PaymentLine line;

    switch (_paymentType) {
      case PaymentLineType.payment:
        if (_selectedJournal == null) return;

        line = PaymentLine(
          id: -DateTime.now().millisecondsSinceEpoch, // Negative temp ID for local line
          type: PaymentLineType.payment,
          date: DateTime.now(),
          amount: amount,
          reference: _referenceController.text.isNotEmpty
              ? _referenceController.text
              : _checkNumberController.text.isNotEmpty
                  ? _checkNumberController.text
                  : null,
          journalId: _selectedJournal!.id,
          journalName: _selectedJournal!.name,
          journalType: _selectedJournal!.type,
          paymentMethodLineId: _selectedMethod?.id,
          paymentMethodCode: _selectedMethod?.code,
          paymentMethodName: _selectedMethod?.name,
          // Card fields
          cardType: _selectedJournal!.isCardJournal ? _cardType : null,
          cardBrandId: _selectedCardBrand?.id,
          cardBrandName: _selectedCardBrand?.name,
          cardDeadlineId: _selectedCardDeadline?.id,
          cardDeadlineName: _selectedCardDeadline?.name,
          loteId: _selectedCardLote?.id,
          loteName: _selectedCardLote?.name,
          voucherDate: _selectedJournal!.isCardJournal ? _voucherDate : null,
          // Check fields
          effectiveDate: _selectedMethod?.isCheck == true ? _effectiveDate : null,
        );
        break;

      case PaymentLineType.advance:
        if (_selectedAdvance == null) return;

        line = PaymentLine(
          id: -DateTime.now().millisecondsSinceEpoch, // Negative temp ID for local line
          type: PaymentLineType.advance,
          date: DateTime.now(),
          amount: amount,
          advanceId: _selectedAdvance!.id,
          advanceName: _selectedAdvance!.name,
          advanceAvailable: _selectedAdvance!.amountAvailable,
        );
        break;

      case PaymentLineType.creditNote:
        if (_selectedCreditNote == null) return;

        line = PaymentLine(
          id: -DateTime.now().millisecondsSinceEpoch, // Negative temp ID for local line
          type: PaymentLineType.creditNote,
          date: DateTime.now(),
          amount: amount,
          creditNoteId: _selectedCreditNote!.id,
          creditNoteName: _selectedCreditNote!.name,
          creditNoteAvailable: _selectedCreditNote!.amountResidual,
        );
        break;
    }

    widget.onAddPayment(line);

    // Clear inputs
    _amountController.clear();
    _referenceController.clear();
    _checkNumberController.clear();
    _selectedAdvance = null;
    _selectedCreditNote = null;
    _selectedCardBrand = null;
    _selectedCardDeadline = null;
    _selectedCardLote = null;
  }
}

/// Chip para selección de tipo de pago
class _PaymentTypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback? onTap;

  const _PaymentTypeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.xs,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.2)
              : isDisabled
                  ? Colors.grey.withValues(alpha: 0.1)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? color
                : isDisabled
                    ? Colors.grey.withValues(alpha: 0.3)
                    : Colors.grey.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? color
                  : isDisabled
                      ? Colors.grey
                      : null,
            ),
            const SizedBox(width: Spacing.xxs),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? color
                    : isDisabled
                        ? Colors.grey
                        : null,
                fontWeight: isSelected ? FontWeight.bold : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
