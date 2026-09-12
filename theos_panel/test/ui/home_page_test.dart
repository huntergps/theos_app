import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos_core/theos_pos_core.dart';
import 'package:theos_panel/app/session_composition.dart';
import 'package:theos_panel/app/notification_scope_adapter.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:theos_panel/ui/home_page.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

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

    expect(find.text('Inicio operativo'), findsOneWidget);
    expect(find.byKey(const Key('logout-button')), findsNothing);
    expect(find.text('Ventas'), findsNothing);
    expect(find.text('Bodega'), findsNothing);
  });

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
}
