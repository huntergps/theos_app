import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/users/users.dart';
import '../../core/services/odoo_service.dart';
import '../../core/database/repositories/repository_providers.dart';

import 'package:theos_pos_core/theos_pos_core.dart';

final userProvider = NotifierProvider<UserNotifier, User?>(
  () => UserNotifier(),
);

enum PermissionSnapshotPhase { idle, loading, ready, failed }

/// Observable state of the permission snapshot independently from identity.
///
/// [PermissionSnapshotPhase.ready] with an empty list means the synchronized
/// user has no application permissions. [PermissionSnapshotPhase.failed]
/// means the snapshot could not be read and authorization remains fail-closed.
class PermissionSnapshotState {
  final PermissionSnapshotPhase phase;
  final List<String> permissions;
  final Object? error;

  const PermissionSnapshotState._(
    this.phase, {
    this.permissions = const [],
    this.error,
  });

  const PermissionSnapshotState.idle() : this._(PermissionSnapshotPhase.idle);

  const PermissionSnapshotState.loading()
    : this._(PermissionSnapshotPhase.loading);

  PermissionSnapshotState.ready(Iterable<String> permissions)
    : this._(
        PermissionSnapshotPhase.ready,
        permissions: List.unmodifiable(permissions),
      );

  PermissionSnapshotState.failed(Object error)
    : this._(PermissionSnapshotPhase.failed, error: error);
}

final permissionSnapshotProvider =
    NotifierProvider<PermissionSnapshotNotifier, PermissionSnapshotState>(
      PermissionSnapshotNotifier.new,
    );

class PermissionSnapshotNotifier extends Notifier<PermissionSnapshotState> {
  @override
  PermissionSnapshotState build() => const PermissionSnapshotState.idle();

  void markLoading() => state = const PermissionSnapshotState.loading();

  void publish(Iterable<String> permissions) =>
      state = PermissionSnapshotState.ready(permissions);

  void fail(Object error) => state = PermissionSnapshotState.failed(error);

  void reset() => state = const PermissionSnapshotState.idle();
}

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
  int _permissionSnapshotGeneration = 0;

  @override
  User? build() => null;

  OdooService get _odooService => ref.read(odooServiceProvider);

  /// Get UserRepository if available
  UserRepository? get _repository => ref.read(userRepositoryProvider);

  /// Applies the current user's own `lang`/`tz` (`res.users.lang`/`tz`,
  /// synced by `UserSyncRepository` — see `theos_pos_core`'s `User` model)
  /// to the active Odoo client, so every JSON-2 call after this point uses
  /// the operator's own language/timezone instead of the SDK's `en_US`
  /// default. This is the single point where theos_pos does this — called
  /// from every path that publishes an authenticated user ([setUser],
  /// [restoreCachedUser], [fetchUser]), never from a screen.
  ///
  /// A `null`/empty [User.lang]/[User.tz] (Odoo returned `false`, or a
  /// profile synced before either field existed) is never overridden with a
  /// hardcoded value — see `OdooClient.updateLocale`.
  void _applyUserLocale(User user) {
    _odooService.client?.updateLocale(language: user.lang, timezone: user.tz);
  }

  Future<List<String>> _loadPermissionSnapshot(
    UserRepository repository,
    int generation,
  ) async {
    final snapshot = ref.read(permissionSnapshotProvider.notifier);
    if (generation == _permissionSnapshotGeneration) {
      snapshot.markLoading();
    }
    try {
      final permissions = await repository.getCurrentUserGroups();
      if (generation == _permissionSnapshotGeneration) {
        snapshot.publish(permissions);
      }
      return permissions;
    } catch (error) {
      if (generation == _permissionSnapshotGeneration) {
        snapshot.fail(error);
      }
      rethrow;
    }
  }

  /// Restores the current user exclusively from the active local database.
  ///
  /// This is the fast path used while resuming a committed session. It avoids
  /// waiting for Odoo before the router and navigation menu can be published.
  Future<User?> restoreCachedUser({bool isOffline = true}) async {
    final generation = ++_permissionSnapshotGeneration;
    final repository = _repository;
    if (repository == null) return null;

    try {
      final user = await repository.getCachedCurrentUser();
      if (user == null) return null;
      final permissions = await _loadPermissionSnapshot(repository, generation);
      if (generation != _permissionSnapshotGeneration) return state;

      state = user.copyWith(permissions: permissions);
      _applyUserLocale(user);
      ref.read(isOfflineModeProvider.notifier).setOffline(isOffline);
      return state;
    } catch (error) {
      logger.d('[UserProvider] Cached user restore failed: $error');
      return null;
    }
  }

  Future<void> fetchUser() async {
    final generation = ++_permissionSnapshotGeneration;
    final repository = _repository;

    // Try offline-first repository first
    if (repository != null) {
      try {
        final user = await repository.getCurrentUser();
        if (user != null) {
          // Fetch permissions from local repository
          logger.d(
            '[UserProvider] Fetching permissions for user ${user.id}...',
          );
          final permissions = await _loadPermissionSnapshot(
            repository,
            generation,
          );
          logger.d(
            '[UserProvider] Got ${permissions.length} permissions: ${permissions.take(5).join(', ')}${permissions.length > 5 ? '...' : ''}',
          );
          if (generation != _permissionSnapshotGeneration) return;
          state = user.copyWith(permissions: permissions);
          _applyUserLocale(user);
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
          if (repository != null) {
            try {
              permissions = await _loadPermissionSnapshot(
                repository,
                generation,
              );
            } catch (e) {
              logger.d('[UserProvider] Failed to load local permissions: $e');
            }
          }
          logger.d(
            '[UserProvider] Using user from Odoo with ${permissions.length} local permissions',
          );
          if (generation != _permissionSnapshotGeneration) return;
          state = user.copyWith(permissions: permissions);
          _applyUserLocale(user);
        } else {
          if (generation != _permissionSnapshotGeneration) return;
          state = null;
        }
      } catch (e) {
        logger.d('[UserProvider] userManager fallback error: $e');
        if (generation != _permissionSnapshotGeneration) return;
        state = null;
      }
    } else {
      if (generation != _permissionSnapshotGeneration) return;
      state = null;
    }
  }

  void clearUser() {
    _permissionSnapshotGeneration++;
    state = null;
    ref.read(permissionSnapshotProvider.notifier).reset();
    // Also reset offline mode when clearing user
    ref.read(isOfflineModeProvider.notifier).setOffline(false);
  }

  /// Set user directly (used for offline login)
  ///
  /// [user] - The User model from local database
  /// [isOffline] - Whether this is an offline login session
  Future<void> setUser(User user, {bool isOffline = false}) async {
    final generation = ++_permissionSnapshotGeneration;
    final repository = _repository;

    // Load permissions from local database
    List<String> permissions = [];
    if (repository != null) {
      try {
        permissions = await _loadPermissionSnapshot(repository, generation);
        logger.d(
          '[UserProvider] Loaded ${permissions.length} permissions from local DB',
        );
      } catch (e) {
        logger.d('[UserProvider] Failed to load local permissions: $e');
      }
    }

    if (generation != _permissionSnapshotGeneration) return;

    // Set the user state with permissions
    state = user.copyWith(permissions: permissions);
    _applyUserLocale(user);

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
