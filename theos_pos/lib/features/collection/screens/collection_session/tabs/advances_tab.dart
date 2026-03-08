import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/spacing.dart';
import '../../../../../shared/utils/formatting_utils.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

import '../../../../advances/widgets/advance_detail_dialog.dart';

/// Reactive stream of advances for a collection session.
///
/// Uses `advanceManager.watchLocalSearch()` so UI auto-updates
/// when advances are created, modified, or synced locally.
final sessionAdvancesProvider =
    StreamProvider.family<List<Advance>, int>((ref, sessionId) {
  return advanceManager.watchLocalSearch(
    domain: [['collection_session_id', '=', sessionId]],
  );
});

/// Tab de anticipos de la sesión de cobranza
///
/// Muestra:
/// - Lista de anticipos registrados en la sesión
/// - Filtros por estado
/// - Totales
/// - Acceso a detalle de cada anticipo
class AdvancesTab extends ConsumerStatefulWidget {
  final CollectionSession session;

  const AdvancesTab({super.key, required this.session});

  @override
  ConsumerState<AdvancesTab> createState() => _AdvancesTabState();
}

class _AdvancesTabState extends ConsumerState<AdvancesTab> {
  AdvanceState? _filterState;
  String _searchText = '';

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final advancesAsync = ref.watch(sessionAdvancesProvider(widget.session.id));

