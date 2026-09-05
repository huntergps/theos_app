import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:odoo_sdk/odoo_sdk.dart'
    show Failure, CacheFailure, NetworkFailure, ServerFailure;
import 'package:theos_pos_core/theos_pos_core.dart'
    show MailActivity, mailActivityManager;

/// Repository for Activities - Consolidated offline-first implementation
///
/// Uses [mailActivityManager] for all local CRUD operations.
/// Implements offline-first pattern with optimistic updates.
///
/// F5 (eliminación de fuga de OdooClient): este repo ya NO guarda su propio
/// `OdooClient?` — todas sus llamadas RPC son sobre `mail.activity`, modelo
/// gestionado por [mailActivityManager]. Los `search_read` usan
/// `mailActivityManager.client.searchRead(...)`; las acciones custom
/// (`action_done`, `action_cancel`, `action_reschedule_*`) usan
/// `mailActivityManager.callCustomMethod(...)` (ver
/// `odoo_sdk/lib/src/model/manager_actions_mixin.dart`).
class ActivityRepository {
  ActivityRepository({this.rpcTimeout = const Duration(seconds: 30)});

  final Duration rpcTimeout;

  // ============ Read Operations ============

  /// Get all activities from local cache
  Future<Either<Failure, List<MailActivity>>> getActivities() async {
    try {
      final models = await mailActivityManager.searchLocal();
      return Right(models);
    } catch (e) {
      return Left(CacheFailure(message: 'Error getting activities: $e'));
    }
  }

  /// Get activities filtered by user
  Future<Either<Failure, List<MailActivity>>> getActivitiesByUser(
    int userId,
  ) async {
    try {
      final allActivities = await mailActivityManager.searchLocal();
      final filtered = allActivities.where((a) => a.userId == userId).toList();
      return Right(filtered);
    } catch (e) {
      return Left(CacheFailure(message: 'Error getting user activities: $e'));
    }
  }

  /// Get overdue activities
  Future<Either<Failure, List<MailActivity>>> getOverdueActivities() async {
    try {
      final allActivities = await mailActivityManager.searchLocal();
      final filtered = allActivities
          .where((a) => a.state == 'overdue')
          .toList();
      return Right(filtered);
    } catch (e) {
      return Left(
        CacheFailure(message: 'Error getting overdue activities: $e'),
      );
    }
  }

  /// Get today's activities
  Future<Either<Failure, List<MailActivity>>> getTodayActivities() async {
    try {
      final allActivities = await mailActivityManager.searchLocal();
      final filtered = allActivities.where((a) => a.state == 'today').toList();
      return Right(filtered);
    } catch (e) {
      return Left(CacheFailure(message: 'Error getting today activities: $e'));
    }
  }

  // ============ Sync Operations ============

  /// Sync activities from server and return updated list
  Future<Either<Failure, List<MailActivity>>> syncAndGet(int userId) async {
    if (!mailActivityManager.isOnline) {
      return const Left(
        NetworkFailure(
          message: 'Sin conexion con el servidor. Se conservan las actividades guardadas.',
        ),
      );
    }

    try {
      // Fetch from server
      final response = await mailActivityManager.client
          .searchRead(
            model: 'mail.activity',
            fields: mailActivityManager.odooFields,
            domain: [
              ['user_id', '=', userId],
            ],
            order: 'date_deadline asc',
          )
          .timeout(rpcTimeout);

      final remoteModels = response
          .map((json) => mailActivityManager.fromOdoo(json))
          .toList();

      // Replace the cache atomically only after a complete remote response.
      // A mapping or local persistence error must leave the previous cache
      // intact so the activities screen remains usable offline.
      await mailActivityManager.database.transaction(() async {
        await mailActivityManager.deleteAllLocal();
        await mailActivityManager.upsertLocalBatch(remoteModels);
      });

      // Return models directly
      return Right(remoteModels);
    } catch (e) {
      return Left(_remoteFailure('sincronizar las actividades', e));
    }
  }

  // ============ Action Operations ============

  /// Complete activity (mark as done)
  Future<Either<Failure, bool>> completeActivity(int activityId) async {
    return _executeRemovalAction(
      activityId: activityId,
      method: 'action_done',
      actionLabel: 'completar la actividad',
    );
  }

  /// Cancel activity
  Future<Either<Failure, bool>> cancelActivity(int activityId) async {
    return _executeRemovalAction(
      activityId: activityId,
      method: 'action_cancel',
      actionLabel: 'cancelar la actividad',
    );
  }

