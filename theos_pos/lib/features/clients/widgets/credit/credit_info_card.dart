import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';

import 'credit_status_badge.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

/// Card showing detailed credit information for a client
///
/// Displays credit limit, usage, available credit, and status
/// with appropriate formatting and visual indicators.
///
/// Usage:
/// ```dart
/// CreditInfoCard(client: client)
/// ```
class CreditInfoCard extends StatelessWidget {
  final Client client;
  final VoidCallback? onRefresh;
  final bool showActions;
  final bool isCompact;
  final int staleHours;

  const CreditInfoCard({
    super.key,
    required this.client,
    this.onRefresh,
    this.showActions = true,
    this.isCompact = false,
    this.staleHours = 24,
  });

  // Computed properties delegating to Client
  bool get _isStale => client.isCreditDataStale(staleHours);

  static final _currencyFormat = NumberFormat.currency(
    locale: 'es_EC',
    symbol: r'$',
    decimalDigits: 2,
  );

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    if (isCompact) {
      return _buildCompactCard(theme);
    }

    return Card(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with status
          _buildHeader(theme),
          const SizedBox(height: 12),

          // Credit info rows
          if (client.hasCreditLimit) ...[
            _buildCreditRows(theme),
            const SizedBox(height: 12),

            // Usage bar
            _buildUsageBar(theme),
          ] else
            _buildNoLimitMessage(theme),

          // Stale data warning
          if (_isStale) ...[
            const SizedBox(height: 12),
            _buildStaleWarning(theme),
          ],

          // Sync button - always visible when onRefresh is provided
          if (onRefresh != null) ...[
            const SizedBox(height: 12),
            _buildSyncButton(theme),
          ],

          // Actions (legacy - for backwards compatibility)
          if (showActions && onRefresh != null) ...[
            const SizedBox(height: 12),
            _buildActions(),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactCard(FluentThemeData theme) {
    if (!client.hasCreditLimit) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withAlpha(25),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FluentIcons.blocked, size: 12, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              'Sin crédito',
              style: theme.typography.caption?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final color = _getUsageColor(client.creditUsagePercentage ?? 0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FluentIcons.money, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            _currencyFormat.format(client.creditAvailable ?? 0),
            style: theme.typography.caption?.copyWith(
              color: client.creditExceeded ? Colors.red : color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          CreditStatusBadge(status: client.creditStatus),
        ],
      ),
    );
  }

  Widget _buildHeader(FluentThemeData theme) {
    return Row(
      children: [
        Icon(
          FluentIcons.money,
          size: 20,
          color: theme.accentColor,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Control de Crédito',
            style: theme.typography.subtitle,
          ),
        ),
        CreditStatusBadge(status: client.creditStatus),
      ],
    );
  }

  Widget _buildCreditRows(FluentThemeData theme) {
    final creditUsed = client.credit ?? 0;
    final creditToInvoice = client.creditToInvoice ?? 0;
    return Column(
      children: [
        _buildInfoRow(
          'Límite de crédito',
          _currencyFormat.format(client.creditLimit ?? 0),
          theme,
        ),
        const SizedBox(height: 4),
        _buildInfoRow(
          'Crédito usado',
          _currencyFormat.format(creditUsed),
          theme,
          valueColor: creditUsed > 0 ? Colors.orange : null,
        ),
        const SizedBox(height: 4),
        _buildInfoRow(
          'Por facturar',
          _currencyFormat.format(creditToInvoice),
          theme,
          valueColor: creditToInvoice > 0 ? Colors.orange : null,
        ),
        const Divider(),
        _buildInfoRow(
          'Disponible',
          _currencyFormat.format(client.creditAvailable ?? 0),
          theme,
          valueColor: client.creditExceeded ? Colors.red : Colors.green,
          isBold: true,
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    FluentThemeData theme, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.typography.body?.copyWith(
            color: theme.typography.body?.color?.withAlpha(179),
          ),
        ),
        Text(
          value,
          style: theme.typography.body?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildUsageBar(FluentThemeData theme) {
    final usagePercent = client.creditUsagePercentage ?? 0;
    final percentage = usagePercent.clamp(0, 100) / 100;
    final color = _getUsageColor(usagePercent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Uso del crédito',
              style: theme.typography.caption,
            ),
            Text(
              '${usagePercent.toStringAsFixed(1)}%',
              style: theme.typography.caption?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ProgressBar(
          value: percentage * 100,
          activeColor: color,
        ),
      ],
    );
  }

  Widget _buildNoLimitMessage(FluentThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(
            FluentIcons.info,
            size: 16,
            color: Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            'Este cliente no tiene límite de crédito configurado',
            style: theme.typography.body?.copyWith(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaleWarning(FluentThemeData theme) {
    return InfoBar(
      title: const Text('Datos desactualizados'),
      content: Text(
        'Los datos de crédito pueden no estar actualizados. '
        'Última sincronización: ${_formatLastSync()}',
      ),
      severity: InfoBarSeverity.warning,
      action: onRefresh != null
          ? Button(
              onPressed: onRefresh,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.sync, size: 12),
                  SizedBox(width: 4),
                  Text('Sincronizar'),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildSyncButton(FluentThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onRefresh,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FluentIcons.sync, size: 14),
            SizedBox(width: 8),
            Text('Sincronizar datos'),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Button(
          onPressed: onRefresh,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.sync, size: 14),
              SizedBox(width: 4),
              Text('Sincronizar'),
            ],
          ),
        ),
      ],
    );
  }

  Color _getUsageColor(double percentage) {
    if (percentage >= 100) return Colors.red;
    if (percentage >= 80) return Colors.orange;
    return Colors.green;
  }

  String _formatLastSync() {
    if (client.creditLastSyncDate == null) return 'Nunca';
    final diff = DateTime.now().difference(client.creditLastSyncDate!);
    if (diff.inDays > 0) return 'Hace ${diff.inDays} días';
    if (diff.inHours > 0) return 'Hace ${diff.inHours} horas';
    if (diff.inMinutes > 0) return 'Hace ${diff.inMinutes} minutos';
    return 'Hace un momento';
  }
}
