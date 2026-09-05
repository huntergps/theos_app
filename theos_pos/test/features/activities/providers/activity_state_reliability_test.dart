import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart' show ServerFailure;
import 'package:theos_pos/core/database/repositories/repository_providers.dart';
import 'package:theos_pos/features/activities/providers/activities_notifier.dart';
import 'package:theos_pos/features/activities/repositories/activity_repository.dart';
import 'package:theos_pos/shared/providers/notification_provider.dart';
import 'package:theos_pos_core/theos_pos_core.dart' show MailActivity;

class _MockActivityRepository extends Mock implements ActivityRepository {}

MailActivity _activity(int id) {
  return MailActivity(
    id: id,
    resId: 1000 + id,
    resModel: 'sale.order',
    summary: 'Actividad $id',
    userId: 7,
    dateDeadline: DateTime(2026, 8, 26),
    state: 'today',
  );
}

void main() {
  test(
    'failed sync preserves activities and does not advance lastSyncAt',
    () async {
      final repository = _MockActivityRepository();
      var callCount = 0;
      when(() => repository.syncAndGet(7)).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) return Right([_activity(1)]);
        return const Left(
          ServerFailure(message: 'No se pudo sincronizar las actividades'),
        );
      });

      final container = ProviderContainer(
        overrides: [activityRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(activitiesNotifierProvider.notifier);

      await notifier.syncActivities(7);
      final successfulState = container.read(activitiesNotifierProvider);
      expect(successfulState.activities.map((item) => item.id), [1]);
      expect(successfulState.lastSyncAt, isNotNull);

      await notifier.syncActivities(7);
      final failedState = container.read(activitiesNotifierProvider);
      expect(failedState.activities.map((item) => item.id), [1]);
      expect(failedState.lastSyncAt, successfulState.lastSyncAt);
      expect(failedState.errorMessage, isNotNull);
    },
  );

  test(
    'activity counter publishes even when messaging data is unavailable',
    () async {
      final repository = _MockActivityRepository();
      when(repository.getNotificationCounters).thenAnswer((_) async => null);
      when(repository.getActivityCounters).thenAnswer(
        (_) async => {
          'activityCounter': 4,
          'overdueCount': 1,
          'todayCount': 2,
          'plannedCount': 1,
        },
      );

      final container = ProviderContainer(
        overrides: [
          activityRepositoryProvider.overrideWithValue(repository),
          notificationSessionAuthenticatedProvider.overrideWithValue(true),
          activitiesProvider.overrideWith(
            (ref) => const Stream<List<MailActivity>>.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(notificationCounterProvider, (_, _) {});

      await container
          .read(notificationCounterProvider.notifier)
          .fetchCounters();

      final counter = container.read(notificationCounterProvider);
      expect(counter.activityCounter, 4);
      expect(counter.inboxCounter, 0);
      expect(counter.starredCounter, 0);
      expect(counter.channelsUnreadCounter, 0);
    },
  );

  test('complete keeps notifier state until remote confirmation', () async {
    final repository = _MockActivityRepository();
    final confirmation = Completer<Either<ServerFailure, bool>>();
    when(() => repository.getActivities())
        .thenAnswer((_) async => Right([_activity(2)]));
    when(() => repository.completeActivity(2))
        .thenAnswer((_) => confirmation.future);

    final container = ProviderContainer(
      overrides: [activityRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(activitiesNotifierProvider.notifier);
    await notifier.loadActivities();

    final pendingAction = notifier.completeActivity(2);
    await Future<void>.delayed(Duration.zero);
    expect(
      container
          .read(activitiesNotifierProvider)
          .activities
          .map((item) => item.id),
      [2],
    );

    confirmation.complete(const Right(true));
    expect(await pendingAction, isTrue);
    expect(container.read(activitiesNotifierProvider).activities, isEmpty);
  });

  test('cancel failure remains visible and preserves notifier state', () async {
    final repository = _MockActivityRepository();
    when(() => repository.getActivities())
        .thenAnswer((_) async => Right([_activity(3)]));
    when(() => repository.cancelActivity(3)).thenAnswer(
      (_) async =>
          const Left(ServerFailure(message: 'Odoo rechazo la cancelacion')),
    );

    final container = ProviderContainer(
      overrides: [activityRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(activitiesNotifierProvider.notifier);
    await notifier.loadActivities();

    expect(await notifier.cancelActivity(3), isFalse);
    final failedState = container.read(activitiesNotifierProvider);
    expect(failedState.activities.map((item) => item.id), [3]);
    expect(failedState.errorMessage, 'Odoo rechazo la cancelacion');
  });
}
