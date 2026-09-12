import 'package:flutter/material.dart';

import '../../app/theme/orbi_theme.dart';
import '../../ui/components/orbi_components.dart';
import 'collection_contracts.dart';

/// Point-of-collection identity for the hub header. A read-only projection of
/// `collection.session.config_id` ("Punto de Cobro",
/// `l10n_ec_collection_box/models/collection_session.py:55`) and the active
/// cashier. Never invented locally and never derived from an amount.
class CollectionPointContext {
  const CollectionPointContext({required this.pointLabel, this.cashierLabel});

  /// Display name of `collection.session.config_id`.
  final String pointLabel;

  /// Cashier/user label for the active session, when known.
  final String? cashierLabel;
}

/// Read-only counts already resolved by `collection.session`
/// (`order_count`, `invoice_count`, `payment_count` —
/// `l10n_ec_collection_box/models/collection_session.py:191-243`). A null
/// field means the count is unknown/not fetched, distinct from an actual
/// zero: unknown must never be shown as empty.
class CollectionSessionRecordCounts {
  const CollectionSessionRecordCounts({
    this.orderCount,
    this.invoiceCount,
    this.paymentCount,
  });
  final int? orderCount;
  final int? invoiceCount;
  final int? paymentCount;
}

/// Availability of a hub tile. Distinguishes "destination not wired yet"
/// from an actual permission/configuration gap so the UI never fakes a
/// working button nor hides a real restriction behind a generic disabled
/// state.
enum CollectionHubActionAvailability {
  available,
  unavailable,
  forbidden,
  notConfigured,
}

/// A single navigation entry of the hub. This screen never runs financial
/// logic itself: [onOpen] is a plain navigation callback supplied by
/// composition (e.g. a `context.go(...)` to an existing/future route). When
/// [onOpen] is null the tile stays visible but inert, distinct from being
/// forbidden or unconfigured.
class CollectionHubAction {
  const CollectionHubAction({
    required this.label,
    required this.description,
    required this.icon,
    this.availability = CollectionHubActionAvailability.available,
    this.onOpen,
  });
  final String label;
  final String description;
  final IconData icon;
  final CollectionHubActionAvailability availability;
  final VoidCallback? onOpen;

  bool get isEnabled =>
      onOpen != null &&
      availability == CollectionHubActionAvailability.available;

  String? get statusLabel => switch (availability) {
    CollectionHubActionAvailability.available => onOpen == null
        ? 'No disponible todavía'
        : null,
    CollectionHubActionAvailability.unavailable => 'No disponible',
    CollectionHubActionAvailability.forbidden => 'Sin autorización',
    CollectionHubActionAvailability.notConfigured => 'No configurado',
  };
}

/// CAJ-09-v2 — contexto de punto y sesión.
///
/// A pure navigation hub composed over already-resolved contracts: the
/// active [shift] (`collection.session.state`), the [point] it belongs to,
/// optional read-only [counts], and three groups of destinations (turn
/// actions, records, closing — the latter maps to
/// `action_session_closing_control`,
/// `l10n_ec_collection_box/models/collection_session.py:2217`). It never
/// books a payment, computes an amount, or talks to Odoo/ERP2 directly —
/// those responsibilities stay in the destinations it points to.
class CollectionSessionHubScreen extends StatelessWidget {
  const CollectionSessionHubScreen({
    super.key,
    required this.point,
    required this.shift,
    required this.turnActions,
    required this.recordActions,
    required this.closing,
    this.counts,
  });

  final CollectionPointContext point;
  final CollectionShiftSnapshot shift;

  /// "Abrir las acciones del turno".
  final List<CollectionHubAction> turnActions;

  /// "Consultar los registros" (CAJ-02: órdenes, facturas, pagos...).
  final List<CollectionHubAction> recordActions;

  /// "Ir a cierre".
  final CollectionHubAction closing;

  final CollectionSessionRecordCounts? counts;

