import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/features/sales/sale_draft_workspace.dart';
import 'package:theos_panel/features/sales/sale_draft_workspace_bar.dart';
import 'package:theos_panel/features/sales/sale_editor.dart';

void main() {
  testWidgets(
    'bar closes tabs, keeps durable IDs, and has no overflow at four widths',
    (tester) async {
      final scope = AppScope(
        appId: 'orbi',
        installationId: 'bar',
        normalizedServerUrl: 'https://erp.test',
        database: 'erp',
        userId: 1,
      );
      final owner = RuntimeDatabaseOwner(
        factory: (_) => AppDatabase(NativeDatabase.memory()),
      );
      late RuntimeDatabase activation;
      late SaleDraftWorkspace workspace;
      await tester.runAsync(() async {
        activation = await owner.open(scope);
      });
      final company = CompanyContext.forScope(
        scope: scope,
        companyId: 1,
        allowedCompanyIds: [1],
        capabilityRevision: 1,
      );
      workspace = SaleDraftWorkspace(
        store: EditableDraftStore(
          owner: owner,
          lease: activation.lease,
          company: company,
        ),
        scopeKey: scope.scopeKey,
        controllerFactory: (store) => SaleDraftController(
          port: LocalSaleEditorPort(),
          store: store,
          scopeKey: scope.scopeKey,
        ),
      );
      await tester.runAsync(() async {
        await workspace.initialize();
        await workspace.create();
      });
      await tester.pumpWidget(
        MaterialApp(home: SaleDraftWorkspaceBar(workspace: workspace)),
      );
      for (final size in [
        const Size(1440, 900),
        const Size(1180, 820),
        const Size(820, 1180),
        const Size(390, 844),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
      final id = workspace.draftIds.first;
      expect(find.byKey(ValueKey('close-draft-$id')), findsOneWidget);
      await tester.runAsync(() async {
        await workspace.close(id);
      });
      expect(workspace.draftIds, isNot(contains(id)));
      final retained = await tester.runAsync(() => workspace.store.read(id));
      expect(retained, isNotNull);
      await tester.runAsync(() async {
        await workspace.disposeAsync();
        await owner.close();
      });
    },
  );
}
