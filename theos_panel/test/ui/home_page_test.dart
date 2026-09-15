import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart' show AuthProfile, CapabilitySnapshot;
import 'package:theos_pos_core/theos_pos_core.dart';
import 'package:theos_panel/app/session_composition.dart';
import 'package:theos_panel/app/notification_scope_adapter.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:theos_panel/features/home/home_center.dart';
import 'package:theos_panel/ui/home_page.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

AuthProfile _profile({String? name}) => AuthProfile(
  serverUrl: 'https://erp2.test',
  database: 'erp2_test',
  login: 'carlos.guajala',
  userId: 9,
  installationId: 'install-1',
  credentialReference: 'ref-1',
  name: name,
);

void main() {
  testWidgets('home content is independent from shell navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Carlos uid 9 has sales_team.group_sale_salesman (36) and the implied
    // all-leads group (37) in ERP2. These are the exact XML IDs returned by
    // res.groups.get_external_id for his effective all_group_ids.
    final capabilities = CapabilityProvisioner.materialize(
      scopeKey: 'carlos-erp2',
      companyId: 1,
      revision: 1,
      fetchedAt: DateTime.utc(2026),
      allGroupIds: const [36, 37],
      externalIds: const {
        36: 'sales_team.group_sale_salesman',
        37: 'sales_team.group_sale_salesman_all_leads',
      },
      hasGroup: (externalId) =>
          externalId == 'sales_team.group_sale_salesman' ||
          externalId == 'sales_team.group_sale_salesman_all_leads',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orbiSessionCompositionProvider.overrideWithValue(
            const OrbiSessionComposition(),
          ),
          runtimeSessionProvider.overrideWithValue(null),
          capabilitySnapshotProvider.overrideWithValue(capabilities),
        ],
        child: FluentApp(theme: OrbiFluentTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();

    // Un solo encabezado: «Inicio operativo», siempre — nunca un saludo por
    // nombre debajo ni en su lugar.
    expect(find.text('Inicio operativo'), findsOneWidget);
    expect(find.textContaining('Hola,'), findsNothing);
    expect(find.byKey(const Key('logout-button')), findsNothing);
  });

  testWidgets(
    // (a) de ACC-03: el título es «Inicio operativo» y no aparece «Hola,» —
    // ni siquiera cuando el perfil sí trae un nombre real. Antes (b0645cd)
    // `_greetingTitle` devolvía «Hola, Carlos Guajala» en este mismo caso.
    'el encabezado es «Inicio operativo» incluso cuando el perfil trae '
    'nombre — se quitó el saludo por nombre (ACC-03, punto 1)',
    (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orbiSessionCompositionProvider.overrideWithValue(
              const OrbiSessionComposition(),
            ),
            runtimeSessionProvider.overrideWithValue(null),
            capabilitySnapshotProvider.overrideWithValue(null),
            authInitialStateProvider.overrideWithValue(
              AuthViewState(profile: _profile(name: 'Carlos Guajala')),
            ),
          ],
          child: FluentApp(theme: OrbiFluentTheme.light, home: const HomePage()),
        ),
      );
      await tester.pump();

      expect(find.text('Inicio operativo'), findsOneWidget);
      expect(find.textContaining('Hola,'), findsNothing);
      expect(find.textContaining('carlos.guajala'), findsNothing);
    },
  );

  testWidgets('home without a resume port shows a useful local state', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orbiSessionCompositionProvider.overrideWithValue(
            const OrbiSessionComposition(),
          ),
          runtimeSessionProvider.overrideWithValue(null),
          capabilitySnapshotProvider.overrideWithValue(null),
        ],
        child: FluentApp(theme: OrbiFluentTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();

    expect(find.text('Trabajo local'), findsOneWidget);
    expect(find.textContaining('No hay un servicio'), findsOneWidget);
    expect(find.byKey(const Key('logout-button')), findsNothing);
  });

  testWidgets(
    // (f) de ACC-03: «No existe Accesos rápidos». Contra b0645cd, con un
    // puerto disponible y capacidad de vendedor, `HomePage` armaba
    // `_quickStarts` (Ventas + Sistema, el segundo por el acceso universal a
    // `/sync`) y `HomeCenterView` los pintaba bajo «Accesos rápidos».
    'no existe «Accesos rápidos» aunque haya un puerto de inicio y permiso '
    'de vendedor',
    (tester) async {
      final capabilities = CapabilitySnapshot(
        scopeKey: 'carlos-erp2',
        companyId: 1,
        revision: 1,
        fetchedAt: DateTime.utc(2026, 9, 15),
        permissions: const {'seller'},
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orbiSessionCompositionProvider.overrideWithValue(
              OrbiSessionComposition(home: const _EmptyPort()),
            ),
            runtimeSessionProvider.overrideWithValue(null),
            capabilitySnapshotProvider.overrideWithValue(capabilities),
          ],
          child: FluentApp(theme: OrbiFluentTheme.light, home: const HomePage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Accesos rápidos'), findsNothing);
      expect(find.text('Empieza por aquí:'), findsNothing);
    },
  );
}

final class _EmptyPort implements HomeResumePort {
  const _EmptyPort();
  @override
  HomeResumeSnapshot get snapshot => const HomeResumeSnapshot(HomeResumeState.empty);
  @override
  Stream<HomeResumeSnapshot> get changes => const Stream.empty();
  @override
  Future<void> resume(HomeResumeItem item) async {}
}
