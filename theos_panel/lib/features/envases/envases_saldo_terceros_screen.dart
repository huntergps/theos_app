import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:odoo_widgets/odoo_widgets.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import '../../ui/components/orbi_components.dart';
import '../../ui/fluent/orbi_page.dart';
import '../../ui/state_labels.dart';

/// Saldo por tercero (envases en custodia de un cliente o proveedor):
/// `l10n_ec.envases.saldo.tercero`, una vista SQL derivada de
/// `stock.move.line` — Odoo la recalcula sola, esta pantalla sólo la
/// muestra. `EnvasesPartnerBalanceReader`/`EnvasesSaldoTercerosCache`.
///
/// Sólo lectura: no hay ningún número aquí que alguien pueda editar a mano,
/// ni un botón que escriba en Odoo. Lee exclusivamente por [snapshots] — la
/// copia local reactiva de `EnvasesSaldoTercerosCache` — así que sigue
/// mostrando la última copia conocida sin conexión, la misma disciplina que
/// el resto de pantallas de Envases.
///
/// Requiere el permiso `envases_custodia`
/// (`l10n_ec_stock_envases.group_envases_custodia`), independiente de
/// `envases_read`: un custodio sin el grupo básico de envases también debe
/// poder abrir esta pantalla — ver `RouteAccessPolicy`.
class EnvasesSaldoTercerosScreen extends StatefulWidget {
  const EnvasesSaldoTercerosScreen({
    super.key,
    required this.snapshots,
    this.onRefresh,
  });

  final Stream<EnvasesSaldoTercerosSnapshot?> snapshots;
  final VoidCallback? onRefresh;

  @override
  State<EnvasesSaldoTercerosScreen> createState() =>
      _EnvasesSaldoTercerosScreenState();
}

