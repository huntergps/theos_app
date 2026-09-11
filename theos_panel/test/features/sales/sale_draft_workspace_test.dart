import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/features/sales/sale_draft_codec.dart';
import 'package:theos_panel/features/sales/sale_draft_workspace.dart';
import 'package:theos_panel/features/sales/sale_editor.dart';

AppScope _scope({int userId = 1}) => AppScope(
  appId: 'orbi-panel',
  installationId: 'workspace-test',
  normalizedServerUrl: 'https://erp.test',
  database: 'erp',
  userId: userId,
);

CompanyContext _company(AppScope scope, {int companyId = 1}) =>
    CompanyContext.forScope(
      scope: scope,
      companyId: companyId,
      allowedCompanyIds: [companyId],
      capabilityRevision: 1,
    );

RuntimeDatabaseOwner _owner(File file) =>
    RuntimeDatabaseOwner(factory: (_) => AppDatabase(NativeDatabase(file)));

SaleDraftWorkspace _workspace(
  RuntimeDatabaseOwner owner,
  RuntimeDatabase activation,
) {
  return SaleDraftWorkspace(
    store: EditableDraftStore(
      owner: owner,
      lease: activation.lease,
      company: _company(activation.scope),
    ),
    scopeKey: activation.scope.scopeKey,
    controllerFactory: (store) => SaleDraftController(
      port: LocalSaleEditorPort(),
      store: store,
      scopeKey: activation.scope.scopeKey,
    ),
  );
}

