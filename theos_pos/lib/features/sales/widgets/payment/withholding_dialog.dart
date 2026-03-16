import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../shared/utils/formatting_utils.dart';
import '../../../../shared/widgets/dialogs/base_form_dialog.dart';

import '../../providers/service_providers.dart';
import '../../services/payment_service.dart';
import '../../../../shared/widgets/dialogs/copyable_info_bar.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

/// Diálogo para registrar retenciones del cliente.
///
/// Usa [FormDialogConfig] y [FormValidationState] para mantener consistencia
/// con otros diálogos de formulario, aunque no hereda directamente de
/// [BaseFormDialog] debido a la complejidad de su lógica interna.
///
/// Permite registrar retenciones de IVA y Renta que el cliente
/// aplica sobre las facturas de venta.
///
/// Si se proporciona [initialWithholdLines], las líneas se pre-llenan
/// con los datos de la orden de venta (sale.order.withhold.line).
class WithholdingDialog extends ConsumerStatefulWidget {
  final int invoiceId;
  final String invoiceName;
  final double invoiceTotal;
  final double invoiceTaxBase;
  final double invoiceTaxAmount;
  final int? partnerId;
  final String? partnerName;

  /// Optional initial withhold lines from sale order to pre-fill the form
  final List<WithholdLine>? initialWithholdLines;

  const WithholdingDialog({
    super.key,
    required this.invoiceId,
    required this.invoiceName,
    required this.invoiceTotal,
    required this.invoiceTaxBase,
    required this.invoiceTaxAmount,
    this.partnerId,
    this.partnerName,
    this.initialWithholdLines,
  });

  /// Muestra el diálogo de retenciones
  ///
  /// [initialWithholdLines] - Optional lines from sale.order.withhold.line
  /// to pre-fill the form. If provided, these will be loaded when types are ready.
  static Future<WithholdingResult?> show({
    required BuildContext context,
    required int invoiceId,
    required String invoiceName,
    required double invoiceTotal,
    required double invoiceTaxBase,
    required double invoiceTaxAmount,
    int? partnerId,
    String? partnerName,
    List<WithholdLine>? initialWithholdLines,
  }) async {
    return showDialog<WithholdingResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => WithholdingDialog(
        invoiceId: invoiceId,
        invoiceName: invoiceName,
        invoiceTotal: invoiceTotal,
        invoiceTaxBase: invoiceTaxBase,
        invoiceTaxAmount: invoiceTaxAmount,
        partnerId: partnerId,
        partnerName: partnerName,
        initialWithholdLines: initialWithholdLines,
      ),
    );
  }

  @override
  ConsumerState<WithholdingDialog> createState() => _WithholdingDialogState();
}

class _WithholdingDialogState extends ConsumerState<WithholdingDialog> {
  // Configuración del diálogo usando FormDialogConfig para consistencia
  static const _config = FormDialogConfig(
    title: 'Registrar Retención',
    icon: FluentIcons.document_set,
    maxWidth: 900,
    maxHeight: 800,
    primaryButtonText: 'Registrar',
  );

  // Tipos de retención disponibles
  List<WithholdingType> _ivaTypes = [];
  List<WithholdingType> _rentaTypes = [];

  // Líneas de retención agregadas
  final List<_WithholdingLineEntry> _lines = [];

  // Campos del formulario
  final _authorizationController = TextEditingController();
  final _sequenceController = TextEditingController();
  WithholdingType? _selectedType;
  final _baseController = TextEditingController();

  // Estado
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  List<String> _validationErrors = [];

