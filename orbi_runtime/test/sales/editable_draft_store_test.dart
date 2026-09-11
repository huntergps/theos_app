import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

AppScope _scope({int userId = 1}) => AppScope(
  appId: 'orbi-panel',
  installationId: 'test-installation',
  normalizedServerUrl: 'https://erp.test',
  database: 'erp',
  userId: userId,
);

CompanyContext _company(AppScope scope, int companyId) =>
    CompanyContext.forScope(
      scope: scope,
      companyId: companyId,
      allowedCompanyIds: [companyId],
      capabilityRevision: 1,
    );

RuntimeDatabaseOwner _owner(File file) =>
    RuntimeDatabaseOwner(factory: (_) => AppDatabase(NativeDatabase(file)));

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('orbi-editable-draft-');
    file = File('${directory.path}/runtime.sqlite');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('persists drafts across owner reopen', () async {
    final scope = _scope();
    final firstOwner = _owner(file);
    final first = await firstOwner.open(scope);
    final store = EditableDraftStore(
      owner: firstOwner,
      lease: first.lease,
      company: _company(scope, 7),
    );
    await store.save('draft-1', {
      'name': 'Caja',
      'lines': [1, 2],
    }, expectedRevision: 0);
    await firstOwner.close();

    final secondOwner = _owner(file);
    addTearDown(secondOwner.close);
    final second = await secondOwner.open(scope);
    final reopened = EditableDraftStore(
      owner: secondOwner,
      lease: second.lease,
      company: _company(scope, 7),
    );
    final record = await reopened.read('draft-1');
    expect(record?.payload, {
      'name': 'Caja',
      'lines': [1, 2],
    });
    expect(record?.revision, 1);
  });

  test('isolates companies and draft IDs', () async {
    final scope = _scope();
    final owner = _owner(file);
    addTearDown(owner.close);
    final activation = await owner.open(scope);
    final companyOne = EditableDraftStore(
      owner: owner,
      lease: activation.lease,
      company: _company(scope, 1),
    );
    final companyTwo = EditableDraftStore(
      owner: owner,
      lease: activation.lease,
      company: _company(scope, 2),
    );
    await companyOne.save('same-id', {'company': 1}, expectedRevision: 0);
    await companyTwo.save('same-id', {'company': 2}, expectedRevision: 0);
    await companyOne.save('other-id', {'draft': 2}, expectedRevision: 0);
    expect((await companyOne.read('same-id'))?.payload['company'], 1);
    expect((await companyTwo.read('same-id'))?.payload['company'], 2);
    expect((await companyOne.read('other-id'))?.payload['draft'], 2);
  });

  test('rejects stale lease reads and writes', () async {
    final owner = _owner(file);
    final firstScope = _scope(userId: 1);
    final first = await owner.open(firstScope);
    final store = EditableDraftStore(
      owner: owner,
      lease: first.lease,
      company: _company(firstScope, 1),
    );
    final secondScope = _scope(userId: 2);
    await owner.open(secondScope);
    expect(await store.read('draft'), isNull);
    expect(
      () => store.save('draft', {}, expectedRevision: 0),
      throwsA(isA<StateError>()),
    );
    await owner.close();
  });

  test('only one concurrent save wins the same expected revision', () async {
    final scope = _scope();
    final owner = _owner(file);
    addTearDown(owner.close);
    final activation = await owner.open(scope);
    final store = EditableDraftStore(
      owner: owner,
      lease: activation.lease,
      company: _company(scope, 1),
    );
    final outcomes = await Future.wait<bool>([
      store
          .save('race', {'winner': 1}, expectedRevision: 0)
          .then<bool>((_) => true, onError: (_, _) => false),
      store
          .save('race', {'winner': 2}, expectedRevision: 0)
          .then<bool>((_) => true, onError: (_, _) => false),
    ]);
    expect(outcomes.where((value) => value == true), hasLength(1));
    expect(outcomes.where((value) => value == false), hasLength(1));
    expect((await store.read('race'))?.revision, 1);
  });

  test('watch emits initial state and committed updates', () async {
    final scope = _scope();
    final owner = _owner(file);
    addTearDown(owner.close);
    final activation = await owner.open(scope);
    final store = EditableDraftStore(
      owner: owner,
      lease: activation.lease,
      company: _company(scope, 1),
    );
    final valuesFuture = store.watch('watched').take(2).toList();
    await Future<void>.delayed(Duration.zero);
    await store.save('watched', {'value': 'new'}, expectedRevision: 0);
    final values = await valuesFuture;
    expect(values.first, isNull);
    expect(values.last?.payload['value'], 'new');
    expect(values.last?.revision, 1);
  });

  test('saving drafts does not create outbox rows', () async {
    final scope = _scope();
    final owner = _owner(file);
    addTearDown(owner.close);
    final activation = await owner.open(scope);
    final store = EditableDraftStore(
      owner: owner,
      lease: activation.lease,
      company: _company(scope, 1),
    );
    await store.save('no-outbox', {'total': 10}, expectedRevision: 0);
    final rows = await activation.database
        .customSelect('SELECT COUNT(*) AS count FROM offline_queue')
        .get();
    expect(rows.single.data['count'], 0);
  });
}
