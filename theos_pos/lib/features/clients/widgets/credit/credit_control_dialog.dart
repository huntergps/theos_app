import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';

import '../../clients.dart';

/// Action chosen by user in credit control dialog
enum CreditDialogAction {
  cancel, // Cancel the operation
  createApproval, // Create approval request in Odoo
  proceedAnyway, // Continue without approval (if allowed)
}

/// Dialog for credit limit/overdue debt issues (Fluent UI version)
///
/// Shows detailed credit information with visual breakdown and allows user to:
/// - Cancel the operation
/// - Create an approval request (if online)
/// - Proceed anyway (if allowed for the client)
class CreditControlDialog extends StatelessWidget {
  final Client client;
  final CreditValidationResult validationResult;
  final double orderAmount;
  final bool isOnline;
  final bool canBypass;

  const CreditControlDialog({
    super.key,
    required this.client,
    required this.validationResult,
    required this.orderAmount,
    this.isOnline = false,
    this.canBypass = false,
  });

  static final _currencyFormat = NumberFormat.currency(
    locale: 'es_EC',
    symbol: r'$',
    decimalDigits: 2,
  );

  /// Show the dialog and return the user's choice
  static Future<CreditDialogAction?> show({
    required BuildContext context,
    required Client client,
    required CreditValidationResult validationResult,
    required double orderAmount,
    bool isOnline = false,
    bool canBypass = false,
  }) {
    return showDialog<CreditDialogAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CreditControlDialog(
        client: client,
        validationResult: validationResult,
        orderAmount: orderAmount,
        isOnline: isOnline,
        canBypass: canBypass,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
      title: Row(
        children: [
          Icon(
            _getFluentIcon(),
            color: _getIconColor(),
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getTitle(),
              style: theme.typography.subtitle,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Message
            Text(
              validationResult.message ?? 'Problema de crédito detectado',
              style: theme.typography.body,
            ),
            const SizedBox(height: 16),

            // Client info card
            _buildClientCard(theme),
            const SizedBox(height: 12),

            // Transaction amount
            _buildTransactionCard(theme),

            // Credit breakdown with visual bar (if applicable)
            if (client.creditLimit != null && client.creditLimit! > 0) ...[
              const SizedBox(height: 16),
              _buildCreditBreakdown(theme),
            ],

            // Overdue info (if applicable)
            if (validationResult.type == CreditCheckType.overdueDebt ||
                (client.totalOverdue ?? 0) > 0) ...[
              const SizedBox(height: 16),
              _buildOverdueSection(theme),
            ],

            // Warnings
            ..._buildWarnings(theme),
          ],
        ),
      ),
      actions: _buildActions(context, theme),
    );
  }

