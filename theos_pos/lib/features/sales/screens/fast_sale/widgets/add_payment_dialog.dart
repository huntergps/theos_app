import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:uuid/uuid.dart';

import '../../../../../core/theme/spacing.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper, PartnerBank, CreditIssue;
import '../../../../advances/providers/advance_providers.dart';
import '../../../../advances/services/advance_service.dart';
import '../../../providers/service_providers.dart';
import '../../../../../shared/utils/formatting_utils.dart';
import 'pos_payment_providers.dart';
import 'quick_amount_button.dart';
import '../../../../../shared/widgets/dialogs/copyable_info_bar.dart';

// ============================================================
// PAYMENT DIALOG WIDGET
// ============================================================

/// Dialog for adding payment lines
class AddPaymentDialogContent extends ConsumerStatefulWidget {
  final FluentThemeData theme;
  final List<AvailableJournal> journals;
  final double pendingAmount;
  final int orderId;
  final int? partnerId; // Partner ID for creating partner bank accounts
  final void Function(PaymentLine) onAddLine;
  final ProviderListenable<AsyncValue<List<AvailableAdvance>>> advancesProvider;
  final ProviderListenable<AsyncValue<List<AvailableCreditNote>>> creditNotesProvider;
  final ProviderListenable<AsyncValue<List<PartnerBank>>> partnerBanksProvider;
  final ProviderListenable<AsyncValue<List<AvailableBank>>> banksProvider;
  final WidgetRef ref;

  const AddPaymentDialogContent({
    super.key,
    required this.theme,
    required this.journals,
    required this.pendingAmount,
    required this.orderId,
    this.partnerId,
    required this.onAddLine,
    required this.advancesProvider,
    required this.creditNotesProvider,
    required this.partnerBanksProvider,
    required this.banksProvider,
    required this.ref,
  });

  @override
  ConsumerState<AddPaymentDialogContent> createState() => AddPaymentDialogContentState();
}

class AddPaymentDialogContentState extends ConsumerState<AddPaymentDialogContent> {
  // Controllers
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _cashTenderedController = TextEditingController();

  // Line type
  PaymentLineType _lineType = PaymentLineType.payment;

  // Payment fields
  AvailableJournal? _selectedJournal;
  PaymentMethod? _selectedMethod;
  DateTime _paymentDate = DateTime.now();

  // Card fields
  AvailableBank? _selectedBank;
  CardBrand? _selectedCardBrand;
  CardDeadline? _selectedCardDeadline;
  CardLote? _selectedLote;
  DateTime _voucherDate = DateTime.now();

  // Cheque fields
  PartnerBank? _selectedPartnerBank;
  DateTime _effectiveDate = DateTime.now();
  DateTime _chequeDate = DateTime.now();

  // Advance/Credit note fields
  AvailableAdvance? _selectedAdvance;
  AvailableCreditNote? _selectedCreditNote;

  // Computed visibility helpers
  bool get _isCashJournal => _selectedJournal?.isCash ?? false;
  bool get _isBankJournal => _selectedJournal?.isBank ?? false;
  bool get _isCardJournal => _selectedJournal?.isCardJournal ?? false;
  bool get _isCardPayment => _selectedMethod?.isCard ?? false;
  bool get _isChequePayment => _selectedMethod?.isCheck ?? false;
  bool get _isDepositChequePayment => _selectedMethod?.isDepositCheque ?? false;
  bool get _isTransferPayment => _selectedMethod?.isTransfer ?? false;
  bool get _isManualPayment => _selectedMethod?.isCash ?? false; // code == 'manual'
  // Card fields (Lote, Marca, Plazo) only for card journals like DATAFAST
  // Banks with card payment methods don't need these details
  bool get _showCardFields => _lineType == PaymentLineType.payment && _isCardPayment && _isCardJournal;
  // Bank card payments (TC/TD on bank journals) - simpler form without Lote/Marca
  bool get _showBankCardFields => _lineType == PaymentLineType.payment && _isCardPayment && !_isCardJournal;
  bool get _showChequeFields => _lineType == PaymentLineType.payment && _isChequePayment;
  // Deposit with check - just needs reference number (like transfer)
  bool get _showDepositChequeFields => _lineType == PaymentLineType.payment && _isDepositChequePayment;
  bool get _showTransferFields => _lineType == PaymentLineType.payment && _isTransferPayment;
  bool get _showCashFields => _lineType == PaymentLineType.payment && _isCashJournal && _isManualPayment;
  // Bank deposit (manual payment on bank journal) - requires date and reference
  bool get _showBankDepositFields => _lineType == PaymentLineType.payment && _isBankJournal && _isManualPayment;

  CardType? get _derivedCardType {
    final code = _selectedMethod?.code ?? '';
    if (code.contains('credit')) return CardType.credit;
    if (code.contains('debit')) return CardType.debit;
    return null;
  }

