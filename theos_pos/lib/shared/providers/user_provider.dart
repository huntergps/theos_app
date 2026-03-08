import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/users/users.dart';
import '../../core/services/odoo_service.dart';
import '../../core/database/repositories/repository_providers.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

final userProvider = NotifierProvider<UserNotifier, User?>(
  () => UserNotifier(),
);

/// Notifier to track if the current session is in offline mode
class OfflineModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setOffline(bool value) => state = value;
}

/// Provider to track if the current session is in offline mode
final isOfflineModeProvider = NotifierProvider<OfflineModeNotifier, bool>(
  () => OfflineModeNotifier(),
);

class UserNotifier extends Notifier<User?> {
  @override
  User? build() => null;

  OdooService get _odooService => ref.read(odooServiceProvider);

  /// Get UserRepository if available
  UserRepository? get _repository => ref.read(userRepositoryProvider);

  Future<void> fetchUser() async {
    // Try offline-first repository first
    if (_repository != null) {
      try {
        final user = await _repository!.getCurrentUser();
        if (user != null) {
          // Fetch permissions from local repository
          logger.d('[UserProvider] Fetching permissions for user ${user.id}...');
          final permissions = await _repository!.getCurrentUserGroups();
          logger.d('[UserProvider] Got ${permissions.length} permissions: ${permissions.take(5).join(', ')}${permissions.length > 5 ? '...' : ''}');
          state = user.copyWith(permissions: permissions);
          return;
        }
      } catch (e) {
        logger.d(
          '[UserProvider] Repository error, falling back to OdooService: $e',
        );
      }
    }

    // Fallback to userManager directly
    // Note: User data sync typically happens during login via SyncProvider.
    // Here we just use Odoo data for the session if available.
    if (_odooService.isLoggedIn) {
      try {
        final user = await userManager.getCurrentUser();
        if (user != null) {
          // Try to fetch permissions from local repository if available
          List<String> permissions = [];
          if (_repository != null) {
            try {
              permissions = await _repository!.getCurrentUserGroups();
            } catch (e) {
              logger.d('[UserProvider] Failed to load local permissions: $e');
            }
          }
          logger.d('[UserProvider] Using user from Odoo with ${permissions.length} local permissions');
          state = user.copyWith(permissions: permissions);
        } else {
          state = null;
        }
      } catch (e) {
        logger.d('[UserProvider] userManager fallback error: $e');
        state = null;
      }
    } else {
      state = null;
    }
  }

  void clearUser() {
    state = null;
    // Also reset offline mode when clearing user
    ref.read(isOfflineModeProvider.notifier).setOffline(false);
  }

  /// Set user directly (used for offline login)
  ///
  /// [user] - The User model from local database
  /// [isOffline] - Whether this is an offline login session
  Future<void> setUser(User user, {bool isOffline = false}) async {
    // Load permissions from local database
    List<String> permissions = [];
    if (_repository != null) {
      try {
        permissions = await _repository!.getCurrentUserGroups();
        logger.d('[UserProvider] Loaded ${permissions.length} permissions from local DB');
      } catch (e) {
        logger.d('[UserProvider] Failed to load local permissions: $e');
      }
    }

    // Set the user state with permissions
    state = user.copyWith(permissions: permissions);

    // Set offline mode flag
    ref.read(isOfflineModeProvider.notifier).setOffline(isOffline);

    logger.d('[UserProvider] User set: ${user.name}, offline mode: $isOffline');
  }

  Future<bool> updateUser(Map<String, dynamic> values) async {
    if (state == null) return false;

    // Try repository first for offline-first
    if (_repository != null) {
      try {
        final success = await _repository!.updateUser(state!.id, values);
        if (success) {
          await fetchUser();
          return true;
        }
      } catch (e) {
        logger.d('[UserProvider] Repository update error: $e');
      }
    }

    // Fallback to OdooService
    final success = await _odooService.writeUser(state!.id, values);
    if (success) {
      await fetchUser();
    }
    return success;
  }
}
