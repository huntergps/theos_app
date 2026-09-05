import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:odoo_sdk/odoo_sdk.dart' show logger;

import '../../core/database/providers.dart' show activitiesProvider;
import '../../core/database/repositories/repository_providers.dart';
import '../models/notification_counter.dart';

// Re-exported for the existing shell invalidation boundary.
export '../../core/database/providers.dart' show activitiesProvider;

typedef NotificationPollingTimerFactory = Timer Function(
  Duration interval,
  void Function(Timer timer) callback,
);

const defaultNotificationPollingInterval = Duration(minutes: 2);

/// Polling configuration is overridable so tests and platform compositions do
/// not need to wait on wall-clock timers.
final notificationPollingIntervalProvider = Provider<Duration>(
  (_) => defaultNotificationPollingInterval,
);

final notificationPollingTimerFactoryProvider =
    Provider<NotificationPollingTimerFactory>((_) => Timer.periodic);

/// JSON-2 requests are authenticated per call with the active bearer client.
/// No browser cookie or secondary push channel is considered authentication.
final notificationSessionAuthenticatedProvider = Provider<bool>(
  (ref) => ref.watch(odooClientProvider) != null,
);

/// Provider for the counters displayed by the application shell.
final notificationCounterProvider =
    NotifierProvider<NotificationCounterNotifier, NotificationCounter>(
      NotificationCounterNotifier.new,
    );

class NotificationCounterNotifier extends Notifier<NotificationCounter> {
  Timer? _pollTimer;
  Timer? _initializationTimer;
  Future<void>? _fetchInFlight;
  bool _disposed = false;

  @override
  NotificationCounter build() {
    ref.listen(activitiesProvider, (previous, next) {
      next.whenData((activities) {
        if (!_disposed && state.activityCounter != activities.length) {
          state = state.copyWith(activityCounter: activities.length);
        }
      });
    });

    ref.onDispose(() {
      _disposed = true;
      _initializationTimer?.cancel();
      _pollTimer?.cancel();
      _pollTimer = null;
    });

    // Installing the timer is synchronous and side-effect free. Keep only the
    // first remote read out of the first shell frame.
    _startPolling();
    _initializationTimer = Timer(const Duration(milliseconds: 750), () {
      if (_disposed) return;
      unawaited(fetchCounters());
    });
    return const NotificationCounter();
  }

  /// Refreshes counters through the authenticated JSON-2 repository boundary.
  /// Concurrent timer/manual requests join the same operation.
  Future<void> fetchCounters() {
    final current = _fetchInFlight;
    if (current != null) return current;

    late final Future<void> operation;
    operation = _fetchCountersAuthenticated().whenComplete(() {
      if (identical(_fetchInFlight, operation)) _fetchInFlight = null;
    });
    _fetchInFlight = operation;
    return operation;
  }

  Future<void> _fetchCountersAuthenticated() async {
    if (_disposed || !ref.read(notificationSessionAuthenticatedProvider)) {
      return;
    }

    try {
      final activityRepo = ref.read(activityRepositoryProvider);
      final results = await Future.wait([
        activityRepo.getNotificationCounters(),
        activityRepo.getActivityCounters(),
      ]);
      if (_disposed) return;

      final messagingData = results[0];
      final activityData = results[1];
      if (messagingData == null && activityData == null) return;

      final newState = messagingData == null
          ? state.copyWith(
              activityCounter:
                  activityData?['activityCounter'] as int? ??
                  state.activityCounter,
            )
          : NotificationCounter.fromOdoo({
              ...messagingData,
              'activityCounter':
                  activityData?['activityCounter'] ?? state.activityCounter,
            });
      state = newState;
      logger.d(
        '[NotificationProvider] Counters updated: '
        'inbox=${newState.inboxCounter}, '
        'activities=${newState.activityCounter}',
      );
    } catch (error) {
      logger.w('[NotificationProvider] Counter polling failed: $error');
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    final interval = ref.read(notificationPollingIntervalProvider);
    if (interval <= Duration.zero) {
      throw StateError('Notification polling interval must be positive');
    }
    _pollTimer = ref.read(notificationPollingTimerFactoryProvider)(
      interval,
      (_) => unawaited(fetchCounters()),
    );
  }
}
