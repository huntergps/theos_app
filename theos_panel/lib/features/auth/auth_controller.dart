import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

abstract interface class AuthServicePort {
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
  });
  Future<AuthServiceResult> restore({bool offline});
  Future<AuthProfile?> loadProfile();
  Future<AuthProfile?> loadProfileFor(String serverUrl, String database);
  Future<void> close();
}

/// Performs exactly one online restore and, only when that attempt fails, one
/// explicit offline restore. Callers own when this is invoked (normally cold
/// start); it never schedules a retry loop.
Future<AuthServiceResult> restoreOnce(AuthServicePort service) async {
  try {
    return await service.restore();
  } catch (_) {
    try {
      return await service.restore(offline: true);
    } catch (_) {
      return const AuthServiceResult(status: AuthServiceStatus.required);
    }
  }
}

class NativeAuthServicePort implements AuthServicePort {
  NativeAuthServicePort(this.service);
  final NativeAuthService service;
  @override
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
  }) => service.login(
    serverUrl: serverUrl,
    database: database,
    login: login,
    password: password,
  );
  @override
  Future<AuthServiceResult> restore({bool offline = false}) =>
      service.restore(offline: offline);
  @override
  Future<AuthProfile?> loadProfile() => service.loadProfile();
  @override
  Future<AuthProfile?> loadProfileFor(String serverUrl, String database) =>
      service.loadProfileFor(serverUrl, database);
  @override
  Future<void> close() => service.close();
}

enum AuthControllerStatus {
  required,
  loading,
  authenticated,
  restored,
  unsupportedWeb,
  error,
}

final class AuthViewState {
  const AuthViewState({
    this.status = AuthControllerStatus.required,
    this.profile,
    this.message,
    this.capabilities,
  });
  final AuthControllerStatus status;
  final AuthProfile? profile;
  final String? message;
  final CapabilitySnapshot? capabilities;
  bool get isBusy => status == AuthControllerStatus.loading;
}

final authServiceProvider = Provider<AuthServicePort>((ref) {
  return const _UnavailableAuthService();
});

final authInitialStateProvider = Provider<AuthViewState>(
  (ref) => const AuthViewState(),
);

final class _UnavailableAuthService implements AuthServicePort {
  const _UnavailableAuthService();
  @override
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
  }) async => const AuthServiceResult(status: AuthServiceStatus.required);
  @override
  Future<AuthServiceResult> restore({bool offline = false}) async =>
      const AuthServiceResult(status: AuthServiceStatus.required);
  @override
  Future<AuthProfile?> loadProfile() async => null;
  @override
  Future<AuthProfile?> loadProfileFor(
    String serverUrl,
    String database,
  ) async => null;
  @override
  Future<void> close() async {}
}

/// Composition owns capability provisioning; routing and menus consume this
/// one provider instead of inventing per-screen permission snapshots.
final capabilitySnapshotProvider = Provider<CapabilitySnapshot?>(
  (ref) => ref.watch(authControllerProvider).capabilities,
);

final authControllerProvider = NotifierProvider<AuthNotifier, AuthViewState>(
  AuthNotifier.new,
);

class AuthNotifier extends Notifier<AuthViewState> {
  AuthServicePort get _service => ref.read(authServiceProvider);

  @override
  AuthViewState build() => ref.watch(authInitialStateProvider);

  Future<void> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
  }) async {
    state = const AuthViewState(status: AuthControllerStatus.loading);
    try {
      state = _fromResult(
        await _service.login(
          serverUrl: serverUrl,
          database: database,
          login: login,
          password: password,
        ),
      );
    } catch (_) {
      state = const AuthViewState(
        status: AuthControllerStatus.error,
        message:
            'No se pudo iniciar sesión. Revisa los datos e inténtalo de nuevo.',
      );
    }
  }

  Future<void> restore({bool offline = false}) async {
    state = const AuthViewState(status: AuthControllerStatus.loading);
    try {
      state = _fromResult(await _service.restore(offline: offline));
    } catch (_) {
      state = const AuthViewState(
        status: AuthControllerStatus.error,
        message: 'No se pudo restaurar la sesión.',
      );
    }
  }

  Future<void> close() async {
    await _service.close();
    // Drop profile/capabilities immediately so providers cannot retain the
    // previous user's company scope after teardown.
    state = const AuthViewState();
  }

  Future<AuthProfile?> loadProfile() async {
    final profile = await _service.loadProfile();
    if (profile != null && state.status == AuthControllerStatus.required) {
      state = AuthViewState(profile: profile);
    }
    return profile;
  }

  Future<AuthProfile?> loadProfileFor(String serverUrl, String database) =>
      _service.loadProfileFor(serverUrl, database);

  AuthViewState _fromResult(AuthServiceResult result) =>
      switch (result.status) {
        AuthServiceStatus.authenticated => AuthViewState(
          status: AuthControllerStatus.authenticated,
          profile: result.profile,
          capabilities: result.capabilities,
        ),
        AuthServiceStatus.restored => AuthViewState(
          status: AuthControllerStatus.restored,
          profile: result.profile,
          capabilities: result.capabilities,
        ),
        AuthServiceStatus.unsupportedWeb => const AuthViewState(
          status: AuthControllerStatus.unsupportedWeb,
          message: 'El acceso web con contraseña está pendiente de W01.',
        ),
        AuthServiceStatus.required => const AuthViewState(
          status: AuthControllerStatus.required,
        ),
      };
}

AuthViewState authViewStateFromResult(AuthServiceResult result) =>
    switch (result.status) {
      AuthServiceStatus.authenticated => AuthViewState(
        status: AuthControllerStatus.authenticated,
        profile: result.profile,
        capabilities: result.capabilities,
      ),
      AuthServiceStatus.restored => AuthViewState(
        status: AuthControllerStatus.restored,
        profile: result.profile,
        capabilities: result.capabilities,
      ),
      AuthServiceStatus.unsupportedWeb => const AuthViewState(
        status: AuthControllerStatus.unsupportedWeb,
        message: 'El acceso web con contraseña está pendiente de W01.',
      ),
      AuthServiceStatus.required => const AuthViewState(
        status: AuthControllerStatus.required,
      ),
    };
