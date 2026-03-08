import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/spacing.dart';
import '../../../../../shared/utils/formatting_utils.dart';
import '../../../../sales/services/payment_service.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide PaymentState;
import '../../../widgets/payment_detail_dialog.dart';

/// Reactive stream of session payments from local DB.
///
/// AccountPayment model already stores all resolved fields (partnerName,
/// journalName, paymentMethodCategory, paymentOriginType) locally, so we
/// can use `accountPaymentManager.watchLocalSearch()` for real-time updates
/// and map each AccountPayment -> SessionPayment for the existing UI.
final sessionPaymentsMappedProvider =
    StreamProvider.family<List<SessionPayment>, int>((ref, sessionId) {
  return accountPaymentManager.watchLocalSearch(
    domain: [
      ['collection_session_id', '=', sessionId],
    ],
    orderBy: 'date desc',
  ).map((payments) => payments.map((p) => SessionPayment(
    id: p.id,
    name: p.name,
    partnerId: p.partnerId,
    partnerName: p.partnerName,
    journalId: p.journalId,
    journalName: p.journalName,
    paymentMethodLineId: p.paymentMethodLineId,
    paymentMethodLineName: p.paymentMethodLineName,
    amount: p.amount,
    paymentType: p.paymentType,
    state: PaymentState.fromString(p.state),
    date: p.date,
    ref: p.ref,
    originType: PaymentOriginType.fromString(p.paymentOriginType),
    methodCategory: PaymentMethodCategory.fromString(p.paymentMethodCategory),
    collectionSessionId: p.collectionSessionId,
  )).toList());
});

/// Tab de cobros de la sesión de cobranza
///
/// Muestra:
/// - Lista de cobros registrados en la sesión
/// - Filtros por estado, tipo de método, origen
/// - Totales por tipo
/// - Acceso a detalle de cada cobro
class PaymentsTab extends ConsumerStatefulWidget {
  final CollectionSession session;

  const PaymentsTab({super.key, required this.session});

