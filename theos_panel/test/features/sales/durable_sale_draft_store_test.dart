import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/features/sales/durable_sale_draft_store.dart';
import 'package:theos_panel/features/sales/sale_editor.dart';

AppScope _scope() => AppScope(
  appId: 'orbi-panel',
  installationId: 'adapter-test',
  normalizedServerUrl: 'https://erp.test',
  database: 'erp',
  userId: 1,
);

CompanyContext _company(AppScope scope, int id) => CompanyContext.forScope(
  scope: scope,
  companyId: id,
  allowedCompanyIds: [id],
  capabilityRevision: 1,
);

RuntimeDatabaseOwner _owner(File file) =>
    RuntimeDatabaseOwner(factory: (_) => AppDatabase(NativeDatabase(file)));

SaleDraftSnapshot _draft(
  String scope, {
  String note = 'initial',
  String command = 'cmd-1',
}) => SaleDraftSnapshot(
  scopeKey: scope,
  clientName: 'Cliente',
  note: note,
  commandId: command,
  orderLocalId: 'local-1',
  lines: const [
    SaleDraftLine(
      uuid: 'line-1',
      name: 'Producto',
      quantity: 2,
      unitPrice: 10,
      discount: 1,
      tax: 1.8,
      total: 20.8,
      uomId: 1,
      uomName: 'Unidad',
      taxIds: [3],
    ),
  ],
);

final class _Port implements SaleEditorPort {
  @override
  Future<SaleEditorResult> submit(SaleDraftSnapshot draft) async =>
      const SaleEditorResult(accepted: true);
}

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('orbi-panel-draft-');
    file = File('${directory.path}/runtime.sqlite');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('controller and adapter round-trip after reopening', () async {
    final scope = _scope();
    final owner = _owner(file);
    final activation = await owner.open(scope);
    final firstAdapter = DurableSaleDraftStore(
      store: EditableDraftStore(
        owner: owner,
        lease: activation.lease,
        company: _company(scope, 1),
      ),
      scopeKey: scope.scopeKey,
      draftId: 'tab-1',
    );
    final firstController = SaleDraftController(
      port: _Port(),
      store: firstAdapter,
      scopeKey: scope.scopeKey,
      initial: _draft(scope.scopeKey),
    );
    await firstController.restore();
    firstController.update(note: 'guardado');
    await firstController.flush();
    await owner.close();

    final reopenedOwner = _owner(file);
    addTearDown(reopenedOwner.close);
    final reopened = await reopenedOwner.open(scope);
    final secondAdapter = DurableSaleDraftStore(
      store: EditableDraftStore(
        owner: reopenedOwner,
        lease: reopened.lease,
        company: _company(scope, 1),
      ),
      scopeKey: scope.scopeKey,
      draftId: 'tab-1',
    );
    final secondController = SaleDraftController(
      port: _Port(),
      store: secondAdapter,
      scopeKey: scope.scopeKey,
    );
    await secondController.restore();
    expect(secondController.draft.note, 'guardado');
    expect(secondController.draft.lines.single.discount, 1);
    await firstController.dispose();
    await secondController.dispose();
  });

  test('company and draft identities remain distinct', () async {
    final scope = _scope();
    final owner = _owner(file);
    addTearDown(owner.close);
    final activation = await owner.open(scope);
    DurableSaleDraftStore adapter(int company, String draftId) =>
        DurableSaleDraftStore(
          store: EditableDraftStore(
            owner: owner,
            lease: activation.lease,
            company: _company(scope, company),
          ),
          scopeKey: scope.scopeKey,
          draftId: draftId,
        );
    final companyOne = adapter(1, 'same-tab');
    final companyTwo = adapter(2, 'same-tab');
    final otherDraft = adapter(1, 'other-tab');
    await companyOne.load(scope.scopeKey);
    await companyTwo.load(scope.scopeKey);
    await otherDraft.load(scope.scopeKey);
    await companyOne.save(_draft(scope.scopeKey, note: 'uno'));
    await companyTwo.save(_draft(scope.scopeKey, note: 'dos'));
    await otherDraft.save(_draft(scope.scopeKey, note: 'otro'));
    expect((await companyOne.load(scope.scopeKey))?.note, 'uno');
    expect((await companyTwo.load(scope.scopeKey))?.note, 'dos');
    expect((await otherDraft.load(scope.scopeKey))?.note, 'otro');
  });

  test('stale adapter CAS rejects and preserves newer snapshot', () async {
    final scope = _scope();
    final owner = _owner(file);
    addTearDown(owner.close);
    final activation = await owner.open(scope);
    DurableSaleDraftStore adapter() => DurableSaleDraftStore(
      store: EditableDraftStore(
        owner: owner,
        lease: activation.lease,
        company: _company(scope, 1),
      ),
      scopeKey: scope.scopeKey,
      draftId: 'cas-tab',
    );
    final first = adapter();
    final second = adapter();
    await first.load(scope.scopeKey);
    await second.load(scope.scopeKey);
    await first.save(_draft(scope.scopeKey, note: 'newer'));
    expect(
      second.save(_draft(scope.scopeKey, note: 'stale')),
      throwsA(isA<StateError>()),
    );
    expect((await first.load(scope.scopeKey))?.note, 'newer');
  });

  test('corrupt payload raises without overwriting it', () async {
    final scope = _scope();
    final owner = _owner(file);
    addTearDown(owner.close);
    final activation = await owner.open(scope);
    final raw = activation.database;
    await raw.customInsert(
      'INSERT INTO orbi_editable_draft '
      '(scope_key, company_id, draft_id, payload, revision) VALUES (?, ?, ?, ?, ?)',
      variables: [
        Variable<String>(scope.scopeKey),
        const Variable<int>(1),
        const Variable<String>('corrupt'),
        const Variable<String>('{"unexpected":true}'),
        const Variable<int>(1),
      ],
    );
    final adapter = DurableSaleDraftStore(
      store: EditableDraftStore(
        owner: owner,
        lease: activation.lease,
        company: _company(scope, 1),
      ),
      scopeKey: scope.scopeKey,
      draftId: 'corrupt',
    );
    expect(adapter.load(scope.scopeKey), throwsA(isA<FormatException>()));
    final stored = await raw
        .customSelect(
          'SELECT payload FROM orbi_editable_draft WHERE draft_id = ?',
          variables: [const Variable<String>('corrupt')],
        )
        .get();
    expect(stored.single.data['payload'], '{"unexpected":true}');
  });

  test('save before load is rejected without creating a row', () async {
    final scope = _scope();
    final owner = _owner(file);
    addTearDown(owner.close);
    final activation = await owner.open(scope);
    final adapter = DurableSaleDraftStore(
      store: EditableDraftStore(
        owner: owner,
        lease: activation.lease,
        company: _company(scope, 1),
      ),
      scopeKey: scope.scopeKey,
      draftId: 'not-loaded',
    );
    expect(adapter.save(_draft(scope.scopeKey)), throwsA(isA<StateError>()));
    final rows = await activation.database
        .customSelect('SELECT COUNT(*) AS count FROM orbi_editable_draft')
        .get();
    expect(rows.single.data['count'], 0);
  });
}