  Widget _buildClientCard(FluentThemeData theme) {
    return Card(
      backgroundColor: theme.cardColor,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(FluentIcons.contact, size: 24, color: theme.accentColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client.name,
                  style: theme.typography.bodyStrong,
                ),
                if (client.vat != null && client.vat!.isNotEmpty)
                  Text(
                    client.vat!,
                    style: theme.typography.caption?.copyWith(
                      color: theme.inactiveColor,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(FluentThemeData theme) {
    return Card(
      backgroundColor: theme.accentColor.withAlpha(25),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(FluentIcons.shopping_cart, size: 24, color: theme.accentColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monto de la Transacción',
                  style: theme.typography.caption?.copyWith(
                    color: theme.inactiveColor,
                  ),
                ),
                Text(
                  _currencyFormat.format(orderAmount),
                  style: theme.typography.title?.copyWith(
                    color: theme.accentColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditBreakdown(FluentThemeData theme) {
    final creditLimit = client.creditLimit!;
    final creditUsed = client.credit ?? 0;
    final creditToInvoice = client.creditToInvoice ?? 0;
    final creditAvailable = client.creditAvailable ?? 0;
    final creditAfterTransaction = creditAvailable - orderAmount;

    // Calculate percentages for visual bar
    final usedPercent = (creditUsed / creditLimit * 100).clamp(0.0, 100.0);
    final toInvoicePercent = (creditToInvoice / creditLimit * 100).clamp(0.0, 100.0);
    final transactionPercent = (orderAmount / creditLimit * 100).clamp(0.0, 100.0);
    final totalPercent = usedPercent + toInvoicePercent + transactionPercent;

    return Card(
      backgroundColor: theme.cardColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(FluentIcons.money, size: 20, color: theme.accentColor),
              const SizedBox(width: 8),
              Text('Desglose de Crédito', style: theme.typography.bodyStrong),
            ],
          ),
          const SizedBox(height: 16),

          // Visual credit bar
          _buildCreditVisualBar(
            theme: theme,
            usedPercent: usedPercent,
            toInvoicePercent: toInvoicePercent,
            transactionPercent: transactionPercent,
            isExceeded: totalPercent > 100,
          ),
          const SizedBox(height: 16),

          // Legend
          _buildLegend(theme),
          const SizedBox(height: 16),

          // Detailed breakdown
          const Divider(),
          const SizedBox(height: 8),
          _buildCreditRow(
            theme: theme,
            label: 'Límite de crédito',
            value: creditLimit,
            icon: FluentIcons.chart_y_angle,
          ),
          const SizedBox(height: 6),
          _buildCreditRow(
            theme: theme,
            label: 'Crédito usado (facturas)',
            value: creditUsed,
            color: Colors.red,
            icon: FluentIcons.remove,
          ),
          const SizedBox(height: 6),
          _buildCreditRow(
            theme: theme,
            label: 'Por facturar (órdenes)',
            value: creditToInvoice,
            color: Colors.orange,
            icon: FluentIcons.remove,
          ),
          const SizedBox(height: 6),
          _buildCreditRow(
            theme: theme,
            label: 'Esta transacción',
            value: orderAmount,
            color: Colors.blue,
            icon: FluentIcons.remove,
          ),
          const Divider(),
          const SizedBox(height: 8),
          _buildCreditRow(
            theme: theme,
            label: 'Disponible actual',
            value: creditAvailable,
            color: creditAvailable > 0 ? Colors.green : Colors.red,
            isBold: true,
          ),
          const SizedBox(height: 6),
          _buildCreditRow(
            theme: theme,
            label: 'Después de transacción',
            value: creditAfterTransaction,
            color: creditAfterTransaction >= 0 ? Colors.green : Colors.red,
            isBold: true,
            showSign: true,
          ),

          // Exceeded amount warning
          if (creditAfterTransaction < 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(25),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red.withAlpha(127)),
              ),
              child: Row(
                children: [
                  Icon(FluentIcons.warning, size: 20, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Exceso de crédito',
                          style: theme.typography.bodyStrong?.copyWith(
                            color: Colors.red,
                          ),
                        ),
                        Text(
                          _currencyFormat.format(-creditAfterTransaction),
                          style: theme.typography.subtitle?.copyWith(
                            color: Colors.red,
                          ),
                        ),
                      ],
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

  Widget _buildCreditVisualBar({
    required FluentThemeData theme,
    required double usedPercent,
    required double toInvoicePercent,
    required double transactionPercent,
    required bool isExceeded,
  }) {
    return Column(
      children: [
        Container(
          height: 24,
          decoration: BoxDecoration(
            color: Colors.grey.withAlpha(50),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                // Used (red)
                if (usedPercent > 0)
                  Flexible(
                    flex: usedPercent.round().clamp(1, 100),
                    child: Container(color: Colors.red),
                  ),
                // To Invoice (orange)
                if (toInvoicePercent > 0)
                  Flexible(
                    flex: toInvoicePercent.round().clamp(1, 100),
                    child: Container(color: Colors.orange),
                  ),
                // Transaction (blue with stripes)
                if (transactionPercent > 0)
                  Flexible(
                    flex: transactionPercent.round().clamp(1, 100),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        // Add subtle pattern to distinguish from fixed usage
                      ),
                    ),
                  ),
                // Available (green)
                if (100 - usedPercent - toInvoicePercent - transactionPercent > 0)
                  Flexible(
                    flex: (100 - usedPercent - toInvoicePercent - transactionPercent)
                        .round()
                        .clamp(1, 100),
                    child: Container(color: Colors.green.withAlpha(100)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Percentage labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '0%',
              style: theme.typography.caption?.copyWith(
                color: theme.inactiveColor,
              ),
            ),
            Text(
              isExceeded
                  ? '${(usedPercent + toInvoicePercent + transactionPercent).toStringAsFixed(0)}% (EXCEDIDO)'
                  : '${(usedPercent + toInvoicePercent + transactionPercent).toStringAsFixed(0)}%',
              style: theme.typography.caption?.copyWith(
                color: isExceeded ? Colors.red : theme.inactiveColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '100%',
              style: theme.typography.caption?.copyWith(
                color: theme.inactiveColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLegend(FluentThemeData theme) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _buildLegendItem(theme, Colors.red, 'Usado'),
        _buildLegendItem(theme, Colors.orange, 'Por facturar'),
        _buildLegendItem(theme, Colors.blue, 'Esta transacción'),
        _buildLegendItem(theme, Colors.green.withAlpha(100), 'Disponible'),
      ],
    );
  }

  Widget _buildLegendItem(FluentThemeData theme, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.typography.caption,
        ),
      ],
    );
  }

  Widget _buildCreditRow({
    required FluentThemeData theme,
    required String label,
    required double value,
    Color? color,
    IconData? icon,
    bool isBold = false,
    bool showSign = false,
  }) {
    String formattedValue = _currencyFormat.format(value.abs());
    if (showSign && value != 0) {
      formattedValue = value >= 0 ? '+$formattedValue' : '-$formattedValue';
    }

    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color ?? theme.inactiveColor),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            label,
            style: theme.typography.body?.copyWith(
              color: theme.typography.body?.color?.withAlpha(179),
            ),
          ),
        ),
        Text(
          formattedValue,
          style: theme.typography.body?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildOverdueSection(FluentThemeData theme) {
    return Card(
      backgroundColor: Colors.red.withAlpha(25),
      borderColor: Colors.red.withAlpha(127),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(FluentIcons.warning, size: 20, color: Colors.red),
              const SizedBox(width: 8),
              Text(
                'Deudas Vencidas',
                style: theme.typography.bodyStrong?.copyWith(
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if ((client.totalOverdue ?? 0) > 0)
            _buildOverdueRow(
              theme: theme,
              icon: FluentIcons.money,
              label: 'Total vencido',
              value: _currencyFormat.format(client.totalOverdue!),
            ),
          if ((client.overdueInvoicesCount ?? 0) > 0) ...[
            const SizedBox(height: 8),
            _buildOverdueRow(
              theme: theme,
              icon: FluentIcons.document_set,
              label: 'Facturas vencidas',
              value: '${client.overdueInvoicesCount}',
            ),
          ],
          if ((client.oldestOverdueDays ?? 0) > 0) ...[
            const SizedBox(height: 8),
            _buildOverdueRow(
              theme: theme,
              icon: FluentIcons.calendar,
              label: 'Días de mora máximo',
              value: '${client.oldestOverdueDays} días',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverdueRow({
    required FluentThemeData theme,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.red),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.typography.body?.copyWith(
              color: Colors.red.dark,
            ),
          ),
        ),
        Text(
          value,
          style: theme.typography.bodyStrong?.copyWith(
            color: Colors.red,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildWarnings(FluentThemeData theme) {
    final warnings = <Widget>[];

    // Stale data warning
    if (validationResult.isDataStale) {
      warnings.add(const SizedBox(height: 12));
      warnings.add(
        InfoBar(
          title: const Text('Datos desactualizados'),
          content: const Text(
            'Los datos de crédito pueden no estar actualizados. Conecte a internet para sincronizar.',
          ),
          severity: InfoBarSeverity.warning,
          isIconVisible: true,
        ),
      );
    }

    // Offline warning
    if (validationResult.isOffline && !validationResult.isDataStale) {
      warnings.add(const SizedBox(height: 12));
      warnings.add(
        InfoBar(
          title: const Text('Modo offline'),
          content: const Text(
            'Sin conexión. Se aplica margen de seguridad al límite de crédito.',
          ),
          severity: InfoBarSeverity.warning,
          isIconVisible: true,
        ),
      );
    }

    return warnings;
  }

  List<Widget> _buildActions(BuildContext context, FluentThemeData theme) {
    return [
      // Cancel button (always available)
      Button(
        onPressed: () => Navigator.of(context).pop(CreditDialogAction.cancel),
        child: const Text('Cancelar'),
      ),

      // Proceed anyway (if allowed)
      if (canBypass || client.allowOverCredit)
        Button(
          onPressed: () =>
              Navigator.of(context).pop(CreditDialogAction.proceedAnyway),
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.all(Colors.orange),
          ),
          child: const Text('Continuar de todas formas'),
        ),

      // Create approval request (if online)
      if (isOnline)
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(CreditDialogAction.createApproval),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.check_mark, size: 16),
              SizedBox(width: 8),
              Text('Solicitar Aprobación'),
            ],
          ),
        ),
    ];
  }

  IconData _getFluentIcon() {
    switch (validationResult.type) {
      case CreditCheckType.creditLimitExceeded:
        return FluentIcons.blocked;
      case CreditCheckType.overdueDebt:
        return FluentIcons.warning;
      case CreditCheckType.staleData:
        return FluentIcons.clock;
      default:
        return FluentIcons.info;
    }
  }

  Color _getIconColor() {
    switch (validationResult.type) {
      case CreditCheckType.creditLimitExceeded:
      case CreditCheckType.overdueDebt:
        return Colors.red;
      case CreditCheckType.staleData:
      case CreditCheckType.warning:
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  String _getTitle() {
    switch (validationResult.type) {
      case CreditCheckType.creditLimitExceeded:
        return 'Límite de Crédito Excedido';
      case CreditCheckType.overdueDebt:
        return 'Cliente con Deudas Atrasadas';
      case CreditCheckType.staleData:
        return 'Datos Desactualizados';
      case CreditCheckType.warning:
        return 'Advertencia de Crédito';
      default:
        return 'Control de Crédito';
    }
  }
}
