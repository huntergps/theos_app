import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:theos_pos/core/database/database_helper.dart';
import 'package:theos_pos/features/collection/repositories/collection_repository.dart';
import 'package:theos_pos/features/users/repositories/user_repository.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;

import '../../../mocks/mock_odoo_client.dart';

class MockDatabaseHelper extends Mock implements DatabaseHelper {}

class MockUserRepository extends Mock implements UserRepository {}

class MockAccountPaymentManager extends Mock implements AccountPaymentManager {}

class MockCashOutManager extends Mock implements CashOutManager {}

class MockCollectionSessionCashManager extends Mock
    implements CollectionSessionCashManager {}

class MockCollectionSessionDepositManager extends Mock
    implements CollectionSessionDepositManager {}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late MockOdooClient client;
  late AppDatabase database;
  late CollectionSessionManager sessionManager;
  late CollectionRepository repository;

  const opened = CollectionSession(
    id: 5,
    name: 'SES/5',
    state: SessionState.opened,
    isSynced: true,
  );
  setUp(() async {
    client = MockOdooClient.online();
    database = AppDatabase(NativeDatabase.memory());
    sessionManager = CollectionSessionManager()..initDb(database);
    await sessionManager.smartUpsert(opened);
    repository = CollectionRepository(
      odooClient: client,
      db: MockDatabaseHelper(),
      userRepository: MockUserRepository(),
      sessionManager: sessionManager,
      paymentManager: MockAccountPaymentManager(),
      cashOutManager: MockCashOutManager(),
      sessionCashManager: MockCollectionSessionCashManager(),
      sessionDepositManager: MockCollectionSessionDepositManager(),
    );
  });

  tearDown(() => database.close());

  test(
    'pause uses the recordset action and verifies the refreshed state',
    () async {
      when(
        () => client.call(
          model: 'collection.session',
          method: 'action_session_pause',
          ids: [5],
          // ignore: deprecated_member_use
          args: null,
          kwargs: null,
          context: any(named: 'context'),
        ),
      ).thenAnswer((_) async => true);
      when(
        () => client.searchRead(
          model: 'collection.session',
          fields: sessionManager.odooFields,
          domain: any(named: 'domain'),
          limit: 1,
          offset: null,
          order: null,
          cancelToken: null,
        ),
      ).thenAnswer(
        (_) async => [
          {'id': 5, 'name': 'SES/5', 'state': 'paused'},
        ],
      );

      final result = await repository.pauseCollectionSession(
        5,
        reason: 'Conteo de efectivo',
      );

      expect(result.state, SessionState.paused);
      final invocation = verify(
        () => client.call(
          model: 'collection.session',
          method: 'action_session_pause',
          ids: [5],
          // ignore: deprecated_member_use
          args: null,
          kwargs: null,
          context: captureAny(named: 'context'),
        ),
      );
      expect(
        invocation.captured.single,
        containsPair('pause_reason', 'Conteo de efectivo'),
      );
    },
  );

  test(
    'pause fails when the server response does not confirm paused state',
    () async {
      when(
        () => client.call(
          model: 'collection.session',
          method: 'action_session_pause',
          ids: [5],
          // ignore: deprecated_member_use
          args: null,
          kwargs: null,
          context: any(named: 'context'),
        ),
      ).thenAnswer((_) async => true);
      when(
        () => client.searchRead(
          model: 'collection.session',
          fields: sessionManager.odooFields,
          domain: any(named: 'domain'),
          limit: 1,
          offset: null,
          order: null,
          cancelToken: null,
        ),
      ).thenAnswer(
        (_) async => [
          {'id': 5, 'name': 'SES/5', 'state': 'opened'},
        ],
      );

      await expectLater(
        repository.pauseCollectionSession(5),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('resume uses the recordset action and confirms opened state', () async {
    await sessionManager.smartUpsert(
      opened.copyWith(state: SessionState.paused),
    );
    when(
      () => client.call(
        model: 'collection.session',
        method: 'action_session_resume',
        ids: [5],
        // ignore: deprecated_member_use
        args: null,
        kwargs: null,
        context: null,
      ),
    ).thenAnswer((_) async => true);
    when(
      () => client.searchRead(
        model: 'collection.session',
        fields: sessionManager.odooFields,
        domain: any(named: 'domain'),
        limit: 1,
        offset: null,
        order: null,
        cancelToken: null,
      ),
    ).thenAnswer(
      (_) async => [
        {'id': 5, 'name': 'SES/5', 'state': 'opened'},
      ],
    );

    final result = await repository.resumeCollectionSession(5);

    expect(result.state, SessionState.opened);
    verify(
      () => client.call(
        model: 'collection.session',
        method: 'action_session_resume',
        ids: [5],
        // ignore: deprecated_member_use
        args: null,
        kwargs: null,
        context: null,
      ),
    ).called(1);
  });

  test('a paused session is recovered as the active user session', () async {
    await sessionManager.smartUpsert(
      const CollectionSession(
        id: 9,
        name: 'SES/9',
        userId: 44,
        state: SessionState.paused,
        isSynced: true,
      ),
    );

    final recovered = await sessionManager.getOpenSession(44);

    expect(recovered?.id, 9);
    expect(recovered?.state, SessionState.paused);
    expect(recovered?.canRegisterTransactions, isFalse);
  });
}
