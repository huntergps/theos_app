import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odoo_sdk/odoo_sdk.dart'
    show OdooAccessDeniedException, OdooAuthenticationException, OdooException,
        OdooOfflineException;
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/app/router.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:theos_panel/features/auth/workspace_unlock_store.dart';

import 'workspace_unlock_test_doubles.dart';

/// The shell's lock screen must be openable with **no network**: an app that
/// advertises working offline cannot have a privacy gate that only the server
/// can open. These exercise the whole path — `attemptWorkspaceUnlock` plus
/// `AuthNotifier` — not just the store.
void main() {
  const profile = AuthProfile(
    serverUrl: 'https://erp2.galapagos.tech',
    database: 'orbi',
    login: 'vendedor',
    userId: 7,
    installationId: 'inst-1',
    credentialReference: 'api-key',
  );
  const otherProfile = AuthProfile(
    serverUrl: 'https://erp2.galapagos.tech',
    database: 'orbi',
    login: 'cajera',
    userId: 9,
    installationId: 'inst-1',
    credentialReference: 'api-key',
  );
  const password = 'Gal4pagos-Orbi!';
  final scopeKey = workspaceUnlockScopeKeyFor(profile);

  late FakeCredentialBackend backend;
  late _RecordingAuthService service;

  setUp(() {
    backend = FakeCredentialBackend();
    service = _RecordingAuthService();
  });

  /// Builds the provider scope the shell's unlock closure runs in and hands
  /// back a live `WidgetRef`, which is what `attemptWorkspaceUnlock` takes.
  Future<WidgetRef> pumpRef(
    WidgetTester tester, {
    AuthViewState initial = const AuthViewState(
      status: AuthControllerStatus.authenticated,
      profile: profile,
    ),
    CredentialBackend? unlockBackend,
    bool supplyBackend = true,
  }) async {
    late WidgetRef captured;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authInitialStateProvider.overrideWithValue(initial),
          authServiceProvider.overrideWithValue(service),
          workspaceUnlockBackendProvider.overrideWithValue(
            supplyBackend ? (unlockBackend ?? backend) : null,
          ),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            captured = ref;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return captured;
  }

  testWidgets(
    'se desbloquea SIN CONEXIÓN: con el derivado guardado, la contraseña '
    'correcta abre el bloqueo sin tocar el servidor ni una sola vez',
    (tester) async {
      await WorkspaceUnlockStore(backend).remember(scopeKey, password);
      service.reachable = false;
      final ref = await pumpRef(tester);
      ref.read(workspaceLockProvider.notifier).lock();
      expect(ref.read(workspaceLockProvider), isTrue);

      expect(await attemptWorkspaceUnlock(ref, password), isTrue);

      expect(ref.read(workspaceLockProvider), isFalse);
      expect(
        service.loginCalls,
        0,
        reason: 'el desbloqueo local no debe contactar al servidor',
      );
      // Unlocking never re-authenticates, so the session it was covering is
      // exactly as it was.
      expect(ref.read(authControllerProvider).profile, profile);
      expect(
        ref.read(authControllerProvider).status,
        AuthControllerStatus.authenticated,
      );
    },
  );

  testWidgets(
    'sin conexión, una contraseña equivocada no desbloquea y no borra el '
    'perfil ya autenticado',
    (tester) async {
      await WorkspaceUnlockStore(backend).remember(scopeKey, password);
      service.reachable = false;
      final ref = await pumpRef(tester);
      ref.read(workspaceLockProvider.notifier).lock();

      expect(await attemptWorkspaceUnlock(ref, 'equivocada'), isFalse);

      expect(ref.read(workspaceLockProvider), isTrue);
      expect(ref.read(authControllerProvider).profile, profile);
      expect(
        ref.read(authControllerProvider).status,
        AuthControllerStatus.authenticated,
      );
    },
  );

  testWidgets(
    'sin derivado guardado y sin red no se puede desbloquear: el servidor '
    'sigue siendo el único camino, y se intenta',
    (tester) async {
      service.reachable = false;
      final ref = await pumpRef(tester);
      ref.read(workspaceLockProvider.notifier).lock();

      expect(await attemptWorkspaceUnlock(ref, password), isFalse);

      expect(ref.read(workspaceLockProvider), isTrue);
      expect(service.loginCalls, 1);
    },
  );

  testWidgets(
    'el primer desbloqueo con red enrola el derivado, y el siguiente ya '
    'funciona sin red',
    (tester) async {
      service.acceptedPassword = password;
      final ref = await pumpRef(tester);
      ref.read(workspaceLockProvider.notifier).lock();

      expect(await attemptWorkspaceUnlock(ref, password), isTrue);
      expect(service.loginCalls, 1);

      service.reachable = false;
      ref.read(workspaceLockProvider.notifier).lock();
      expect(await attemptWorkspaceUnlock(ref, password), isTrue);
      expect(
        service.loginCalls,
        1,
        reason: 'el segundo desbloqueo ya no necesita servidor',
      );
    },
  );

  testWidgets(
    'si la contraseña cambió en el servidor, la nueva entra con red y '
    'reemplaza el derivado viejo: la vieja deja de abrir el bloqueo',
    (tester) async {
      await WorkspaceUnlockStore(backend).remember(scopeKey, 'la-vieja');
      service.acceptedPassword = 'la-nueva';
      final ref = await pumpRef(tester);
      ref.read(workspaceLockProvider.notifier).lock();

      expect(await attemptWorkspaceUnlock(ref, 'la-nueva'), isTrue);
      expect(service.loginCalls, 1);

      final store = WorkspaceUnlockStore(backend);
      expect(
        await store.verify(scopeKey, 'la-nueva'),
        WorkspaceUnlockVerdict.unlocked,
      );
      expect(
        await store.verify(scopeKey, 'la-vieja'),
        WorkspaceUnlockVerdict.rejected,
      );
    },
  );

  testWidgets(
    'un rechazo INEQUÍVOCO del servidor borra el derivado: un desbloqueo sin '
    'conexión que siga abriendo una cuenta revocada es una credencial que '
    'nadie puede revocar',
    (tester) async {
      await WorkspaceUnlockStore(backend).remember(scopeKey, password);
      service.failWith = const OdooAccessDeniedException('revocado');
      final ref = await pumpRef(tester);
      ref.read(workspaceLockProvider.notifier).lock();

      // Wrong locally, so it falls through to the server, which revokes.
      expect(await attemptWorkspaceUnlock(ref, 'la-que-ya-no-vale'), isFalse);

      expect(
        await WorkspaceUnlockStore(backend).isRemembered(scopeKey),
        isFalse,
        reason: 'una cuenta sin acceso no puede conservar su desbloqueo local',
      );
      expect(ref.read(workspaceLockProvider), isTrue);
    },
  );

  testWidgets(
    'una ERRATA en línea NO borra el derivado, porque el servidor responde '
    'igual a una contraseña mal escrita y a una cambiada: distinguirlas sería '
    'regalar información a quien prueba contraseñas',
    (tester) async {
      await WorkspaceUnlockStore(backend).remember(scopeKey, password);
      service.failWith = const OdooAuthenticationException('no');
      final ref = await pumpRef(tester);

      expect(await attemptWorkspaceUnlock(ref, 'dedo-equivocado'), isFalse);
      service.failWith = null;

      expect(
        await WorkspaceUnlockStore(backend).isRemembered(scopeKey),
        isTrue,
        reason: 'una errata no puede costarle el desbloqueo sin red a quien sí '
            'conoce su contraseña',
      );
      // Y la contraseña buena sigue abriendo sin red.
      service.reachable = false;
      ref.read(workspaceLockProvider.notifier).lock();
      expect(await attemptWorkspaceUnlock(ref, password), isTrue);
    },
  );

  testWidgets(
    'un 429 por enfriamiento NO borra el derivado: el servidor dijo «ahora '
    'no», no «esta credencial es mala» — borrarlo convertiría un límite de '
    'ritmo en la pérdida de lo único que funciona sin red',
    (tester) async {
      await WorkspaceUnlockStore(backend).remember(scopeKey, password);
      service.failWith = const OdooException(
        message: 'too many attempts',
        statusCode: 429,
      );
      final ref = await pumpRef(tester);

      expect(await attemptWorkspaceUnlock(ref, 'mal'), isFalse);

      expect(
        await WorkspaceUnlockStore(backend).isRemembered(scopeKey),
        isTrue,
      );
    },
  );

  testWidgets(
    'una clave guardada que el servidor rechaza SÍ borra el derivado: nadie '
    'teclea una clave, así que un rechazo no puede ser una errata',
    (tester) async {
      await WorkspaceUnlockStore(backend).remember(scopeKey, password);
      service.failWith = StateError('stored API key was rejected');
      final ref = await pumpRef(tester);

      expect(await attemptWorkspaceUnlock(ref, 'lo-que-sea'), isFalse);

      expect(
        await WorkspaceUnlockStore(backend).isRemembered(scopeKey),
        isFalse,
      );
    },
  );

  testWidgets(
    'quedarse sin red tampoco borra el derivado: es justo cuando más se '
    'necesita',
    (tester) async {
      await WorkspaceUnlockStore(backend).remember(scopeKey, password);
      service.failWith = const OdooOfflineException();
      final ref = await pumpRef(tester);

      expect(await attemptWorkspaceUnlock(ref, 'mal'), isFalse);
      expect(
        await WorkspaceUnlockStore(backend).isRemembered(scopeKey),
        isTrue,
      );
    },
  );

  testWidgets(
    'tras agotar el límite de intentos no se desbloquea ni siquiera con el '
    'servidor dispuesto a aceptar la contraseña correcta',
    (tester) async {
      await WorkspaceUnlockStore(backend).remember(scopeKey, password);
      service.acceptedPassword = password;
      final ref = await pumpRef(tester);
      ref.read(workspaceLockProvider.notifier).lock();

      for (var i = 0; i < kWorkspaceUnlockMaxAttempts; i++) {
        expect(await attemptWorkspaceUnlock(ref, 'mal'), isFalse);
      }
      final callsBefore = service.loginCalls;

      expect(await attemptWorkspaceUnlock(ref, password), isFalse);
      expect(ref.read(workspaceLockProvider), isTrue);
      expect(
        service.loginCalls,
        callsBefore,
        reason: 'un límite que la red puede esquivar no es un límite',
      );
    },
  );

  testWidgets(
    'en una plataforma sin almacén seguro (la web) no se guarda nada y el '
    'bloqueo sigue exigiendo red',
    (tester) async {
      service.reachable = false;
      final ref = await pumpRef(tester, supplyBackend: false);
      ref.read(workspaceLockProvider.notifier).lock();

      await ref
          .read(authControllerProvider.notifier)
          .login(
            serverUrl: profile.serverUrl,
            database: profile.database,
            login: profile.login,
            password: password,
          );
      expect(backend.entries, isEmpty);
      expect(await attemptWorkspaceUnlock(ref, password), isFalse);
      expect(ref.read(workspaceLockProvider), isTrue);
    },
  );

  testWidgets(
    'EL DERIVADO DESAPARECE AL CERRAR SESIÓN: no queda ninguna credencial '
    'huérfana en el almacén seguro',
    (tester) async {
      await WorkspaceUnlockStore(backend).remember(scopeKey, password);
      await WorkspaceUnlockStore(backend).verify(scopeKey, 'mal');
      expect(backend.entries, isNotEmpty);
      final ref = await pumpRef(tester);

      await ref.read(authControllerProvider.notifier).close();

      expect(
        backend.entries,
        isEmpty,
        reason: 'ni el derivado ni su contador de intentos pueden sobrevivir',
      );
      expect(
        await WorkspaceUnlockStore(backend).verify(scopeKey, password),
        WorkspaceUnlockVerdict.notEnrolled,
      );
      expect(ref.read(authControllerProvider).profile, isNull);
    },
  );

  testWidgets(
    'al cambiar de usuario el derivado del anterior no sobrevive: el que '
    'entra después desbloquea con la suya, nunca con la del anterior',
    (tester) async {
      await WorkspaceUnlockStore(backend).remember(scopeKey, password);
      final ref = await pumpRef(tester);

      // "Cambiar de usuario" y "Cerrar sesión" pasan ambos por close(), que es
      // exactamente por lo que el borrado vive ahí.
      await ref.read(authControllerProvider.notifier).close();
      expect(backend.entries, isEmpty);

      service.profile = otherProfile;
      service.acceptedPassword = 'otra-contraseña';
      await ref
          .read(authControllerProvider.notifier)
          .login(
            serverUrl: otherProfile.serverUrl,
            database: otherProfile.database,
            login: otherProfile.login,
            password: 'otra-contraseña',
          );
      expect(ref.read(authControllerProvider).profile, otherProfile);

      service.reachable = false;
      ref.read(workspaceLockProvider.notifier).lock();
      expect(
        await attemptWorkspaceUnlock(ref, password),
        isFalse,
        reason: 'la contraseña del usuario anterior no abre el bloqueo',
      );
      expect(await attemptWorkspaceUnlock(ref, 'otra-contraseña'), isTrue);
    },
  );

  testWidgets(
    'un login exitoso enrola el derivado, así que el primer bloqueo ya se '
    'puede abrir sin red',
    (tester) async {
      service.acceptedPassword = password;
      final ref = await pumpRef(tester, initial: const AuthViewState());

      await ref
          .read(authControllerProvider.notifier)
          .login(
            serverUrl: profile.serverUrl,
            database: profile.database,
            login: profile.login,
            password: password,
          );

      expect(
        await WorkspaceUnlockStore(backend).isRemembered(scopeKey),
        isTrue,
      );
      service.reachable = false;
      ref.read(workspaceLockProvider.notifier).lock();
      expect(await attemptWorkspaceUnlock(ref, password), isTrue);
    },
  );

  testWidgets(
    'quien pide NO guardar su credencial tampoco deja un derivado: pierde el '
    'desbloqueo sin red, que es justo el trato que pidió',
    (tester) async {
      service.acceptedPassword = password;
      final ref = await pumpRef(tester, initial: const AuthViewState());

      await ref
          .read(authControllerProvider.notifier)
          .login(
            serverUrl: profile.serverUrl,
            database: profile.database,
            login: profile.login,
            password: password,
            persistCredential: false,
          );

      expect(
        ref.read(authControllerProvider).status,
        AuthControllerStatus.authenticated,
      );
      expect(backend.entries, isEmpty);
    },
  );

  testWidgets(
    'un login rechazado no enrola nada: una contraseña que el servidor no '
    'aceptó nunca puede volverse un desbloqueo sin red',
    (tester) async {
      service.acceptedPassword = password;
      final ref = await pumpRef(tester, initial: const AuthViewState());

      await ref
          .read(authControllerProvider.notifier)
          .login(
            serverUrl: profile.serverUrl,
            database: profile.database,
            login: profile.login,
            password: 'no-es-la-mía',
          );

      expect(backend.entries, isEmpty);
    },
  );

  testWidgets(
    'un almacén seguro que falla no rompe el login: sólo deja el desbloqueo '
    'dependiendo de la red',
    (tester) async {
      service.acceptedPassword = password;
      final ref = await pumpRef(
        tester,
        initial: const AuthViewState(),
        unlockBackend: ThrowingCredentialBackend(),
      );

      await ref
          .read(authControllerProvider.notifier)
          .login(
            serverUrl: profile.serverUrl,
            database: profile.database,
            login: profile.login,
            password: password,
          );

      expect(
        ref.read(authControllerProvider).status,
        AuthControllerStatus.authenticated,
      );
      await ref.read(authControllerProvider.notifier).close();
      expect(ref.read(authControllerProvider).profile, isNull);
    },
  );
}