  @override
  void initState() {
    super.initState();
    // Start with empty amount - user will use quick buttons or type manually
    // The placeholder will show the pending amount as reference
    _amountController.text = '';
    if (widget.journals.isNotEmpty) {
      _selectedJournal = widget.journals.first;
      if (_selectedJournal!.paymentMethods.isNotEmpty) {
        _selectedMethod = _selectedJournal!.paymentMethods.first;
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _cashTenderedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final advancesAsync = ref.watch(widget.advancesProvider);
    final creditNotesAsync = ref.watch(widget.creditNotesProvider);

    return ContentDialog(
      title: Row(
        children: [
          Icon(FluentIcons.money, size: 20, color: widget.theme.accentColor),
          const SizedBox(width: Spacing.sm),
          const Text('Agregar Pago'),
        ],
      ),
      constraints: const BoxConstraints(maxWidth: 650, maxHeight: 700),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pending amount info
            Container(
              padding: const EdgeInsets.all(Spacing.sm),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Pendiente:', style: widget.theme.typography.body),
                  Text(
                    widget.pendingAmount.toCurrency(),
                    style: widget.theme.typography.bodyStrong?.copyWith(color: Colors.blue),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.md),

            // Line type selector
            _buildLineTypeSelector(advancesAsync, creditNotesAsync),
            const SizedBox(height: Spacing.sm),

            // Content based on line type
            if (_lineType == PaymentLineType.payment)
              _buildPaymentFields()
            else if (_lineType == PaymentLineType.advance)
              _buildAdvanceFields(advancesAsync)
            else if (_lineType == PaymentLineType.creditNote)
              _buildCreditNoteFields(creditNotesAsync),

            // Validation alerts
            _buildValidationAlerts(),
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isValid ? _addPaymentLine : null,
          child: Text(_getButtonText()),
        ),
      ],
    );
  }

  Widget _buildLineTypeSelector(
    AsyncValue<List<AvailableAdvance>> advancesAsync,
    AsyncValue<List<AvailableCreditNote>> creditNotesAsync,
  ) {
    final hasAdvances = advancesAsync.when(
      data: (list) => list.isNotEmpty,
      loading: () => false,
      error: (_, _) => false,
    );
    final hasCreditNotes = creditNotesAsync.when(
      data: (list) => list.isNotEmpty,
      loading: () => false,
      error: (_, _) => false,
    );

    return InfoLabel(
      label: 'Tipo de abono',
      child: ComboBox<PaymentLineType>(
        isExpanded: true,
        value: _lineType,
        items: [
          ComboBoxItem(
            value: PaymentLineType.payment,
            child: Row(
              children: [
                Icon(FluentIcons.money, size: 14, color: Colors.green),
                const SizedBox(width: Spacing.xs),
                const Text('Pago directo'),
              ],
            ),
          ),
          ComboBoxItem(
            value: PaymentLineType.advance,
            enabled: hasAdvances,
            child: Row(
              children: [
                Icon(FluentIcons.circle_dollar, size: 14,
                     color: hasAdvances ? Colors.magenta : widget.theme.inactiveColor),
                const SizedBox(width: Spacing.xs),
                Text('Anticipo',
                     style: TextStyle(color: hasAdvances ? null : widget.theme.inactiveColor)),
                if (!hasAdvances)
                  Text(' (sin disponibles)',
                       style: widget.theme.typography.caption?.copyWith(color: widget.theme.inactiveColor)),
              ],
            ),
          ),
          ComboBoxItem(
            value: PaymentLineType.creditNote,
            enabled: hasCreditNotes,
            child: Row(
              children: [
                Icon(FluentIcons.page_list, size: 14,
                     color: hasCreditNotes ? Colors.purple : widget.theme.inactiveColor),
                const SizedBox(width: Spacing.xs),
                Text('Nota de cr\u00e9dito',
                     style: TextStyle(color: hasCreditNotes ? null : widget.theme.inactiveColor)),
                if (!hasCreditNotes)
                  Text(' (sin disponibles)',
                       style: widget.theme.typography.caption?.copyWith(color: widget.theme.inactiveColor)),
              ],
            ),
          ),
        ],
        onChanged: (type) {
          if (type != null && type != _lineType) {
            setState(() {
              _lineType = type;
              // Reset selections for the new type
              _selectedAdvance = null;
              _selectedCreditNote = null;
              // Don't reset amount here - let user keep their entered amount
              // Amount will be auto-set when selecting specific advance/credit note
            });
          }
        },
      ),
    );
  }

  Widget _buildPaymentFields() {
    // Use reactive journals list from provider (updated via WebSocket)
    final journalsAsync = ref.watch(posAvailableJournalsProvider);
    final journals = journalsAsync.when(
      data: (data) => data,
      loading: () => widget.journals,
      error: (_, _) => widget.journals,
    );

    // Ensure _selectedJournal reference is from current journals list
    // This is needed because ComboBox uses object identity for value matching
    if (_selectedJournal != null && journals.isNotEmpty) {
      final currentJournal = journals.where((j) => j.id == _selectedJournal!.id).firstOrNull;
      if (currentJournal != null) {
        _selectedJournal = currentJournal;
        // Also update method reference
        if (_selectedMethod != null) {
          _selectedMethod = currentJournal.paymentMethods
                  .where((m) => m.id == _selectedMethod!.id)
                  .firstOrNull ??
              (currentJournal.paymentMethods.isNotEmpty
                  ? currentJournal.paymentMethods.first
                  : null);
        }
      } else if (journals.isNotEmpty) {
        // Journal was deleted, select first available
        _selectedJournal = journals.first;
        _selectedMethod = _selectedJournal!.paymentMethods.isNotEmpty
            ? _selectedJournal!.paymentMethods.first
            : null;
      }
    } else if (_selectedJournal == null && journals.isNotEmpty) {
      // No journal selected yet, select first
      _selectedJournal = journals.first;
      _selectedMethod = _selectedJournal!.paymentMethods.isNotEmpty
          ? _selectedJournal!.paymentMethods.first
          : null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Journal selector
        InfoLabel(
          label: 'Diario de pago',
          child: ComboBox<AvailableJournal>(
            isExpanded: true,
            value: _selectedJournal,
            items: journals.map((j) => ComboBoxItem(
              value: j,
              child: Row(
                children: [
                  Icon(
                    j.isCash ? FluentIcons.money :
                    j.isCardJournal ? FluentIcons.payment_card : FluentIcons.bank,
                    size: 14,
                  ),
                  const SizedBox(width: Spacing.xs),
                  Text(j.name),
                ],
              ),
            )).toList(),
            onChanged: (j) {
              setState(() {
                _selectedJournal = j;
                _selectedMethod = j?.paymentMethods.isNotEmpty == true
                    ? j!.paymentMethods.first
                    : null;
                _selectedBank = null;
                _selectedCardBrand = null;
                _selectedCardDeadline = null;
                _selectedLote = null;
                _selectedPartnerBank = null;
              });
            },
          ),
        ),

        // Payment method selector
        if (_selectedJournal != null && _selectedJournal!.paymentMethods.length > 1) ...[
          const SizedBox(height: Spacing.sm),
          InfoLabel(
            label: 'Forma de pago',
            child: ComboBox<PaymentMethod>(
              isExpanded: true,
              value: _selectedMethod,
              items: _selectedJournal!.paymentMethods.map((m) => ComboBoxItem(
                value: m,
                child: Text(m.displayName),
              )).toList(),
              onChanged: (m) {
                setState(() {
                  _selectedMethod = m;
                  _selectedCardDeadline = null;
                });
              },
            ),
          ),
        ],

        const SizedBox(height: Spacing.sm),

        // Amount input with '=' button to fill pending amount
        InfoLabel(
          label: 'Monto a pagar',
          child: Row(
            children: [
              Expanded(
                child: TextBox(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  placeholder: 'Pendiente: ${widget.pendingAmount.toCurrency()}',
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text('\$'),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: Spacing.xs),
              Tooltip(
                message: 'Pagar todo el pendiente',
                child: IconButton(
                  icon: const Icon(FluentIcons.calculator_equal_to, size: 18),
                  onPressed: () {
                    _amountController.text = widget.pendingAmount.toFixed(2);
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
        ),

        // Cash section
        if (_showCashFields) ...[
          const SizedBox(height: Spacing.sm),
          _buildCashSection(),
        ],

        // Card section (for card journals like DATAFAST)
        if (_showCardFields) ...[
          const SizedBox(height: Spacing.sm),
          _buildCardSection(),
        ],

        // Bank card payment section (simpler form for TC/TD on bank journals)
        if (_showBankCardFields) ...[
          const SizedBox(height: Spacing.sm),
          _buildBankCardSection(),
        ],

        // Cheque section
        if (_showChequeFields) ...[
          const SizedBox(height: Spacing.sm),
          _buildChequeSection(),
        ],

        // Transfer section
        if (_showTransferFields) ...[
          const SizedBox(height: Spacing.sm),
          _buildTransferSection(),
        ],

        // Deposit cheque section (bank deposit with check - just needs reference)
        if (_showDepositChequeFields) ...[
          const SizedBox(height: Spacing.sm),
          _buildDepositChequeSection(),
        ],

        // Bank deposit section (manual payment on bank journal - requires date and reference)
        if (_showBankDepositFields) ...[
          const SizedBox(height: Spacing.sm),
          _buildBankDepositSection(),
        ],

        // Reference (for generic payments - not bank deposits which have their own section)
        if (!_showCashFields && !_showCardFields && !_showBankCardFields && !_showChequeFields && !_showTransferFields && !_showDepositChequeFields && !_showBankDepositFields) ...[
          const SizedBox(height: Spacing.sm),
          InfoLabel(
            label: 'Referencia (opcional)',
            child: TextBox(
              controller: _referenceController,
              placeholder: 'N\u00famero de comprobante',
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCashSection() {
    final amount = double.tryParse(_amountController.text) ?? widget.pendingAmount;
    final tendered = double.tryParse(_cashTenderedController.text) ?? 0;
    final change = tendered - amount;

    return Container(
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Efectivo', style: widget.theme.typography.bodyStrong?.copyWith(color: Colors.green.dark)),
          const SizedBox(height: Spacing.sm),
          // Quick amounts - these ADD to the current tendered amount
          Wrap(
            spacing: Spacing.xs,
            runSpacing: Spacing.xs,
            children: [
              QuickAmountButton(label: 'Exacto', amount: amount, isExact: true, onTap: () {
                _cashTenderedController.text = amount.toFixed(2);
                // Also set the payment amount to match
                _amountController.text = amount.toFixed(2);
                setState(() {});
              }),
              ...[1.0, 5.0, 10.0, 20.0, 50.0, 100.0].map((a) => QuickAmountButton(
                label: '+\$${a.toInt()}',
                amount: a,
                onTap: () {
                  // SUM to existing tendered amount
                  final currentTendered = double.tryParse(_cashTenderedController.text) ?? 0;
                  final newTendered = currentTendered + a;
                  _cashTenderedController.text = newTendered.toFixed(2);
                  // Also update the payment amount (cap at pending)
                  final cappedAmount = newTendered > widget.pendingAmount ? widget.pendingAmount : newTendered;
                  _amountController.text = cappedAmount.toFixed(2);
                  setState(() {});
                },
              )),
              // Clear button
              QuickAmountButton(label: 'C', amount: 0, isExact: false, onTap: () {
                _cashTenderedController.text = '';
                _amountController.text = '';
                setState(() {});
              }),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Row(
            children: [
              Expanded(
                child: InfoLabel(
                  label: 'Recibido',
                  child: TextBox(
                    controller: _cashTenderedController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    prefix: const Padding(padding: EdgeInsets.only(left: 8), child: Text('\$')),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: InfoLabel(
                  label: 'Cambio',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: change >= 0 ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      change.toCurrency(),
                      style: widget.theme.typography.body?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: change >= 0 ? Colors.green.dark : Colors.red.dark,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardSection() {
    final journalId = _selectedJournal?.id;
    if (journalId == null) return const SizedBox.shrink();

    final banksAsync = ref.watch(widget.banksProvider);
    final brandsAsync = ref.watch(posCardBrandsByJournalProvider(journalId));
    final lotesAsync = ref.watch(posOpenLotesProvider(journalId));
    final cardType = _derivedCardType;
    final deadlinesAsync = cardType != null
        ? ref.watch(posCardDeadlinesProvider((journalId: journalId, cardType: cardType)))
        : const AsyncValue<List<CardDeadline>>.data([]);

    // Auto-select default card brand from journal
    if (_selectedCardBrand == null && _selectedJournal?.defaultCardBrandId != null) {
      brandsAsync.whenData((brands) {
        final defaultBrand = brands.where((b) => b.id == _selectedJournal!.defaultCardBrandId).firstOrNull;
        if (defaultBrand != null && _selectedCardBrand == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedCardBrand = defaultBrand);
          });
        }
      });
    }

    // Auto-select default deadline from journal
    if (_selectedCardDeadline == null && cardType != null) {
      final defaultDeadlineId = _selectedJournal?.getDefaultDeadlineId(cardType);
      if (defaultDeadlineId != null) {
        deadlinesAsync.whenData((deadlines) {
          final defaultDeadline = deadlines.where((d) => d.id == defaultDeadlineId).firstOrNull;
          if (defaultDeadline != null && _selectedCardDeadline == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedCardDeadline = defaultDeadline);
            });
          }
        });
      }
    }

    return Container(
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tarjeta ${cardType == CardType.credit ? 'Cr\u00e9dito' : 'D\u00e9bito'}',
               style: widget.theme.typography.bodyStrong?.copyWith(color: Colors.blue.dark)),
          const SizedBox(height: Spacing.sm),
          // Bank and voucher (bank is wider to fit long names)
          Row(children: [
            Expanded(
              flex: 3,
              child: banksAsync.when(
                loading: () => const ProgressRing(),
                error: (_, _) => const Text('Error'),
                data: (banks) => InfoLabel(
                  label: 'Banco emisor',
                  child: ComboBox<AvailableBank>(
                    isExpanded: true,
                    placeholder: const Text('Seleccione...'),
                    value: _selectedBank,
                    items: banks.map((b) => ComboBoxItem(
                      value: b,
                      child: Text(b.name, overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (b) => setState(() => _selectedBank = b),
                  ),
                ),
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              flex: 2,
              child: InfoLabel(
                label: 'N\u00b0 Voucher *',
                child: TextBox(controller: _referenceController, placeholder: 'Requerido'),
              ),
            ),
          ]),
          const SizedBox(height: Spacing.sm),
          // Lote and date
          Row(children: [
            Expanded(child: lotesAsync.when(
              loading: () => const ProgressRing(),
              error: (_, _) => const Text('Error'),
              data: (lotes) => InfoLabel(
                label: 'Lote *',
                child: Row(
                  children: [
                    Expanded(
                      child: ComboBox<CardLote>(
                        isExpanded: true,
                        placeholder: Text(lotes.isEmpty ? 'Crear nuevo...' : 'Seleccione...'),
                        value: _selectedLote,
                        items: lotes.map((l) => ComboBoxItem(value: l, child: Text(l.displayName))).toList(),
                        onChanged: (l) => setState(() => _selectedLote = l),
                      ),
                    ),
                    const SizedBox(width: Spacing.xs),
                    Tooltip(
                      message: 'Crear nuevo lote',
                      child: IconButton(
                        icon: const Icon(FluentIcons.add, size: 14),
                        onPressed: () async {
                          final paymentService = ref.read(paymentServiceProvider);
                          final newLote = await paymentService.createLote(journalId);
                          if (!mounted) return;
                          if (newLote != null) {
                            // Refresh the lotes provider and select the new one
                            ref.invalidate(posOpenLotesProvider(journalId));
                            setState(() => _selectedLote = newLote);
                            CopyableInfoBar.showSuccess(
                              context,
                              title: 'Lote creado',
                              message: newLote.displayName,
                            );
                          } else {
                            CopyableInfoBar.showError(
                              context,
                              title: 'Error',
                              message: 'No se pudo crear el lote',
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            )),
            const SizedBox(width: Spacing.sm),
            Expanded(child: InfoLabel(
              label: 'Fecha voucher *',
              child: DatePicker(
                selected: _voucherDate,
                onChanged: (d) => setState(() => _voucherDate = d),
              ),
            )),
          ]),
          const SizedBox(height: Spacing.sm),
          // Brand and deadline
          Row(children: [
            Expanded(child: brandsAsync.when(
              loading: () => const ProgressRing(),
              error: (_, _) => const Text('Error'),
              data: (brands) => InfoLabel(
                label: 'Marca *',
                child: ComboBox<CardBrand>(
                  isExpanded: true,
                  placeholder: const Text('Seleccione...'),
                  value: _selectedCardBrand,
                  items: brands.map((b) => ComboBoxItem(value: b, child: Text(b.name))).toList(),
                  onChanged: (b) => setState(() => _selectedCardBrand = b),
                ),
              ),
            )),
            const SizedBox(width: Spacing.sm),
            if (cardType == CardType.credit)
              Expanded(child: deadlinesAsync.when(
                loading: () => const ProgressRing(),
                error: (_, _) => const Text('Error'),
                data: (deadlines) => InfoLabel(
                  label: 'Plazo *',
                  child: ComboBox<CardDeadline>(
                    isExpanded: true,
                    placeholder: const Text('Seleccione...'),
                    value: _selectedCardDeadline,
                    items: deadlines.map((d) => ComboBoxItem(value: d, child: Text(d.name))).toList(),
                    onChanged: (d) => setState(() => _selectedCardDeadline = d),
                  ),
                ),
              ))
            else
              const Expanded(child: SizedBox.shrink()),
          ]),
        ],
      ),
    );
  }

  Widget _buildChequeSection() {
    final partnerBanksAsync = ref.watch(widget.partnerBanksProvider);

    return Container(
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cheque', style: widget.theme.typography.bodyStrong?.copyWith(color: Colors.teal.dark)),
          const SizedBox(height: Spacing.sm),
          Row(children: [
            Expanded(child: InfoLabel(
              label: 'N\u00b0 Cheque *',
              child: TextBox(controller: _referenceController, placeholder: 'Requerido'),
            )),
            const SizedBox(width: Spacing.sm),
            Expanded(child: partnerBanksAsync.when(
              loading: () => const ProgressRing(),
              error: (_, _) => const Text('Error'),
              data: (banks) => InfoLabel(
                label: 'Cuenta cliente',
                child: Row(
                  children: [
                    Expanded(
                      child: ComboBox<PartnerBank>(
                        isExpanded: true,
                        placeholder: const Text('Seleccione...'),
                        value: _selectedPartnerBank,
                        items: banks.map((b) => ComboBoxItem(value: b, child: Text(b.displayName))).toList(),
                        onChanged: (b) => setState(() => _selectedPartnerBank = b),
                      ),
                    ),
                    const SizedBox(width: Spacing.xs),
                    Tooltip(
                      message: 'Crear cuenta bancaria',
                      child: IconButton(
                        icon: const Icon(FluentIcons.add, size: 16),
                        onPressed: () => _showCreatePartnerBankDialog(),
                      ),
                    ),
                  ],
                ),
              ),
            )),
          ]),
          const SizedBox(height: Spacing.sm),
          Row(children: [
            Expanded(child: InfoLabel(
              label: 'Fecha cheque *',
              child: DatePicker(
                selected: _chequeDate,
                onChanged: (d) => setState(() => _chequeDate = d),
              ),
            )),
            const SizedBox(width: Spacing.sm),
            Expanded(child: InfoLabel(
              label: 'Fecha efectiva *',
              child: DatePicker(
                selected: _effectiveDate,
                onChanged: (d) => setState(() => _effectiveDate = d),
              ),
            )),
          ]),
          if (_effectiveDate.isAfter(_chequeDate)) ...[
            const SizedBox(height: Spacing.xs),
            Container(
              padding: const EdgeInsets.all(Spacing.xs),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(children: [
                Icon(FluentIcons.warning, size: 12, color: Colors.orange),
                const SizedBox(width: Spacing.xs),
                Text('Cheque posfechado', style: widget.theme.typography.caption?.copyWith(color: Colors.orange)),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  /// Shows dialog to create a new partner bank account
  Future<void> _showCreatePartnerBankDialog() async {
    final partnerId = widget.partnerId;
    if (partnerId == null) {
      CopyableInfoBar.showWarning(
        context,
        title: 'Error',
        message: 'No hay cliente seleccionado',
      );
      return;
    }

    final accNumberController = TextEditingController();
    AvailableBank? selectedBank;

    final banksAsync = ref.read(widget.banksProvider);
    final banks = banksAsync.value ?? [];

    final result = await showDialog<PartnerBank?>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Nueva Cuenta Bancaria'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoLabel(
                label: 'N\u00b0 Cuenta *',
                child: TextBox(
                  controller: accNumberController,
                  placeholder: 'N\u00famero de cuenta',
                  autofocus: true,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              InfoLabel(
                label: 'Banco',
                child: StatefulBuilder(
                  builder: (context, setDialogState) => ComboBox<AvailableBank>(
                    isExpanded: true,
                    placeholder: const Text('Seleccione banco...'),
                    value: selectedBank,
                    items: banks.map((b) => ComboBoxItem(
                      value: b,
                      child: Text(b.name),
                    )).toList(),
                    onChanged: (b) => setDialogState(() => selectedBank = b),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          Button(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(context).pop(null),
          ),
          FilledButton(
            child: const Text('Crear'),
            onPressed: () async {
              final accNumber = accNumberController.text.trim();
              if (accNumber.isEmpty) {
                CopyableInfoBar.showWarning(
                  context,
                  title: 'Error',
                  message: 'El número de cuenta es obligatorio',
                );
                return;
              }

              // Create the partner bank
              final advanceService = ref.read(advanceServiceProvider);
              final newBank = await advanceService.createPartnerBank(
                partnerId: partnerId,
                accNumber: accNumber,
                bankId: selectedBank?.id,
                bankName: selectedBank?.name,
              );

              if (!context.mounted) return;
              Navigator.of(context).pop(newBank);
            },
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      // Refresh the partner banks list and select the new one
      ref.invalidate(posPartnerBanksProvider);
      setState(() {
        _selectedPartnerBank = result;
      });

      CopyableInfoBar.showSuccess(
        context,
        title: 'Cuenta creada',
        message: 'Cuenta ${result.displayName} creada exitosamente',
      );
    }
  }

  Widget _buildTransferSection() {
    return Container(
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Transferencia', style: widget.theme.typography.bodyStrong?.copyWith(color: Colors.purple.dark)),
          const SizedBox(height: Spacing.sm),
          Row(children: [
            Expanded(child: InfoLabel(
              label: 'Fecha *',
              child: DatePicker(
                selected: _paymentDate,
                onChanged: (d) => setState(() => _paymentDate = d),
              ),
            )),
            const SizedBox(width: Spacing.sm),
            Expanded(child: InfoLabel(
              label: 'N\u00b0 Referencia *',
              child: TextBox(controller: _referenceController, placeholder: 'Requerido'),
            )),
          ]),
        ],
      ),
    );
  }

  /// Deposit cheque section - bank deposit using a check
  /// Only needs deposit reference number, not full check info
  Widget _buildDepositChequeSection() {
    return Container(
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dep\u00f3sito Bancario Cheque', style: widget.theme.typography.bodyStrong?.copyWith(color: Colors.teal.dark)),
          const SizedBox(height: Spacing.sm),
          Row(children: [
            Expanded(child: InfoLabel(
              label: 'Fecha *',
              child: DatePicker(
                selected: _paymentDate,
                onChanged: (d) => setState(() => _paymentDate = d),
              ),
            )),
            const SizedBox(width: Spacing.sm),
            Expanded(child: InfoLabel(
              label: 'N\u00b0 Dep\u00f3sito *',
              child: TextBox(controller: _referenceController, placeholder: 'Requerido'),
            )),
          ]),
        ],
      ),
    );
  }

  /// Bank deposit section - manual payment on bank journal
  /// Requires date and reference number (like Odoo)
  Widget _buildBankDepositSection() {
    return Container(
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dep\u00f3sito Bancario', style: widget.theme.typography.bodyStrong?.copyWith(color: Colors.blue.dark)),
          const SizedBox(height: Spacing.sm),
          Row(children: [
            Expanded(child: InfoLabel(
              label: 'Fecha *',
              child: DatePicker(
                selected: _paymentDate,
                onChanged: (d) => setState(() => _paymentDate = d),
              ),
            )),
            const SizedBox(width: Spacing.sm),
            Expanded(child: InfoLabel(
              label: 'N\u00b0 Referencia *',
              child: TextBox(controller: _referenceController, placeholder: 'Requerido'),
            )),
          ]),
        ],
      ),
    );
  }

  /// Bank card payment section - simpler form for TC/TD on bank journals
  /// Does not require Lote/Marca/Plazo like card journals (DATAFAST)
  Widget _buildBankCardSection() {
    final isCredit = _derivedCardType == CardType.credit;
    final title = isCredit ? 'Tarjeta Cr\u00e9dito (Banco)' : 'Tarjeta D\u00e9bito (Banco)';

    return Container(
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: widget.theme.typography.bodyStrong?.copyWith(color: Colors.blue.dark)),
          const SizedBox(height: Spacing.sm),
          Row(children: [
            Expanded(child: InfoLabel(
              label: 'N\u00b0 Voucher *',
              child: TextBox(
                controller: _referenceController,
                placeholder: 'Requerido',
              ),
            )),
            const SizedBox(width: Spacing.sm),
            Expanded(child: InfoLabel(
              label: 'Fecha voucher *',
              child: DatePicker(
                selected: _voucherDate,
                onChanged: (d) => setState(() => _voucherDate = d),
              ),
            )),
          ]),
        ],
      ),
    );
  }

  Widget _buildAdvanceFields(AsyncValue<List<AvailableAdvance>> advancesAsync) {
    return advancesAsync.when(
      loading: () => const Center(child: ProgressRing()),
      error: (e, _) => Text('Error: $e'),
      data: (advances) => Container(
        padding: const EdgeInsets.all(Spacing.sm),
        decoration: BoxDecoration(
          color: Colors.magenta.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.magenta.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Aplicar Anticipo', style: widget.theme.typography.bodyStrong?.copyWith(color: Colors.magenta.dark)),
            const SizedBox(height: Spacing.sm),
            InfoLabel(
              label: 'Anticipo disponible *',
              child: ComboBox<AvailableAdvance>(
                isExpanded: true,
                placeholder: const Text('Seleccione...'),
                value: _selectedAdvance,
                items: advances.map((a) => ComboBoxItem(
                  value: a,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(a.name, overflow: TextOverflow.ellipsis)),
                      Text(a.amountAvailable.toCurrency(),
                           style: TextStyle(color: Colors.green.dark, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )).toList(),
                onChanged: (a) {
                  setState(() {
                    _selectedAdvance = a;
                    if (a != null) {
                      final autoAmount = a.amountAvailable < widget.pendingAmount ? a.amountAvailable : widget.pendingAmount;
                      _amountController.text = autoAmount.toFixed(2);
                    }
                  });
                },
              ),
            ),
            if (_selectedAdvance != null) ...[
              const SizedBox(height: Spacing.sm),
              Row(children: [
                Expanded(child: Container(
                  padding: const EdgeInsets.all(Spacing.sm),
                  decoration: BoxDecoration(color: Colors.magenta.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Disponible', style: widget.theme.typography.caption),
                    Text(_selectedAdvance!.amountAvailable.toCurrency(),
                         style: widget.theme.typography.bodyStrong?.copyWith(color: Colors.magenta.dark)),
                  ]),
                )),
                const SizedBox(width: Spacing.sm),
                Expanded(child: InfoLabel(
                  label: 'Monto a aplicar',
                  child: TextBox(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    prefix: const Padding(padding: EdgeInsets.only(left: 8), child: Text('\$')),
                    onChanged: (_) => setState(() {}),
                  ),
                )),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCreditNoteFields(AsyncValue<List<AvailableCreditNote>> creditNotesAsync) {
    return creditNotesAsync.when(
      loading: () => const Center(child: ProgressRing()),
      error: (e, _) => Text('Error: $e'),
      data: (creditNotes) => Container(
        padding: const EdgeInsets.all(Spacing.sm),
        decoration: BoxDecoration(
          color: Colors.purple.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Aplicar Nota de Cr\u00e9dito', style: widget.theme.typography.bodyStrong?.copyWith(color: Colors.purple.dark)),
            const SizedBox(height: Spacing.sm),
            InfoLabel(
              label: 'Nota de cr\u00e9dito *',
              child: ComboBox<AvailableCreditNote>(
                isExpanded: true,
                placeholder: const Text('Seleccione...'),
                value: _selectedCreditNote,
                items: creditNotes.map((nc) => ComboBoxItem(
                  value: nc,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(nc.name, overflow: TextOverflow.ellipsis)),
                      Text(nc.amountResidual.toCurrency(),
                           style: TextStyle(color: Colors.green.dark, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )).toList(),
                onChanged: (nc) {
                  setState(() {
                    _selectedCreditNote = nc;
                    if (nc != null) {
                      final autoAmount = nc.amountResidual < widget.pendingAmount ? nc.amountResidual : widget.pendingAmount;
                      _amountController.text = autoAmount.toFixed(2);
                    }
                  });
                },
              ),
            ),
            if (_selectedCreditNote != null) ...[
              const SizedBox(height: Spacing.sm),
              Row(children: [
                Expanded(child: Container(
                  padding: const EdgeInsets.all(Spacing.sm),
                  decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Saldo NC', style: widget.theme.typography.caption),
                    Text(_selectedCreditNote!.amountResidual.toCurrency(),
                         style: widget.theme.typography.bodyStrong?.copyWith(color: Colors.purple.dark)),
                  ]),
                )),
                const SizedBox(width: Spacing.sm),
                Expanded(child: InfoLabel(
                  label: 'Monto a aplicar',
                  child: TextBox(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    prefix: const Padding(padding: EdgeInsets.only(left: 8), child: Text('\$')),
                    onChanged: (_) => setState(() {}),
                  ),
                )),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildValidationAlerts() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final alerts = <Widget>[];

    if (_lineType == PaymentLineType.advance && _selectedAdvance != null) {
      if (amount > _selectedAdvance!.amountAvailable) {
        alerts.add(_buildAlert('El monto excede el disponible del anticipo', Colors.orange));
      }
    }
    if (_lineType == PaymentLineType.creditNote && _selectedCreditNote != null) {
      if (amount > _selectedCreditNote!.amountResidual) {
        alerts.add(_buildAlert('El monto excede el saldo de la nota de cr\u00e9dito', Colors.orange));
      }
    }

    if (alerts.isEmpty) return const SizedBox.shrink();
    return Column(children: [const SizedBox(height: Spacing.sm), ...alerts]);
  }

  Widget _buildAlert(String message, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.xs),
      padding: const EdgeInsets.all(Spacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(FluentIcons.warning, size: 14, color: color),
        const SizedBox(width: Spacing.xs),
        Expanded(child: Text(message, style: widget.theme.typography.caption?.copyWith(color: color))),
      ]),
    );
  }

  bool get _isValid {
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) return false;

    switch (_lineType) {
      case PaymentLineType.payment:
        if (_selectedJournal == null || _selectedMethod == null) return false;
        if (_showCardFields) {
          // Full card journal (DATAFAST) - requires Lote, Marca, Plazo
          if (_referenceController.text.isEmpty || _selectedLote == null || _selectedCardBrand == null) return false;
          if (_derivedCardType == CardType.credit && _selectedCardDeadline == null) return false;
        } else if (_showBankCardFields) {
          // Bank card payment - only requires voucher number and date
          if (_referenceController.text.isEmpty) return false;
        } else if (_showChequeFields) {
          if (_referenceController.text.isEmpty) return false;
        } else if (_showTransferFields) {
          if (_referenceController.text.isEmpty) return false;
        } else if (_showDepositChequeFields) {
          if (_referenceController.text.isEmpty) return false;
        } else if (_showBankDepositFields) {
          // Bank deposit (manual on bank journal) - requires reference
          if (_referenceController.text.isEmpty) return false;
        }
        return true;
      case PaymentLineType.advance:
        return _selectedAdvance != null && amount <= _selectedAdvance!.amountAvailable;
      case PaymentLineType.creditNote:
        return _selectedCreditNote != null && amount <= _selectedCreditNote!.amountResidual;
    }
  }

  String _getButtonText() {
    switch (_lineType) {
      case PaymentLineType.payment:
        return 'Abonar Pago';
      case PaymentLineType.advance:
        return 'Aplicar Anticipo';
      case PaymentLineType.creditNote:
        return 'Aplicar NC';
    }
  }

  void _addPaymentLine() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) return;

    final tempId = POSPaymentLinesByOrderNotifier.getNextTempId();
    final lineUuid = const Uuid().v4();

    PaymentLine line;

    switch (_lineType) {
      case PaymentLineType.payment:
        if (_selectedJournal == null) return;
        line = PaymentLine(
          id: tempId,
          lineUuid: lineUuid,
          type: PaymentLineType.payment,
          date: (_showTransferFields || _showDepositChequeFields) ? _paymentDate : (_showChequeFields ? _chequeDate : DateTime.now()),
          amount: amount,
          reference: _referenceController.text.isNotEmpty ? _referenceController.text : null,
          journalId: _selectedJournal!.id,
          journalName: _selectedJournal!.name,
          journalType: _selectedJournal!.type,
          paymentMethodLineId: _selectedMethod?.id,
          paymentMethodCode: _selectedMethod?.code,
          paymentMethodName: _selectedMethod?.name,
          bankId: _showCardFields ? _selectedBank?.id : null,
          bankName: _showCardFields ? _selectedBank?.name : null,
          cardType: _showCardFields ? _derivedCardType : null,
          cardBrandId: _showCardFields ? _selectedCardBrand?.id : null,
          cardBrandName: _showCardFields ? _selectedCardBrand?.name : null,
          cardDeadlineId: _showCardFields ? _selectedCardDeadline?.id : null,
          cardDeadlineName: _showCardFields ? _selectedCardDeadline?.name : null,
          loteId: _showCardFields ? _selectedLote?.id : null,
          loteName: _showCardFields ? _selectedLote?.name : null,
          voucherDate: _showCardFields ? _voucherDate : null,
          partnerBankId: _showChequeFields ? _selectedPartnerBank?.id : null,
          partnerBankName: _showChequeFields ? _selectedPartnerBank?.displayName : null,
          effectiveDate: _showChequeFields ? _effectiveDate : null,
        );
        break;
      case PaymentLineType.advance:
        if (_selectedAdvance == null) return;
        line = PaymentLine(
          id: tempId,
          lineUuid: lineUuid,
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
          id: tempId,
          lineUuid: lineUuid,
          type: PaymentLineType.creditNote,
          date: DateTime.now(),
          amount: amount,
          creditNoteId: _selectedCreditNote!.id,
          creditNoteName: _selectedCreditNote!.name,
          creditNoteAvailable: _selectedCreditNote!.amountResidual,
        );
        break;
    }

    widget.onAddLine(line);
    Navigator.of(context).pop();
  }
}
