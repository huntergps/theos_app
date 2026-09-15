import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/app/preferences/app_preferences.dart';
import 'package:theos_panel/app/router.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:theos_panel/features/auth/pin_credential_store.dart';
import 'package:theos_panel/ui/layouts/workspace_lock_screen.dart';

// Contra 90a37dc, `WorkspaceLockScreen` no tiene `onUnlockWithPin` y
// `router.dart` no tiene `attemptWorkspaceUnlockWithPin`: este archivo no
// compila todavía, así que las dos pruebas de este bloque fallan por falta
// del propio mecanismo, no por una aserción concreta — decisión del dueño,
// 14-sep-2026, "al volver, se desbloquea con PIN o con la clave, SIN perder
// la sesión ni lo abierto".
void main() {
  const profile = AuthProfile(
    serverUrl: 'https://erp.test',
    database: 'demo',
    login: 'carlos.guajala',
    userId: 7,
    installationId: 'i-1',
    credentialReference: 'api-key',
    companyId: 1,
    companyName: 'Empresa Demo',
  );

  final scopeKey = pinScopeKeyFor(
    profile.serverUrl,
    profile.database,
    profile.login,
  );

  // El vendedor bloqueado también tiene `cashier` — un permiso que el PIN de
  // ENTRADA (`restrictSnapshotToSellerPin`) nunca concede. Si desbloquear
  // con PIN pasara por ese mismo recorte, esta prueba lo notaría.
  CapabilitySnapshot capabilitiesWithCashier() => CapabilitySnapshot(
    scopeKey: 'scope',
    companyId: 1,
    revision: 1,
    fetchedAt: DateTime.utc(2026, 9, 14),
    permissions: const ['seller', 'cashier'],
  );

  Future<ProviderContainer> pumpLockedShell(
    WidgetTester tester,
    SharedPreferences preferences,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        authInitialStateProvider.overrideWithValue(
          AuthViewState(
            status: AuthControllerStatus.authenticated,
            profile: profile,
            capabilities: capabilitiesWithCashier(),
          ),
        ),
        sharedPreferencesProvider.overrideWithValue(preferences),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(orbiRouterProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: FluentApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
    'PIN unlocks and keeps full permissions',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'orbi/workspace/locked': true,
      });
      final preferences = await SharedPreferences.getInstance();
      await PinCredentialStore(preferences).enroll(scopeKey, '1234');

      final container = await pumpLockedShell(tester, preferences);

      expect(find.byType(WorkspaceLockScreen), findsOneWidget);
      expect(
        find.byKey(const Key('workspace-lock-pin')),
        findsOneWidget,
        reason: 'el PIN ya está enrolado para esta identidad en este aparato',
      );

      await tester.enterText(
        find.byKey(const Key('workspace-lock-pin')),
        '1234',
      );
      await tester.tap(find.byKey(const Key('workspace-unlock-pin-button')));
      await tester.pumpAndSettle();

      expect(container.read(workspaceLockProvider), isFalse);
      expect(find.byType(WorkspaceLockScreen), findsNothing);
      expect(
        container.read(capabilitySnapshotProvider)?.permissions,
        containsAll(<String>['seller', 'cashier']),
        reason:
            'el tope de vendedor sólo aplica al ENTRAR o CAMBIAR de usuario '
            'con PIN, nunca al desbloquear',
      );
    },
  );

  testWidgets('wrong PIN respects attempt limit', (tester) async {
    SharedPreferences.setMockInitialValues({'orbi/workspace/locked': true});
    final preferences = await SharedPreferences.getInstance();
    final store = PinCredentialStore(preferences);
    await store.enroll(scopeKey, '1234');

    final container = await pumpLockedShell(tester, preferences);

    Future<void> attempt(String pin) async {
      await tester.enterText(
        find.byKey(const Key('workspace-lock-pin')),
        pin,
      );
      await tester.tap(find.byKey(const Key('workspace-unlock-pin-button')));
      await tester.pumpAndSettle();
    }

    for (var i = 0; i < kSellerPinMaxAttempts; i++) {
      await attempt('0000');
    }

    expect(
      store.readAttempts(scopeKey).isLockedAt(DateTime.now()),
      isTrue,
      reason: 'se agotó el cupo de intentos ($kSellerPinMaxAttempts)',
    );

    // Incluso el PIN correcto se rechaza mientras dure el bloqueo temporal.
    await attempt('1234');
    expect(
      container.read(workspaceLockProvider),
      isTrue,
      reason: 'un cupo agotado no se salta ni con el PIN correcto',
    );
  });
}