  @override
  Widget build(BuildContext context) => OrbiPageShell(
    title: 'Caja: punto y sesión',
    child: LayoutBuilder(
      builder: (context, constraints) {
        // Grid on desktop and tablet-landscape, list/form on
        // tablet-portrait and phone. The decision follows the real
        // available space (width vs. height of THIS constraints box, the
        // same signal `OperationalShell` already uses for its own
        // wide/compact split), never a hardcoded height threshold.
        final wide =
            constraints.maxWidth >= OrbiTheme.compactBreakpoint &&
            constraints.maxWidth >= constraints.maxHeight;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _contextCard(context),
              const SizedBox(height: OrbiTheme.space16),
              _section(context, 'Acciones del turno', turnActions, wide),
              const SizedBox(height: OrbiTheme.space16),
              _section(context, 'Registros', recordActions, wide),
              const SizedBox(height: OrbiTheme.space16),
              Text('Cierre', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: OrbiTheme.space8),
              _tile(context, closing),
            ],
          ),
        );
      },
    ),
  );

  Widget _contextCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(OrbiTheme.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            liveRegion: true,
            label: 'Punto ${point.pointLabel}, turno ${_stateLabel(shift.state)}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  point.pointLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (point.cashierLabel != null) Text(point.cashierLabel!),
                Text('Turno: ${_stateLabel(shift.state)}'),
              ],
            ),
          ),
          if (counts != null) ...[
            const SizedBox(height: OrbiTheme.space12),
            _countsSummary(),
          ],
        ],
      ),
    ),
  );

  Widget _countsSummary() => Wrap(
    spacing: OrbiTheme.space16,
    runSpacing: OrbiTheme.space4,
    children: [
      _countChip('Órdenes', counts!.orderCount),
      _countChip('Facturas', counts!.invoiceCount),
      _countChip('Pagos', counts!.paymentCount),
    ],
  );

  Widget _countChip(String label, int? value) => OrbiStatusChip(
    label: '$label: ${value?.toString() ?? 'No disponible'}',
    icon: Icons.list_alt,
  );

  Widget _section(
    BuildContext context,
    String title,
    List<CollectionHubAction> actions,
    bool wide,
  ) {
    if (actions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: OrbiTheme.space8),
        wide ? _grid(context, actions) : _list(context, actions),
      ],
    );
  }

  Widget _grid(BuildContext context, List<CollectionHubAction> actions) =>
      LayoutBuilder(
        builder: (context, constraints) {
          const spacing = OrbiTheme.space12;
          const minTileWidth = 260.0;
          final columns = (constraints.maxWidth / (minTileWidth + spacing))
              .floor()
              .clamp(1, actions.length);
          final totalSpacing = spacing * (columns - 1);
          final tileWidth = (constraints.maxWidth - totalSpacing) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final action in actions)
                SizedBox(width: tileWidth, child: _tile(context, action)),
            ],
          );
        },
      );

  Widget _list(BuildContext context, List<CollectionHubAction> actions) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final action in actions) ...[
            _tile(context, action),
            const SizedBox(height: OrbiTheme.space8),
          ],
        ],
      );

  Widget _tile(BuildContext context, CollectionHubAction action) {
    final status = action.statusLabel;
    return Card(
      child: Semantics(
        button: action.isEnabled,
        label: status == null
            ? '${action.label}. ${action.description}'
            : '${action.label}. ${action.description}. $status',
        child: InkWell(
          onTap: action.isEnabled ? action.onOpen : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(OrbiTheme.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(action.icon, semanticLabel: ''),
                    const SizedBox(width: OrbiTheme.space8),
                    Expanded(
                      child: Text(
                        action.label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const Icon(Icons.chevron_right, semanticLabel: ''),
                  ],
                ),
                const SizedBox(height: OrbiTheme.space4),
                Text(action.description),
                if (status != null) ...[
                  const SizedBox(height: OrbiTheme.space8),
                  Text(
                    status,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _stateLabel(CollectionShiftState state) => switch (state) {
    CollectionShiftState.opening => 'Abriendo',
    CollectionShiftState.opened => 'En curso',
    CollectionShiftState.closing => 'Cierre pendiente',
    CollectionShiftState.closed => 'Cerrado',
    CollectionShiftState.conflict => 'Requiere revisión',
  };
}
