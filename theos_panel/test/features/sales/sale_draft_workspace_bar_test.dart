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

  testWidgets(
    'reopen menu reflects drafts created after the bar first built '
    '(twin of the async-note-restore defect: a value read once and never '
    're-synced as later events arrive)',
    (tester) async {
      final scope = AppScope(
        appId: 'orbi',
        installationId: 'bar-refresh',
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
      await tester.runAsync(() => workspace.initialize());
      await tester.pumpWidget(
        MaterialApp(home: SaleDraftWorkspaceBar(workspace: workspace)),
      );
      await tester.pumpAndSettle();

      // A tab created after the bar's first frame — the reopen list must
      // learn about it without the bar itself being torn down and rebuilt.
      // The listener-triggered refresh kicks off its own real Drift query, so
      // the pumps that let that `FutureBuilder` observe it must stay inside
      // `runAsync` too: a real Future resolved outside the fake test zone
      // never delivers its completion to a widget pumped from inside it.
      late String secondId;
      await tester.runAsync(() async {
        secondId = await workspace.create();
        var enabled = false;
        for (var attempt = 0; attempt < 10 && !enabled; attempt++) {
          await tester.pump();
          enabled = tester
              .widget<PopupMenuButton<String>>(
                find.byKey(const Key('reopen-draft-button')),
              )
              .enabled;
        }
        expect(enabled, isTrue, reason: 'Reopen menu never finished loading.');
        await tester.tap(find.byKey(const Key('reopen-draft-button')));
        await tester.pump();
        await tester.pump();
      });

      expect(
        find.byWidgetPredicate(
          (widget) => widget is PopupMenuItem<String> && widget.value == secondId,
        ),
        findsOneWidget,
        reason:
            'The reopen menu cached its list on first build and never '
            'refreshed after a new draft was created in the same session.',
      );

      await tester.runAsync(() async {
        await workspace.disposeAsync();
        await owner.close();
      });
    },
  );
}
