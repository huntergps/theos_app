part of '../notification_provider.dart';

// ============================================================
// ACTIVITY (mail.activity) — WebSocket Sync Handlers
// ============================================================
//
// Extraído de notification_provider.dart (refactor de descomposición,
// plan aprobado por software-architect). Cero cambio de comportamiento:
// los métodos se movieron tal cual, solo cambia su ubicación física.

mixin _ActivityNotificationHandlers {
  /// Provisto por [NotificationCounterNotifier] (via `Notifier<T>`).
  Ref get ref;

  /// Handle activity created or updated notification
  /// Fetches the specific activity from Odoo and updates local DB
  Future<void> _handleActivityCreatedOrUpdated(int activityId) async {
    try {
      final activityRepo = ref.read(activityRepositoryProvider);
      // Refresh single activity from Odoo (incremental sync)
      await activityRepo.refreshSingleActivity(activityId);

      // With StreamProvider, the UI auto-updates when local DB changes.
      // No manual refresh needed — the stream re-emits automatically.

      logger.d(
        '[NotificationProvider] ✅ Activity $activityId synced (stream auto-refreshes UI)',
      );
    } catch (e) {
      logger.d(
        '[NotificationProvider] ❌ Error handling activity notification: $e',
      );
    }
  }

  /// Handle activity deleted notification
  /// Removes the activity from local DB
  Future<void> _handleActivityDeleted(int activityId) async {
    try {
      final activityRepo = ref.read(activityRepositoryProvider);
      // Delete activity from local DB
      await activityRepo.deleteLocalActivity(activityId);

      // With StreamProvider, the UI auto-updates when local DB changes.
      // No manual refresh needed — the stream re-emits automatically.

      logger.d(
        '[NotificationProvider] ✅ Activity $activityId deleted (stream auto-refreshes UI)',
      );
    } catch (e) {
      logger.d('[NotificationProvider] ❌ Error handling activity deletion: $e');
    }
  }
}
