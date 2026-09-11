import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

AppScope _scope({int userId = 1}) => AppScope(
  appId: 'orbi-panel',
  installationId: 'listing-test',
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
    directory = await Directory.systemTemp.createTemp('orbi-editable-list-');
    file = File('${directory.path}/runtime.sqlite');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test(
    'returns bounded deterministic keyset pages and immutable list',
    () async {
      final scope = _scope();
      final owner = _owner(file);
      addTearDown(owner.close);
      final activation = await owner.open(scope);
      final store = EditableDraftStore(
        owner: owner,
        lease: activation.lease,
        company: _company(scope, 7),
      );
      for (final id in ['a', 'b', 'c', 'd']) {
        await store.save(id, {'id': id}, expectedRevision: 0);
      }

      final first = await store.list(limit: 2);
      expect(first.map((record) => record.key.draftId), ['a', 'b']);
      expect(first, isA<List<EditableDraftRecord>>());
      expect(() => first.add(first.first), throwsA(isA<UnsupportedError>()));
      final second = await store.list(limit: 2, afterDraftId: 'b');
      expect(second.map((record) => record.key.draftId), ['c', 'd']);
      expect((await store.list(limit: 2, afterDraftId: 'z')), isEmpty);
    },
  );

  test('watchList emits initial page and committed updates', () async {
    final scope = _scope();
    final owner = _owner(file);
    addTearDown(owner.close);
    final activation = await owner.open(scope);
    final store = EditableDraftStore(
      owner: owner,
      lease: activation.lease,
      company: _company(scope, 1),
    );
    final initial = Completer<void>();
    final updated = Completer<void>();
    final values = <List<EditableDraftRecord>>[];
    final subscription = store.watchList(limit: 2).listen((value) {
      values.add(value);
      if (values.length == 1) initial.complete();
      if (values.length == 2) updated.complete();
    });
    addTearDown(subscription.cancel);
    await initial.future;
    await store.save('first', {'value': 1}, expectedRevision: 0);
    await updated.future;
    expect(values.first, isEmpty);
    expect(values.last.single.payload['value'], 1);
  });

  test('list and watchList surface malformed persisted rows', () async {
    final scope = _scope();
    final owner = _owner(file);
    addTearDown(owner.close);
    final activation = await owner.open(scope);
    final store = EditableDraftStore(
      owner: owner,
      lease: activation.lease,
      company: _company(scope, 1),
    );
    await activation.database.customStatement(
      "INSERT INTO orbi_editable_draft "
      "(scope_key, company_id, draft_id, payload, revision) "
      "VALUES ('${scope.scopeKey}', 1, 'broken', 'not-json', 1)",
    );
    await expectLater(store.list(), throwsA(isA<StateError>()));
    await expectLater(store.watchList(), emitsError(isA<StateError>()));
  });

  test(
    'watchList can be cancelled and closes after scope invalidation',
    () async {
      final scope = _scope();
      final owner = _owner(file);
      addTearDown(owner.close);
      final activation = await owner.open(scope);
      final store = EditableDraftStore(
        owner: owner,
        lease: activation.lease,
        company: _company(scope, 1),
      );
      final firstValue = Completer<void>();
      final subscription = store.watchList().listen(
        (_) => firstValue.complete(),
      );
      await firstValue.future;
      await subscription.cancel();
      await store.save('after-cancel', {}, expectedRevision: 0);

      final invalidated = Completer<void>();
      store.watchList().listen((_) {}, onDone: invalidated.complete);
      await owner.open(_scope(userId: 2));
      await invalidated.future.timeout(const Duration(seconds: 2));
    },
  );

  test(
    'excludes other companies, survives reopen, and rejects stale lease',
    () async {
      final scope = _scope();
      final firstOwner = _owner(file);
      final first = await firstOwner.open(scope);
      final companyOne = EditableDraftStore(
        owner: firstOwner,
        lease: first.lease,
        company: _company(scope, 1),
      );
      final companyTwo = EditableDraftStore(
        owner: firstOwner,
        lease: first.lease,
        company: _company(scope, 2),
      );
      await companyOne.save('same', {'company': 1}, expectedRevision: 0);
      await companyTwo.save('same', {'company': 2}, expectedRevision: 0);
      expect((await companyOne.list()).map((r) => r.payload['company']), [1]);
      await firstOwner.close();

      final secondOwner = _owner(file);
      addTearDown(secondOwner.close);
      final second = await secondOwner.open(scope);
      final reopened = EditableDraftStore(
        owner: secondOwner,
        lease: second.lease,
        company: _company(scope, 1),
      );
      expect((await reopened.list()).single.payload['company'], 1);

      final stale = EditableDraftStore(
        owner: secondOwner,
        lease: second.lease,
        company: _company(scope, 1),
      );
      await secondOwner.open(_scope(userId: 2));
      expect(await stale.list(), isEmpty);
      await firstOwner.close();
    },
  );

  test('validates page arguments before accessing SQLite', () async {
    final scope = _scope();
    final owner = _owner(file);
    addTearDown(owner.close);
    final activation = await owner.open(scope);
    final store = EditableDraftStore(
      owner: owner,
      lease: activation.lease,
      company: _company(scope, 1),
    );
    expect(() => store.list(limit: 0), throwsArgumentError);
    expect(() => store.list(limit: 201), throwsArgumentError);
    expect(() => store.list(afterDraftId: ''), throwsArgumentError);
    expect(() => store.watchList(limit: 0), throwsArgumentError);
  });
}