  @override
  ConsumerState<PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends ConsumerState<PaymentsTab> {
  PaymentState? _filterState;
  PaymentMethodCategory? _filterCategory;
  PaymentOriginType? _filterOrigin;
  String _searchText = '';

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final paymentsAsync = ref.watch(sessionPaymentsMappedProvider(widget.session.id));

    return Column(
      children: [
        // Header con filtros
        _buildHeader(theme),
        const SizedBox(height: Spacing.sm),

        // Lista de cobros
        Expanded(
          child: paymentsAsync.when(
            loading: () => const Center(child: ProgressRing()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.error, size: 48, color: Colors.red),
                  const SizedBox(height: Spacing.sm),
                  Text('Error cargando cobros: $e'),
                  const SizedBox(height: Spacing.sm),
                  Button(
                    onPressed: () => ref.invalidate(
                      sessionPaymentsMappedProvider(widget.session.id),
                    ),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
            data: (payments) {
              // Aplicar filtros
              var filtered = payments;
              if (_filterState != null) {
                filtered = filtered
                    .where((p) => p.state == _filterState)
                    .toList();
              }
              if (_filterCategory != null) {
                filtered = filtered
                    .where((p) => p.methodCategory == _filterCategory)
                    .toList();
              }
              if (_filterOrigin != null) {
                filtered = filtered
                    .where((p) => p.originType == _filterOrigin)
                    .toList();
              }
              if (_searchText.isNotEmpty) {
                final search = _searchText.toLowerCase();
                filtered = filtered
                    .where((p) =>
                        (p.name?.toLowerCase().contains(search) ?? false) ||
                        (p.partnerName?.toLowerCase().contains(search) ??
                            false) ||
                        (p.ref?.toLowerCase().contains(search) ?? false) ||
                        (p.journalName?.toLowerCase().contains(search) ??
                            false))
                    .toList();
              }

              if (filtered.isEmpty) {
                return _buildEmptyState(theme, payments.isEmpty);
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
                        return _buildPaymentCard(theme, filtered[index]);
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
      child: Wrap(
        spacing: Spacing.sm,
        runSpacing: Spacing.sm,
        alignment: WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Búsqueda
          SizedBox(
            width: 200,
            child: TextBox(
              placeholder: 'Buscar cobro...',
              prefix: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(FluentIcons.search, size: 16),
              ),
              onChanged: (v) => setState(() => _searchText = v),
            ),
          ),

          // Filtro por estado
          ComboBox<PaymentState?>(
            value: _filterState,
            placeholder: const Text('Estado'),
            items: [
              const ComboBoxItem(value: null, child: Text('Todos')),
              ...PaymentState.values.map(
                (s) => ComboBoxItem(
                  value: s,
                  child: Text(s.label),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _filterState = v),
          ),

          // Filtro por categoría de método
          ComboBox<PaymentMethodCategory?>(
            value: _filterCategory,
            placeholder: const Text('Método'),
            items: [
              const ComboBoxItem(value: null, child: Text('Todos')),
              ...PaymentMethodCategory.values.map(
                (c) => ComboBoxItem(
                  value: c,
                  child: Text(c.label),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _filterCategory = v),
          ),

          // Filtro por origen
          ComboBox<PaymentOriginType?>(
            value: _filterOrigin,
            placeholder: const Text('Origen'),
            items: [
              const ComboBoxItem(value: null, child: Text('Todos')),
              ...PaymentOriginType.values.map(
                (o) => ComboBoxItem(
                  value: o,
                  child: Text(o.label),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _filterOrigin = v),
          ),

          // Botón refrescar
          IconButton(
            icon: const Icon(FluentIcons.refresh),
            onPressed: () =>
                ref.invalidate(sessionPaymentsMappedProvider(widget.session.id)),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsBar(FluentThemeData theme, List<SessionPayment> payments) {
    final totalAmount = payments.fold(0.0, (sum, p) => sum + p.amount);

    // Agrupar por categoría de método
    final cashTotal = payments
        .where((p) => p.methodCategory == PaymentMethodCategory.cash)
        .fold(0.0, (sum, p) => sum + p.amount);
    final cardTotal = payments
        .where((p) =>
            p.methodCategory == PaymentMethodCategory.cardCredit ||
            p.methodCategory == PaymentMethodCategory.cardDebit)
        .fold(0.0, (sum, p) => sum + p.amount);
    final otherTotal = payments
        .where((p) =>
            p.methodCategory != PaymentMethodCategory.cash &&
            p.methodCategory != PaymentMethodCategory.cardCredit &&
            p.methodCategory != PaymentMethodCategory.cardDebit)
        .fold(0.0, (sum, p) => sum + p.amount);

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
            'Efectivo',
            cashTotal,
            FluentIcons.money,
            Colors.green,
          ),
          _buildTotalItem(
            theme,
            'Tarjeta',
            cardTotal,
            FluentIcons.payment_card,
            Colors.blue,
          ),
          _buildTotalItem(
            theme,
            'Otros',
            otherTotal,
            FluentIcons.more,
            Colors.orange,
          ),
          _buildTotalItem(
            theme,
            'Cantidad',
            payments.length.toDouble(),
            FluentIcons.number_field,
            Colors.purple,
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
            FluentIcons.payment_card,
            size: 64,
            color: theme.inactiveColor,
          ),
          const SizedBox(height: Spacing.md),
          Text(
            noData
                ? 'No hay cobros registrados en esta sesión'
                : 'No hay cobros que coincidan con el filtro',
            style: theme.typography.body?.copyWith(
              color: theme.inactiveColor,
            ),
          ),
          if (noData) ...[
            const SizedBox(height: Spacing.md),
            Text(
              'Los cobros se registran desde la pantalla de ventas',
              style: theme.typography.caption?.copyWith(
                color: theme.inactiveColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentCard(FluentThemeData theme, SessionPayment payment) {
    final stateColor = _getStateColor(payment.state);
    final categoryColor = _getCategoryColor(payment.methodCategory);
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: categoryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getCategoryIcon(payment.methodCategory),
            color: categoryColor,
          ),
        ),
        title: Row(
          children: [
            Text(
              payment.name ?? 'Sin nombre',
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
                payment.state.label,
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
              payment.partnerName ?? 'Cliente desconocido',
              style: theme.typography.caption,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    payment.methodCategory.label,
                    style: theme.typography.caption?.copyWith(
                      color: categoryColor,
                      fontSize: 10,
                    ),
                  ),
                ),
                if (payment.originType != null) ...[
                  const SizedBox(width: Spacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: theme.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      payment.originType!.label,
                      style: theme.typography.caption?.copyWith(
                        color: theme.accentColor,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: Spacing.sm),
                Icon(FluentIcons.calendar, size: 12, color: theme.inactiveColor),
                const SizedBox(width: 4),
                Text(
                  payment.date != null
                      ? dateFormat.format(payment.date!)
                      : 'Sin fecha',
                  style: theme.typography.caption?.copyWith(
                    color: theme.inactiveColor,
                  ),
                ),
              ],
            ),
            if (payment.journalName != null) ...[
              const SizedBox(height: 2),
              Text(
                payment.journalName!,
                style: theme.typography.caption?.copyWith(
                  color: theme.inactiveColor,
                ),
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              payment.amount.toCurrency(),
              style: theme.typography.bodyStrong?.copyWith(
                color: payment.isInbound ? Colors.green : Colors.red,
              ),
            ),
            Text(
              payment.isInbound ? 'Cobro' : 'Pago',
              style: theme.typography.caption?.copyWith(
                color: theme.inactiveColor,
              ),
            ),
          ],
        ),
        onPressed: () => _showPaymentDetail(payment),
      ),
    );
  }

  Color _getStateColor(PaymentState state) {
    switch (state) {
      case PaymentState.draft:
        return Colors.grey;
      case PaymentState.posted:
        return Colors.green;
      case PaymentState.canceled:
        return Colors.red;
      case PaymentState.rejected:
        return Colors.red.darker;
    }
  }

  Color _getCategoryColor(PaymentMethodCategory category) {
    switch (category) {
      case PaymentMethodCategory.cash:
        return Colors.green;
      case PaymentMethodCategory.cardCredit:
        return Colors.blue;
      case PaymentMethodCategory.cardDebit:
        return Colors.teal;
      case PaymentMethodCategory.cheque:
        return Colors.orange;
      case PaymentMethodCategory.transfer:
        return Colors.purple;
      case PaymentMethodCategory.other:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(PaymentMethodCategory category) {
    switch (category) {
      case PaymentMethodCategory.cash:
        return FluentIcons.money;
      case PaymentMethodCategory.cardCredit:
      case PaymentMethodCategory.cardDebit:
        return FluentIcons.payment_card;
      case PaymentMethodCategory.cheque:
        return FluentIcons.page;
      case PaymentMethodCategory.transfer:
        return FluentIcons.bank;
      case PaymentMethodCategory.other:
        return FluentIcons.more;
    }
  }

  Future<void> _showPaymentDetail(SessionPayment payment) async {
    await PaymentDetailDialog.show(
      context: context,
      paymentId: payment.id,
    );
    // Refrescar después de cerrar el diálogo
    ref.invalidate(sessionPaymentsMappedProvider(widget.session.id));
  }
}
