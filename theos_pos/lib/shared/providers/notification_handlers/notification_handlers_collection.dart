part of '../notification_provider.dart';

// ============================================================
// COLLECTION SESSION — WebSocket Sync Handlers
// ============================================================
//
// Extraído de notification_provider.dart (refactor de descomposición,
// plan aprobado por software-architect). Cero cambio de comportamiento:
// los métodos se movieron tal cual, solo cambia su ubicación física.

// El `on Notifier<...>` es necesario para que el acceso a `.state` de otros
// notifiers (miembro @protected de AnyNotifier) sea legal desde este mixin,
// igual que lo era cuando este código vivía dentro de la clase.
mixin _CollectionNotificationHandlers on Notifier<NotificationCounter> {

  /// Handle session created with UUID notification
  /// Updates currentSessionProvider with the real session data from Odoo
  Future<void> _handleSessionCreatedWithUuid({
    required int sessionId,
    required String sessionUuid,
    String? sessionName,
  }) async {
    try {
      logger.d(
        '[NotificationProvider] 🔄 Updating currentSession: id=$sessionId, uuid=$sessionUuid, name=$sessionName',
      );

      // Get current session from provider
      final currentSession = ref.read(currentSessionProvider);

      // If the current session has the same UUID (was created locally), update it
      if (currentSession != null && currentSession.sessionUuid == sessionUuid) {
        // Fetch the complete session from Odoo
        final collectionRepo = ref.read(collectionRepositoryProvider);
        if (collectionRepo != null) {
          final odooSession = await collectionRepo.fetchSessionFromOdoo(
            sessionId,
          );
          if (odooSession != null) {
            // Update currentSessionProvider with the real data
            ref.read(currentSessionProvider.notifier).state = odooSession;
            logger.d(
              '[NotificationProvider] ✅ currentSessionProvider updated: ${odooSession.name}',
            );
          }
        }
      }
    } catch (e) {
      logger.d(
        '[NotificationProvider] ❌ Error handling session created with UUID: $e',
      );
    }
  }

  /// Handle collection session/config update notification
  /// Refreshes collection configs and sessions from Odoo to update dashboard and session screens
  /// If [sessionId] is provided, also refreshes the specific session from Odoo
  Future<void> _handleCollectionUpdate({int? sessionId}) async {
    try {
      // Force refresh collection configs provider to update UI immediately
      // This will trigger syncCollectionConfigs() which fetches fresh data from Odoo
      final _ = await ref.refresh(collectionConfigsProvider.future);

      // ✅ Si se proporciona sessionId, actualizar la sesión DESDE ODOO primero
      // y luego invalidar el provider para que la UI se actualice con datos frescos
      if (sessionId != null) {
        final collectionRepo = ref.read(collectionRepositoryProvider);
        if (collectionRepo != null) {
          // Forzar actualización desde Odoo (no solo base de datos local)
          final refreshedSession = await collectionRepo.getCollectionSession(
            sessionId,
            forceRefresh: true, // Obtener datos frescos de Odoo
          );

          if (refreshedSession != null) {
            logger.d(
              '[NotificationProvider] ✅ Session $sessionId refreshed from Odoo: state=${refreshedSession.state}',
            );

            // Si esta es la sesión actual, actualizar el currentSessionProvider también
            final currentSession = ref.read(currentSessionProvider);
            if (currentSession?.id == sessionId ||
                currentSession?.sessionUuid == refreshedSession.sessionUuid) {
              ref.read(currentSessionProvider.notifier).state =
                  refreshedSession;
              logger.d(
                '[NotificationProvider] ✅ currentSessionProvider updated with refreshed session',
              );
            }
          }
        }

        // Invalidar el provider para forzar recarga de la UI
        ref.invalidate(sessionByIdProvider(sessionId));
        logger.d(
          '[NotificationProvider] ✅ Session $sessionId provider invalidated',
        );
      }

      logger.d(
        '[NotificationProvider] ✅ Collection configs refreshed from WebSocket notification',
      );
    } catch (e) {
      logger.d('[NotificationProvider] ❌ Error handling collection update: $e');
    }
  }
}
