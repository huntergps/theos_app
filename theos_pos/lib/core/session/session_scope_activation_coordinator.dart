import 'session_scope.dart';

/// Identity marker for a user-owned local installation.
final class SessionInstallationMarker {
  const SessionInstallationMarker(this.scope);
  final SessionScope scope;
}

enum SessionScopeActivationPhase {
  inactive,
  resolvingIdentity,
  persistingIdentity,
  openingDatabase,
  enablingWork,
  active,
  blocked,
  rollingBack,
}

enum SessionScopeErrorReason {
  missingOfflineIdentity,
  installationNotCommitted,
  scopeMismatch,
}

final class SessionScopeError implements Exception {
  const SessionScopeError(this.reason);

  final SessionScopeErrorReason reason;

  @override
  String toString() => 'SessionScopeError(${reason.name})';
}

final class SessionScopeActivationRollbackException implements Exception {
  const SessionScopeActivationRollbackException({
    required this.cause,
    required this.rollbackCauses,
  });

  final Object cause;
  final List<Object> rollbackCauses;

  @override
  String toString() =>
      'SessionScopeActivationRollbackException($cause, $rollbackCauses)';
}

final class SessionScopeActivationResult {
  const SessionScopeActivationResult({
    required this.scope,
    required this.manifest,
  });

  final SessionScope scope;
  final SessionInstallationMarker manifest;
}

/// Platform composition boundary for ordered scoped-database activation.
abstract interface class SessionScopeActivationDriver {
  Future<int> resolveOnlineUserId();

  Future<int?> loadOfflineUserId();

  Future<SessionInstallationMarker> commitOnlineInstallation(
    SessionScope scope,
  );

  Future<SessionInstallationMarker?> loadOfflineInstallation(
    SessionScope scope,
  );

  Future<void> openScopedDatabase(SessionScope scope);

  Future<void> closeScopedDatabase(SessionScope scope);

  Future<void> enableSyncAndReplay(SessionScope scope);

  Future<void> disableSyncAndReplay(SessionScope scope);
}

/// Fail-closed ordering gate between authentication, Drift and sync.
final class SessionScopeActivationCoordinator {
  SessionScopeActivationCoordinator({required this._driver});

  final SessionScopeActivationDriver _driver;
  SessionScopeActivationPhase _phase = SessionScopeActivationPhase.inactive;
  SessionScope? _activeScope;
  bool _busy = false;

  SessionScopeActivationPhase get phase => _phase;
  SessionScope? get activeScope => _activeScope;

  Future<SessionScopeActivationResult> activateOnline({
    required String serverUrl,
    required String database,
  }) {
    return _exclusive(() async {
      await _deactivateUnlocked();
      try {
        _phase = SessionScopeActivationPhase.resolvingIdentity;
        final userId = await _driver.resolveOnlineUserId();
        final scope = _scope(serverUrl, database, userId);
        _phase = SessionScopeActivationPhase.persistingIdentity;
        final manifest = await _driver.commitOnlineInstallation(scope);
        return await _activateCommitted(scope, manifest);
      } catch (_) {
        _resetPreActivationFailure();
        rethrow;
      }
    });
  }

  Future<SessionScopeActivationResult> activateOffline({
    required String serverUrl,
    required String database,
  }) {
    return _exclusive(() async {
      await _deactivateUnlocked();
      try {
        _phase = SessionScopeActivationPhase.resolvingIdentity;
        final userId = await _driver.loadOfflineUserId();
        if (userId == null || userId <= 0) {
          _phase = SessionScopeActivationPhase.blocked;
          throw const SessionScopeError(
            SessionScopeErrorReason.missingOfflineIdentity,
          );
        }
        final scope = _scope(serverUrl, database, userId);
        _phase = SessionScopeActivationPhase.persistingIdentity;
        final manifest = await _driver.loadOfflineInstallation(scope);
        if (manifest == null) {
          _phase = SessionScopeActivationPhase.blocked;
          throw const SessionScopeError(
            SessionScopeErrorReason.installationNotCommitted,
          );
        }
        return await _activateCommitted(scope, manifest);
      } catch (_) {
        _resetPreActivationFailure();
        rethrow;
      }
    });
  }

  void _resetPreActivationFailure() {
    // A failed identity lookup must not leave the coordinator claiming that
    // work is still being committed.
    if (_phase == SessionScopeActivationPhase.resolvingIdentity ||
        _phase == SessionScopeActivationPhase.persistingIdentity) {
      _phase = SessionScopeActivationPhase.inactive;
    }
  }

  Future<void> deactivate() => _exclusive(_deactivateUnlocked);

  Future<SessionScopeActivationResult> _activateCommitted(
    SessionScope scope,
    SessionInstallationMarker manifest,
  ) async {
    if (manifest.scope != scope) {
      _phase = SessionScopeActivationPhase.blocked;
      throw const SessionScopeError(SessionScopeErrorReason.scopeMismatch);
    }
    var openAttempted = false;
    try {
      _phase = SessionScopeActivationPhase.openingDatabase;
      openAttempted = true;
      await _driver.openScopedDatabase(scope);
      _phase = SessionScopeActivationPhase.enablingWork;
      await _driver.enableSyncAndReplay(scope);
      _activeScope = scope;
      _phase = SessionScopeActivationPhase.active;
      return SessionScopeActivationResult(scope: scope, manifest: manifest);
    } catch (error) {
      if (!openAttempted) {
        _phase = SessionScopeActivationPhase.inactive;
        rethrow;
      }
      _phase = SessionScopeActivationPhase.rollingBack;
      final rollbackCauses = <Object>[];
      try {
        await _driver.disableSyncAndReplay(scope);
      } catch (rollbackError) {
        rollbackCauses.add(rollbackError);
      }
      try {
        await _driver.closeScopedDatabase(scope);
      } catch (rollbackError) {
        rollbackCauses.add(rollbackError);
      }
      _activeScope = null;
      _phase = SessionScopeActivationPhase.inactive;
      if (rollbackCauses.isNotEmpty) {
        throw SessionScopeActivationRollbackException(
          cause: error,
          rollbackCauses: List<Object>.unmodifiable(rollbackCauses),
        );
      }
      rethrow;
    }
  }

  Future<void> _deactivateUnlocked() async {
    final scope = _activeScope;
    if (scope == null) {
      if (_phase != SessionScopeActivationPhase.blocked) {
        _phase = SessionScopeActivationPhase.inactive;
      }
      return;
    }
    _phase = SessionScopeActivationPhase.rollingBack;
    Object? disableError;
    StackTrace? disableStackTrace;
    try {
      await _driver.disableSyncAndReplay(scope);
    } catch (error, stackTrace) {
      disableError = error;
      disableStackTrace = stackTrace;
    }
    try {
      await _driver.closeScopedDatabase(scope);
    } finally {
      _activeScope = null;
      _phase = SessionScopeActivationPhase.inactive;
    }
    if (disableError != null) {
      Error.throwWithStackTrace(disableError, disableStackTrace!);
    }
  }

  SessionScope _scope(String serverUrl, String database, int userId) {
    if (userId <= 0) {
      throw StateError('Online UID must be a positive integer');
    }
    return SessionScope(
      serverUrl: serverUrl,
      database: database,
      userId: userId,
    );
  }

  Future<T> _exclusive<T>(Future<T> Function() operation) async {
    if (_busy) {
      throw StateError('Session scope activation is already in progress');
    }
    _busy = true;
    try {
      return await operation();
    } finally {
      _busy = false;
    }
  }
}