    return Column(
      children: [
        // Header con filtros y botón agregar
        _buildHeader(theme),
        const SizedBox(height: Spacing.sm),

        // Lista de anticipos
        Expanded(
          child: advancesAsync.when(
            loading: () => const Center(child: ProgressRing()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.error, size: 48, color: Colors.red),
                  const SizedBox(height: Spacing.sm),
                  Text('Error cargando anticipos: $e'),
                  const SizedBox(height: Spacing.sm),
                  Button(
                    onPressed: () => ref.invalidate(
                      sessionAdvancesProvider(widget.session.id),
                    ),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
            data: (advances) {
              // Aplicar filtros
              var filtered = advances;
              if (_filterState != null) {
                filtered = filtered
                    .where((a) => a.state == _filterState)
                    .toList();
              }
              if (_searchText.isNotEmpty) {
                final search = _searchText.toLowerCase();
                filtered = filtered
                    .where((a) =>
                        (a.name?.toLowerCase().contains(search) ?? false) ||
                        (a.partnerName?.toLowerCase().contains(search) ??
                            false) ||
                        a.reference.toLowerCase().contains(search))
                    .toList();
              }

              if (filtered.isEmpty) {
                return _buildEmptyState(theme, advances.isEmpty);
              }

              return Column(
                children: [
                  // Totales
                  _buildTotalsBar(theme, filtered),
                  const SizedBox(height: Spacing.sm),

                  // Lista
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.md,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        return _buildAdvanceCard(theme, filtered[index]);
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(FluentThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.md),
      child: Row(
        children: [
          // Búsqueda
          Expanded(
            child: TextBox(
              placeholder: 'Buscar anticipo...',
              prefix: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(FluentIcons.search, size: 16),
              ),
              onChanged: (v) => setState(() => _searchText = v),
            ),
          ),
          const SizedBox(width: Spacing.sm),

          // Filtro por estado
          ComboBox<AdvanceState?>(
            value: _filterState,
            placeholder: const Text('Todos'),
            items: [
              const ComboBoxItem(value: null, child: Text('Todos')),
              ...AdvanceState.values.map(
                (s) => ComboBoxItem(
                  value: s,
                  child: Text(s.label),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _filterState = v),
          ),
          const SizedBox(width: Spacing.sm),

          // Botón refrescar
          IconButton(
            icon: const Icon(FluentIcons.refresh),
            onPressed: () =>
                ref.invalidate(sessionAdvancesProvider(widget.session.id)),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsBar(FluentThemeData theme, List<Advance> advances) {
    final totalAmount = advances.fold(0.0, (sum, a) => sum + a.amount);
    final totalAvailable =
        advances.fold(0.0, (sum, a) => sum + a.amountAvailable);
    final totalUsed = advances.fold(0.0, (sum, a) => sum + a.amountUsed);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Spacing.md),
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.resources.controlStrokeColorDefault),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildTotalItem(
            theme,
            'Total',
            totalAmount,
            FluentIcons.money,
            theme.accentColor,
          ),
          _buildTotalItem(
            theme,
            'Disponible',
            totalAvailable,
            FluentIcons.check_mark,
            Colors.green,
          ),
          _buildTotalItem(
            theme,
            'Usado',
            totalUsed,
            FluentIcons.completed,
            Colors.blue,
          ),
          _buildTotalItem(
            theme,
            'Cantidad',
            advances.length.toDouble(),
            FluentIcons.number_field,
            Colors.orange,
            isCount: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTotalItem(
    FluentThemeData theme,
    String label,
    double value,
    IconData icon,
    Color color, {
    bool isCount = false,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.typography.caption?.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          isCount ? value.toInt().toString() : value.toCurrency(),
          style: theme.typography.bodyStrong?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(FluentThemeData theme, bool noData) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FluentIcons.money,
            size: 64,
            color: theme.inactiveColor,
          ),
          const SizedBox(height: Spacing.md),
          Text(
            noData
                ? 'No hay anticipos registrados en esta sesión'
                : 'No hay anticipos que coincidan con el filtro',
            style: theme.typography.body?.copyWith(
              color: theme.inactiveColor,
            ),
          ),
          if (noData) ...[
            const SizedBox(height: Spacing.md),
            Text(
              'Los anticipos se registran desde la pantalla de ventas',
              style: theme.typography.caption?.copyWith(
                color: theme.inactiveColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdvanceCard(FluentThemeData theme, Advance advance) {
    final stateColor = _getStateColor(advance.state);
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: stateColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getStateIcon(advance.state),
            color: stateColor,
          ),
        ),
        title: Row(
          children: [
            Text(
              advance.name ?? 'Sin nombre',
              style: theme.typography.bodyStrong,
            ),
            const SizedBox(width: Spacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.xs,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: stateColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: stateColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                advance.state.label,
                style: theme.typography.caption?.copyWith(
                  color: stateColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              advance.partnerName ?? 'Cliente desconocido',
              style: theme.typography.caption,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(FluentIcons.calendar, size: 12, color: theme.inactiveColor),
                const SizedBox(width: 4),
                Text(
                  dateFormat.format(advance.date),
                  style: theme.typography.caption?.copyWith(
                    color: theme.inactiveColor,
                  ),
                ),
                if (advance.isExpired) ...[
                  const SizedBox(width: Spacing.sm),
                  Icon(FluentIcons.warning, size: 12, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    'Vencido',
                    style: theme.typography.caption?.copyWith(
                      color: Colors.orange,
                    ),
                  ),
                ] else if (advance.daysToExpire != null &&
                    advance.daysToExpire! <= 7) ...[
                  const SizedBox(width: Spacing.sm),
                  Text(
                    'Vence en ${advance.daysToExpire} días',
                    style: theme.typography.caption?.copyWith(
                      color: Colors.orange,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              advance.amount.toCurrency(),
              style: theme.typography.bodyStrong?.copyWith(
                color: theme.accentColor,
              ),
            ),
            Text(
              'Disponible: ${advance.amountAvailable.toCurrency()}',
              style: theme.typography.caption?.copyWith(
                color: advance.amountAvailable > 0
                    ? Colors.green
                    : theme.inactiveColor,
              ),
            ),
            if (advance.usagePercentage > 0)
              Text(
                '${advance.usagePercentage.toFixed(0)}% usado',
                style: theme.typography.caption?.copyWith(
                  color: theme.inactiveColor,
                ),
              ),
          ],
        ),
        onPressed: () => _showAdvanceDetail(advance),
      ),
    );
  }

  Color _getStateColor(AdvanceState state) {
    switch (state) {
      case AdvanceState.draft:
        return Colors.grey;
      case AdvanceState.posted:
        return Colors.green;
      case AdvanceState.inUse:
        return Colors.blue;
      case AdvanceState.used:
        return Colors.teal;
      case AdvanceState.expired:
        return Colors.orange;
      case AdvanceState.canceled:
        return Colors.red;
      case AdvanceState.rejected:
        return Colors.red.darker;
    }
  }

  IconData _getStateIcon(AdvanceState state) {
    switch (state) {
      case AdvanceState.draft:
        return FluentIcons.edit;
      case AdvanceState.posted:
        return FluentIcons.check_mark;
      case AdvanceState.inUse:
        return FluentIcons.sync;
      case AdvanceState.used:
        return FluentIcons.completed;
      case AdvanceState.expired:
        return FluentIcons.warning;
      case AdvanceState.canceled:
        return FluentIcons.cancel;
      case AdvanceState.rejected:
        return FluentIcons.blocked;
    }
  }

  Future<void> _showAdvanceDetail(Advance advance) async {
    await AdvanceDetailDialog.show(
      context: context,
      advanceId: advance.id,
    );
    // Refrescar después de cerrar el diálogo
    ref.invalidate(sessionAdvancesProvider(widget.session.id));
  }
}
