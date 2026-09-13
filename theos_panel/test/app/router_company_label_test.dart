import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/app/preferences/app_preferences.dart';
import 'package:theos_panel/app/router.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';

/// Regression guard for the "Empresa #1" placeholder the dueño saw
/// (2026-09-12): `res.users.company_id`, read the same way on native and web
/// (`OdooActiveIdentityReader.read`), already returns the real name
/// alongside the id — `AuthProfile.companyName` now carries it end to end,
/// and the shell's header must actually show it instead of falling back to
/// the number.
void main() {
  const profileWithName = AuthProfile(
    serverUrl: 'https://erp.test',
    database: 'demo',
    login: 'erik',
    userId: 7,
    installationId: 'i-1',
    credentialReference: 'api-key',
    companyId: 1,
    companyName: 'Aldas Romero Erik Andres',
  );

  const profileWithoutName = AuthProfile(
    serverUrl: 'https://erp.test',
    database: 'demo',
    login: 'erik',
    userId: 7,
    installationId: 'i-1',
    credentialReference: 'api-key',
    companyId: 1,
  );

  CapabilitySnapshot capabilities() => CapabilitySnapshot(
    scopeKey: 'scope',
    companyId: 1,
    revision: 1,
    fetchedAt: DateTime.utc(2026, 9, 12),
    permissions: const [],
  );

  Future<void> pump(WidgetTester tester, AuthProfile profile) async {
    // Ancho de escritorio: desde e2108c7 el menú lo resuelve Fluent en
    // automático, y a los 800 px por omisión de flutter_test cae en el carril
    // de iconos, donde Fluent esconde la cabecera con la empresa.
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
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
  }

  testWidgets(
    'the header shows the real company name when the profile carries one',
    (tester) async {
      await pump(tester, profileWithName);
      expect(find.text('Aldas Romero Erik Andres'), findsOneWidget);
      expect(find.textContaining('Empresa #'), findsNothing);
    },
  );

  testWidgets(
    'falls back to the numeric placeholder only when no name was ever '
    'resolved — never the default for an authenticated user with a name',
    (tester) async {
      await pump(tester, profileWithoutName);
      expect(find.text('Empresa #1'), findsOneWidget);
    },
  );

  // Companion regression guard: the footer's "Sincronización" used to be a
  // literal `'Sincronización no verificada'` that never changed. With no
  // active runtime session (as in this test, which never activates one) the
  // coordinator is genuinely absent, and the label must say so honestly —
  // "no disponible", a distinct fact from the old always-on "no verificada"
  // — rather than repeat the same frozen string regardless of what is
  // actually going on underneath.
  testWidgets(
    'the footer reports sync as unavailable rather than the old permanent '
    '"no verificada" literal when there is no active session',
    (tester) async {
      await pump(tester, profileWithName);
      expect(
        find.textContaining('Sincronización no disponible'),
        findsOneWidget,
      );
      expect(find.textContaining('Sincronización no verificada'), findsNothing);
    },
  );
}
