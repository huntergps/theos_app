import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show
        Advance,
        AdvanceType,
        AdvanceLine,
        AvailableJournal,
        CardBrand,
        CardDeadline,
        AvailableBank;

import '../../../core/services/logger_service.dart';
import '../../../core/theme/spacing.dart';
import '../../../shared/widgets/dialogs/copyable_info_bar.dart';
import '../../../shared/utils/formatting_utils.dart';
import '../providers/advance_providers.dart';
import '../services/advance_service.dart';
import '../../sales/providers/service_providers.dart';

/// Resultado del diálogo de registro de anticipo
class AdvanceRegistrationResult {
  final bool success;
  final int? advanceId;
  final String? advanceName;
  final double amount;
  final String? errorMessage;

  AdvanceRegistrationResult({
    required this.success,
    this.advanceId,
    this.advanceName,
    this.amount = 0,
    this.errorMessage,
  });
}

/// Diálogo mejorado para registro de anticipos
///
/// Soporta:
/// - Múltiples líneas de pago (efectivo + tarjeta, etc.)
/// - Campos específicos por tipo de pago:
///   - Tarjeta: marca, plazo, voucher
///   - Cheque: número, banco, fecha vencimiento
///   - Transferencia: referencia, cuenta bancaria
/// - Fecha estimada editable
/// - Referencia con validación de longitud mínima
class AdvanceRegistrationDialog extends ConsumerStatefulWidget {
  final int partnerId;
  final String partnerName;
  final int sessionId;
  final double? suggestedAmount;

  const AdvanceRegistrationDialog({
    super.key,
    required this.partnerId,
    required this.partnerName,
    required this.sessionId,
    this.suggestedAmount,
  });

  /// Muestra el diálogo y retorna el resultado
  static Future<AdvanceRegistrationResult?> show({
    required BuildContext context,
    required int partnerId,
    required String partnerName,
    required int sessionId,
    double? suggestedAmount,
  }) {
    return showDialog<AdvanceRegistrationResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AdvanceRegistrationDialog(
        partnerId: partnerId,
        partnerName: partnerName,
        sessionId: sessionId,
        suggestedAmount: suggestedAmount,
      ),
    );
  }

  @override
  ConsumerState<AdvanceRegistrationDialog> createState() =>
      _AdvanceRegistrationDialogState();
}

