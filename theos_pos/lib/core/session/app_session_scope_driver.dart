import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';
import 'session_scope.dart';
import 'session_scope_activation_coordinator.dart';

/// Composition-root driver for the session lifecycle.
///
/// An online activation creates a user-scoped database and records its
/// identity so an offline start can reopen the same installation.
final class AppSessionScopeDriver implements SessionScopeActivationDriver {
  static const _uidPrefix = 'session_scope_uid:';
  static const _committedPrefix = 'session_scope_committed:';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<int> resolveOnlineUserId() async =>
      _onlineUserId ??
      (throw StateError('Online session did not provide a positive UID'));

  int? _onlineUserId;

  void setOnlineUserId(int uid) {
    if (uid <= 0) throw ArgumentError.value(uid, 'uid');
    _onlineUserId = uid;
  }

  Future<bool> isCommitted(SessionScope scope) async =>
      (await _prefs).getBool('$_committedPrefix${scope.storageIdentifier}') ==
      true;

  @override
  Future<int?> loadOfflineUserId() async =>
      _onlineUserId ?? (await _prefs).getInt('$_uidPrefix$_scopeKey');

  String _scopeKey = '';
  SessionScope? _workScope;
  bool _syncReplayEnabled = false;

  /// Whether background sync/replay is currently allowed for the active scope.
  bool get syncReplayEnabled => _syncReplayEnabled;

  @override
  Future<SessionInstallationMarker> commitOnlineInstallation(
    SessionScope scope,
  ) async {
    _scopeKey = scope.storageIdentifier;
    final prefs = await _prefs;
    await prefs.setInt('$_uidPrefix${scope.storageIdentifier}', scope.userId);
    await prefs.setBool('$_committedPrefix${scope.storageIdentifier}', true);
    return SessionInstallationMarker(scope);
  }

  @override
  Future<SessionInstallationMarker?> loadOfflineInstallation(
    SessionScope scope,
  ) async {
    _scopeKey = scope.storageIdentifier;
    final prefs = await _prefs;
    if (prefs.getBool('$_committedPrefix${scope.storageIdentifier}') != true) {
      return null;
    }
    return SessionInstallationMarker(scope);
  }

  @override
  Future<void> openScopedDatabase(SessionScope scope) async {
    // AppInitializer may have opened a provisional connection before the UID
    // was resolved. Never reuse that server-only connection: the active Drift
    // database must be owned by the authenticated SessionScope.
    if (DatabaseHelper.isInitialized &&
        DatabaseHelper.currentDatabaseName != scope.driftDatabaseName) {
      await DatabaseHelper.closeAndReset();
    }
    if (!DatabaseHelper.isInitialized) {
      await DatabaseHelper.initializeForServer(scope.driftDatabaseName);
    }
  }

  @override
  Future<void> closeScopedDatabase(SessionScope scope) async {
    if (DatabaseHelper.currentDatabaseName == scope.driftDatabaseName) {
      await DatabaseHelper.closeAndReset();
    }
  }

  @override
  Future<void> enableSyncAndReplay(SessionScope scope) async {
    // This is the lifecycle gate consumed by scoped sync providers. It is set
    // only after Drift opens successfully and is cleared before it closes.
    _workScope = scope;
    _syncReplayEnabled = true;
  }

  @override
  Future<void> disableSyncAndReplay(SessionScope scope) async {
    // Disable before closing Drift; repeated teardown is idempotent.
    if (_workScope == scope) {
      _syncReplayEnabled = false;
      _workScope = null;
    }
  }
}
