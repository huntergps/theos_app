import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';

/// A private, self-contained fake — deliberately not the one from
/// auth_flow_test.dart, so this file never needs to touch that already
/// heavily-tested file just to add PIN coverage.
final class _FakeAuthService implements AuthServicePort {
  _FakeAuthService(this.result);
  AuthServiceResult result;

  @override
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
  }) async => result;

  @override
  Future<AuthServiceResult> restore({bool offline = false}) async => result;

  @override
  Future<AuthProfile?> loadProfile() async => result.profile;

  @override
  Future<AuthProfile?> loadProfileFor(
    String serverUrl,
    String database,
  ) async => result.profile;

  @override
  Future<void> close() async {}
}

/// Igual que [_FakeAuthService] pero además implementa
/// [SellerPinAuthServicePort], para probar `AuthNotifier.loginWithSellerPin`
/// — el camino nuevo que `PinLoginScreen` usa desde el selector de usuarios
/// (14-sep-2026), en vez de `restoreForSellerPin`/`restore()`.
/// `loginWithPinCredential` entra con exactamente el [result] configurado,
/// sin mirar el `profile` que se le pasó — lo que importa aquí es el tope de
/// vendedor que aplica [AuthNotifier], no cuál perfil ganó.
final class _FakePinAuthService
    implements AuthServicePort, SellerPinAuthServicePort {
  _FakePinAuthService(this.result);
  AuthServiceResult result;

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
  Future<AuthProfile?> loadProfile() async => result.profile;

  @override
  Future<AuthProfile?> loadProfileFor(
    String serverUrl,
    String database,
  ) async => result.profile;

  @override
  Future<void> close() async {}

  @override
  Future<AuthServiceResult> loginWithPinCredential(AuthProfile profile) async =>
      result;

  @override
  Future<void> retainCredentialForPin(
    AuthProfile profile,
    bool retained,
  ) async {}

  @override
  Future<List<AuthProfile>> pinRetainedProfilesFor(
    String serverUrl,
    String database,
  ) async => const [];
}

final class _ThrowingAuthService implements AuthServicePort {
  @override
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AuthServiceResult> restore({bool offline = false}) =>
      throw StateError('network unreachable');

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

CapabilitySnapshot _snapshot(List<String> permissions) => CapabilitySnapshot(
  scopeKey: 'scope',
  companyId: 1,
  revision: 1,
  fetchedAt: DateTime.utc(2026, 9, 11),
  permissions: permissions,
);

const _profile = AuthProfile(
  serverUrl: 'https://erp.test',
  database: 'demo',
  login: 'multirole',
  userId: 7,
  installationId: 'i-1',
  credentialReference: 'api-key',
);

void main() {
  // The test the coordinator called out as the one that really matters: a
  // multirole cashier+seller account entering by PIN must never surface
  // cashier capabilities.
  test(
    'a cashier-and-seller account gets ONLY seller capabilities through PIN',
    () async {
      final fake = _FakeAuthService(
        AuthServiceResult(
          status: AuthServiceStatus.restored,
          profile: _profile,
          capabilities: _snapshot(const ['seller', 'cashier']),
        ),
      );
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      await container
          .read(authControllerProvider.notifier)
          .restoreForSellerPin();

      final state = container.read(authControllerProvider);
      expect(state.status, AuthControllerStatus.restored);
      expect(state.capabilities?.permissions, {'seller'});
      expect(state.capabilities?.permissions.contains('cashier'), isFalse);
    },
  );

  test(
    'the same account still gets cashier capabilities through a normal '
    'restore — PIN is what narrows it, not the account itself',
    () async {
      final fake = _FakeAuthService(
        AuthServiceResult(
          status: AuthServiceStatus.restored,
          profile: _profile,
          capabilities: _snapshot(const ['seller', 'cashier']),
        ),
      );
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).restore();

      final state = container.read(authControllerProvider);
      expect(state.capabilities?.permissions, {'seller', 'cashier'});
    },
  );

  test(
    'administrator/approver/warehouse/sync are all dropped through PIN too',
    () async {
      final fake = _FakeAuthService(
        AuthServiceResult(
          status: AuthServiceStatus.authenticated,
          profile: _profile,
          capabilities: _snapshot(const [
            'seller',
            'cashier',
            'approver',
            'warehouse',
            'administrator',
            'sync',
          ]),
        ),
      );
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      await container
          .read(authControllerProvider.notifier)
          .restoreForSellerPin();

      expect(
        container.read(authControllerProvider).capabilities?.permissions,
        {'seller'},
      );
    },
  );

