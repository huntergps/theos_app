import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/app/preferences/app_preferences.dart';
import 'package:theos_panel/app/router.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:theos_panel/ui/layouts/workspace_lock_screen.dart';

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

  CapabilitySnapshot capabilities() => CapabilitySnapshot(
    scopeKey: 'scope',
    companyId: 1,
    revision: 1,
    fetchedAt: DateTime.utc(2026, 9, 13),
    permissions: const [],
  );

  testWidgets(
    'bloquear y recargar la app (mismo almacenamiento) muestra la pantalla '
    'de bloqueo, no Inicio',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({'orbi/workspace/locked': true});
      final preferences = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          authInitialStateProvider.overrideWithValue(
            AuthViewState(
              status: AuthControllerStatus.authenticated,
              profile: profile,
              capabilities: capabilities(),
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

      expect(find.byType(WorkspaceLockScreen), findsOneWidget);
      expect(find.text('Total ventas del día'), findsNothing);
    },
  );
}
