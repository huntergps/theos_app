import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:theos_pos/core/database/repositories/repository_providers.dart';
import 'package:theos_pos/features/sync/repositories/card_cash_sync_repository.dart';
import 'package:theos_pos/features/users/repositories/user_repository.dart';
import 'package:theos_pos/shared/constants/user_groups.dart';
import 'package:theos_pos/shared/providers/user_provider.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

import '../../mocks/mock_odoo_client.dart';

class _MockUserRepository extends Mock implements UserRepository {}

void main() {
  group('atomic permission snapshot', () {
    late AppDatabase database;
    late MockOdooClient client;
    late CardCashSyncRepository repository;
    late Map<String, int> localGroupIds;

    const userA = 41;
    const userB = 42;

    setUp(() async {
      database = AppDatabase(NativeDatabase.memory());
      client = MockOdooClient.online();
      localGroupIds = {
        for (var index = 0; index < kKnownTheosUserGroups.length; index++)
          kKnownTheosUserGroups[index]: 100 + index,
      };

      for (final entry in localGroupIds.entries) {
        await database
            .into(database.resGroups)
            .insert(
              ResGroupsCompanion.insert(
                odooId: entry.value,
                name: entry.key,
                xmlId: Value(entry.key),
              ),
            );
      }

      await database
          .into(database.resUsers)
          .insert(
            ResUsersCompanion.insert(
              odooId: userA,
              name: 'User A',
              login: 'user.a',
              groupIds: Value('${localGroupIds[OdooUserGroup.collectionUser]}'),
            ),
          );
      await database
          .into(database.resUsers)
          .insert(
            ResUsersCompanion.insert(
              odooId: userB,
              name: 'User B',
              login: 'user.b',
              groupIds: Value(
                '${localGroupIds[OdooUserGroup.systemAdministrator]}',
              ),
            ),
          );

      repository = CardCashSyncRepository(appDb: database, odooClient: client);
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'publishes additions and removals only after every group is read',
      () async {
        final observedBeforeCalls = <Set<int>>[];
        final requestedGroups = <String>[];
        final remoteMemberships = {
          OdooUserGroup.internalUser,
          OdooUserGroup.salesUser,
        };

        when(
          () => client.call(
            model: 'res.users',
            method: 'has_group',
            ids: any(named: 'ids'),
            kwargs: any(named: 'kwargs'),
          ),
        ).thenAnswer((invocation) async {
          expect(invocation.namedArguments[#ids], [userA]);
          final kwargs =
              invocation.namedArguments[#kwargs]! as Map<String, dynamic>;
          final group = kwargs['group_ext_id']! as String;
          requestedGroups.add(group);
          observedBeforeCalls.add(await _storedGroupIds(database, userA));
          return remoteMemberships.contains(group);
        });

        final count = await repository.syncUserGroups(userA);

        expect(count, remoteMemberships.length);
        expect(requestedGroups, kKnownTheosUserGroups);
        expect(
          observedBeforeCalls,
          everyElement({localGroupIds[OdooUserGroup.collectionUser]}),
        );
        expect(
          await _storedGroupIds(database, userA),
          remoteMemberships.map((group) => localGroupIds[group]!).toSet(),
        );
        expect(await _storedGroupIds(database, userB), {
          localGroupIds[OdooUserGroup.systemAdministrator],
        });
      },
    );

    test('an empty remote snapshot revokes all previous permissions', () async {
      _stubMemberships(client, const {});

      final count = await repository.syncUserGroups(userA);

      expect(count, 0);
      expect(await _storedGroupIds(database, userA), isEmpty);
    });

    test(
      'resolves missing groups from the user identity, never ir.model.data',
      () async {
        final missingXmlId = OdooUserGroup.salesUser;
        await (database.delete(
          database.resGroups,
        )..where((table) => table.xmlId.equals(missingXmlId))).go();
        when(
          () => client.call(
            model: 'res.users',
            method: 'has_group',
            ids: any(named: 'ids'),
            kwargs: any(named: 'kwargs'),
          ),
        ).thenAnswer((invocation) async {
          final kwargs =
              invocation.namedArguments[#kwargs]! as Map<String, dynamic>;
          return kwargs['group_ext_id'] == missingXmlId;
        });
        when(
          () => client.read(
            model: 'res.users',
            ids: any(named: 'ids'),
            fields: any(named: 'fields'),
          ),
        ).thenAnswer(
          (_) async => [
            {
              'id': userA,
              'all_group_ids': [999],
            },
          ],
        );
        when(
          () => client.call(
            model: 'res.groups',
            method: 'get_external_id',
            ids: any(named: 'ids'),
            kwargs: any(named: 'kwargs'),
          ),
        ).thenAnswer((_) async => {'999': missingXmlId});
        when(
          () => client.searchRead(
            model: 'res.groups',
            domain: any(named: 'domain'),
            fields: any(named: 'fields'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
          ),
        ).thenAnswer(
          (_) async => [
            {'id': 999, 'name': 'Sales', 'full_name': 'Sales', 'share': false},
          ],
        );
        when(
          () => client.searchRead(
            model: 'ir.model.data',
            domain: any(named: 'domain'),
            fields: any(named: 'fields'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
          ),
        ).thenThrow(StateError('ir.model.data is forbidden for normal users'));

        expect(await repository.syncUserGroups(userA), 1);
        expect(await _storedGroupIds(database, userA), {999});
        verifyNever(
          () => client.searchRead(
            model: 'ir.model.data',
            domain: any(named: 'domain'),
            fields: any(named: 'fields'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
          ),
        );
      },
    );

    test(
      'native identity failure preserves the previous permission snapshot',
      () async {
        final missingXmlId = OdooUserGroup.salesUser;
        await (database.delete(
          database.resGroups,
        )..where((table) => table.xmlId.equals(missingXmlId))).go();
        _stubMemberships(client, {missingXmlId});
        when(
          () => client.read(
            model: 'res.users',
            ids: any(named: 'ids'),
            fields: any(named: 'fields'),
          ),
        ).thenThrow(
          const OdooConnectionException('native identity unavailable'),
        );

        await expectLater(
          repository.syncUserGroups(userA),
          throwsA(isA<Exception>()),
        );
        expect(await _storedGroupIds(database, userA), {
          localGroupIds[OdooUserGroup.collectionUser],
        });
      },
    );

    test('rejects a native identity for another user', () async {
      final missingXmlId = OdooUserGroup.salesUser;
      await (database.delete(
        database.resGroups,
      )..where((table) => table.xmlId.equals(missingXmlId))).go();
      _stubMemberships(client, {missingXmlId});
      when(
        () => client.read(
          model: 'res.users',
          ids: any(named: 'ids'),
          fields: any(named: 'fields'),
        ),
      ).thenAnswer(
        (_) async => [
          {
            'id': userB,
            'all_group_ids': [999],
          },
        ],
      );

      await expectLater(
        repository.syncUserGroups(userA),
        throwsA(isA<PermissionSnapshotSyncException>()),
      );
      expect(await _storedGroupIds(database, userA), {
        localGroupIds[OdooUserGroup.collectionUser],
      });
    });

    test('rejects invalid native effective group IDs', () async {
      final missingXmlId = OdooUserGroup.salesUser;
      await (database.delete(
        database.resGroups,
      )..where((table) => table.xmlId.equals(missingXmlId))).go();
      _stubMemberships(client, {missingXmlId});
      when(
        () => client.read(
          model: 'res.users',
          ids: any(named: 'ids'),
          fields: any(named: 'fields'),
        ),
      ).thenAnswer(
        (_) async => [
          {
            'id': userA,
            'all_group_ids': [0],
          },
        ],
      );

      await expectLater(
        repository.syncUserGroups(userA),
        throwsA(isA<PermissionSnapshotSyncException>()),
      );
      expect(await _storedGroupIds(database, userA), {
        localGroupIds[OdooUserGroup.collectionUser],
      });
    });

    test('publishes every functional authorization membership', () async {
      final functionalMemberships = <String>{
        OdooUserGroup.creditApprover,
        OdooUserGroup.saleConfirm,
        OdooUserGroup.allowDeleteRecords,
        OdooUserGroup.saleDelete,
      };
      _stubMemberships(client, functionalMemberships);

      final count = await repository.syncUserGroups(userA);

      expect(count, functionalMemberships.length);
      expect(
        await _storedGroupIds(database, userA),
        functionalMemberships.map((group) => localGroupIds[group]!).toSet(),
      );
    });

    test(
      'a partial failure publishes neither partial groups nor another user',
      () async {
        final calls = <String>[];
        when(
          () => client.call(
            model: 'res.users',
            method: 'has_group',
            ids: any(named: 'ids'),
            kwargs: any(named: 'kwargs'),
          ),
        ).thenAnswer((invocation) async {
          final kwargs =
              invocation.namedArguments[#kwargs]! as Map<String, dynamic>;
          final group = kwargs['group_ext_id']! as String;
          calls.add(group);
          if (group == OdooUserGroup.accountManager) {
            throw const OdooConnectionException('fixture failure');
          }
          return group == OdooUserGroup.internalUser ||
              group == OdooUserGroup.systemAdministrator;
        });

        await expectLater(
          repository.syncUserGroups(userA),
          throwsA(isA<Exception>()),
        );

        expect(calls, contains(OdooUserGroup.accountManager));
        expect(await _storedGroupIds(database, userA), {
          localGroupIds[OdooUserGroup.collectionUser],
        });
        expect(await _storedGroupIds(database, userB), {
          localGroupIds[OdooUserGroup.systemAdministrator],
        });
      },
    );
  });

  test(
    'UserNotifier ignores an older permission snapshot that finishes last',
    () async {
      final repository = _MockUserRepository();
      final permissionsA = Completer<List<String>>();
      final permissionsB = Completer<List<String>>();
      var userReads = 0;
      var permissionReads = 0;
      const userA = User(id: 41, name: 'User A', login: 'user.a');
      const userB = User(id: 42, name: 'User B', login: 'user.b');

      when(repository.getCurrentUser).thenAnswer((_) async {
        userReads++;
        return userReads == 1 ? userA : userB;
      });
      when(repository.getCurrentUserGroups).thenAnswer((_) {
        permissionReads++;
        return permissionReads == 1 ? permissionsA.future : permissionsB.future;
      });

      final container = ProviderContainer(
        overrides: [userRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(userProvider.notifier);

      final firstLoad = notifier.fetchUser();
      await Future<void>.delayed(Duration.zero);
      final secondLoad = notifier.fetchUser();
      await Future<void>.delayed(Duration.zero);

      permissionsB.complete([OdooUserGroup.collectionUser]);
      await secondLoad;
      expect(container.read(userProvider)?.id, userB.id);

      permissionsA.complete([OdooUserGroup.systemAdministrator]);
      await firstLoad;

      final published = container.read(userProvider);
      expect(published?.id, userB.id);
      expect(published?.permissions, [OdooUserGroup.collectionUser]);
    },
  );

  test(
    'UserNotifier restores startup identity without a remote user read',
    () async {
      final repository = _MockUserRepository();
      const cachedUser = User(id: 41, name: 'Cached User', login: 'cached');
      const permissions = [OdooUserGroup.internalUser, OdooUserGroup.salesUser];

      when(repository.getCachedCurrentUser).thenAnswer((_) async => cachedUser);
      when(repository.getCurrentUserGroups)
          .thenAnswer((_) async => permissions);

      final container = ProviderContainer(
        overrides: [userRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final restored = await container
          .read(userProvider.notifier)
          .restoreCachedUser();

      expect(restored?.id, cachedUser.id);
      expect(restored?.permissions, permissions);
      expect(container.read(userProvider), restored);
      expect(container.read(isOfflineModeProvider), isTrue);
      verify(() => repository.getCachedCurrentUser()).called(1);
      verifyNever(() => repository.getCurrentUser());
    },
  );

  test('empty permission snapshot is ready, not an error', () async {
    final repository = _MockUserRepository();
    const cachedUser = User(id: 43, name: 'No Groups', login: 'no.groups');

    when(repository.getCachedCurrentUser).thenAnswer((_) async => cachedUser);
    when(repository.getCurrentUserGroups).thenAnswer((_) async => const []);

    final container = ProviderContainer(
      overrides: [userRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final restored = await container
        .read(userProvider.notifier)
        .restoreCachedUser();
    final snapshot = container.read(permissionSnapshotProvider);

    expect(restored?.permissions, isEmpty);
    expect(snapshot.phase, PermissionSnapshotPhase.ready);
    expect(snapshot.permissions, isEmpty);
    expect(snapshot.error, isNull);
  });

  test(
    'permission read failure remains distinguishable and fail-closed',
    () async {
      final repository = _MockUserRepository();
      const user = User(
        id: 44,
        name: 'Unreadable Groups',
        login: 'unreadable.groups',
        permissions: [OdooUserGroup.systemAdministrator],
      );
      final failure = StateError('permission fixture failed');

      when(repository.getCurrentUserGroups).thenThrow(failure);

      final container = ProviderContainer(
        overrides: [userRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container.read(userProvider.notifier).setUser(user);
      final published = container.read(userProvider);
      final snapshot = container.read(permissionSnapshotProvider);

      expect(published?.permissions, isEmpty);
      expect(snapshot.phase, PermissionSnapshotPhase.failed);
      expect(snapshot.permissions, isEmpty);
      expect(snapshot.error, same(failure));
    },
  );
}

void _stubMemberships(MockOdooClient client, Set<String> memberships) {
  when(
    () => client.call(
      model: 'res.users',
      method: 'has_group',
      ids: any(named: 'ids'),
      kwargs: any(named: 'kwargs'),
    ),
  ).thenAnswer((invocation) async {
    final kwargs = invocation.namedArguments[#kwargs]! as Map<String, dynamic>;
    return memberships.contains(kwargs['group_ext_id']);
  });
}

Future<Set<int>> _storedGroupIds(AppDatabase database, int userId) async {
  final user = await (database.select(
    database.resUsers,
  )..where((table) => table.odooId.equals(userId))).getSingle();
  final raw = user.groupIds;
  if (raw == null || raw.isEmpty) return {};
  return raw.split(',').map(int.parse).toSet();
}