  final _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _loadWithholdingTypes();
  }

  @override
  void dispose() {
    _authorizationController.dispose();
    _sequenceController.dispose();
    _baseController.dispose();
    super.dispose();
  }

  Future<void> _loadWithholdingTypes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final paymentService = ref.read(paymentServiceProvider);
      final types = await paymentService.getWithholdingTypes();

      // Separar por tipo (IVA vs Renta basado en código)
      _ivaTypes = types.where((t) => t.code.startsWith('1')).toList();
      _rentaTypes = types.where((t) => t.code.startsWith('3')).toList();

      // Pre-fill lines from initialWithholdLines if provided
      logger.i('[WithholdingDialog]', 'Checking initialWithholdLines: ${widget.initialWithholdLines?.length ?? "null"}');
      if (widget.initialWithholdLines != null && widget.initialWithholdLines!.isNotEmpty) {
        logger.i('[WithholdingDialog]', 'Calling _prefillLinesFromSaleOrder with ${types.length} types');
        _prefillLinesFromSaleOrder(types);
      } else {
        logger.i('[WithholdingDialog]', 'No initialWithholdLines to pre-fill');
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error cargando tipos de retención: $e';
      });
    }
  }

  /// Pre-fill withhold lines from sale order withhold lines
  void _prefillLinesFromSaleOrder(List<WithholdingType> availableTypes) {
    logger.i('[WithholdingDialog]', '=== PRE-FILL LINES DEBUG ===');
    logger.i('[WithholdingDialog]', 'initialWithholdLines: ${widget.initialWithholdLines?.length ?? "null"}');
    logger.i('[WithholdingDialog]', 'availableTypes: ${availableTypes.length}');

    if (widget.initialWithholdLines == null) {
      logger.w('[WithholdingDialog]', 'No initial lines to pre-fill');
      return;
    }

    for (final saleOrderLine in widget.initialWithholdLines!) {
      logger.i('[WithholdingDialog]', 'Processing line: taxId=${saleOrderLine.taxId}, taxName=${saleOrderLine.taxName}');

      // Find matching withholding type by tax_id
      WithholdingType? found;
      for (final t in availableTypes) {
        if (t.id == saleOrderLine.taxId) {
          found = t;
          break;
        }
      }

      final matchingType = found ?? WithholdingType(
        id: saleOrderLine.taxId,
        code: saleOrderLine.withholdType == WithholdType.vatSale ? '1' : '3',
        name: saleOrderLine.taxName,
        percentage: saleOrderLine.taxPercent * 100,
      );

      logger.i('[WithholdingDialog]', '  Matched type: ${matchingType.name} (${matchingType.percentage}%)');
      logger.i('[WithholdingDialog]', '  Adding line: base=${saleOrderLine.base}, amount=${saleOrderLine.amount}');

      _lines.add(
        _WithholdingLineEntry(
          type: matchingType,
          base: saleOrderLine.base,
          amount: saleOrderLine.amount,
        ),
      );
    }

    logger.i('[WithholdingDialog]', 'Total lines after pre-fill: ${_lines.length}');
  }

  double get _totalWithholding =>
      _lines.fold(0.0, (sum, line) => sum + line.amount);

  /// Formatea la secuencia al formato SRI: 001-001-000000001
  /// Acepta entradas como "1-1-8" y las convierte a "001-001-000000008"
  String _formatSequence(String input) {
    // Remover espacios
    final cleaned = input.trim();
    if (cleaned.isEmpty) return '';

    // Dividir por guiones
    final parts = cleaned.split('-');
    if (parts.length != 3) return cleaned; // No formatear si no tiene 3 partes

    try {
      final establecimiento = int.tryParse(parts[0]) ?? 0;
      final puntoEmision = int.tryParse(parts[1]) ?? 0;
      final secuencial = int.tryParse(parts[2]) ?? 0;

      // Formatear: 3 dígitos - 3 dígitos - 9 dígitos
      return '${establecimiento.toString().padLeft(3, '0')}-'
          '${puntoEmision.toString().padLeft(3, '0')}-'
          '${secuencial.toString().padLeft(9, '0')}';
    } catch (_) {
      return cleaned;
    }
  }

  /// Aplica el formato cuando el usuario termina de escribir (on blur)
  void _onSequenceEditingComplete() {
    final formatted = _formatSequence(_sequenceController.text);
    if (formatted != _sequenceController.text) {
      _sequenceController.text = formatted;
    }
  }

  void _addLine() {
    if (_selectedType == null) {
      _showError('Seleccione un tipo de retención');
      return;
    }

    final base = double.tryParse(_baseController.text) ?? 0;
    if (base <= 0) {
      _showError('Ingrese una base válida');
      return;
    }

    // Calcular monto de retención
    final amount = base * _selectedType!.percentage / 100;

    setState(() {
      _lines.add(
        _WithholdingLineEntry(type: _selectedType!, base: base, amount: amount),
      );

      // Limpiar formulario
      _selectedType = null;
      _baseController.clear();
    });
  }

  void _removeLine(int index) {
    setState(() {
      _lines.removeAt(index);
    });
  }

  void _showError(String message) {
    CopyableInfoBar.showError(
      context,
      title: 'Error de retencion',
      message: message,
    );
  }

  /// Validación usando FormValidationState para consistencia
  FormValidationState _validate() {
    final errors = <String>[];

    if (_lines.isEmpty) {
      errors.add('Agregue al menos una línea de retención');
    }

    // Validar autorización (49 dígitos) - REQUERIDO
    final auth = _authorizationController.text.trim();
    if (auth.isEmpty) {
      errors.add('El número de autorización es requerido');
    } else if (auth.length != 49) {
      errors.add('El número de autorización debe tener exactamente 49 dígitos (tiene ${auth.length})');
    } else if (!RegExp(r'^\d{49}$').hasMatch(auth)) {
      errors.add('El número de autorización solo debe contener dígitos');
    }

    // Validar secuencia - REQUERIDO (formato: 001-001-000000001)
    final seq = _sequenceController.text.trim();
    if (seq.isEmpty) {
      errors.add('El número de secuencia es requerido');
    } else if (!RegExp(r'^\d{3}-\d{3}-\d{9}$').hasMatch(seq)) {
      errors.add('El número de secuencia debe tener formato 001-001-000000001');
    }

    return FormValidationState.fromErrors(errors);
  }

  Future<void> _save() async {
    // Auto-formatear secuencia antes de validar
    _onSequenceEditingComplete();

    // Validar usando FormValidationState
    final validation = _validate();
    if (!validation.isValid) {
      setState(() => _validationErrors = validation.errors);
      return;
    }

    setState(() {
      _isSaving = true;
      _validationErrors = [];
    });

    try {
      final paymentService = ref.read(paymentServiceProvider);
      final auth = _authorizationController.text.trim();
      final seq = _sequenceController.text.trim();

      final result = await paymentService.registerWithholding(
        invoiceId: widget.invoiceId,
        lines: _lines
            .map(
              (l) => WithholdingLine(
                taxId: l.type.id,
                base: l.base,
                amount: l.amount,
              ),
            )
            .toList(),
        authorizationNumber: auth,
        documentNumber: seq,
      );

      if (!mounted) return;

      if (result.success) {
        Navigator.pop(context, result);
      } else {
        setState(() => _isSaving = false);
        _showError(result.errorMessage ?? 'Error al registrar retención');
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showError('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ContentDialog(
      constraints: BoxConstraints(
        maxWidth: _config.maxWidth,
        maxHeight: _config.maxHeight ?? MediaQuery.of(context).size.height * 0.9,
      ),
      title: Row(
        children: [
          Icon(_config.icon, color: theme.accentColor),
          Spacing.horizontal.sm,
          Text(_config.title),
        ],
      ),
      content: _isLoading
          ? const Center(child: ProgressRing())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.error, size: 48, color: Colors.red),
                  Spacing.vertical.md,
                  Text(_error!, style: theme.typography.body),
                  Spacing.vertical.md,
                  FilledButton(
                    onPressed: _loadWithholdingTypes,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Banner de errores de validación (estilo consistente)
                if (_validationErrors.isNotEmpty) ...[
                  _buildValidationBanner(theme),
                  const SizedBox(height: 16),
                ],
                // Contenido
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Info de la factura
                        _buildInvoiceInfo(theme),
                        Spacing.vertical.md,

                        // Número de autorización
                        _buildAuthorizationField(theme),
                        Spacing.vertical.md,

                        // Formulario para agregar líneas
                        _buildAddLineForm(theme),
                        Spacing.vertical.md,

                        // Lista de líneas agregadas
                        _buildLinesList(theme),
                        Spacing.vertical.md,

                        // Total
                        _buildTotalSection(theme),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      actions: [
        Button(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text(_config.cancelButtonText),
        ),
        FilledButton(
          onPressed: _isSaving || _lines.isEmpty ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ProgressRing(strokeWidth: 2),
                )
              : Text(_config.primaryButtonText),
        ),
      ],
    );
  }

  Widget _buildValidationBanner(FluentThemeData theme) {
    return InfoBar(
      title: Text(
        _validationErrors.length == 1
            ? 'Error de validación'
            : 'Errores de validación',
      ),
      content: Text(
        _validationErrors.length == 1
            ? _validationErrors.first
            : _validationErrors.map((e) => '• $e').join('\n'),
      ),
      severity: InfoBarSeverity.error,
      isLong: _validationErrors.length > 1,
      onClose: () => setState(() => _validationErrors = []),
    );
  }

  Widget _buildInvoiceInfo(FluentThemeData theme) {
    return Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  FluentIcons.receipt_check,
                  size: 24,
                  color: theme.accentColor,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Factura ${widget.invoiceName}',
                    style: theme.typography.subtitle,
                  ),
                  if (widget.partnerName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.partnerName!,
                      style: theme.typography.body?.copyWith(
                        color: theme.resources.textFillColorSecondary,
                      ),
                    ),
                  ],
                ],
              ),
              const Spacer(),
              _buildFinancialSummary(theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary(FluentThemeData theme) {
    return Row(
      children: [
        _buildInfoItem('Base Imp.', widget.invoiceTaxBase, theme),
        const SizedBox(width: 24),
        Container(
          width: 1,
          height: 40,
          color: theme.resources.dividerStrokeColorDefault,
        ),
        const SizedBox(width: 24),
        _buildInfoItem('IVA', widget.invoiceTaxAmount, theme),
        const SizedBox(width: 24),
        Container(
          width: 1,
          height: 40,
          color: theme.resources.dividerStrokeColorDefault,
        ),
        const SizedBox(width: 24),
        _buildInfoItem('Total', widget.invoiceTotal, theme, isTotal: true),
      ],
    );
  }

  Widget _buildInfoItem(
    String label,
    double value,
    FluentThemeData theme, {
    bool isTotal = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: theme.typography.caption),
        Text(
          _currencyFormat.format(value),
          style: isTotal
              ? theme.typography.subtitle?.copyWith(color: theme.accentColor)
              : theme.typography.bodyStrong,
        ),
      ],
    );
  }

  Widget _buildAuthorizationField(FluentThemeData theme) {
    return InfoLabel(
      label: 'Número de Autorización (SRI)',
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextBox(
              controller: _authorizationController,
              placeholder: '49 dígitos',
              maxLength: 49,
            ),
          ),
          Spacing.horizontal.sm,
          SizedBox(
            width: 180,
            child: TextBox(
              controller: _sequenceController,
              placeholder: '001-001-000000001',
              onEditingComplete: _onSequenceEditingComplete,
              onSubmitted: (_) => _onSequenceEditingComplete(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddLineForm(FluentThemeData theme) {
    return Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Agregar Nueva Retención', style: theme.typography.bodyStrong),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Tipo de retención
              Expanded(
                flex: 4,
                child: InfoLabel(
                  label: 'Tipo de Retención',
                  child: ComboBox<WithholdingType>(
                    value: _selectedType,
                    placeholder: const Text('Seleccione tipo...'),
                    isExpanded: true,
                    items: [
                      if (_ivaTypes.isNotEmpty) ...[
                        ComboBoxItem<WithholdingType>(
                          enabled: false,
                          value: null,
                          child: Text(
                            '── Retención IVA ──',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.accentColor,
                            ),
                          ),
                        ),
                        ..._ivaTypes.map(
                          (t) => ComboBoxItem(
                            value: t,
                            child: Text(
                              '${t.code} - ${t.name} (${t.percentage}%)',
                            ),
                          ),
                        ),
                      ],
                      if (_rentaTypes.isNotEmpty) ...[
                        ComboBoxItem<WithholdingType>(
                          enabled: false,
                          value: null,
                          child: Text(
                            '── Retención Renta ──',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.accentColor,
                            ),
                          ),
                        ),
                        ..._rentaTypes.map(
                          (t) => ComboBoxItem(
                            value: t,
                            child: Text(
                              '${t.code} - ${t.name} (${t.percentage}%)',
                            ),
                          ),
                        ),
                      ],
                    ],
                    onChanged: (value) => setState(() => _selectedType = value),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Base
              Expanded(
                flex: 2,
                child: InfoLabel(
                  label: 'Base Imponible',
                  child: TextBox(
                    controller: _baseController,
                    placeholder: '0.00',
                    textAlign: TextAlign.right,
                    suffix: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Botón para usar base de IVA
                        Tooltip(
                          message: 'Usar base IVA',
                          child: IconButton(
                            icon: const Icon(FluentIcons.calculator, size: 14),
                            onPressed: () {
                              _baseController.text = widget.invoiceTaxBase
                                  .toFixed(2);
                            },
                          ),
                        ),
                        // Botón para usar total
                        Tooltip(
                          message: 'Usar total',
                          child: IconButton(
                            icon: const Icon(FluentIcons.money, size: 14),
                            onPressed: () {
                              _baseController.text = widget.invoiceTotal
                                  .toFixed(2);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Botón agregar
              FilledButton(
                onPressed: _addLine,
                child: Container(
                  height: 32,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.add, size: 16),
                      SizedBox(width: 8),
                      Text('Agregar'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLinesList(FluentThemeData theme) {
    if (_lines.isEmpty) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border.all(
            color: theme.resources.controlStrokeColorDefault,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FluentIcons.document_set,
              size: 48,
              color: theme.resources.textFillColorTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'No hay retenciones agregadas',
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detalle de Retenciones (${_lines.length})',
          style: theme.typography.bodyStrong,
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.resources.controlStrokeColorDefault,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            children: [
              // Encabezado
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(5),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: theme.resources.controlStrokeColorDefault,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        'CONCEPTO',
                        style: theme.typography.caption?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'BASE IMP.',
                        style: theme.typography.caption?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        '%',
                        style: theme.typography.caption?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'VALOR',
                        style: theme.typography.caption?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 48), // Espacio para botones de acción
                  ],
                ),
              ),
              // Líneas
              ...List.generate(_lines.length, (index) {
                final line = _lines[index];
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: index.isEven
                        ? Colors.transparent
                        : theme.resources.subtleFillColorSecondary.withValues(
                            alpha: 0.5,
                          ),
                    border: index < _lines.length - 1
                        ? Border(
                            bottom: BorderSide(
                              color: theme.resources.controlStrokeColorDefault
                                  .withValues(alpha: 0.5),
                            ),
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              line.type.code,
                              style: theme.typography.caption?.copyWith(
                                color: theme.resources.textFillColorSecondary,
                              ),
                            ),
                            Text(
                              line.type.name,
                              style: theme.typography.body,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _currencyFormat.format(line.base),
                          style: theme.typography.body,
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${line.type.percentage}%',
                            style: theme.typography.caption?.copyWith(
                              color: theme.accentColor,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _currencyFormat.format(line.amount),
                          style: theme.typography.bodyStrong,
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Container(
                        width: 48,
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          icon: Icon(
                            FluentIcons.delete,
                            size: 16,
                            color: Colors.red,
                          ),
                          onPressed: () => _removeLine(index),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTotalSection(FluentThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Total Retención:', style: theme.typography.subtitle),
          Text(
            _currencyFormat.format(_totalWithholding),
            style: theme.typography.title?.copyWith(color: theme.accentColor),
          ),
        ],
      ),
    );
  }
}

/// Entrada de línea de retención (uso interno)
class _WithholdingLineEntry {
  final WithholdingType type;
  final double base;
  final double amount;

  _WithholdingLineEntry({
    required this.type,
    required this.base,
    required this.amount,
  });
}
