import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

part 'mail_activity.model.freezed.dart';
part 'mail_activity.model.g.dart';

/// Activity priority levels
enum ActivityPriority { overdue, today, planned, done }

extension ActivityPriorityExtension on ActivityPriority {
  /// Get display name in Spanish
  String get displayName {
    switch (this) {
      case ActivityPriority.overdue:
        return 'Atrasada';
      case ActivityPriority.today:
        return 'Hoy';
      case ActivityPriority.planned:
        return 'Planificada';
      case ActivityPriority.done:
        return 'Completada';
    }
  }
}

/// Odoo model: mail.activity
@OdooModel('mail.activity', tableName: 'mail_activity_table')
@freezed
abstract class MailActivity with _$MailActivity {
  const MailActivity._();

  const factory MailActivity({
    @OdooId() required int id,
    @OdooInteger(odooName: 'res_id') required int resId,
    @OdooString(odooName: 'res_model') required String resModel,
    @OdooString(odooName: 'res_name') String? resName,
    @OdooString() String? summary,
    @OdooString() String? note,
    @OdooMany2One('mail.activity.type', odooName: 'activity_type_id') int? activityTypeId,
    @OdooMany2OneName(sourceField: 'activity_type_id') String? activityTypeName,
    @OdooMany2One('res.users', odooName: 'user_id') int? userId,
    @OdooMany2OneName(sourceField: 'user_id') String? userName,
    @OdooDate(odooName: 'date_deadline') required DateTime dateDeadline,
    @OdooString() required String state,
    @OdooString() String? icon,
    @OdooBoolean(odooName: 'can_write') @Default(true) bool canWrite,
    @OdooDateTime(odooName: 'create_date', writable: false) DateTime? createDate,
    @OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,
  }) = _MailActivity;

  factory MailActivity.fromJson(Map<String, dynamic> json) =>
      _$MailActivityFromJson(json);

  // ═══════════════════ Computed Properties ═══════════════════

  /// Get display color based on state
  String get stateColor {
    switch (state) {
      case 'overdue':
        return 'red';
      case 'today':
        return 'orange';
      case 'planned':
        return 'green';
      default:
        return 'grey';
    }
  }

  /// Get display label based on state
  String get stateLabel {
    switch (state) {
      case 'overdue':
        return 'Vencida';
      case 'today':
        return 'Hoy';
      case 'planned':
        return 'Planificada';
      default:
        return 'Desconocido';
    }
  }

  /// Check if activity is overdue
  bool get isOverdue => state == 'overdue';

  /// Check if activity is today
  bool get isToday => state == 'today';

  /// Check if activity is planned (future)
  bool get isPlanned => state == 'planned';

  /// Check if activity is done
  bool get isDone => state == 'done';

  /// Check if activity is upcoming (future, not today)
  bool get isUpcoming {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return dateDeadline.isAfter(today) && !isDone;
  }

  /// Check if activity is due today (computed, not from state)
  bool get isDueToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadline = DateTime(
      dateDeadline.year,
      dateDeadline.month,
      dateDeadline.day,
    );
    return deadline == today && !isDone;
  }

  /// Get priority based on state/deadline
  ActivityPriority get priority {
    if (isDone) return ActivityPriority.done;
    if (isOverdue) return ActivityPriority.overdue;
    if (isToday) return ActivityPriority.today;
    return ActivityPriority.planned;
  }

  /// Get display title (summary or activity type)
  String get displayTitle =>
      (summary?.isNotEmpty ?? false) ? summary! : (activityTypeName ?? 'Actividad');

  /// Days until deadline (negative if overdue)
  int get daysUntilDeadline {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadline = DateTime(
      dateDeadline.year,
      dateDeadline.month,
      dateDeadline.day,
    );
    return deadline.difference(today).inDays;
  }

  /// Alias for activityTypeId
  int get activityTypeIdValue => activityTypeId ?? 0;

  /// Alias for activityTypeName
  String get activityTypeNameValue => activityTypeName ?? 'Actividad';

  // ═══════════════════ Factory Methods ═══════════════════

  /// Crear nueva actividad.
  static MailActivity create({
    required int resId,
    required String resModel,
    required DateTime dateDeadline,
    String? summary,
    String? note,
    int? activityTypeId,
    String? activityTypeName,
    int? userId,
    String? userName,
  }) {
    return MailActivity(
      id: 0,
      resId: resId,
      resModel: resModel,
      dateDeadline: dateDeadline,
      state: 'planned',
      summary: summary,
      note: note,
      activityTypeId: activityTypeId,
      activityTypeName: activityTypeName,
      userId: userId,
      userName: userName,
    );
  }
}
