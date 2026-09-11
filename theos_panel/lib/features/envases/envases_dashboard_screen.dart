import 'dart:async';

import 'package:flutter/material.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import '../../ui/components/orbi_components.dart';
import '../../ui/components/records/orbi_record_grid.dart';
import '../../ui/bindings/record_view_controller.dart';

/// Read-only Envases dashboard surface.
///
/// The runtime owns the query, cache and synchronization. This widget only
/// renders snapshots supplied by [snapshots] and delegates refresh intent to
/// [onRefresh].
class EnvasesDashboardScreen extends StatefulWidget {
  const EnvasesDashboardScreen({
    super.key,
    required this.snapshots,
    this.workspaceEnvases = 'Envases',
    this.isConnected,
    this.onRefresh,
    this.onProductTap,
  });

  final Stream<EnvasesDashboardSnapshot?> snapshots;
  final String workspaceEnvases;
  final bool? isConnected;
  final VoidCallback? onRefresh;
  final ValueChanged<int>? onProductTap;

  @override
  State<EnvasesDashboardScreen> createState() => _EnvasesDashboardScreenState();
}

class _EnvasesDashboardScreenState extends State<EnvasesDashboardScreen> {
  StreamSubscription<EnvasesDashboardSnapshot?>? _subscription;
  int _streamGeneration = 0;
  late final OrbiRecordViewController<EnvasesDashboardRow> _controller =
      OrbiRecordViewController<EnvasesDashboardRow>();
  late final TextEditingController _productFilter = TextEditingController();
  EnvasesDashboardSnapshot? _snapshot;
  Object? _error;
  bool _waiting = true;
  String _productQuery = '';

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(covariant EnvasesDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshots != widget.snapshots) {
      _streamGeneration++;
      _subscription?.cancel();
      _snapshot = null;
      _error = null;
      _waiting = true;
      _controller.clearSelection();
      _controller.replaceRecords(const <OrbiRecord<EnvasesDashboardRow>>[]);
      _listen();
    }
  }

  void _listen() {
    final generation = _streamGeneration;
    _subscription = widget.snapshots.listen(
      (value) {
        if (!mounted || generation != _streamGeneration) return;
        _controller.replaceRecords(_recordsFor(value));
        setState(() {
          _snapshot = value;
          _error = null;
          _waiting = false;
        });
      },
      onError: (Object error, StackTrace stack) {
        if (!mounted || generation != _streamGeneration) return;
        setState(() {
          _error = error;
          _waiting = false;
        });
      },
      onDone: () {
        if (!mounted || generation != _streamGeneration) return;
        setState(() => _waiting = false);
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _productFilter.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OrbiPageShell(
      title: widget.workspaceEnvases,
      actions: [
        _ConnectionStatus(connected: widget.isConnected),
        IconButton(
          key: const Key('envases-refresh-button'),
          tooltip: 'Actualizar envases',
          onPressed: widget.onRefresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DashboardHeader(title: widget.workspaceEnvases, snapshot: _snapshot),
          if (_snapshot?.rows.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    key: const Key('envases-product-filter'),
                    controller: _productFilter,
                    decoration: const InputDecoration(
                      labelText: 'Filtrar por producto o unidad',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(
                        () => _productQuery = value.trim().toLowerCase(),
                      );
                      _controller.replaceRecords(_recordsFor(_snapshot));
                    },
                  ),
                ),
              ),
            ),
          if (_error != null) _ErrorBanner(onRetry: widget.onRefresh),
          if (_snapshot?.rows.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Mostrando ${_filteredRows(_snapshot!.rows).length} de '
                '${_snapshot!.rows.length} registros',
                key: const Key('envases-filtered-count'),
              ),
            ),
          if (_waiting && _snapshot == null && _error == null)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: _error != null && _snapshot == null
                  ? OrbiErrorState(
                      message: 'No se pudo cargar el dashboard de envases.',
                      onRetry: widget.onRefresh,
                    )
                  : _content(context),
            ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context) {
    final snapshot = _snapshot;
    if (snapshot == null) {
      return const OrbiEmptyState(
        title: 'Sin datos descargados',
        message: 'Aún no hay una copia local del dashboard de envases.',
      );
    }
    if (snapshot.rows.isEmpty) {
      return const OrbiEmptyState(
        title: 'Sin registros',
        message: 'No hay productos de envases en la copia local.',
      );
    }
    final filtered = _filteredRows(snapshot.rows);
    if (filtered.isEmpty) {
      return const OrbiEmptyState(
        title: 'Sin coincidencias',
        message: 'No hay productos que coincidan con el filtro.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.onProductTap == null)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Vista agregada; detalle por ubicación no disponible en esta conexión',
            ),
          ),
        Expanded(
          child: Card(
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            color: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: OrbiRecordGrid<EnvasesDashboardRow>(
                controller: _controller,
                columns: _columns,
                cardBuilder: _envasesCard,
                onRecordTap: widget.onProductTap == null
                    ? null
                    : (record) => widget.onProductTap!(record.value.productId),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<OrbiRecord<EnvasesDashboardRow>> _recordsFor(
    EnvasesDashboardSnapshot? snapshot,
  ) => [
    for (final row in _filteredRows(snapshot?.rows ?? const []))
      OrbiRecord<EnvasesDashboardRow>(
        id: '${row.companyId}:${row.productId}',
        value: row,
      ),
  ];

  List<EnvasesDashboardRow> _filteredRows(List<EnvasesDashboardRow> rows) =>
      _productQuery.isEmpty
      ? rows
      : rows
            .where(
              (row) =>
                  row.productName.toLowerCase().contains(_productQuery) ||
                  row.uomName.toLowerCase().contains(_productQuery),
            )
            .toList(growable: false);

  List<OrbiRecordColumn<EnvasesDashboardRow>> get _columns => [
    OrbiRecordColumn(
      id: 'product',
      label: 'Producto',
      value: (row) => row.productName,
    ),
    OrbiRecordColumn(
      id: 'packaging',
      label: 'Envase / unidad',
      value: (row) => row.uomName,
    ),
    _quantityColumn('total_propio', 'Total propio', (row) => row.totalPropio),
    _quantityColumn('en_sede', 'En sede', (row) => row.enSede),
    _quantityColumn(
      'en_custodia_cliente',
      'Custodia cliente',
      (row) => row.enCustodiaCliente,
    ),
    _quantityColumn(
      'en_custodia_proveedor',
      'Custodia proveedor',
      (row) => row.enCustodiaProveedor,
    ),
    _quantityColumn('en_transito', 'En tránsito', (row) => row.enTransito),
    _quantityColumn(
      'danados',
      'Dañados (incluidos en total)',
      (row) => row.danados,
    ),
  ];

  OrbiRecordColumn<EnvasesDashboardRow> _quantityColumn(
    String id,
    String label,
    double Function(EnvasesDashboardRow) value,
  ) => OrbiRecordColumn(
    id: id,
    label: label,
    textAlign: TextAlign.end,
    value: (row) => '${_formatQuantity(value(row))} ${row.uomName}',
  );

  Widget _envasesCard(
    BuildContext context,
    OrbiRecord<EnvasesDashboardRow> record,
  ) {
    final row = record.value;
    final metrics = <String, double>{
      'En sede': row.enSede,
      'Custodia cliente': row.enCustodiaCliente,
      'Custodia proveedor': row.enCustodiaProveedor,
      'En tránsito': row.enTransito,
      'Dañados': row.danados,
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 600 ? 2 : 1;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.productName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(row.uomName),
                        ],
                      ),
                    ),
                    Chip(
                      label: Text(
                        '${_formatQuantity(row.totalPropio)} propios',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (var index = 0; index < metrics.length; index += columns)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: index + columns < metrics.length ? 8 : 0,
                    ),
                    child: Row(
                      children: [
                        for (final entry
                            in metrics.entries.skip(index).take(columns))
                          Expanded(
                            child: Padding(
                              padding: EdgeInsetsDirectional.only(
                                end:
                                    entry.key ==
                                        metrics.entries
                                            .skip(index)
                                            .take(columns)
                                            .last
                                            .key
                                    ? 0
                                    : 8,
                              ),
                              child: _metric(
                                context,
                                entry.key,
                                entry.value,
                                row.uomName,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _metric(
    BuildContext context,
    String label,
    double value,
    String unit,
  ) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Text('${_formatQuantity(value)} $unit'),
        ],
      ),
    ),
  );
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.title, required this.snapshot});

  final String title;
  final EnvasesDashboardSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estado de envases',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          const Text('Consulta la propiedad de envases por producto y unidad.'),
          if (snapshot != null) ...[
            const SizedBox(height: 4),
            Text(
              'Última descarga en este equipo: ${_formatDate(snapshot!.cachedAt)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({required this.connected});

  final bool? connected;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(
      connected == null
          ? Icons.cloud_outlined
          : connected!
          ? Icons.cloud_done_outlined
          : Icons.cloud_off_outlined,
      size: 18,
    ),
    label: Text(
      connected == null
          ? 'Red sin verificar'
          : connected!
          ? 'Conectado'
          : 'Sin conexión',
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        leading: Icon(
          Icons.error_outline,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
        title: const Text('No se pudo actualizar el dashboard.'),
        subtitle: const Text('Se conserva la última copia disponible.'),
        trailing: onRetry == null
            ? null
            : TextButton(onPressed: onRetry, child: const Text('Reintentar')),
      ),
    ),
  );
}

String _formatQuantity(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

String _formatDate(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
