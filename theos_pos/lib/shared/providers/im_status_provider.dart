import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/im_status.dart';
import '../../core/database/repositories/repository_providers.dart';

import 'package:odoo_sdk/odoo_sdk.dart' show logger;

/// Provider for managing user IM status/presence
/// Matches Odoo 19.0 presence system
final imStatusProvider = NotifierProvider<ImStatusNotifier, ImStatus>(
  () => ImStatusNotifier(),
);

class ImStatusNotifier extends Notifier<ImStatus> {
  @override
  ImStatus build() => ImStatus.online;

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
