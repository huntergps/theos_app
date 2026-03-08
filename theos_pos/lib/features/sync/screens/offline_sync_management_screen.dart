import 'dart:convert';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../../../core/database/datasources/datasources.dart';
import '../../../core/database/repositories/repository_providers.dart';
import '../../../shared/widgets/dialogs/copyable_info_bar.dart';
import '../providers/sync_service_providers.dart' show dataPurgeServiceProvider;
import '../services/data_purge_service.dart';
import '../services/offline_sync_service.dart' show SyncOperationStatus;
import '../../../shared/providers/offline_queue_provider.dart';

/// Screen for managing offline sync operations and local data
class OfflineSyncManagementScreen extends ConsumerStatefulWidget {
  const OfflineSyncManagementScreen({super.key});

  @override
  ConsumerState<OfflineSyncManagementScreen> createState() =>
      _OfflineSyncManagementScreenState();
}

class _OfflineSyncManagementScreenState
    extends ConsumerState<OfflineSyncManagementScreen> {
  bool _hasPermission = false;
  bool _isLoadingPurge = true;
  int _localOrdersCount = 0;
  int _pendingOpsCount = 0;
  int _failedOpsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPurgeData();
  }

  Future<void> _loadPurgeData() async {
    setState(() => _isLoadingPurge = true);

    final purgeService = ref.read(dataPurgeServiceProvider);

    final hasPermission = await purgeService.hasPermission();
    final localOrders = await purgeService.getLocalOrdersCount();
    final pendingOps = await purgeService.getPendingOperationsCount();
    final failedOps = await purgeService.getFailedOperationsCount();

    if (mounted) {
      setState(() {
        _hasPermission = hasPermission;
        _localOrdersCount = localOrders;
        _pendingOpsCount = pendingOps;
        _failedOpsCount = failedOps;
        _isLoadingPurge = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final queueState = ref.watch(offlineQueueProvider);
    final isOnline = ref.watch(catalogSyncRepositoryProvider)?.isOnline ?? false;

    return ScaffoldPage(
      header: PageHeader(
        title: Row(
          children: [
            Icon(FluentIcons.cloud_upload, size: 24, color: theme.accentColor),
            const SizedBox(width: 12),
            const Text('Cola Offline'),
          ],
        ),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.refresh),
              label: const Text('Actualizar'),
              onPressed: () {
                ref.read(offlineQueueProvider.notifier).refresh();
                _loadPurgeData();
              },
            ),
            CommandBarButton(
              icon: Icon(
                isOnline ? FluentIcons.plug_connected : FluentIcons.plug_disconnected,
                color: isOnline ? Colors.green : Colors.red,
              ),
              label: Text(isOnline ? 'Conectado' : 'Sin conexion'),
              onPressed: null,
            ),
          ],
        ),
      ),
      content: Column(
        children: [
          // Summary and purge section (fixed height)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildSummarySection(theme, queueState, isOnline),
                const SizedBox(height: 16),
                _buildPurgeSection(theme),
              ],
            ),
          ),

          // Grid section (takes remaining height)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Grid header
                  Row(
                    children: [
                      Icon(FluentIcons.list, size: 20, color: theme.accentColor),
                      const SizedBox(width: 8),
                      Text('Transacciones Pendientes', style: theme.typography.subtitle),
                      const SizedBox(width: 12),
                      if (queueState.totalCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${queueState.totalCount}',
                            style: theme.typography.body?.copyWith(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Data grid
                  Expanded(
                    child: queueState.isLoading
                        ? const Center(child: ProgressRing())
                        : queueState.totalCount == 0
                            ? _buildEmptyState(theme)
                            : _OfflineQueueDataGrid(
                                operations: queueState.operations,
                                syncProgress: queueState.syncProgress,
                                currentSyncIndex: queueState.currentSyncIndex,
                                totalSyncCount: queueState.totalSyncCount,
                                isProcessing: queueState.isProcessing,
                                onRemove: (id) => _confirmRemoveOperation(context, ref, id),
                              ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(
    FluentThemeData theme,
    OfflineQueueState queueState,
    bool isOnline,
  ) {
    return Card(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _SummaryCard(
            title: 'Total',
            count: queueState.totalCount,
            icon: FluentIcons.cloud_upload,
            color: queueState.totalCount > 0 ? Colors.orange : Colors.green,
          ),
          const SizedBox(width: 12),
          if (queueState.criticalCount > 0) ...[
            _SummaryCard(title: 'Criticos', count: queueState.criticalCount, icon: FluentIcons.warning, color: Colors.red),
            const SizedBox(width: 12),
          ],
          if (queueState.highCount > 0) ...[
            _SummaryCard(title: 'Altos', count: queueState.highCount, icon: FluentIcons.important, color: Colors.orange),
            const SizedBox(width: 12),
          ],
          if (queueState.normalCount > 0) ...[
            _SummaryCard(title: 'Normales', count: queueState.normalCount, icon: FluentIcons.info, color: Colors.blue),
            const SizedBox(width: 12),
          ],
          const Spacer(),
          if (queueState.isProcessing)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: ProgressRing(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sincronizando ${queueState.currentSyncIndex}/${queueState.totalSyncCount}',
                      style: theme.typography.body,
                    ),
                    SizedBox(
                      width: 120,
                      child: ProgressBar(
                        value: queueState.totalSyncCount > 0
                            ? (queueState.currentSyncIndex / queueState.totalSyncCount) * 100
                            : 0,
                      ),
                    ),
                  ],
                ),
              ],
            )
          else if (queueState.totalCount > 0)
            FilledButton(
              onPressed: isOnline ? () => ref.read(offlineQueueProvider.notifier).processQueue() : null,
              child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(FluentIcons.sync, size: 14), SizedBox(width: 6), Text('Sincronizar')]),
            ),
        ],
      ),
    );
  }

  Widget _buildPurgeSection(FluentThemeData theme) {
    if (_isLoadingPurge) return const SizedBox(height: 60, child: Center(child: ProgressRing()));
    if (!_hasPermission) return const SizedBox.shrink();

    return Card(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(FluentIcons.broom, size: 16, color: theme.accentColor),
          const SizedBox(width: 8),
          Text('Limpieza:', style: theme.typography.bodyStrong),
          const SizedBox(width: 16),
          _PurgeStatChip(label: 'Ordenes', count: _localOrdersCount, color: Colors.blue),
          const SizedBox(width: 8),
          _PurgeStatChip(label: 'Pendientes', count: _pendingOpsCount, color: Colors.orange),
          const SizedBox(width: 8),
          _PurgeStatChip(label: 'Fallidas', count: _failedOpsCount, color: Colors.red),
          const Spacer(),
          Button(onPressed: _localOrdersCount > 0 ? () => _showPurgeDialog(_PurgeType.orders) : null, child: const Text('Ordenes')),
          const SizedBox(width: 8),
          Button(onPressed: _pendingOpsCount > 0 ? () => _showPurgeDialog(_PurgeType.pending) : null, child: const Text('Cola')),
          const SizedBox(width: 8),
          Button(onPressed: _failedOpsCount > 0 ? () => _showPurgeDialog(_PurgeType.failed) : null, child: const Text('Fallidas')),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _pendingOpsCount > 0 || _localOrdersCount > 0 ? () => _showPurgeDialog(_PurgeType.all) : null,
            style: ButtonStyle(backgroundColor: WidgetStateProperty.all(Colors.red)),
            child: const Text('Purgar Todo'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(FluentThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FluentIcons.completed, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          Text('Todo sincronizado', style: theme.typography.title?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('No hay transacciones pendientes', style: theme.typography.body?.copyWith(color: theme.resources.textFillColorSecondary)),
        ],
      ),
    );
  }

  Future<void> _showPurgeDialog(_PurgeType type) async {
    String title;
    String message;

    switch (type) {
      case _PurgeType.all:
        title = 'Purgar Todo';
        message = 'Se eliminaran $_localOrdersCount ordenes y $_pendingOpsCount operaciones.';
        break;
      case _PurgeType.orders:
        title = 'Eliminar Ordenes';
        message = 'Se eliminaran $_localOrdersCount ordenes no sincronizadas.';
        break;
      case _PurgeType.pending:
        title = 'Limpiar Cola';
        message = 'Se eliminaran $_pendingOpsCount operaciones pendientes.';
        break;
      case _PurgeType.failed:
        title = 'Limpiar Fallidas';
        message = 'Se eliminaran $_failedOpsCount operaciones fallidas.';
        break;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          Button(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: ButtonStyle(backgroundColor: WidgetStateProperty.all(Colors.red)),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (result == true) await _executePurge(type);
  }

  Future<void> _executePurge(_PurgeType type) async {
    final purgeService = ref.read(dataPurgeServiceProvider);
    PurgeResult result;

    switch (type) {
      case _PurgeType.all:
        result = await purgeService.purgeAll();
        break;
      case _PurgeType.orders:
        result = await purgeService.purgeLocalOrders();
        break;
      case _PurgeType.pending:
        result = await purgeService.clearPendingOperations();
        break;
      case _PurgeType.failed:
        result = await purgeService.clearFailedOperations();
        break;
    }

    if (mounted) {
      if (result.success) {
        CopyableInfoBar.showSuccess(
          context,
          title: 'Completado',
          message: 'Ordenes: ${result.ordersDeleted}, Ops: ${result.operationsCleared}',
        );
      } else {
        CopyableInfoBar.showError(
          context,
          title: 'Error',
          message: result.error ?? 'Error',
        );
      }
      await _loadPurgeData();
      ref.read(offlineQueueProvider.notifier).refresh();
    }
  }

  Future<void> _confirmRemoveOperation(BuildContext context, WidgetRef ref, int operationId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Eliminar Operacion'),
        content: const Text('Esta operacion no sera sincronizada. Continuar?'),
        actions: [
          Button(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: ButtonStyle(backgroundColor: WidgetStateProperty.all(Colors.red)),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (result == true) {
      await ref.read(offlineQueueProvider.notifier).removeOperation(operationId);
      _loadPurgeData();
    }
  }
}

enum _PurgeType { all, orders, pending, failed }

/// Summary card
class _SummaryCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;

  const _SummaryCard({required this.title, required this.count, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text('$count', style: theme.typography.bodyStrong?.copyWith(color: color)),
          const SizedBox(width: 4),
          Text(title, style: theme.typography.caption?.copyWith(color: theme.resources.textFillColorSecondary)),
        ],
      ),
    );
  }
}

/// Stat chip for purge section
class _PurgeStatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _PurgeStatChip({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: Text('$label: $count', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

/// Syncfusion DataGrid for offline queue
class _OfflineQueueDataGrid extends StatefulWidget {
  final List<OfflineOperation> operations;
  final Map<int, OperationSyncProgress> syncProgress;
  final int currentSyncIndex;
  final int totalSyncCount;
  final bool isProcessing;
  final void Function(int) onRemove;

  const _OfflineQueueDataGrid({
    required this.operations,
    required this.syncProgress,
    required this.currentSyncIndex,
    required this.totalSyncCount,
    required this.isProcessing,
    required this.onRemove,
  });

  @override
  State<_OfflineQueueDataGrid> createState() => _OfflineQueueDataGridState();
}

class _OfflineQueueDataGridState extends State<_OfflineQueueDataGrid> {
  late _OfflineQueueDataSource _dataSource;

  @override
  void initState() {
    super.initState();
    _dataSource = _OfflineQueueDataSource(
      widget.operations,
      widget.syncProgress,
      widget.isProcessing,
      widget.onRemove,
    );
  }

  @override
  void didUpdateWidget(covariant _OfflineQueueDataGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.operations != oldWidget.operations ||
        widget.syncProgress != oldWidget.syncProgress ||
        widget.isProcessing != oldWidget.isProcessing) {
      _dataSource = _OfflineQueueDataSource(
        widget.operations,
        widget.syncProgress,
        widget.isProcessing,
        widget.onRemove,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      padding: EdgeInsets.zero,
      child: SfDataGrid(
        source: _dataSource,
        allowFiltering: true,
        allowSorting: true,
        columnWidthMode: ColumnWidthMode.fill,
        gridLinesVisibility: GridLinesVisibility.both,
        headerGridLinesVisibility: GridLinesVisibility.both,
        headerRowHeight: 40,
        rowHeight: 85, // Taller rows to show values and progress
        columns: [
          GridColumn(
            columnName: 'priority',
            label: _buildHeader('Prioridad'),
            width: 90,
            allowFiltering: true,
          ),
          GridColumn(
            columnName: 'model',
            label: _buildHeader('Modelo'),
            width: 120,
            allowFiltering: true,
          ),
          GridColumn(
            columnName: 'method',
            label: _buildHeader('Metodo'),
            width: 100,
            allowFiltering: true,
          ),
          GridColumn(
            columnName: 'recordId',
            label: _buildHeader('ID'),
            width: 60,
          ),
          GridColumn(
            columnName: 'createdAt',
            label: _buildHeader('Creado'),
            width: 130,
          ),
          GridColumn(
            columnName: 'retryCount',
            label: _buildHeader('Reintentos'),
            width: 80,
          ),
          GridColumn(
            columnName: 'status',
            label: _buildHeader('Estado'),
            width: 120,
            allowFiltering: true,
          ),
          GridColumn(
            columnName: 'values',
            label: _buildHeader('Valores'),
            minimumWidth: 250,
          ),
          GridColumn(
            columnName: 'actions',
            label: _buildHeader(''),
            width: 50,
            allowFiltering: false,
            allowSorting: false,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}

/// DataSource for SfDataGrid
class _OfflineQueueDataSource extends DataGridSource {
  final List<OfflineOperation> operations;
  final Map<int, OperationSyncProgress> syncProgress;
  final bool isProcessing;
  final void Function(int) onRemove;
  final DateFormat _dateFormat = DateFormat('dd/MM/yy HH:mm');

  _OfflineQueueDataSource(
    this.operations,
    this.syncProgress,
    this.isProcessing,
    this.onRemove,
  ) {
    _buildRows();
  }

  List<DataGridRow> _rows = [];

  void _buildRows() {
    _rows = operations.map((op) {
      return DataGridRow(cells: [
        DataGridCell(columnName: 'priority', value: op),
        DataGridCell(columnName: 'model', value: op),
        DataGridCell(columnName: 'method', value: op),
        DataGridCell(columnName: 'recordId', value: op),
        DataGridCell(columnName: 'createdAt', value: op),
        DataGridCell(columnName: 'retryCount', value: op),
        DataGridCell(columnName: 'status', value: op),
        DataGridCell(columnName: 'values', value: op),
        DataGridCell(columnName: 'actions', value: op),
      ]);
    }).toList();
  }

  @override
  List<DataGridRow> get rows => _rows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final op = row.getCells().first.value as OfflineOperation;

    return DataGridRowAdapter(
      cells: [
        _buildPriorityCell(op),
        _buildModelCell(op),
        _buildMethodCell(op),
        _buildIdCell(op),
        _buildDateCell(op),
        _buildRetryCell(op),
        _buildStatusCell(op),
        _buildValuesCell(op),
        _buildActionsCell(op),
      ],
    );
  }

  Widget _buildPriorityCell(OfflineOperation op) {
    final color = _getPriorityColor(op.priority);
    final label = _getPriorityLabel(op.priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildModelCell(OfflineOperation op) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      child: Text(_getModelName(op.model), style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
    );
  }

  Widget _buildMethodCell(OfflineOperation op) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      child: Text(_getMethodName(op.method), style: const TextStyle(fontSize: 11)),
    );
  }

  Widget _buildIdCell(OfflineOperation op) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      child: Text(op.recordId?.toString() ?? '-', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
    );
  }

  Widget _buildDateCell(OfflineOperation op) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      child: Text(_dateFormat.format(op.createdAt.toLocal()), style: const TextStyle(fontSize: 10)),
    );
  }

  Widget _buildRetryCell(OfflineOperation op) {
    final color = op.retryCount > 0 ? Colors.orange : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      child: Text('${op.retryCount}', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildStatusCell(OfflineOperation op) {
    // Check if this operation is currently being synced
    final progress = syncProgress[op.id];
    if (progress != null && isProcessing) {
      return _buildSyncProgressCell(progress);
    }

    String status;
    Color color;

    if (op.lastError != null && op.lastError!.isNotEmpty) {
      status = 'Error';
      color = Colors.red;
    } else if (op.retryCount >= 10) {
      status = 'Fallido';
      color = Colors.red;
    } else if (op.nextRetryAt != null && op.nextRetryAt!.isAfter(DateTime.now())) {
      final remaining = op.nextRetryAt!.difference(DateTime.now());
      if (remaining.inMinutes > 0) {
        status = 'Retry ${remaining.inMinutes}m';
      } else {
        status = 'Retry ${remaining.inSeconds}s';
      }
      color = Colors.orange;
    } else if (op.retryCount > 0) {
      status = 'Reintentando';
      color = Colors.orange;
    } else {
      status = 'Pendiente';
      color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(status, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildSyncProgressCell(OperationSyncProgress progress) {
    String statusLabel;
    Color color;
    IconData? icon;

    switch (progress.status) {
      case SyncOperationStatus.processing:
        statusLabel = 'Sincronizando...';
        color = Colors.blue;
        break;
      case SyncOperationStatus.success:
        statusLabel = 'Completado';
        color = Colors.green;
        icon = FluentIcons.check_mark;
        break;
      case SyncOperationStatus.failed:
        statusLabel = 'Error';
        color = Colors.red;
        icon = FluentIcons.error;
        break;
      case SyncOperationStatus.skipped:
        statusLabel = 'Omitido';
        color = Colors.orange;
        icon = FluentIcons.warning;
        break;
      case SyncOperationStatus.conflict:
        statusLabel = 'Conflicto';
        color = Colors.orange;
        icon = FluentIcons.warning;
        break;
      case SyncOperationStatus.pending:
        statusLabel = 'Esperando...';
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status label with icon
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (progress.status == SyncOperationStatus.processing)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: ProgressRing(strokeWidth: 2, activeColor: color),
                )
              else if (icon != null)
                Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  statusLabel,
                  style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Progress bar
          SizedBox(
            width: 80,
            child: ProgressBar(
              value: progress.progressPercent,
              activeColor: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
          // Progress text
          Text(
            '${progress.current}/${progress.total} (${progress.progressPercent.toStringAsFixed(0)}%)',
            style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildValuesCell(OfflineOperation op) {
    final values = op.values;

    // Build list of all key-value pairs to display
    final items = <Widget>[];

    // Sort keys for consistent display, prioritizing important fields
    final priorityKeys = ['amount', 'sale_id', 'order_id', 'partner_id', 'product_id', 'name', 'journal_id'];
    final sortedKeys = values.keys.toList()
      ..sort((a, b) {
        final aIndex = priorityKeys.indexOf(a);
        final bIndex = priorityKeys.indexOf(b);
        if (aIndex >= 0 && bIndex >= 0) return aIndex.compareTo(bIndex);
        if (aIndex >= 0) return -1;
        if (bIndex >= 0) return 1;
        return a.compareTo(b);
      });

    for (final key in sortedKeys) {
      final value = values[key];
      if (value == null) continue;

      // Skip internal/technical fields
      if (key.startsWith('_') || key == 'local_id') continue;

      // Format the value for display
      String displayValue;
      if (value is String) {
        displayValue = value.length > 25 ? '${value.substring(0, 22)}...' : value;
      } else if (value is List) {
        displayValue = '[${value.length} items]';
      } else if (value is Map) {
        displayValue = '{...}';
      } else if (value is double) {
        displayValue = value.toStringAsFixed(2);
      } else {
        displayValue = value.toString();
      }

      // Human-readable key names
      final displayKey = _getFieldDisplayName(key);

      items.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$displayKey: ',
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF555555)),
            ),
            Flexible(
              child: Text(
                displayValue,
                style: const TextStyle(fontSize: 9, color: Color(0xFF777777)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // Show error if present
    if (op.lastError != null && op.lastError!.isNotEmpty) {
      items.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FluentIcons.error, size: 10, color: Colors.red),
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                op.lastError!.length > 40 ? '${op.lastError!.substring(0, 37)}...' : op.lastError!,
                style: TextStyle(fontSize: 9, color: Colors.red),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.centerLeft,
        child: const Text('-', style: TextStyle(fontSize: 10, color: Color(0xFF999999))),
      );
    }

    return Tooltip(
      message: const JsonEncoder.withIndent('  ').convert(values),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        alignment: Alignment.topLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: items.take(4).toList(), // Show max 4 fields
        ),
      ),
    );
  }

  String _getFieldDisplayName(String key) {
    const fieldNames = {
      'amount': 'Monto',
      'sale_id': 'Venta',
      'order_id': 'Orden',
      'partner_id': 'Cliente',
      'product_id': 'Producto',
      'name': 'Nombre',
      'journal_id': 'Diario',
      'uuid': 'UUID',
      'session_id': 'Sesion',
      'tax_id': 'Impuesto',
      'payment_type': 'Tipo',
      'ref': 'Ref',
      'date': 'Fecha',
      'product_uom_qty': 'Cant',
      'price_unit': 'Precio',
      'discount': 'Desc',
      'collection_session_id': 'Sesion Caja',
      'payment_method_line_id': 'Metodo Pago',
      'cash_register_balance_start': 'Saldo Inicial',
      'cash_register_balance_end_real': 'Saldo Final',
      'config_id': 'Config',
      'user_id': 'Usuario',
      'warehouse_id': 'Almacen',
      'pricelist_id': 'Lista Precios',
    };
    return fieldNames[key] ?? key;
  }

  Widget _buildActionsCell(OfflineOperation op) {
    return Center(
      child: IconButton(
        icon: Icon(FluentIcons.delete, size: 14, color: Colors.red),
        onPressed: () => onRemove(op.id),
      ),
    );
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case OfflinePriority.critical: return Colors.red;
      case OfflinePriority.high: return Colors.orange;
      case OfflinePriority.normal: return Colors.blue;
      case OfflinePriority.low: return Colors.grey;
      default: return Colors.blue;
    }
  }

  String _getPriorityLabel(int priority) {
    switch (priority) {
      case OfflinePriority.critical: return 'Critico';
      case OfflinePriority.high: return 'Alto';
      case OfflinePriority.normal: return 'Normal';
      case OfflinePriority.low: return 'Bajo';
      default: return 'Normal';
    }
  }

  String _getModelName(String model) {
    switch (model) {
      case 'collection.session': return 'Sesion';
      case 'account.payment': return 'Pago';
      case 'res.partner': return 'Cliente';
      case 'sale.order': return 'Orden';
      case 'sale.order.line': return 'Linea';
      case 'sale.order.withhold.line': return 'Retencion';
      case 'l10n_ec_collection_box.sale.order.payment': return 'Pago Cobro';
      case 'l10n_ec_collection_box.sale.order.payment.wizard': return 'Facturacion';
      default: return model.split('.').last;
    }
  }

  String _getMethodName(String method) {
    switch (method) {
      case 'session_create_and_open': return 'Abrir';
      case 'session_close': return 'Cerrar';
      case 'payment_create': return 'Crear';
      case 'invoice_create_with_payments': return 'Facturar';
      case 'create': return 'Crear';
      case 'write': return 'Editar';
      case 'unlink': return 'Eliminar';
      default: return method;
    }
  }
}
