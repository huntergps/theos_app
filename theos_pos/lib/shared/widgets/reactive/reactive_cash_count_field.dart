import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:odoo_widgets/odoo_widgets.dart' show ReactiveNumberInput;

import 'reactive_field_base.dart';
import '../../utils/formatting_utils.dart';

/// Denomination configuration for cash counting
class CashDenomination {
  final String label;
  final double value;
  final bool isCoin;

  const CashDenomination({
    required this.label,
    required this.value,
    this.isCoin = false,
  });

  /// Ecuador currency denominations
  static const List<CashDenomination> ecuadorBills = [
    CashDenomination(label: '\$100', value: 100),
    CashDenomination(label: '\$50', value: 50),
    CashDenomination(label: '\$20', value: 20),
    CashDenomination(label: '\$10', value: 10),
    CashDenomination(label: '\$5', value: 5),
    CashDenomination(label: '\$1', value: 1),
  ];

  static const List<CashDenomination> ecuadorCoins = [
    CashDenomination(label: '\$1', value: 1, isCoin: true),
    CashDenomination(label: '50¢', value: 0.50, isCoin: true),
    CashDenomination(label: '25¢', value: 0.25, isCoin: true),
    CashDenomination(label: '10¢', value: 0.10, isCoin: true),
    CashDenomination(label: '5¢', value: 0.05, isCoin: true),
    CashDenomination(label: '1¢', value: 0.01, isCoin: true),
  ];
}

/// State for cash count with all denominations
class CashCountState {
  final Map<double, int> counts;

  const CashCountState({this.counts = const {}});

  CashCountState copyWith({Map<double, int>? counts}) {
    return CashCountState(counts: counts ?? this.counts);
  }

  int getCount(double denomination) => counts[denomination] ?? 0;

  CashCountState setCount(double denomination, int count) {
    final newCounts = Map<double, int>.from(counts);
    newCounts[denomination] = count;
    return CashCountState(counts: newCounts);
  }

  double get billsTotal {
    double total = 0;
    for (final denom in CashDenomination.ecuadorBills) {
      total += (counts[denom.value] ?? 0) * denom.value;
    }
    return total;
  }

  double get coinsTotal {
    double total = 0;
    for (final denom in CashDenomination.ecuadorCoins) {
      total += (counts[denom.value] ?? 0) * denom.value;
    }
    return total;
  }

  double get total => billsTotal + coinsTotal;

  /// Create from CollectionSessionCash model fields
  factory CashCountState.fromCashModel({
    int bills100 = 0,
    int bills50 = 0,
    int bills20 = 0,
    int bills10 = 0,
    int bills5 = 0,
    int bills1 = 0,
    int coins1 = 0,
    int coins50Cent = 0,
    int coins25Cent = 0,
    int coins10Cent = 0,
    int coins5Cent = 0,
    int coins1Cent = 0,
  }) {
    return CashCountState(
      counts: {
        100.0: bills100,
        50.0: bills50,
        20.0: bills20,
        10.0: bills10,
        5.0: bills5,
        1.0: bills1 + coins1, // Combined for simplicity
        0.50: coins50Cent,
        0.25: coins25Cent,
        0.10: coins10Cent,
        0.05: coins5Cent,
        0.01: coins1Cent,
      },
    );
  }
}

/// A reactive cash counting field with denomination breakdown
///
/// Usage:
/// ```dart
/// ReactiveCashCountField(
///   config: ReactiveFieldConfig(
///     label: 'Conteo de Efectivo',
///     isEditing: true,
///     prefixIcon: FluentIcons.money,
///   ),
///   value: cashCountState,
///   onChanged: (state) => notifier.updateCashCount(state),
/// )
/// ```
class ReactiveCashCountField extends ConsumerWidget {
  final ReactiveFieldConfig config;
  final CashCountState value;
  final ValueChanged<CashCountState>? onChanged;
  final bool showBills;
  final bool showCoins;
  final bool showTotals;
  final bool showSteppers;
  final bool compact;

  const ReactiveCashCountField({
    super.key,
    required this.config,
    required this.value,
    this.onChanged,
    this.showBills = true,
    this.showCoins = true,
    this.showTotals = true,
    this.showSteppers = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);

    if (!config.isEditing) {
      return _buildViewMode(context, theme);
    }

    return _buildEditMode(context, theme);
  }