  test(
    'an account without the seller permission is refused PIN access '
    'outright, not "restored" with zero capabilities',
    () async {
      final fake = _FakeAuthService(
        AuthServiceResult(
          status: AuthServiceStatus.restored,
          profile: _profile,
          capabilities: _snapshot(const ['cashier']),
        ),
      );
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      await container
          .read(authControllerProvider.notifier)
          .restoreForSellerPin();

      final state = container.read(authControllerProvider);
      expect(state.status, AuthControllerStatus.error);
      expect(state.capabilities, isNull);
    },
  );

  test('a restore with no capabilities at all is refused, not granted', () async {
    final fake = _FakeAuthService(
      const AuthServiceResult(
        status: AuthServiceStatus.restored,
        profile: _profile,
      ),
    );
    final container = ProviderContainer(
      overrides: [authServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    await container.read(authControllerProvider.notifier).restoreForSellerPin();

    expect(
      container.read(authControllerProvider).status,
      AuthControllerStatus.error,
    );
  });

  test('a session that is not authenticated/restored passes through unchanged', () async {
    final fake = _FakeAuthService(
      const AuthServiceResult(status: AuthServiceStatus.required),
    );
    final container = ProviderContainer(
      overrides: [authServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    await container.read(authControllerProvider.notifier).restoreForSellerPin();

    expect(
      container.read(authControllerProvider).status,
      AuthControllerStatus.required,
    );
  });

  test('a transport failure surfaces as an error, not a crash', () async {
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(_ThrowingAuthService()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authControllerProvider.notifier).restoreForSellerPin();

    expect(
      container.read(authControllerProvider).status,
      AuthControllerStatus.error,
    );
  });

  // --- `AuthNotifier.loginWithSellerPin` — el camino del selector de
  // usuarios (decisión del dueño, 14-sep-2026): mismas garantías que
  // `restoreForSellerPin` de arriba, pero entrando por
  // `SellerPinAuthServicePort.loginWithPinCredential` en vez de
  // `restore()`. -----------------------------------------------------------
  group('AuthNotifier.loginWithSellerPin', () {
    test(
      'seller pin login clamps permissions: caja + vendedor entra sólo '
      'como vendedor',
      () async {
        final fake = _FakePinAuthService(
          AuthServiceResult(
            status: AuthServiceStatus.authenticated,
            profile: _profile,
            capabilities: _snapshot(const ['seller', 'cashier']),
          ),
        );
        final container = ProviderContainer(
          overrides: [authServiceProvider.overrideWithValue(fake)],
        );
        addTearDown(container.dispose);

        await container
            .read(authControllerProvider.notifier)
            .loginWithSellerPin(_profile);

        final state = container.read(authControllerProvider);
        expect(state.status, AuthControllerStatus.authenticated);
        expect(state.capabilities?.permissions, {'seller'});
        expect(state.capabilities?.permissions.contains('cashier'), isFalse);
      },
    );

    test(
      'an account without the seller permission is refused, not "restored" '
      'with zero capabilities',
      () async {
        final fake = _FakePinAuthService(
          AuthServiceResult(
            status: AuthServiceStatus.authenticated,
            profile: _profile,
            capabilities: _snapshot(const ['cashier']),
          ),
        );
        final container = ProviderContainer(
          overrides: [authServiceProvider.overrideWithValue(fake)],
        );
        addTearDown(container.dispose);

        await container
            .read(authControllerProvider.notifier)
            .loginWithSellerPin(_profile);

        final state = container.read(authControllerProvider);
        expect(state.status, AuthControllerStatus.error);
        expect(state.capabilities, isNull);
      },
    );

    test(
      'a rejected pin credential (required) surfaces as an error, not a '
      'silent no-op',
      () async {
        final fake = _FakePinAuthService(
          const AuthServiceResult(status: AuthServiceStatus.required),
        );
        final container = ProviderContainer(
          overrides: [authServiceProvider.overrideWithValue(fake)],
        );
        addTearDown(container.dispose);

        await container
            .read(authControllerProvider.notifier)
            .loginWithSellerPin(_profile);

        expect(
          container.read(authControllerProvider).status,
          AuthControllerStatus.error,
        );
      },
    );

    test(
      'a platform without SellerPinAuthServicePort refuses PIN outright, '
      'not with a network attempt through restore()',
      () async {
        final fake = _FakeAuthService(
          const AuthServiceResult(status: AuthServiceStatus.required),
        );
        final container = ProviderContainer(
          overrides: [authServiceProvider.overrideWithValue(fake)],
        );
        addTearDown(container.dispose);

        await container
            .read(authControllerProvider.notifier)
            .loginWithSellerPin(_profile);

        final state = container.read(authControllerProvider);
        expect(state.status, AuthControllerStatus.error);
        expect(state.message, contains('no está disponible'));
      },
    );
  });
}
