
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:drift/native.dart';

import 'package:theos_panel/app/envases_composition.dart';
import 'package:theos_panel/features/envases/envases_dashboard_screen.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

/// Exercises the real, disk-backed [EnvasesDashboardCache] behind
/// [EnvasesDashboardController] and [EnvasesDashboardScreen] together,
/// instead of feeding the widget a hand-rolled stream. It proves the screen
/// is wired to the local observable copy: a write that lands in the shared
/// SQLite row through a second, independent cache instance (standing in for
/// a background sync job) must reach the screen through `cache.watch()`
/// without the screen's own reader ever being asked again.
void main() {
  AppScope scope() => AppScope(
    appId: 'orbi',
    installationId: 'i',
    normalizedServerUrl: 'https://erp.test',
    database: 'db',
    userId: 1,
  );

  Map<String, dynamic> row(String name, {required int id}) => {
    'id': id,
    'product_id': [id, name],
    'uom_id': [1, 'Unidad'],
    'company_id': [4, 'Empresa'],
    'total_propio': 2.0,
    'en_sede': 2.0,
    'danados': 0.0,
    'en_custodia_cliente': 0.0,
    'en_custodia_proveedor': 0.0,
    'en_transito': 0.0,
  };

  testWidgets(
    'screen picks up a local cache write from another sync path without '
    'asking its own reader again',
    (tester) async {
      final owner = RuntimeDatabaseOwner(
        factory: (_) => AppDatabase(NativeDatabase.memory()),
      );
      final s = scope();
      final db = await owner.open(s);
      addTearDown(owner.close);
      final company = CompanyContext.forScope(
        scope: s,
        companyId: 4,
        allowedCompanyIds: [4],
        capabilityRevision: 1,
      );

      var ownReaderCalls = 0;
      final ownCache = EnvasesDashboardCache(
        owner: owner,
        lease: db.lease,
        company: company,
      );
      final ownReader = EnvasesDashboardReader(
        company: company,
        transport: ({
          required model,
          required domain,
          required fields,
          required context,
          required limit,
          required offset,
          required order,
        }) async {
          ownReaderCalls++;
          return [row('Jaba', id: 10)];
        },
      );
      final controller = EnvasesDashboardController(
        cache: ownCache,
        reader: ownReader,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        FluentApp(
          theme: OrbiFluentTheme.light,
          home: EnvasesDashboardScreen(
            snapshots: controller.snapshots,
            onRefresh: controller.refresh,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Sin datos descargados'), findsOneWidget);

      await controller.refresh();
      await tester.pump();
      expect(find.text('Jaba'), findsOneWidget);
      expect(ownReaderCalls, 1);

      // A second, independent cache instance over the same shared lease and
      // company stands in for another writer (e.g. a background sync job).
      // It never touches `controller` or `ownReader`.
      final backgroundCache = EnvasesDashboardCache(
        owner: owner,
        lease: db.lease,
        company: company,
      );
      final backgroundReader = EnvasesDashboardReader(
        company: company,
        transport: ({
          required model,
          required domain,
          required fields,
          required context,
          required limit,
          required offset,
          required order,
        }) async => [row('Cerveza', id: 11)],
      );
      await backgroundCache.refresh(backgroundReader);

      await tester.pump();

      expect(find.text('Cerveza'), findsOneWidget);
      expect(find.text('Jaba'), findsNothing);
      expect(
        ownReaderCalls,
        1,
        reason:
            'the screen must refresh from the local copy alone; its own '
            'reader must not be asked again to observe the change',
      );
    },
  );
}
