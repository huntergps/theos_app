import 'package:fluent_ui/fluent_ui.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:theos_pos_core/theos_pos_core.dart' show MailActivity;

import '../utils/activity_translations.dart';
import '../widgets/reschedule_button.dart';
import '../../../shared/utils/formatting_utils.dart';

/// Callbacks para acciones de actividades
typedef ActivityActionCallback = void Function(int activityId);

/// DataSource de Syncfusion para el grid de actividades
class ActivitiesDataSource extends DataGridSource {
  ActivitiesDataSource({
    required List<MailActivity> activities,
    required this.dateFormat,
    this.onRescheduleToday,
    this.onRescheduleTomorrow,
    this.onRescheduleNextWeek,
    this.onMarkAsDone,
    this.onCancel,
  }) {
    updateActivities(activities);
  }

  String dateFormat;
  final ActivityActionCallback? onRescheduleToday;
  final ActivityActionCallback? onRescheduleTomorrow;
  final ActivityActionCallback? onRescheduleNextWeek;
  final ActivityActionCallback? onMarkAsDone;
  final ActivityActionCallback? onCancel;

  List<DataGridRow> _activities = [];

  void updateActivities(List<MailActivity> activities) {
    _activities = activities.map<DataGridRow>((activity) {
      String activityType;
      if (activity.activityTypeName != null &&
          activity.activityTypeName!.isNotEmpty) {
        activityType = translateActivityType(activity.activityTypeName!);
      } else {
        activityType = translateModelName(activity.resModel);
      }

      return DataGridRow(
        cells: [
          DataGridCell<MailActivity>(columnName: 'status', value: activity),
          DataGridCell<String>(
            columnName: 'summary',
            value: activity.summary ?? activity.activityTypeName ?? 'Sin titulo',
          ),
          DataGridCell<String>(
            columnName: 'resName',
            value: activity.resName ?? '-',
          ),
          DataGridCell<String>(
            columnName: 'userName',
            value: activity.userName ?? '-',
          ),
          DataGridCell<String>(columnName: 'activityType', value: activityType),
          DataGridCell<DateTime>(
            columnName: 'dateDeadline',
            value: activity.dateDeadline,
          ),
          DataGridCell<String>(columnName: 'state', value: activity.state),
          DataGridCell<MailActivity>(
            columnName: 'reschedule',
            value: activity,
          ),
          DataGridCell<MailActivity>(columnName: 'done', value: activity),
          DataGridCell<MailActivity>(columnName: 'cancel', value: activity),
        ],
      );
    }).toList();
    notifyListeners();
  }

  @override
  List<DataGridRow> get rows => _activities;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final activity = row.getCells()[0].value as MailActivity;
    final stateColor = _getStateColor(activity.state);

    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        return _buildCell(cell, activity, stateColor);
      }).toList(),
    );
  }

  Widget _buildCell(
    DataGridCell cell,
    MailActivity activity,
    Color stateColor,
  ) {
    switch (cell.columnName) {
      case 'status':
        return _buildStatusCell(stateColor);
      case 'summary':
        return _buildSummaryCell(cell, activity);
      case 'activityType':
        return _buildActivityTypeCell(cell);
      case 'dateDeadline':
        return _buildDateCell(cell, stateColor);
      case 'state':
        return _buildStateCell(activity, stateColor);
      case 'reschedule':
        return _buildRescheduleCell(activity);
      case 'done':
        return _buildDoneCell(activity);
      case 'cancel':
        return _buildCancelCell(activity);
      default:
        return _buildDefaultCell(cell);
    }
  }

  Widget _buildStatusCell(Color stateColor) {
    return Container(
      alignment: Alignment.center,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: stateColor,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildSummaryCell(DataGridCell cell, MailActivity activity) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            cell.value.toString(),
            style: const TextStyle(fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (activity.note != null && activity.note!.isNotEmpty)
            Text(
              activity.note!.replaceAll(RegExp(r'<[^>]*>'), '').trim(),
              style: TextStyle(fontSize: 11, color: Colors.grey[100]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _buildActivityTypeCell(DataGridCell cell) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.all(8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[20],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          cell.value.toString(),
          style: TextStyle(fontSize: 11, color: Colors.grey[100]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildDateCell(DataGridCell cell, Color stateColor) {
    final date = cell.value as DateTime;
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FluentIcons.calendar, size: 14, color: stateColor),
          const SizedBox(width: 4),
          Text(
            _formatDate(date),
            style: TextStyle(
              fontSize: 12,
              color: stateColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateCell(MailActivity activity, Color stateColor) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: stateColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: stateColor.withValues(alpha: 0.3)),
        ),
        child: Text(
          activity.stateLabel,
          style: TextStyle(
            color: stateColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildRescheduleCell(MailActivity activity) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      child: RescheduleButton(
        onRescheduleToday: onRescheduleToday != null
            ? () => onRescheduleToday!(activity.id)
            : null,
        onRescheduleTomorrow: onRescheduleTomorrow != null
            ? () => onRescheduleTomorrow!(activity.id)
            : null,
        onRescheduleNextWeek: onRescheduleNextWeek != null
            ? () => onRescheduleNextWeek!(activity.id)
            : null,
      ),
    );
  }

  Widget _buildDoneCell(MailActivity activity) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      child: Tooltip(
        message: 'Marcar como listo',
        child: IconButton(
          icon: const Icon(FluentIcons.accept, size: 16),
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.isHovered) {
                return Colors.green.withValues(alpha: 0.1);
              }
              return Colors.transparent;
            }),
            foregroundColor: WidgetStateProperty.all(Colors.green),
          ),
          onPressed:
              onMarkAsDone != null ? () => onMarkAsDone!(activity.id) : null,
        ),
      ),
    );
  }

  Widget _buildCancelCell(MailActivity activity) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      child: Tooltip(
        message: 'Cancelar actividad',
        child: IconButton(
          icon: const Icon(FluentIcons.cancel, size: 16),
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.isHovered) {
                return Colors.red.withValues(alpha: 0.1);
              }
              return Colors.transparent;
            }),
            foregroundColor: WidgetStateProperty.all(Colors.red),
          ),
          onPressed: onCancel != null ? () => onCancel!(activity.id) : null,
        ),
      ),
    );
  }

  Widget _buildDefaultCell(DataGridCell cell) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.all(8.0),
      child: Text(
        cell.value?.toString() ?? '',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Color _getStateColor(String state) {
    switch (state) {
      case 'overdue':
        return Colors.red;
      case 'today':
        return Colors.orange;
      case 'planned':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final relativeDate = FormattingUtils.formatRelativeDate(date);

    // Si es 'Hoy', 'Ayer', 'Manana', usar eso
    if (relativeDate == 'Hoy' ||
        relativeDate == 'Ayer' ||
        relativeDate == 'Manana') {
      return relativeDate;
    }

    // Para fechas cercanas, mostrar dias
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final activityDate = DateTime(date.year, date.month, date.day);
    final difference = activityDate.difference(today).inDays;

    if (difference < 0) {
      return 'Hace ${-difference}d';
    } else if (difference <= 7) {
      return 'En ${difference}d';
    }

    // Para fechas lejanas, usar el formato configurado
    return FormattingUtils.formatDate(date, pattern: dateFormat);
  }
}