  Future<Either<Failure, bool>> _executeRemovalAction({
    required int activityId,
    required String method,
    required String actionLabel,
  }) async {
    if (!mailActivityManager.isOnline) {
      return Left(
        NetworkFailure(
          message:
              'Sin conexion con el servidor. No se pudo $actionLabel y la actividad se conserva.',
        ),
      );
    }

    try {
      final remoteResult = await mailActivityManager
          .callCustomMethod<dynamic>(method, ids: [activityId])
          .timeout(rpcTimeout);
      if (remoteResult == false) {
        return Left(
          ServerFailure(
            message:
                'El servidor rechazo la operacion de $actionLabel. La actividad se conserva.',
          ),
        );
      }
    } catch (e) {
      return Left(_remoteFailure(actionLabel, e));
    }

    try {
      // Local removal is deliberately last: the record remains visible until
      // Odoo has confirmed the action, eliminating false success offline or
      // after RPC errors/timeouts.
      await mailActivityManager.deleteLocal(activityId);
      return const Right(true);
    } catch (e) {
      return Left(
        CacheFailure(
          message:
              'El servidor confirmo la operacion, pero no se pudo actualizar la copia local: $e',
          originalError: e,
        ),
      );
    }
  }

  Failure _remoteFailure(String actionLabel, Object error) {
    if (error is TimeoutException) {
      return NetworkFailure(
        message:
            'Tiempo de espera agotado al $actionLabel. La informacion local se conserva.',
        code: 'TIMEOUT',
        originalError: error,
      );
    }
    return ServerFailure(
      message:
          'No se pudo $actionLabel en el servidor. La informacion local se conserva.',
      originalError: error,
    );
  }

  // ============ Notification Operations ============

  /// Get notification counters from local cache
  Future<Map<String, dynamic>?> getNotificationCounters() async {
    return null;
  }

  /// Get activity counters from local cache
  Future<Map<String, dynamic>?> getActivityCounters() async {
    try {
      final activities = await mailActivityManager.searchLocal();
      final overdueCount = activities.where((a) => a.state == 'overdue').length;
      final todayCount = activities.where((a) => a.state == 'today').length;
      final plannedCount = activities.where((a) => a.state == 'planned').length;

      return {
        'activityCounter': activities.length,
        'overdueCount': overdueCount,
        'todayCount': todayCount,
        'plannedCount': plannedCount,
      };
    } catch (_) {
      return null;
    }
  }

  /// Refresh single activity from server
  Future<void> refreshSingleActivity(int activityId) async {
    if (!mailActivityManager.isOnline) return;

    try {
      final response = await mailActivityManager.client.searchRead(
        model: 'mail.activity',
        fields: mailActivityManager.odooFields,
        domain: [
          ['id', '=', activityId],
        ],
        limit: 1,
      );

      if (response.isNotEmpty) {
        final activity = mailActivityManager.fromOdoo(response.first);
        await mailActivityManager.upsertLocal(activity);
      }
    } catch (_) {
      // Silently fail - background operation
    }
  }

  /// Delete activity from local DB
  Future<void> deleteLocalActivity(int activityId) async {
    await mailActivityManager.deleteLocal(activityId);
  }

  // ============ Reschedule Operations ============

  /// Reschedule activity to today
  Future<Either<Failure, bool>> rescheduleToToday(int activityId) async {
    return _reschedule(activityId, 'action_reschedule_today');
  }

  /// Reschedule activity to tomorrow
  Future<Either<Failure, bool>> rescheduleToTomorrow(int activityId) async {
    return _reschedule(activityId, 'action_reschedule_tomorrow');
  }

  /// Reschedule activity to next week
  Future<Either<Failure, bool>> rescheduleToNextWeek(int activityId) async {
    return _reschedule(activityId, 'action_reschedule_nextweek');
  }

  Future<Either<Failure, bool>> _reschedule(
    int activityId,
    String method,
  ) async {
    try {
      if (!mailActivityManager.isOnline) {
        return Left(ServerFailure(message: 'No hay conexion con el servidor'));
      }

      await mailActivityManager.callCustomMethod<dynamic>(
        method,
        ids: [activityId],
      );

      // Refresh the activity from server to get updated date
      final response = await mailActivityManager.client.searchRead(
        model: 'mail.activity',
        fields: mailActivityManager.odooFields,
        domain: [
          ['id', '=', activityId],
        ],
        limit: 1,
      );

      if (response.isNotEmpty) {
        final updatedActivity = mailActivityManager.fromOdoo(response.first);
        await mailActivityManager.upsertLocal(updatedActivity);
      }

      return const Right(true);
    } catch (e) {
      return Left(ServerFailure(message: 'Error rescheduling activity: $e'));
    }
  }
}
