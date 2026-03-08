import 'package:fluent_ui/fluent_ui.dart';

import '../../../../../core/theme/spacing.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper, PartnerBank, CreditIssue;
import '../../../../../shared/utils/formatting_utils.dart';
import '../../../../../shared/widgets/dialogs/copyable_info_bar.dart';

/// Dialog content for adding withhold lines with ComboBox dropdowns
/// Supports custom base amounts for splitting withholdings across multiple bases
class AddWithholdDialogContent extends StatefulWidget {
  final FluentThemeData theme;
  final double orderTotal;
  final double orderTax;
  final double orderSubtotal;
  final List<AvailableWithholdTax> vatTaxes;
  final List<AvailableWithholdTax> incomeTaxes;
  final int orderId;
  final void Function(WithholdLine line) onAddLine;

  const AddWithholdDialogContent({
    super.key,
    required this.theme,
    required this.orderTotal,
    required this.orderTax,
    required this.orderSubtotal,
    required this.vatTaxes,
    required this.incomeTaxes,
    required this.orderId,
    required this.onAddLine,
  });

  @override
  State<AddWithholdDialogContent> createState() => AddWithholdDialogContentState();
}

class AddWithholdDialogContentState extends State<AddWithholdDialogContent> {
  // IVA withholding state
  AvailableWithholdTax? _selectedVatTax;
  final _vatBaseController = TextEditingController();
  bool _useCustomVatBase = false;

  // Income withholding state
  AvailableWithholdTax? _selectedIncomeTax;
  final _incomeBaseController = TextEditingController();
  bool _useCustomIncomeBase = false;

  @override
  void initState() {
    super.initState();
    _vatBaseController.text = widget.orderTax.toFixed(2);
    _incomeBaseController.text = widget.orderSubtotal.toFixed(2);
  }

  @override
  void dispose() {
    _vatBaseController.dispose();
    _incomeBaseController.dispose();
    super.dispose();
  }

  double get _vatBase => _useCustomVatBase
      ? (double.tryParse(_vatBaseController.text) ?? widget.orderTax)
      : widget.orderTax;