class _EnvasesSaldoTercerosScreenState
    extends State<EnvasesSaldoTercerosScreen> {
  StreamSubscription<EnvasesSaldoTercerosSnapshot?>? _subscription;
  EnvasesSaldoTercerosSnapshot? _snapshot;
  Object? _error;
  bool _waiting = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(covariant EnvasesSaldoTercerosScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshots != widget.snapshots) {
      _subscription?.cancel();
      _snapshot = null;
      _error = null;
      _waiting = true;
      _listen();
    }
  }

  void _listen() {
    _subscription = widget.snapshots.listen(
      (value) {
        if (!mounted) return;
        setState(() {
          _snapshot = value;
          _error = null;
          _waiting = false;
        });
      },
      onError: (Object error, StackTrace stack) {
        if (!mounted) return;
        setState(() {
          _error = error;
          _waiting = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  List<EnvasesPartnerBalanceRow> _filtered(
    List<EnvasesPartnerBalanceRow> rows,
  ) {
    if (_query.isEmpty) return rows;
    return rows
        .where(
          (row) =>
              row.partnerName.toLowerCase().contains(_query) ||
              row.productName.toLowerCase().contains(_query) ||
              row.warehouseName.toLowerCase().contains(_query),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return OrbiPage(
      title: 'Saldo por tercero',
      subtitle: 'Envases en custodia de un cliente o proveedor',
      commands: [
        CommandBarButton(
          key: const Key('envases-saldo-terceros-refresh'),
          icon: const Icon(FluentIcons.refresh),
          label: const Text('Actualizar'),
          tooltip: 'Actualizar saldo por tercero',
          onPressed: widget.onRefresh,
        ),
      ],
      child: _waiting && _snapshot == null && _error == null
          ? const Center(
              child: ProgressRing(key: Key('envases-saldo-terceros-loading')),
            )
          : _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final snapshot = _snapshot;
    if (snapshot == null) {
      if (_error != null) {
        return OrbiErrorState(
          message: 'No se pudo cargar el saldo por tercero.',
          onRetry: widget.onRefresh,
        );
      }
      return const OrbiEmptyState(
        title: 'Sin datos descargados',
        message: 'Aún no hay una copia local del saldo por tercero.',
      );
    }
    final rows = _filtered(snapshot.rows);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) _ErrorBanner(onRetry: widget.onRefresh),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextBox(
            key: const Key('envases-saldo-terceros-filter'),
            placeholder: 'Filtrar por tercero, envase o bodega',
            prefix: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(FluentIcons.search),
            ),
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: snapshot.rows.isEmpty
              ? const OrbiEmptyState(
                  title: 'Sin saldos',
                  message:
                      'No hay envases en custodia de ningún cliente o '
                      'proveedor.',
                )
              : rows.isEmpty
              ? const OrbiEmptyState(
                  title: 'Sin resultados',
                  message: 'No hay saldos que coincidan con el filtro.',
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final window = MediaQuery.sizeOf(context);
                    final portrait =
                        window.height > window.width &&
                        constraints.maxWidth < 1200;
                    final narrow =
                        constraints.maxWidth < OrbiListing.cardBreakpoint ||
                        portrait;
                    return narrow
                        ? _groupedCards(context, rows)
                        : _table(context, rows);
                  },
                ),
        ),
      ],
    );
  }

  Widget _table(BuildContext context, List<EnvasesPartnerBalanceRow> rows) {
    final theme = FluentTheme.of(context);
    return Card(
      backgroundColor: theme.scaffoldBackgroundColor,
      borderColor: theme.resources.surfaceStrokeColorDefault,
      borderRadius: BorderRadius.circular(12),
      padding: const EdgeInsets.all(8),
      child: OrbiListing<EnvasesPartnerBalanceRow>(
        rows: rows,
        storageKey: 'envases-saldo-terceros',
        emptyMessage: 'No hay saldos que coincidan con el filtro.',
        columns: [
          OrbiColumn(
            key: 'tercero',
            label: 'Tercero',
            value: (row) => row.partnerName,
            alwaysVisible: true,
          ),
          OrbiColumn(
            key: 'rol',
            label: 'Rol',
            value: (row) => envasesCustodyRoleLabel(row.role),
          ),
          OrbiColumn(
            key: 'envase',
            label: 'Envase',
            value: (row) => row.productName,
          ),
          OrbiColumn(
            key: 'bodega',
            label: 'Bodega',
            value: (row) => row.warehouseName,
          ),
          OrbiColumn(
            key: 'cantidad',
            label: 'Cantidad',
            numeric: true,
            emphasis: true,
            value: (row) => _formatQuantity(row.quantity),
          ),
        ],
      ),
    );
  }

  Widget _groupedCards(
    BuildContext context,
    List<EnvasesPartnerBalanceRow> rows,
  ) {
    final grouped = <String, List<EnvasesPartnerBalanceRow>>{};
    for (final row in rows) {
      grouped.putIfAbsent(row.partnerName, () => []).add(row);
    }
    final terceros = grouped.keys.toList()..sort();
    final theme = FluentTheme.of(context);
    return ListView(
      key: const Key('envases-saldo-terceros-grouped'),
      children: [
        for (final tercero in terceros) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Text(
              tercero,
              style: theme.typography.bodyStrong,
              key: Key('envases-saldo-terceros-grupo-$tercero'),
            ),
          ),
          for (final row in grouped[tercero]!) _card(context, row),
        ],
      ],
    );
  }

  Widget _card(BuildContext context, EnvasesPartnerBalanceRow row) {
    final theme = FluentTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(row.productName, style: theme.typography.bodyStrong),
            const SizedBox(height: 4),
            Text(
              'Bodega: ${row.warehouseName}',
              style: theme.typography.caption,
            ),
            const SizedBox(height: 4),
            Text('Cantidad: ${_formatQuantity(row.quantity)}'),
            const SizedBox(height: 8),
            OrbiStatusChip(
              label: envasesCustodyRoleLabel(row.role),
              icon: FluentIcons.contact,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final resources = FluentTheme.of(context).resources;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        backgroundColor: resources.systemFillColorCriticalBackground,
        borderColor: resources.systemFillColorCritical,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Icon(
              FluentIcons.error_badge,
              color: resources.systemFillColorCritical,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'No se pudo actualizar. Se conserva la última copia '
                'disponible.',
              ),
            ),
            if (onRetry != null)
              Button(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

String _formatQuantity(double value) =>
    value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
