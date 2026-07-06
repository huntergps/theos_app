import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';

import 'credit_status_badge.dart';
import 'package:theos_pos_core/theos_pos_core.dart';
import '../../../../core/constants/app_colors.dart';

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
  final bool isCompact;
  final int staleHours;

  const CreditInfoCard({
    super.key,
    required this.client,
    this.onRefresh,
    this.isCompact = false,
    this.staleHours = 4,
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
          // Credit info rows
          if (client.hasCreditLimit) ...[
            _buildCreditRows(theme),

            // Usage bar — solo mostrar si hay uso real (> 0%)
            if ((client.creditUsagePercentage ?? 0) > 0) ...[
              const SizedBox(height: 8),
              _buildUsageBar(theme),
            ],
          ] else
            _buildNoLimitMessage(theme),

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

    final usageColor = _getUsageColor(client.creditUsagePercentage ?? 0);
    final isStaleNow = _isStale;
    final displayColor = isStaleNow ? Colors.orange : usageColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: displayColor.withAlpha(isStaleNow ? 30 : 25),
        borderRadius: BorderRadius.circular(4),
        border: isStaleNow
            ? Border.all(color: Colors.orange.withAlpha(100), width: 1)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isStaleNow ? FluentIcons.warning : FluentIcons.money,
            size: 12,
            color: displayColor,
          ),
          const SizedBox(width: 4),
          Text(
            'Disp. ${_currencyFormat.format(client.creditAvailable ?? 0)}',
            style: theme.typography.caption?.copyWith(
              color: client.creditExceeded ? AppColors.danger : displayColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '— ${_formatLastSyncShort()}',
            style: theme.typography.caption?.copyWith(
              color: isStaleNow ? Colors.orange : theme.inactiveColor,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 4),
          CreditStatusBadge(status: client.creditStatus),
        ],
      ),
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
          valueColor: creditUsed > 0 ? AppColors.warning : null,
        ),
        const SizedBox(height: 4),
        _buildInfoRow(
          'Por facturar',
          _currencyFormat.format(creditToInvoice),
          theme,
          valueColor: creditToInvoice > 0 ? AppColors.warning : null,
        ),
        const Divider(),
        Row(
          children: [
            Text(
              'Disponible',
              style: theme.typography.body?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (onRefresh != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: IconButton(
                  icon: Icon(
                    FluentIcons.sync,
                    size: 12,
                    color: _isStale ? Colors.orange : theme.inactiveColor,
                  ),
                  onPressed: onRefresh,
                ),
              ),
            const Spacer(),
            Text(
              _currencyFormat.format(client.creditAvailable ?? 0),
              style: theme.typography.body?.copyWith(
                fontWeight: FontWeight.bold,
                color: client.creditExceeded ? AppColors.danger : AppColors.success,
              ),
            ),
          ],
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

  Color _getUsageColor(double percentage) {
    if (percentage >= 100) return AppColors.danger;
    if (percentage >= 80) return AppColors.warning;
    return AppColors.success;
  }

  String _formatLastSyncShort() {
    if (client.creditLastSyncDate == null) return 'sin sync';
    final diff = DateTime.now().difference(client.creditLastSyncDate!);
    if (diff.inDays > 0) return 'hace ${diff.inDays}d';
    if (diff.inHours > 0) return 'hace ${diff.inHours}h';
    if (diff.inMinutes > 0) return 'hace ${diff.inMinutes}m';
    return 'recién';
  }
}