/// Auth service that counts server contact and can be made unreachable, so a
/// test can prove an unlock happened with **no** network at all.
final class _RecordingAuthService implements AuthServicePort {
  int loginCalls = 0;
  bool reachable = true;
  String? acceptedPassword;
  AuthProfile profile = const AuthProfile(
    serverUrl: 'https://erp2.galapagos.tech',
    database: 'orbi',
    login: 'vendedor',
    userId: 7,
    installationId: 'inst-1',
    credentialReference: 'api-key',
  );

  /// Makes the server fail with a CLASSIFIED cause, so a test can prove the
  /// unlock path treats a revocation differently from a typo.
  Object? failWith;

  @override
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
  }) async {
    loginCalls++;
    final classified = failWith;
    if (classified != null) throw classified;
    if (!reachable) throw StateError('sin red');
    if (acceptedPassword == null || password != acceptedPassword) {
      return const AuthServiceResult(status: AuthServiceStatus.required);
    }
    return AuthServiceResult(
      status: AuthServiceStatus.authenticated,
      profile: profile,
    );
  }

  @override
  Future<AuthServiceResult> restore({bool offline = false}) async =>
      const AuthServiceResult(status: AuthServiceStatus.required);

  @override
  Future<AuthProfile?> loadProfile() async => profile;

  @override
  Future<AuthProfile?> loadProfileFor(
    String serverUrl,
    String database,
  ) async => profile;

  @override
  Future<void> close() async {}
}