  double get _incomeBase => _useCustomIncomeBase
      ? (double.tryParse(_incomeBaseController.text) ?? widget.orderSubtotal)
      : widget.orderSubtotal;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return ContentDialog(
      title: Row(
        children: [
          Icon(FluentIcons.calculator_percentage, size: 20, color: Colors.orange),
          const SizedBox(width: Spacing.sm),
          const Text('Registrar Retención'),
        ],
      ),
      constraints: const BoxConstraints(maxWidth: 650, maxHeight: 600),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order summary - compact
            Container(
              padding: const EdgeInsets.all(Spacing.sm),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: theme.resources.dividerStrokeColorDefault),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildInfoChip(theme, 'Subtotal', widget.orderSubtotal),
                  Container(width: 1, height: 30, color: theme.resources.dividerStrokeColorDefault),
                  _buildInfoChip(theme, 'IVA', widget.orderTax, color: Colors.blue),
                  Container(width: 1, height: 30, color: theme.resources.dividerStrokeColorDefault),
                  _buildInfoChip(theme, 'Total', widget.orderTotal, isBold: true),
                ],
              ),
            ),

            const SizedBox(height: Spacing.md),

            // Help text
            Container(
              padding: const EdgeInsets.all(Spacing.xs),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(FluentIcons.info, size: 14, color: Colors.blue),
                  const SizedBox(width: Spacing.xs),
                  Expanded(
                    child: Text(
                      'Puede ingresar una base personalizada si la retención aplica sobre un monto diferente al total.',
                      style: theme.typography.caption?.copyWith(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: Spacing.md),

            // IVA Withholdings section
            if (widget.vatTaxes.isNotEmpty) ...[
              _buildWithholdingSection(
                theme: theme,
                title: 'Retención de IVA',
                subtitle: 'Base: IVA facturado',
                defaultBase: widget.orderTax,
                baseController: _vatBaseController,
                useCustomBase: _useCustomVatBase,
                onCustomBaseChanged: (val) => setState(() => _useCustomVatBase = val),
                taxes: widget.vatTaxes,
                selectedTax: _selectedVatTax,
                onTaxChanged: (tax) => setState(() => _selectedVatTax = tax),
                onAdd: _addVatWithholding,
                currentBase: _vatBase,
                accentColor: Colors.teal,
              ),
              const SizedBox(height: Spacing.lg),
            ],

            // Income Withholdings section
            if (widget.incomeTaxes.isNotEmpty) ...[
              _buildWithholdingSection(
                theme: theme,
                title: 'Retención de Renta (IR)',
                subtitle: 'Base: Subtotal',
                defaultBase: widget.orderSubtotal,
                baseController: _incomeBaseController,
                useCustomBase: _useCustomIncomeBase,
                onCustomBaseChanged: (val) => setState(() => _useCustomIncomeBase = val),
                taxes: widget.incomeTaxes,
                selectedTax: _selectedIncomeTax,
                onTaxChanged: (tax) => setState(() => _selectedIncomeTax = tax),
                onAdd: _addIncomeWithholding,
                currentBase: _incomeBase,
                accentColor: Colors.purple,
              ),
            ],
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Widget _buildInfoChip(FluentThemeData theme, String label, double value, {Color? color, bool isBold = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: theme.typography.caption?.copyWith(color: theme.inactiveColor)),
        Text(
          value.toCurrency(),
          style: (isBold ? theme.typography.bodyStrong : theme.typography.body)?.copyWith(color: color),
        ),
      ],
    );
  }

  Widget _buildWithholdingSection({
    required FluentThemeData theme,
    required String title,
    required String subtitle,
    required double defaultBase,
    required TextEditingController baseController,
    required bool useCustomBase,
    required void Function(bool) onCustomBaseChanged,
    required List<AvailableWithholdTax> taxes,
    required AvailableWithholdTax? selectedTax,
    required void Function(AvailableWithholdTax?) onTaxChanged,
    required VoidCallback onAdd,
    required double currentBase,
    required Color accentColor,
  }) {
    final calculatedAmount = selectedTax != null
        ? WithholdLine.calculateAmount(currentBase, selectedTax.percent)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(FluentIcons.calculator_percentage, size: 16, color: accentColor),
              const SizedBox(width: Spacing.xs),
              Text(title, style: theme.typography.bodyStrong?.copyWith(color: accentColor)),
              const Spacer(),
              Text(subtitle, style: theme.typography.caption?.copyWith(color: theme.inactiveColor)),
            ],
          ),
          const SizedBox(height: Spacing.sm),

          // Base amount row
          Row(
            children: [
              // Custom base toggle
              Checkbox(
                checked: useCustomBase,
                onChanged: (val) {
                  onCustomBaseChanged(val ?? false);
                  if (!(val ?? false)) {
                    baseController.text = defaultBase.toFixed(2);
                  }
                },
                content: Text('Base personalizada', style: theme.typography.caption),
              ),
              const SizedBox(width: Spacing.sm),
              // Base input
              SizedBox(
                width: 120,
                child: TextBox(
                  controller: baseController,
                  enabled: useCustomBase,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text('\$'),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),

          const SizedBox(height: Spacing.sm),

          // Tax selector with better display
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ComboBox<AvailableWithholdTax>(
                  isExpanded: true,
                  placeholder: Text('Seleccione el porcentaje de retención...', style: theme.typography.caption),
                  value: selectedTax,
                  items: taxes.map((tax) {
                    final amount = WithholdLine.calculateAmount(currentBase, tax.percent);
                    return ComboBoxItem(
                      value: tax,
                      child: Row(
                        children: [
                          // Percentage badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${tax.percent.toFixed(0)}%',
                              style: theme.typography.caption?.copyWith(
                                color: accentColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: Spacing.sm),
                          // Tax name (in Spanish)
                          Expanded(
                            child: Text(
                              tax.label,
                              style: theme.typography.body,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Calculated amount
                          Text(
                            '= ${amount.toCurrency()}',
                            style: theme.typography.bodyStrong?.copyWith(color: accentColor),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: onTaxChanged,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              FilledButton(
                onPressed: selectedTax != null ? onAdd : null,
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(accentColor),
                ),
                child: Row(
                  children: [
                    const Icon(FluentIcons.add, size: 12),
                    const SizedBox(width: Spacing.xxs),
                    const Text('Agregar'),
                  ],
                ),
              ),
            ],
          ),

          // Calculation preview
          if (selectedTax != null) ...[
            const SizedBox(height: Spacing.sm),
            Container(
              padding: const EdgeInsets.all(Spacing.sm),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(currentBase.toCurrency(), style: theme.typography.body),
                  const SizedBox(width: Spacing.xs),
                  Text('\u00d7', style: theme.typography.body?.copyWith(color: theme.inactiveColor)),
                  const SizedBox(width: Spacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${selectedTax.percent.toFixed(0)}%',
                      style: theme.typography.bodyStrong?.copyWith(color: accentColor),
                    ),
                  ),
                  const SizedBox(width: Spacing.xs),
                  Text('=', style: theme.typography.body?.copyWith(color: theme.inactiveColor)),
                  const SizedBox(width: Spacing.xs),
                  Text(
                    calculatedAmount.toCurrency(),
                    style: theme.typography.subtitle?.copyWith(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _addVatWithholding() {
    if (_selectedVatTax == null) return;

    final tax = _selectedVatTax!;
    final base = _vatBase;
    final amount = WithholdLine.calculateAmount(base, tax.percent);

    final line = WithholdLine.create(
      taxId: tax.id,
      taxName: tax.label, // Use Spanish name
      taxPercent: tax.percent,
      withholdType: tax.withholdType,
      base: base,
      amount: amount,
    );

    widget.onAddLine(line);
    setState(() => _selectedVatTax = null);

    // Show success feedback
    CopyableInfoBar.showSuccess(
      context,
      title: 'Retención IVA agregada',
      message: '${base.toCurrency()} \u00d7 ${tax.percent.toFixed(0)}% = ${amount.toCurrency()}',
    );
  }

  void _addIncomeWithholding() {
    if (_selectedIncomeTax == null) return;

    final tax = _selectedIncomeTax!;
    final base = _incomeBase;
    final amount = WithholdLine.calculateAmount(base, tax.percent);

    final line = WithholdLine.create(
      taxId: tax.id,
      taxName: tax.label, // Use Spanish name
      taxPercent: tax.percent,
      withholdType: tax.withholdType,
      base: base,
      amount: amount,
    );

    widget.onAddLine(line);
    setState(() => _selectedIncomeTax = null);

    // Show success feedback
    CopyableInfoBar.showSuccess(
      context,
      title: 'Retención Renta agregada',
      message: '${base.toCurrency()} \u00d7 ${tax.percent.toFixed(0)}% = ${amount.toCurrency()}',
    );
  }
}
