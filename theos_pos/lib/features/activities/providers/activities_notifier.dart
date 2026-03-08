import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/repositories/repository_providers.dart';
import '../../../core/providers/base_notifier.dart';
import '../repositories/activity_repository.dart';
import 'activities_state.dart';

/// Provider for ActivitiesNotifier
final activitiesNotifierProvider =
    NotifierProvider<ActivitiesNotifier, ActivitiesState>(() => ActivitiesNotifier());

/// Notifier for managing activities state
///
/// Uses [BaseNotifierMixin] — incompatible with @riverpod due to `on Notifier<S>` constraint.
class ActivitiesNotifier extends Notifier<ActivitiesState>
    with BaseNotifierMixin<ActivitiesState> {
  late ActivityRepository _repository;

  @override
  String get logTag => '[ActivitiesNotifier]';

  @override
  ActivitiesState copyWithLoading(bool loading) =>
      state.copyWith(isLoading: loading);

  @override
  ActivitiesState copyWithError(String? error) =>
      state.copyWith(errorMessage: error);

  @override
  ActivitiesState build() {
    _repository = ref.watch(activityRepositoryProvider);
    return ActivitiesState.initial();
  }

  /// Load activities from local cache
  Future<void> loadActivities() async {
    await executeEither(
      action: () => _repository.getActivities(),
      onSuccess: (activities) {
        state = state.copyWith(activities: activities);
      },
    );
  }

  /// Sync activities from server
  Future<void> syncActivities(int userId) async {
    state = state.copyWith(isSaving: true);
    clearError();

    await executeEither(
      action: () => _repository.syncAndGet(userId),
      onSuccess: (activities) {
        state = state.copyWith(
          isSaving: false,
          activities: activities,
          lastSyncAt: DateTime.now(),
        );
      },
      onFailure: (failure) {
        state = state.copyWith(isSaving: false, errorMessage: failure.message);
      },
      showLoading: false, // We use isSaving instead
    );
  }

  /// Set filter
  void setFilter(ActivityFilter filter) {
    state = state.copyWith(filter: filter);
  }

  /// Set search query
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Clear search
  void clearSearch() {
    state = state.copyWith(searchQuery: '');
  }

  /// Reschedule activity to today
  Future<bool> rescheduleToToday(int activityId) async {
    final result = await _repository.rescheduleToToday(activityId);
    return result.fold(
      (failure) {
        state = state.copyWith(errorMessage: failure.message);
        return false;
      },
      (success) {
        // Reload activities to get updated data
        loadActivities();
        return success;
      },
    );
  }

  /// Reschedule activity to tomorrow
  Future<bool> rescheduleToTomorrow(int activityId) async {
    final result = await _repository.rescheduleToTomorrow(activityId);
    return result.fold(
      (failure) {
        state = state.copyWith(errorMessage: failure.message);
        return false;
      },
      (success) {
        loadActivities();
        return success;
      },
    );
  }

  /// Reschedule activity to next week
  Future<bool> rescheduleToNextWeek(int activityId) async {
    final result = await _repository.rescheduleToNextWeek(activityId);
    return result.fold(
      (failure) {
        state = state.copyWith(errorMessage: failure.message);
        return false;
      },
      (success) {
        loadActivities();
        return success;
      },
    );
  }

  /// Complete activity (mark as done)
  Future<bool> completeActivity(int activityId) async {
    final currentActivities = state.activities;

    return executeOptimistic(
      optimisticUpdate: () {
        state = state.copyWith(
          activities: currentActivities.where((a) => a.id != activityId).toList(),
        );
      },
      action: () => _repository.completeActivity(activityId),
      rollback: () {
        state = state.copyWith(activities: currentActivities);
      },
    );
  }

  /// Cancel activity
  Future<bool> cancelActivity(int activityId) async {
    final currentActivities = state.activities;

    return executeOptimistic(
      optimisticUpdate: () {
        state = state.copyWith(
          activities: currentActivities.where((a) => a.id != activityId).toList(),
        );
      },
      action: () => _repository.cancelActivity(activityId),
      rollback: () {
        state = state.copyWith(activities: currentActivities);
      },
    );
  }
}