  Widget _buildViewMode(BuildContext context, FluentThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        if (config.label.isNotEmpty && !config.isCompact)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                if (config.prefixIcon != null) ...[
                  Icon(config.prefixIcon, size: 16, color: theme.accentColor),
                  const SizedBox(width: 8),
                ],
                Text(config.label, style: theme.typography.bodyStrong),
              ],
            ),
          ),
        // Summary totals
        _buildTotalsSummary(theme),
      ],
    );
  }

  Widget _buildEditMode(BuildContext context, FluentThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        if (config.label.isNotEmpty && !config.isCompact)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                if (config.prefixIcon != null) ...[
                  Icon(config.prefixIcon, size: 16, color: theme.accentColor),
                  const SizedBox(width: 8),
                ],
                Text(config.label, style: theme.typography.bodyStrong),
              ],
            ),
          ),
        // Denominations grid
        if (compact) _buildCompactGrid(theme) else _buildFullGrid(theme),
        // Totals
        if (showTotals) ...[
          const SizedBox(height: 16),
          _buildTotalsSummary(theme),
        ],
      ],
    );
  }

  Widget _buildFullGrid(FluentThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bills column
        if (showBills)
          Expanded(
            child: _buildDenominationColumn(
              theme,
              'Billetes',
              CashDenomination.ecuadorBills,
              value.billsTotal,
            ),
          ),
        if (showBills && showCoins) const SizedBox(width: 24),
        // Coins column
        if (showCoins)
          Expanded(
            child: _buildDenominationColumn(
              theme,
              'Monedas',
              CashDenomination.ecuadorCoins,
              value.coinsTotal,
            ),
          ),
      ],
    );
  }

  Widget _buildCompactGrid(FluentThemeData theme) {
    final allDenominations = [
      if (showBills) ...CashDenomination.ecuadorBills,
      if (showCoins) ...CashDenomination.ecuadorCoins,
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: allDenominations.map((denom) {
        return _buildCompactDenominationInput(theme, denom);
      }).toList(),
    );
  }

  Widget _buildDenominationColumn(
    FluentThemeData theme,
    String title,
    List<CashDenomination> denominations,
    double subtotal,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Column header
        Text(
          title,
          style: theme.typography.caption?.copyWith(
            color: theme.inactiveColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        // Denomination rows
        ...denominations.map((denom) => _buildDenominationRow(theme, denom)),
        // Subtotal
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal:',
                style: theme.typography.body?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtotal.toCurrency(),
                style: theme.typography.body?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.accentColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDenominationRow(FluentThemeData theme, CashDenomination denom) {
    final count = value.getCount(denom.value);
    final total = count * denom.value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          // Denomination label
          SizedBox(
            width: 55,
            child: Text(
              denom.label,
              style: theme.typography.body?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Count input with optional steppers
          ReactiveNumberInput(
            value: count,
            showSteppers: showSteppers,
            decimalPlaces: 0,
            onChanged: config.isEnabled
                ? (newCount) {
                    onChanged?.call(
                      value.setCount(denom.value, newCount.toInt()),
                    );
                  }
                : null,
          ),
          const SizedBox(width: 10),
          // Calculated total
          Expanded(
            child: Text(
              total.toCurrency(),
              style: theme.typography.body?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDenominationInput(
    FluentThemeData theme,
    CashDenomination denom,
  ) {
    final count = value.getCount(denom.value);

    return SizedBox(
      width: showSteppers ? 160 : 100,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(denom.label, style: theme.typography.caption),
          const SizedBox(width: 4),
          Expanded(
            child: ReactiveNumberInput(
              value: count,
              showSteppers: showSteppers,
              decimalPlaces: 0,
              onChanged: config.isEnabled
                  ? (newCount) {
                      onChanged?.call(
                        value.setCount(denom.value, newCount.toInt()),
                      );
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsSummary(FluentThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          if (showBills && showCoins) ...[
            _buildTotalRow(theme, 'Billetes:', value.billsTotal),
            const SizedBox(height: 4),
            _buildTotalRow(theme, 'Monedas:', value.coinsTotal),
            const Divider(),
          ],
          _buildTotalRow(theme, 'TOTAL:', value.total, isMain: true),
        ],
      ),
    );
  }

  Widget _buildTotalRow(
    FluentThemeData theme,
    String label,
    double amount, {
    bool isMain = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isMain ? theme.typography.bodyStrong : theme.typography.body,
        ),
        Text(
          amount.toCurrency(),
          style: (isMain ? theme.typography.subtitle : theme.typography.body)
              ?.copyWith(color: theme.accentColor, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
