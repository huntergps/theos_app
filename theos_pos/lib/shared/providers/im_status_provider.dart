import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/im_status.dart';
import '../../core/services/websocket/odoo_websocket_service.dart';
import '../../features/authentication/services/server_service.dart';
import '../../core/database/repositories/repository_providers.dart';
import '../../core/services/logger_service.dart';

/// Provider for managing user IM status/presence
/// Matches Odoo 19.0 presence system
final imStatusProvider =
    NotifierProvider<ImStatusNotifier, ImStatus>(() => ImStatusNotifier());

class ImStatusNotifier extends Notifier<ImStatus> {
  StreamSubscription<OdooWebSocketEvent>? _subscription;

  @override
  ImStatus build() {
    // Setup WebSocket presence listener
    _setupPresenceListener();

    // Cleanup on dispose
    ref.onDispose(() {
      _subscription?.cancel();
    });

    return ImStatus.online;
  }

  /// Setup WebSocket listener for presence updates using typed event stream
  void _setupPresenceListener() {
    final wsService = ref.read(odooWebSocketServiceProvider);
    final serverService = ref.read(serverServiceProvider.notifier);

    _subscription = wsService.eventStream.listen((event) {
      if (event is OdooPresenceEvent) {
        // Only update if it's our own partner
        final currentPartnerId = serverService.currentSession?.partnerId;
        if (currentPartnerId == event.partnerId) {
          final newStatus = ImStatus.fromString(event.imStatus);
          logger.d(
            '[ImStatusProvider] Presence updated via WebSocket: ${newStatus.label}',
          );
          state = newStatus;
        } else {
          logger.d(
            '[ImStatusProvider] Presence update for different partner: ${event.partnerId} (current: $currentPartnerId)',
          );
        }
      }
    });
  }

  /// Change IM status and sync with Odoo
  Future<bool> setStatus(ImStatus newStatus) async {
    try {
      final repository = ref.read(userRepositoryProvider);
      if (repository == null) {
        logger.d('[ImStatusProvider] UserRepository not initialized');
        return false;
      }

      logger.d('[ImStatusProvider] Changing status to: ${newStatus.label}');

      // Call Odoo API to set status
      final success = await repository.setManualImStatus(
        newStatus.toOdooString(),
      );

      if (success) {
        // Update local state only if API call succeeded
        state = newStatus;
        logger.d('[ImStatusProvider] Status changed to: ${newStatus.label}');
        return true;
      } else {
        logger.d('[ImStatusProvider] Failed to change status');
        return false;
      }
    } catch (e) {
      logger.d('[ImStatusProvider] Error changing status: $e');
      return false;
    }
  }

  /// Initialize status from user data
  void initializeFromUser(String? imStatus) {
    if (imStatus != null) {
      state = ImStatus.fromString(imStatus);
      logger.d('[ImStatusProvider] Initialized status: ${state.label}');
    }
  }

  /// Reset to online (called on login)
  void resetToOnline() {
    state = ImStatus.online;
  }
}