class _AdvanceRegistrationDialogState
    extends ConsumerState<AdvanceRegistrationDialog> {
  final _referenceController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Líneas de pago
  final List<_PaymentLineState> _paymentLines = [];

  // Datos de catálogos
  List<AvailableJournal> _journals = [];
  List<CardBrand> _cardBrands = [];
  List<CardDeadline> _cardDeadlines = [];
  List<AvailableBank> _banks = [];
  List<PartnerBank> _partnerBanks = [];

  // Fecha estimada
  DateTime _dateEstimated = DateTime.now().add(const Duration(days: 30));

  // Estados
  bool _isLoading = true;
  bool _isSaving = false;
  int _minReferenceLength = 30;

  @override
  void initState() {
    super.initState();
    _loadCatalogs();
  }

  @override
  void dispose() {
    _referenceController.dispose();
    for (final line in _paymentLines) {
      line.amountController.dispose();
      line.documentController.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCatalogs() async {
    try {
      final advanceService = ref.read(advanceServiceProvider);
      final paymentService = ref.read(paymentServiceProvider);

      // Cargar en paralelo
      final results = await Future.wait<dynamic>([
        paymentService.getAvailableJournals(widget.sessionId),
        advanceService.getBanks(),
        advanceService.getCardDeadlines(),
        advanceService.getPartnerBanks(widget.partnerId),
        advanceService.getMinReferenceLength(),
      ]);

      if (mounted) {
        setState(() {
          _journals = results[0] as List<AvailableJournal>;
          _banks = results[1] as List<AvailableBank>;
          _cardDeadlines = results[2] as List<CardDeadline>;
          _partnerBanks = results[3] as List<PartnerBank>;
          _minReferenceLength = results[4] as int;
          _isLoading = false;

          // Agregar primera línea de pago si hay diarios
          if (_journals.isNotEmpty) {
            _addPaymentLine();
            // Si hay monto sugerido, establecerlo en la primera línea
            if (widget.suggestedAmount != null && _paymentLines.isNotEmpty) {
              _paymentLines.first.amountController.text = widget
                  .suggestedAmount!
                  .toFixed(2);
            }
          }
        });
      }
    } catch (e) {
      logger.e('[AdvanceDialog]', 'Error loading catalogs: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _addPaymentLine() {
    setState(() {
      _paymentLines.add(
        _PaymentLineState(
          journal: _journals.isNotEmpty ? _journals.first : null,
          amountController: TextEditingController(),
          documentController: TextEditingController(),
        ),
      );
    });
  }

  void _removePaymentLine(int index) {
    if (_paymentLines.length > 1) {
      setState(() {
        final line = _paymentLines.removeAt(index);
        line.amountController.dispose();
        line.documentController.dispose();
      });
    }
  }

  Future<void> _loadCardBrandsForJournal(int journalId) async {
    try {
      final advanceService = ref.read(advanceServiceProvider);
      final brands = await advanceService.getCardBrands(journalId);
      if (mounted) {
        setState(() {
          _cardBrands = brands;
        });
      }
    } catch (e) {
      logger.e('[AdvanceDialog]', 'Error loading card brands: $e');
    }
  }

  double get _totalAmount {
    return _paymentLines.fold(0.0, (sum, line) {
      final amount = double.tryParse(line.amountController.text) ?? 0;
      return sum + amount;
    });
  }

  Future<void> _save() async {
    // Validar monto total
    if (_totalAmount <= 0) {
      _showError('El monto total debe ser mayor a cero');
      return;
    }

    // Validar que todas las líneas tengan diario y monto
    for (int i = 0; i < _paymentLines.length; i++) {
      final line = _paymentLines[i];
      if (line.journal == null) {
        _showError('Seleccione un método de pago en la línea ${i + 1}');
        return;
      }
      final amount = double.tryParse(line.amountController.text) ?? 0;
      if (amount <= 0) {
        _showError('Ingrese un monto válido en la línea ${i + 1}');
        return;
      }
    }

    // Construir referencia
    String reference = _referenceController.text.trim();
    if (reference.isEmpty) {
      reference =
          'Anticipo de cliente recibido - ${widget.partnerName}. '
          'Fecha: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}';
    }

    // Validar longitud mínima
    if (reference.length < _minReferenceLength) {
      reference = reference.padRight(_minReferenceLength);
    }

    setState(() => _isSaving = true);

    try {
      final advanceService = ref.read(advanceServiceProvider);

      // Construir líneas de anticipo
      final advanceLines = _paymentLines.map((line) {
        return AdvanceLine(
          journalId: line.journal!.id,
          journalName: line.journal!.name,
          journalType: line.journal!.type,
          amount: double.tryParse(line.amountController.text) ?? 0,
          documentNumber: line.documentController.text.isNotEmpty
              ? line.documentController.text
              : null,
          cardBrandId: line.cardBrand?.id,
          cardBrandName: line.cardBrand?.name,
          cardDeadlineId: line.cardDeadline?.id,
          cardDeadlineName: line.cardDeadline?.name,
          checkDueDate: line.checkDueDate,
          partnerBankId: line.partnerBank?.id,
          partnerBankName: line.partnerBank?.displayName,
        );
      }).toList();

      // Crear el anticipo
      final advance = Advance(
        date: DateTime.now(),
        dateEstimated: _dateEstimated,
        advanceType: AdvanceType.inbound,
        partnerId: widget.partnerId,
        partnerName: widget.partnerName,
        reference: reference,
        collectionSessionId: widget.sessionId,
        lines: advanceLines,
      );

      final result = await advanceService.createAndPostAdvance(advance);

      if (mounted) {
        if (result.success) {
          Navigator.pop(
            context,
            AdvanceRegistrationResult(
              success: true,
              advanceId: result.advanceId,
              advanceName: result.advanceName,
              amount: _totalAmount,
            ),
          );
        } else {
          setState(() => _isSaving = false);
          _showError(result.errorMessage ?? 'Error al registrar anticipo');
        }
      }
    } catch (e) {
      logger.e('[AdvanceDialog]', 'Error saving advance: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        _showError('Error: $e');
      }
    }
  }

  void _showError(String message) {
    CopyableInfoBar.showError(context, title: 'Error', message: message);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ContentDialog(
      title: Row(
        children: [
          const Icon(FluentIcons.money, size: 24),
          const SizedBox(width: Spacing.sm),
          Expanded(child: Text('Anticipo - ${widget.partnerName}')),
        ],
      ),
      constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
      content: _isLoading
          ? const Center(child: ProgressRing())
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Fecha estimada
                    _buildDateEstimatedField(theme),
                    const SizedBox(height: Spacing.md),

                    // Referencia
                    _buildReferenceField(theme),
                    const SizedBox(height: Spacing.md),

                    // Líneas de pago
                    _buildPaymentLinesSection(theme),
                    const SizedBox(height: Spacing.md),

                    // Total
                    _buildTotalSection(theme),
                  ],
                ),
              ),
            ),
      actions: [
        Button(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ProgressRing(strokeWidth: 2),
                )
              : const Text('Registrar Anticipo'),
        ),
      ],
    );
  }

  Widget _buildDateEstimatedField(FluentThemeData theme) {
    return InfoLabel(
      label: 'Fecha Estimada de Uso',
      child: DatePicker(
        selected: _dateEstimated,
        onChanged: (date) {
          setState(() => _dateEstimated = date);
        },
      ),
    );
  }

  Widget _buildReferenceField(FluentThemeData theme) {
    return InfoLabel(
      label: 'Referencia / Glosa (mínimo $_minReferenceLength caracteres)',
      child: TextBox(
        controller: _referenceController,
        placeholder: 'Descripción del anticipo...',
        maxLines: 2,
        suffix: Text(
          '${_referenceController.text.length}/$_minReferenceLength',
          style: theme.typography.caption,
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildPaymentLinesSection(FluentThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Formas de Pago', style: theme.typography.subtitle),
            Button(
              onPressed: _addPaymentLine,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.add, size: 12),
                  SizedBox(width: 4),
                  Text('Agregar'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        ..._paymentLines.asMap().entries.map((entry) {
          return _buildPaymentLineCard(theme, entry.key, entry.value);
        }),
      ],
    );
  }

  Widget _buildPaymentLineCard(
    FluentThemeData theme,
    int index,
    _PaymentLineState line,
  ) {
    final isCard = line.journal?.isCardJournal ?? false;
    final isCheck = line.journal?.type == 'bank' && line.showCheckFields;
    final isTransfer = line.journal?.type == 'bank' && !line.showCheckFields;

    return Card(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con número y botón eliminar
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.xs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '#${index + 1}',
                    style: theme.typography.caption?.copyWith(
                      color: theme.accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                if (_paymentLines.length > 1)
                  IconButton(
                    icon: Icon(FluentIcons.delete, size: 14, color: Colors.red),
                    onPressed: () => _removePaymentLine(index),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.xs),

            // Diario y Monto en fila
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: InfoLabel(
                    label: 'Método de Pago',
                    child: ComboBox<AvailableJournal>(
                      isExpanded: true,
                      value: line.journal,
                      items: _journals
                          .map(
                            (j) => ComboBoxItem(value: j, child: Text(j.name)),
                          )
                          .toList(),
                      onChanged: (j) {
                        setState(() {
                          line.journal = j;
                          line.cardBrand = null;
                          line.cardDeadline = null;
                          line.showCheckFields = false;
                        });
                        if (j?.isCardJournal ?? false) {
                          _loadCardBrandsForJournal(j!.id);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: InfoLabel(
                    label: 'Monto',
                    child: TextBox(
                      controller: line.amountController,
                      placeholder: '0.00',
                      keyboardType: TextInputType.number,
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Text('\$'),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
              ],
            ),

            // Campos específicos según tipo
            if (isCard) ...[
              const SizedBox(height: Spacing.sm),
              _buildCardFields(theme, line),
            ],

            if (line.journal?.type == 'bank') ...[
              const SizedBox(height: Spacing.sm),
              _buildBankTypeSelector(theme, line),
              if (isCheck) ...[
                const SizedBox(height: Spacing.sm),
                _buildCheckFields(theme, line),
              ],
              if (isTransfer) ...[
                const SizedBox(height: Spacing.sm),
                _buildTransferFields(theme, line),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCardFields(FluentThemeData theme, _PaymentLineState line) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: InfoLabel(
                label: 'Marca de Tarjeta',
                child: ComboBox<CardBrand>(
                  isExpanded: true,
                  value: line.cardBrand,
                  placeholder: const Text('Seleccionar...'),
                  items: _cardBrands
                      .map((b) => ComboBoxItem(value: b, child: Text(b.name)))
                      .toList(),
                  onChanged: (b) => setState(() => line.cardBrand = b),
                ),
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: InfoLabel(
                label: 'Plazo',
                child: ComboBox<CardDeadline>(
                  isExpanded: true,
                  value: line.cardDeadline,
                  placeholder: const Text('Corriente/Diferido'),
                  items: _cardDeadlines
                      .map((d) => ComboBoxItem(value: d, child: Text(d.name)))
                      .toList(),
                  onChanged: (d) => setState(() => line.cardDeadline = d),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        InfoLabel(
          label: 'Número de Voucher',
          child: TextBox(
            controller: line.documentController,
            placeholder: 'Número del voucher...',
          ),
        ),
      ],
    );
  }

  Widget _buildBankTypeSelector(FluentThemeData theme, _PaymentLineState line) {
    return Row(
      children: [
        Checkbox(
          checked: line.showCheckFields,
          onChanged: (v) => setState(() => line.showCheckFields = v ?? false),
          content: const Text('Es Cheque'),
        ),
      ],
    );
  }

  Widget _buildCheckFields(FluentThemeData theme, _PaymentLineState line) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: InfoLabel(
                label: 'Número de Cheque',
                child: TextBox(
                  controller: line.documentController,
                  placeholder: 'Número...',
                ),
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: InfoLabel(
                label: 'Banco',
                child: ComboBox<AvailableBank>(
                  isExpanded: true,
                  value: line.bank,
                  placeholder: const Text('Seleccionar...'),
                  items: _banks
                      .map((b) => ComboBoxItem(value: b, child: Text(b.name)))
                      .toList(),
                  onChanged: (b) => setState(() => line.bank = b),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        InfoLabel(
          label: 'Fecha de Vencimiento',
          child: DatePicker(
            selected: line.checkDueDate,
            onChanged: (d) => setState(() => line.checkDueDate = d),
          ),
        ),
      ],
    );
  }

  Widget _buildTransferFields(FluentThemeData theme, _PaymentLineState line) {
    return Column(
      children: [
        InfoLabel(
          label: 'Número de Referencia',
          child: TextBox(
            controller: line.documentController,
            placeholder: 'Referencia de transferencia...',
          ),
        ),
        if (_partnerBanks.isNotEmpty) ...[
          const SizedBox(height: Spacing.sm),
          InfoLabel(
            label: 'Cuenta Bancaria del Cliente',
            child: ComboBox<PartnerBank>(
              isExpanded: true,
              value: line.partnerBank,
              placeholder: const Text('Seleccionar...'),
              items: _partnerBanks
                  .map(
                    (b) => ComboBoxItem(value: b, child: Text(b.displayName)),
                  )
                  .toList(),
              onChanged: (b) => setState(() => line.partnerBank = b),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTotalSection(FluentThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: theme.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('TOTAL ANTICIPO', style: theme.typography.bodyStrong),
          Text(
            _totalAmount.toCurrency(),
            style: theme.typography.subtitle?.copyWith(
              color: theme.accentColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Estado interno de una línea de pago
class _PaymentLineState {
  AvailableJournal? journal;
  final TextEditingController amountController;
  final TextEditingController documentController;
  CardBrand? cardBrand;
  CardDeadline? cardDeadline;
  AvailableBank? bank;
  PartnerBank? partnerBank;
  DateTime? checkDueDate;
  bool showCheckFields = false;

  _PaymentLineState({
    this.journal,
    required this.amountController,
    required this.documentController,
  });
}