Future<void> _seed(
  EditableDraftStore store,
  String id, {
  String? scopeKey,
  String commandId = 'seed-command',
}) => store.save(
  id,
  SaleDraftCodec.encode(
    SaleDraftSnapshot(scopeKey: scopeKey ?? 'default', commandId: commandId),
  ),
  expectedRevision: 0,
);

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('orbi-workspace-');
    file = File('${directory.path}/runtime.sqlite');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test(
    'initializes a new secure durable tab and switches to another',
    () async {
      final scope = _scope();
      final owner = _owner(file);
      addTearDown(owner.close);
      final activation = await owner.open(scope);
      final workspace = _workspace(owner, activation);
      addTearDown(workspace.disposeAsync);

      await workspace.initialize();
      final first = workspace.selectedDraftId!;
      final second = await workspace.create();
      expect(second, isNot(first));
      expect(workspace.draftIds, containsAll([first, second]));
      await workspace.select(first);
      expect(workspace.selectedDraftId, first);
      await workspace.close(second);
      expect(workspace.draftIds, contains(first));
      expect(await workspace.store.read(second), isNotNull);
    },
  );

  test(
    'reopens durable rows and selects the legacy active editor first',
    () async {
      final scope = _scope();
      final owner = _owner(file);
      addTearDown(owner.close);
      final activation = await owner.open(scope);
      final rawStore = EditableDraftStore(
        owner: owner,
        lease: activation.lease,
        company: _company(scope),
      );
      final snapshot = SaleDraftSnapshot(
        scopeKey: scope.scopeKey,
        commandId: 'stable-command',
      );
      await rawStore.save(
        'workspace-active-editor',
        SaleDraftCodec.encode(snapshot),
        expectedRevision: 0,
      );
      final workspace = _workspace(owner, activation);
      addTearDown(workspace.disposeAsync);
      await workspace.initialize();
      expect(workspace.selectedDraftId, 'workspace-active-editor');
      expect(workspace.selectedController!.draft.commandId, 'stable-command');
    },
  );

  test('surfaces corrupt payload without replacing it', () async {
    final scope = _scope();
    final owner = _owner(file);
    addTearDown(owner.close);
    final activation = await owner.open(scope);
    await activation.database.customStatement(
      "INSERT INTO orbi_editable_draft "
      "(scope_key, company_id, draft_id, payload, revision) "
      "VALUES ('${scope.scopeKey}', 1, 'broken', 'not-json', 1)",
    );
    final workspace = _workspace(owner, activation);
    addTearDown(workspace.disposeAsync);
    await expectLater(workspace.initialize(), throwsA(isA<StateError>()));
    final raw = await activation.database
        .customSelect(
          'SELECT payload FROM orbi_editable_draft WHERE draft_id = ?',
          variables: [drift.Variable<String>('broken')],
        )
        .getSingle();
    expect(raw.data['payload'], 'not-json');
    expect(workspace.error, isNotNull);
  });

  test(
    'switch rejects a busy controller and preserves company scope',
    () async {
      final scope = _scope();
      final owner = _owner(file);
      addTearDown(owner.close);
      final activation = await owner.open(scope);
      final workspace = _workspace(owner, activation);
      addTearDown(workspace.disposeAsync);
      await workspace.initialize();
      final first = workspace.selectedDraftId!;
      final second = await workspace.create();
      final controller = workspace.controllers[first]!;
      controller.update(clientName: 'Persisted');
      await workspace.select(first);
      await workspace.select(second);
      expect((await workspace.store.read(first))?.payload, isNotEmpty);
    },
  );

  test(
    'discovers recovered IDs, opens lazily, and closes to another tab',
    () async {
      final scope = _scope();
      final owner = _owner(file);
      addTearDown(owner.close);
      final activation = await owner.open(scope);
      final raw = EditableDraftStore(
        owner: owner,
        lease: activation.lease,
        company: _company(scope),
      );
      await _seed(raw, 'a', scopeKey: scope.scopeKey, commandId: 'a-command');
      await _seed(raw, 'b', scopeKey: scope.scopeKey, commandId: 'b-command');
      await _seed(
        EditableDraftStore(
          owner: owner,
          lease: activation.lease,
          company: _company(scope, companyId: 2),
        ),
        'other-company',
        scopeKey: scope.scopeKey,
      );
      final workspace = _workspace(owner, activation);
      addTearDown(workspace.disposeAsync);
      await workspace.initialize();
      expect(workspace.draftIds, ['a', 'b']);
      expect(workspace.controllers.keys, ['a']);
      await workspace.select('b');
      expect(workspace.selectedController!.draft.commandId, 'b-command');
      await workspace.close('b');
      expect(workspace.selectedDraftId, 'a');
      await workspace.reopen('b');
      expect(workspace.selectedDraftId, 'b');
      expect(workspace.selectedController, isNotNull);
      expect(workspace.selectedDraftId, 'b');
    },
  );

  test(
    'revision conflict makes close fail but retains the editable tab',
    () async {
      final scope = _scope();
      final owner = _owner(file);
      addTearDown(owner.close);
      final activation = await owner.open(scope);
      final workspace = _workspace(owner, activation);
      addTearDown(workspace.disposeAsync);
      await workspace.initialize();
      final id = workspace.selectedDraftId!;
      final external = EditableDraftStore(
        owner: owner,
        lease: activation.lease,
        company: _company(scope),
      );
      await external.save(id, {'external': true}, expectedRevision: 1);
      workspace.selectedController!.update(clientName: 'local-change');
      await expectLater(workspace.close(id), throwsA(isA<StateError>()));
      expect(workspace.draftIds, contains(id));
      expect(workspace.controllers, contains(id));
    },
  );

  test('serializes concurrent creates', () async {
    final scope = _scope();
    final owner = _owner(file);
    addTearDown(owner.close);
    final activation = await owner.open(scope);
    final workspace = _workspace(owner, activation);
    final initialization = workspace.initialize();
    await Future.wait([workspace.create(), workspace.create()]);
    await initialization;
    expect(workspace.draftIds.length, 3);
    await workspace.disposeAsync();
  });

  test(
    'disposal during initialize completes without late publication',
    () async {
      final scope = _scope();
      final owner = _owner(file);
      addTearDown(owner.close);
      final activation = await owner.open(scope);
      final workspace = _workspace(owner, activation);
      final initialization = workspace.initialize();
      await workspace.disposeAsync();
      await expectLater(initialization, completes);
    },
  );
}
