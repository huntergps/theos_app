import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:theos_pos/core/database/repositories/repository_providers.dart';
import 'package:theos_pos/features/activities/repositories/activity_repository.dart';
import 'package:theos_pos/shared/providers/notification_provider.dart';
import 'package:theos_pos_core/theos_pos_core.dart' show MailActivity;

class _MockActivityRepository extends Mock implements ActivityRepository {}

class _ControlledTimer implements Timer {
  _ControlledTimer(this._callback);

  final void Function(Timer timer) _callback;
  bool _isActive = true;
  int _tick = 0;

  void fire() {
    if (!_isActive) return;
    _tick++;
    _callback(this);
  }

  @override
  bool get isActive => _isActive;

  @override
  int get tick => _tick;

  @override
  void cancel() => _isActive = false;
}

void main() {
  late _MockActivityRepository repository;
  late _ControlledTimer pollingTimer;
  late Duration installedInterval;

  setUp(() {
    repository = _MockActivityRepository();
    when(repository.getNotificationCounters).thenAnswer((_) async => null);
    when(repository.getActivityCounters).thenAnswer(
      (_) async => {
        'activityCounter': 3,
        'overdueCount': 0,
        'todayCount': 2,
        'plannedCount': 1,
      },
    );
  });

  ProviderContainer createContainer({required bool authenticated}) {
    return ProviderContainer(
      overrides: [
        activityRepositoryProvider.overrideWithValue(repository),
        notificationSessionAuthenticatedProvider.overrideWithValue(
          authenticated,
        ),
        notificationPollingIntervalProvider.overrideWithValue(
          const Duration(seconds: 37),
        ),
        notificationPollingTimerFactoryProvider.overrideWithValue((
          interval,
          callback,
        ) {
          installedInterval = interval;
          pollingTimer = _ControlledTimer(callback);
          return pollingTimer;
        }),
        activitiesProvider.overrideWith(
          (ref) => const Stream<List<MailActivity>>.empty(),
        ),
      ],
    );
  }

  test('uses a two-minute production polling interval', () {
    expect(defaultNotificationPollingInterval, const Duration(minutes: 2));
  });

  test(
    'publishes the local activity count reactively without network',
    () async {
      final activities = StreamController<List<MailActivity>>();
      addTearDown(activities.close);
      final container = ProviderContainer(
        overrides: [
          activityRepositoryProvider.overrideWithValue(repository),
          notificationSessionAuthenticatedProvider.overrideWithValue(false),
          notificationPollingTimerFactoryProvider.overrideWithValue((
            interval,
            callback,
          ) {
            pollingTimer = _ControlledTimer(callback);
            return pollingTimer;
          }),
          activitiesProvider.overrideWith((ref) => activities.stream),
        ],
      );
      addTearDown(container.dispose);
      container.listen(notificationCounterProvider, (_, _) {});

      activities.add([
        MailActivity(
          id: 1,
          resId: 10,
          resModel: 'sale.order',
          summary: 'Seguimiento',
          userId: 7,
          dateDeadline: DateTime(2026, 8, 26),
          state: 'today',
        ),
        MailActivity(
          id: 2,
          resId: 11,
          resModel: 'sale.order',
          summary: 'Cobro',
          userId: 7,
          dateDeadline: DateTime(2026, 8, 27),
          state: 'planned',
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(notificationCounterProvider).activityCounter, 2);
      verifyNever(repository.getNotificationCounters);
      verifyNever(repository.getActivityCounters);
    },
  );

  test(
    'uses the injected interval and polls through authenticated JSON-2',
    () async {
      final container = createContainer(authenticated: true);
      addTearDown(container.dispose);
      container.listen(notificationCounterProvider, (_, _) {});

      expect(installedInterval, const Duration(seconds: 37));
      pollingTimer.fire();
      await container
          .read(notificationCounterProvider.notifier)
          .fetchCounters();

      verify(repository.getNotificationCounters).called(1);
      verify(repository.getActivityCounters).called(1);
      expect(container.read(notificationCounterProvider).activityCounter, 3);
    },
  );

  test(
    'does not poll repositories without a bearer-authenticated session',
    () async {
      final container = createContainer(authenticated: false);
      addTearDown(container.dispose);
      container.listen(notificationCounterProvider, (_, _) {});

      pollingTimer.fire();
      await container
          .read(notificationCounterProvider.notifier)
          .fetchCounters();

      verifyNever(repository.getNotificationCounters);
      verifyNever(repository.getActivityCounters);
    },
  );

  test('cancels polling when the provider container is disposed', () {
    final container = createContainer(authenticated: true);
    container.listen(notificationCounterProvider, (_, _) {});

    expect(pollingTimer.isActive, isTrue);
    container.dispose();

    expect(pollingTimer.isActive, isFalse);
  });
}
