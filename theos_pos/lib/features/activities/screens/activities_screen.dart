import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';

import '../../../core/database/providers.dart';
import '../../../core/database/repositories/repository_providers.dart';
import '../../../core/services/config_service.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/theme/spacing.dart';
import '../../../shared/widgets/dialogs/copyable_info_bar.dart';
import '../datasources/activities_datasource.dart';
import 'package:theos_pos_core/theos_pos_core.dart' show MailActivity;
import '../widgets/activity_card.dart';

class ActivitiesScreen extends ConsumerStatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  ConsumerState<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends ConsumerState<ActivitiesScreen> {
  String _filterState = 'all'; // all, overdue, today, planned
  String _searchQuery = '';
  bool _isLoading = false;
  late ActivitiesDataSource _dataSource;

  @override
  void initState() {
    super.initState();
    _dataSource = ActivitiesDataSource(
      activities: [],
      dateFormat: 'dd/MM/yyyy',
      onRescheduleToday: _handleRescheduleToday,
      onRescheduleTomorrow: _handleRescheduleTomorrow,
      onRescheduleNextWeek: _handleRescheduleNextWeek,
      onMarkAsDone: _handleMarkAsDone,
      onCancel: _handleCancel,
    );
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    setState(() => _isLoading = true);
    try {
      logger.d('[ActivitiesScreen] Loading activities...');

      final repository = ref.read(activityRepositoryProvider);
      final currentUser = await ref.read(currentUserProvider.future);

      if (currentUser != null) {
        final result = await repository.syncAndGet(currentUser.id);
        result.fold(
          (failure) => logger.d('[ActivitiesScreen] Sync failed: ${failure.message}'),
          (activities) => logger.d('[ActivitiesScreen] Synced ${activities.length} activities'),
        );
        ref.invalidate(activitiesProvider);
      } else {
        logger.d('[ActivitiesScreen] User not available');
      }
    } catch (e, stackTrace) {
      logger.d('[ActivitiesScreen] Error loading activities: $e');
      logger.d('[ActivitiesScreen] Stack trace: $stackTrace');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<MailActivity> _filterActivities(List<MailActivity> activities) {
    var filtered = activities;

    if (_filterState != 'all') {
      filtered = filtered.where((a) => a.state == _filterState).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((a) {
        return (a.summary?.toLowerCase().contains(query) ?? false) ||
            (a.resName?.toLowerCase().contains(query) ?? false) ||
            (a.note?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    filtered.sort((a, b) {
      if (a.isOverdue && !b.isOverdue) return -1;
      if (!a.isOverdue && b.isOverdue) return 1;
      return a.dateDeadline.compareTo(b.dateDeadline);
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final activitiesAsync = ref.watch(activitiesProvider);
    final spacing = ref.watch(themedSpacingProvider);
    final appConfig = ref.watch(configServiceProvider);
    _dataSource.dateFormat = appConfig.dateFormat;

    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Actividades'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.refresh),
              label: const Text('Actualizar'),
              onPressed: _isLoading ? null : _loadActivities,
            ),
          ],
        ),
      ),
      content: Column(
        children: [
          _buildFilters(spacing),
          Expanded(
            child: activitiesAsync.when(
              data: (activities) => _buildContent(activities, spacing),
              loading: () => const Center(child: ProgressRing()),
              error: (error, _) => _buildError(error, spacing),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(ThemedSpacing spacing) {
    return Padding(
      padding: spacing.all.md,
      child: Row(
        children: [
          Expanded(
            child: TextBox(
              placeholder: 'Buscar actividades...',
              prefix: Padding(
                padding: EdgeInsets.only(left: spacing.sm),
                child: const Icon(FluentIcons.search),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          spacing.horizontal.ms,
          SizedBox(
            width: 180,
            child: ComboBox<String>(
              value: _filterState,
              items: const [
                ComboBoxItem(value: 'all', child: Text('Todas')),
                ComboBoxItem(value: 'overdue', child: Text('Vencidas')),
                ComboBoxItem(value: 'today', child: Text('Hoy')),
                ComboBoxItem(value: 'planned', child: Text('Planificadas')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _filterState = value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(List<MailActivity> activities, ThemedSpacing spacing) {
    final filtered = _filterActivities(activities);

    if (filtered.isEmpty) {
      return _buildEmptyState(spacing);
    }

    _dataSource.updateActivities(filtered);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth > 800;
        return isLargeScreen
            ? _buildDataGrid(context)
            : _buildMobileCards(filtered);
      },
    );
  }

  Widget _buildEmptyState(ThemedSpacing spacing) {
    final theme = FluentTheme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FluentIcons.task_logo, size: 64, color: Colors.grey[100]),
          spacing.vertical.md,
          Text(
            _searchQuery.isNotEmpty
                ? 'No se encontraron actividades'
                : 'No hay actividades',
            style: theme.typography.subtitle,
          ),
          spacing.vertical.sm,
          Text(
            _searchQuery.isNotEmpty
                ? 'Intenta con otra busqueda'
                : 'Excelente! Todas tus tareas estan completas',
            style: theme.typography.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildError(Object error, ThemedSpacing spacing) {
    final theme = FluentTheme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FluentIcons.error_badge, size: 48, color: Colors.red),
          spacing.vertical.md,
          const Text('Error al cargar actividades'),
          spacing.vertical.sm,
          Text(error.toString(), style: theme.typography.caption),
          spacing.vertical.md,
          FilledButton(
            onPressed: _loadActivities,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDataGrid(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final headerColor = theme.accentColor
        .defaultBrushFor(theme.brightness)
        .withValues(alpha: 0.2);
    final headerTextColor = isDark ? Colors.white : Colors.black;

    return SfDataGridTheme(
      data: SfDataGridThemeData(headerColor: headerColor),
      child: SfDataGrid(
        source: _dataSource,
        columnWidthMode: ColumnWidthMode.none,
        allowSorting: true,
        allowMultiColumnSorting: true,
        allowColumnsResizing: true,
        showSortNumbers: false,
        selectionMode: SelectionMode.single,
        navigationMode: GridNavigationMode.cell,
        gridLinesVisibility: GridLinesVisibility.both,
        headerGridLinesVisibility: GridLinesVisibility.both,
        headerRowHeight: 48,
        columns: _buildGridColumns(headerTextColor),
      ),
    );
  }

  List<GridColumn> _buildGridColumns(Color headerTextColor) {
    return [
      _buildIconColumn('status', FluentIcons.status_circle_block2, headerTextColor, width: 60),
      _buildTextColumn('summary', 'Actividad', headerTextColor, fill: true),
      _buildTextColumn('resName', 'Documento', headerTextColor, fill: true),
      _buildTextColumn('userName', 'Asignado', headerTextColor, fill: true),
      _buildTextColumn('activityType', 'Tipo', headerTextColor, width: 150),
      _buildTextColumn('dateDeadline', 'Fecha limite', headerTextColor, width: 130, center: true),
      _buildTextColumn('state', 'Estado', headerTextColor, width: 120, center: true, sortable: false),
      _buildIconColumn('reschedule', FluentIcons.calendar, headerTextColor, width: 60, tooltip: 'Reagendar'),
      _buildIconColumn('done', FluentIcons.accept, headerTextColor, width: 60, tooltip: 'Listo'),
      _buildIconColumn('cancel', FluentIcons.cancel, headerTextColor, width: 60, tooltip: 'Cancelar'),
    ];
  }

  GridColumn _buildIconColumn(
    String name,
    IconData icon,
    Color color, {
    double width = 60,
    String? tooltip,
  }) {
    Widget iconWidget = Icon(icon, size: 16, color: color);
    if (tooltip != null) {
      iconWidget = Tooltip(message: tooltip, child: iconWidget);
    }

    return GridColumn(
      columnName: name,
      width: width,
      allowSorting: false,
      label: Container(
        padding: const EdgeInsets.all(8.0),
        alignment: Alignment.center,
        child: iconWidget,
      ),
    );
  }

  GridColumn _buildTextColumn(
    String name,
    String label,
    Color color, {
    double? width,
    bool fill = false,
    bool center = false,
    bool sortable = true,
  }) {
    return GridColumn(
      columnName: name,
      width: width ?? double.nan,
      columnWidthMode: fill ? ColumnWidthMode.fill : ColumnWidthMode.none,
      allowSorting: sortable,
      label: Container(
        padding: const EdgeInsets.all(8.0),
        alignment: center ? Alignment.center : Alignment.centerLeft,
        child: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }

  Widget _buildMobileCards(List<MailActivity> activities) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        return ActivityCard(
          activity: activity,
          onRescheduleToday: () => _handleRescheduleToday(activity.id),
          onRescheduleTomorrow: () => _handleRescheduleTomorrow(activity.id),
          onRescheduleNextWeek: () => _handleRescheduleNextWeek(activity.id),
          onMarkAsDone: () => _handleMarkAsDone(activity.id),
          onCancel: () => _handleCancel(activity.id),
        );
      },
    );
  }

  // =============================================================================
  // ACTION HANDLERS
  // =============================================================================

  Future<void> _handleRescheduleToday(int activityId) async {
    await _executeAction(
      activityId,
      'rescheduleToToday',
      'Actividad reagendada para hoy',
    );
  }

  Future<void> _handleRescheduleTomorrow(int activityId) async {
    await _executeAction(
      activityId,
      'rescheduleToTomorrow',
      'Actividad reagendada para manana',
    );
  }

  Future<void> _handleRescheduleNextWeek(int activityId) async {
    await _executeAction(
      activityId,
      'rescheduleToNextWeek',
      'Actividad reagendada para proxima semana',
    );
  }

  Future<void> _handleMarkAsDone(int activityId) async {
    await _executeAction(activityId, 'completeActivity', 'Actividad completada');
  }

  Future<void> _handleCancel(int activityId) async {
    await _executeAction(activityId, 'cancelActivity', 'Actividad cancelada');
  }

  Future<void> _executeAction(
    int activityId,
    String methodName,
    String successMessage,
  ) async {
    final repository = ref.read(activityRepositoryProvider);
    logger.d('[ActivitiesScreen] Executing $methodName for activity $activityId');

    late final dynamic result;
    switch (methodName) {
      case 'rescheduleToToday':
        result = await repository.rescheduleToToday(activityId);
        break;
      case 'rescheduleToTomorrow':
        result = await repository.rescheduleToTomorrow(activityId);
        break;
      case 'rescheduleToNextWeek':
        result = await repository.rescheduleToNextWeek(activityId);
        break;
      case 'completeActivity':
        result = await repository.completeActivity(activityId);
        break;
      case 'cancelActivity':
        result = await repository.cancelActivity(activityId);
        break;
      default:
        return;
    }

    result.fold(
      (failure) {
        logger.d('[ActivitiesScreen] ${failure.message}');
        if (mounted) _showNotification(failure.message, isError: true);
      },
      (success) {
        logger.d('[ActivitiesScreen] $methodName completed');
        ref.invalidate(activitiesProvider);
        if (mounted) _showNotification(successMessage);
      },
    );
  }

  void _showNotification(String message, {bool isError = false}) {
    if (isError) {
      CopyableInfoBar.showError(
        context,
        title: 'Error',
        message: message,
        durationSeconds: 5,
      );
    } else {
      CopyableInfoBar.showSuccess(
        context,
        title: 'Exito',
        message: message,
        durationSeconds: 3,
      );
    }
  }
}
