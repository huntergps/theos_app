import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import 'pin_capability_limiter.dart';

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

abstract interface class ApiKeyAuthServicePort {
  Future<AuthServiceResult> loginWithApiKey({
    required String serverUrl,
    required String database,
    required String login,
    required String apiKey,
  });
}

/// Optional extension for services that can enforce the UI's explicit
/// credential-retention choice. Legacy test/embedded services keep the
/// original AuthServicePort contract.
abstract interface class CredentialPolicyAuthServicePort {
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
    bool persistCredential,
  });

  Future<AuthServiceResult> loginWithApiKey({
    required String serverUrl,
    required String database,
    required String login,
    required String apiKey,
    bool persistCredential,
  });
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

class NativeAuthServicePort
    implements
        AuthServicePort,
        ApiKeyAuthServicePort,
        CredentialPolicyAuthServicePort {
  NativeAuthServicePort(this.service);
  final NativeAuthService service;
  @override
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
    bool persistCredential = true,
  }) => service.login(
    serverUrl: serverUrl,
    database: database,
    login: login,
    password: password,
    persistCredential: persistCredential,
  );
  @override
  Future<AuthServiceResult> loginWithApiKey({
    required String serverUrl,
    required String database,
    required String login,
    required String apiKey,
    bool persistCredential = true,
  }) => service.loginWithApiKey(
    serverUrl: serverUrl,
    database: database,
    login: login,
    apiKey: apiKey,
    persistCredential: persistCredential,
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
  AuthViewState get currentState => state;

  @override
  AuthViewState build() => ref.watch(authInitialStateProvider);

  Future<void> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
    bool persistCredential = true,
  }) async {
    state = const AuthViewState(status: AuthControllerStatus.loading);
    try {
      final service = _service;
      late final AuthServiceResult result;
      if (service case final CredentialPolicyAuthServicePort policy) {
        result = await policy.login(
          serverUrl: serverUrl,
          database: database,
          login: login,
          password: password,
          persistCredential: persistCredential,
        );
      } else {
        result = await service.login(
          serverUrl: serverUrl,
          database: database,
          login: login,
          password: password,
        );
      }
      if (!ref.mounted) return;
      state = _fromResult(result);
    } catch (_) {
      if (!ref.mounted) return;
      state = const AuthViewState(
        status: AuthControllerStatus.error,
        message:
            'No se pudo iniciar sesión. Revisa los datos e inténtalo de nuevo.',
      );
    }
  }

  Future<void> loginWithApiKey({
    required String serverUrl,
    required String database,
    required String login,
    required String apiKey,
    bool persistCredential = true,
  }) async {
    final service = _service;
    if (service is! ApiKeyAuthServicePort) {
      state = const AuthViewState(
        status: AuthControllerStatus.error,
        message: 'El modo API key no está configurado en esta plataforma.',
      );
      return;
    }
    final apiService = service as ApiKeyAuthServicePort;
    state = const AuthViewState(status: AuthControllerStatus.loading);
    try {
      late final AuthServiceResult result;
      if (service case final CredentialPolicyAuthServicePort policy) {
        result = await policy.loginWithApiKey(
          serverUrl: serverUrl,
          database: database,
          login: login,
          apiKey: apiKey,
          persistCredential: persistCredential,
        );
      } else {
        result = await apiService.loginWithApiKey(
          serverUrl: serverUrl,
          database: database,
          login: login,
          apiKey: apiKey,
        );
      }
      if (!ref.mounted) return;
      state = _fromResult(result);
    } catch (_) {
      if (!ref.mounted) return;
      state = const AuthViewState(
        status: AuthControllerStatus.error,
        message: 'No se pudo validar la API key.',
      );
    }
  }

  Future<void> restore({bool offline = false}) async {
    state = const AuthViewState(status: AuthControllerStatus.loading);
    try {
      final result = await _service.restore(offline: offline);
      if (!ref.mounted) return;
      state = _fromResult(result);
    } catch (_) {
      if (!ref.mounted) return;
      state = const AuthViewState(
        status: AuthControllerStatus.error,
        message: 'No se pudo restaurar la sesión.',
      );
    }
  }

  /// Restores the session exactly like [restore] does, then clamps whatever
  /// capabilities come back to the seller-only ceiling PIN mode may ever
  /// grant — see pin_capability_limiter.dart. This is the ONLY path the PIN
  /// screen (ACC-02) may use to reach an authenticated state: it never calls
  /// [login] or [restore] directly, so a multirole cashier+seller account
  /// can never surface Caja/Aprobaciones/Administración permissions just by
  /// coming in through PIN instead of Workspace credentials.
  ///
  /// A restored session without the seller permission is reported as
  /// [AuthControllerStatus.error] rather than as a successful restore with an
  /// empty permission set: PIN is the declared door for the seller role, and
  /// a user without it has no door to walk through, not merely nothing to
  /// see once inside.
  Future<void> restoreForSellerPin({bool offline = false}) async {
    state = const AuthViewState(status: AuthControllerStatus.loading);
    try {
      final result = await _service.restore(offline: offline);
      if (!ref.mounted) return;
      final restored = _fromResult(result);
      if (restored.status != AuthControllerStatus.authenticated &&
          restored.status != AuthControllerStatus.restored) {
        state = restored;
        return;
      }
      final capabilities = restored.capabilities;
      if (capabilities == null || !snapshotAllowsSellerPin(capabilities)) {
        state = const AuthViewState(
          status: AuthControllerStatus.error,
          message: 'Este usuario no tiene acceso de vendedor por PIN.',
        );
        return;
      }
      state = AuthViewState(
        status: restored.status,
        profile: restored.profile,
        capabilities: restrictSnapshotToSellerPin(capabilities),
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = const AuthViewState(
        status: AuthControllerStatus.error,
        message: 'No se pudo restaurar la sesión con PIN.',
      );
    }
  }

  Future<void> close() async {
    await _service.close();
    if (!ref.mounted) return;
    // Drop profile/capabilities immediately so providers cannot retain the
    // previous user's company scope after teardown.
    state = const AuthViewState();
  }

  Future<AuthProfile?> loadProfile() async {
    return _service.loadProfile();
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
