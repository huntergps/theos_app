import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:theos_pos/core/database/database_helper.dart';
import 'package:theos_pos/features/users/repositories/user_repository.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show AppDatabase, ResUsersCompanion;

import '../../mocks/mock_odoo_client.dart';

class _MockDatabaseHelper extends Mock implements DatabaseHelper {}

void main() {
  late MockOdooClient client;
  late UserRepository repository;
  late AppDatabase appDatabase;

  setUp(() {
    client = MockOdooClient.online();
    appDatabase = AppDatabase(NativeDatabase.memory());
    repository = UserRepository(
      odooClient: client,
      db: _MockDatabaseHelper(),
      appDb: appDatabase,
    );
  });

  tearDown(() async => appDatabase.close());

  test('writes users and partners with their own ids and values', () async {
    when(
      () => client.write(
        model: any(named: 'model'),
        ids: any(named: 'ids'),
        values: any(named: 'values'),
      ),
    ).thenAnswer((_) async => true);

    expect(
      await repository.updateUserAndPartner(
        userId: 10,
        partnerId: 20,
        userValues: {'lang': 'es_EC'},
        partnerValues: {'phone': '099'},
      ),
      isTrue,
    );
    verify(
      () => client.write(
        model: 'res.users',
        ids: [10],
        values: {'lang': 'es_EC'},
      ),
    ).called(1);
    verify(
      () => client.write(
        model: 'res.partner',
        ids: [20],
        values: {'phone': '099'},
      ),
    ).called(1);
  });

  test('returns false when partner write is rejected', () async {
    when(
      () => client.write(
        model: 'res.users',
        ids: [10],
        values: {'lang': 'es_EC'},
      ),
    ).thenAnswer((_) async => true);
    when(
      () => client.write(
        model: 'res.partner',
        ids: [20],
        values: {'phone': '099'},
      ),
    ).thenAnswer((_) async => false);

    expect(
      await repository.updateUserAndPartner(
        userId: 10,
        partnerId: 20,
        userValues: {'lang': 'es_EC'},
        partnerValues: {'phone': '099'},
      ),
      isFalse,
    );
  });

  test('does not call RPC for empty change maps', () async {
    expect(
      await repository.updateUserAndPartner(userId: 10, partnerId: 20),
      isTrue,
    );
    verifyNever(
      () => client.write(
        model: any(named: 'model'),
        ids: any(named: 'ids'),
        values: any(named: 'values'),
      ),
    );
  });

  test(
    'distinguishes an unpublished permission snapshot from no groups',
    () async {
      await appDatabase
          .into(appDatabase.resUsers)
          .insert(
            ResUsersCompanion.insert(
              odooId: 11,
              name: 'Pending Permissions',
              login: 'pending.permissions',
              isCurrentUser: const Value(true),
            ),
          );

      await expectLater(
        repository.getCurrentUserGroups(),
        throwsA(isA<PermissionSnapshotUnavailableException>()),
      );

      await (appDatabase.update(appDatabase.resUsers)
            ..where((user) => user.odooId.equals(11)))
          .write(const ResUsersCompanion(groupIds: Value('')));

      expect(await repository.getCurrentUserGroups(), isEmpty);
    },
  );
}
