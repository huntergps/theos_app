import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart' show NetworkFailure, ServerFailure;
import 'package:theos_pos/features/activities/repositories/activity_repository.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

import '../../../mocks/mock_odoo_client.dart';
import '../../../mocks/mock_offline_queue.dart';

void main() {
  late AppDatabase database;
  late MockOdooClient client;
  late ActivityRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    client = MockOdooClient.online();
    mailActivityManager.initialize(
      client: client,
      db: database,
      queue: MockOfflineQueue.withDefaults(),
    );
    repository = ActivityRepository();
  });

  tearDown(() async {
    await database.close();
  });

  MailActivity activity(int id, {int userId = 7, String state = 'today'}) {
    return MailActivity(
      id: id,
      resId: 1000 + id,
      resModel: 'sale.order',
      resName: 'S$id',
      summary: 'Actividad $id',
      userId: userId,
      dateDeadline: DateTime(2026, 8, 26),
      state: state,
    );
  }

  Map<String, dynamic> remoteActivity(
    int id, {
    int userId = 7,
    String state = 'today',
  }) {
    return {
      'id': id,
      'res_id': 1000 + id,
      'res_model': 'sale.order',
      'res_name': 'S$id',
      'summary': 'Actividad $id',
      'note': false,
      'activity_type_id': false,
      'user_id': [userId, 'Usuario $userId'],
      'date_deadline': '2026-08-26',
      'state': state,
      'icon': false,
      'can_write': true,
      'create_date': false,
      'write_date': false,
    };
  }

  test('action_done sends the activity id as recordset ids', () async {
    await mailActivityManager.upsertLocal(activity(71));
    when(
      () =>
          client.call(model: 'mail.activity', method: 'action_done', ids: [71]),
    ).thenAnswer((_) async => true);

    final result = await repository.completeActivity(71);

    expect(result.isRight(), isTrue);
    expect(await mailActivityManager.readLocal(71), isNull);
    verify(
      () =>
          client.call(model: 'mail.activity', method: 'action_done', ids: [71]),
    ).called(1);
  });

  test('reschedule actions send the activity id as recordset ids', () async {
    when(
      () => client.call(
        model: 'mail.activity',
        method: 'action_reschedule_today',
        ids: [72],
      ),
    ).thenAnswer((_) async => null);
    when(
      () => client.searchRead(
        model: 'mail.activity',
        fields: mailActivityManager.odooFields,
        domain: [
          ['id', '=', 72],
        ],
        limit: 1,
      ),
    ).thenAnswer((_) async => []);

    final result = await repository.rescheduleToToday(72);

    expect(result.isRight(), isTrue);
    verify(
      () => client.call(
        model: 'mail.activity',
        method: 'action_reschedule_today',
        ids: [72],
      ),
    ).called(1);
  });

  test('action_cancel sends the activity id as recordset ids', () async {
    await mailActivityManager.upsertLocal(activity(73));
    when(
      () => client.call(
        model: 'mail.activity',
        method: 'action_cancel',
        ids: [73],
      ),
    ).thenAnswer((_) async => true);

    final result = await repository.cancelActivity(73);
    await pumpEventQueue();

    expect(result.isRight(), isTrue);
    expect(await mailActivityManager.readLocal(73), isNull);
    verify(
      () => client.call(
        model: 'mail.activity',
        method: 'action_cancel',
        ids: [73],
      ),
    ).called(1);
  });

  test(
    'complete fails closed offline and preserves the local activity',
    () async {
      client = MockOdooClient.offline();
      mailActivityManager.initialize(
        client: client,
        db: database,
        queue: MockOfflineQueue.withDefaults(),
      );
      await mailActivityManager.upsertLocal(activity(81));

      final result = await repository.completeActivity(81);

      expect(result.isLeft(), isTrue);
      expect(
        result.fold((failure) => failure, (_) => null),
        isA<NetworkFailure>(),
      );
      expect(await mailActivityManager.readLocal(81), isNotNull);
      verifyNever(
        () => client.call(
          model: any(named: 'model'),
          method: any(named: 'method'),
          ids: any(named: 'ids'),
        ),
      );
    },
  );

  test('complete preserves the local activity when the RPC fails', () async {
    await mailActivityManager.upsertLocal(activity(82));
    when(
      () =>
          client.call(model: 'mail.activity', method: 'action_done', ids: [82]),
    ).thenThrow(StateError('RPC failed'));

    final result = await repository.completeActivity(82);

    expect(result.isLeft(), isTrue);
    expect(
      result.fold((failure) => failure, (_) => null),
      isA<ServerFailure>(),
    );
    expect(await mailActivityManager.readLocal(82), isNotNull);
  });

  test('cancel preserves the local activity on timeout', () async {
    repository = ActivityRepository(
      rpcTimeout: const Duration(milliseconds: 5),
    );
    await mailActivityManager.upsertLocal(activity(83));
    when(
      () => client.call(
        model: 'mail.activity',
        method: 'action_cancel',
        ids: [83],
      ),
    ).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return true;
    });

    final result = await repository.cancelActivity(83);

    expect(result.isLeft(), isTrue);
    final failure = result.fold((value) => value, (_) => null);
    expect(failure, isA<NetworkFailure>());
    expect(failure?.code, 'TIMEOUT');
    expect(await mailActivityManager.readLocal(83), isNotNull);
  });

  test('complete keeps the activity until Odoo confirms success', () async {
    await mailActivityManager.upsertLocal(activity(84));
    final confirmation = Completer<dynamic>();
    when(
      () =>
          client.call(model: 'mail.activity', method: 'action_done', ids: [84]),
    ).thenAnswer((_) => confirmation.future);

    final pendingResult = repository.completeActivity(84);
    await pumpEventQueue();

    expect(await mailActivityManager.readLocal(84), isNotNull);

    confirmation.complete(true);
    final result = await pendingResult;
    expect(result.isRight(), isTrue);
    expect(await mailActivityManager.readLocal(84), isNull);
  });

  test(
    'sync failure returns Failure and preserves cached activities',
    () async {
      await mailActivityManager.upsertLocal(activity(91));
      when(
        () => client.searchRead(
          model: 'mail.activity',
          fields: mailActivityManager.odooFields,
          domain: [
            ['user_id', '=', 7],
          ],
          order: 'date_deadline asc',
        ),
      ).thenThrow(StateError('RPC failed'));

      final result = await repository.syncAndGet(7);

      expect(result.isLeft(), isTrue);
      expect(
        result.fold((failure) => failure, (_) => null),
        isA<ServerFailure>(),
      );
      expect((await mailActivityManager.searchLocal()).map((item) => item.id), [
        91,
      ]);
    },
  );

  test('sync success atomically replaces the cached activities', () async {
    await mailActivityManager.upsertLocal(activity(92));
    when(
      () => client.searchRead(
        model: 'mail.activity',
        fields: mailActivityManager.odooFields,
        domain: [
          ['user_id', '=', 7],
        ],
        order: 'date_deadline asc',
      ),
    ).thenAnswer((_) async => [remoteActivity(93)]);

    final result = await repository.syncAndGet(7);

    expect(result.isRight(), isTrue);
    expect((await mailActivityManager.searchLocal()).map((item) => item.id), [
      93,
    ]);
  });
}
