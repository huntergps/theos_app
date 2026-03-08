import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/providers/base_feature_state.dart';
import 'package:theos_pos_core/theos_pos_core.dart' show MailActivity;

part 'activities_state.freezed.dart';

/// Filter options for activities list
enum ActivityFilter {
  all,
  overdue,
  today,
  planned,
}

extension ActivityFilterExtension on ActivityFilter {
  String get label {
    switch (this) {
      case ActivityFilter.all:
        return 'Todas';
      case ActivityFilter.overdue:
        return 'Vencidas';
      case ActivityFilter.today:
        return 'Hoy';
      case ActivityFilter.planned:
        return 'Planificadas';
    }
  }

  /// Convert to Odoo state string for filtering
  String? get odooState {
    switch (this) {
      case ActivityFilter.all:
        return null;
      case ActivityFilter.overdue:
        return 'overdue';
      case ActivityFilter.today:
        return 'today';
      case ActivityFilter.planned:
        return 'planned';
    }
  }
}

/// State for activities screen
///
/// Implements [BaseFeatureState] for standardized loading/error handling.
@freezed
abstract class ActivitiesState with _$ActivitiesState implements BaseFeatureState {
  const factory ActivitiesState({
    @Default([]) List<MailActivity> activities,
    @Default(ActivityFilter.all) ActivityFilter filter,
    @Default('') String searchQuery,
    @Default(false) bool isLoading,
    @Default(false) bool isSaving,
    String? errorMessage,
    DateTime? lastSyncAt,
  }) = _ActivitiesState;

  const ActivitiesState._();

  /// Whether syncing is in progress (alias for isSaving for backwards compat)
  bool get isSyncing => isSaving;

  @override
  bool get hasError => errorMessage != null;

  @override
  bool get isProcessing => isLoading || isSaving;

  /// Get filtered activities based on current filter and search query
  List<MailActivity> get filteredActivities {
    var filtered = List<MailActivity>.from(activities);

    // Apply filter
    if (filter != ActivityFilter.all) {
      filtered = filtered.where((a) {
        switch (filter) {
          case ActivityFilter.overdue:
            return a.isOverdue;
          case ActivityFilter.today:
            return a.isDueToday;
          case ActivityFilter.planned:
            return a.isUpcoming;
          case ActivityFilter.all:
            return true;
        }
      }).toList();
    }

    // Apply search query
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((a) {
        return a.displayTitle.toLowerCase().contains(query) ||
            (a.resName?.toLowerCase().contains(query) ?? false) ||
            (a.note?.toLowerCase().contains(query) ?? false) ||
            (a.userName?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Sort by priority (overdue first, then today, then by date)
    filtered.sort((a, b) {
      // First by priority
      final priorityComparison = a.priority.index.compareTo(b.priority.index);
      if (priorityComparison != 0) return priorityComparison;

      // Then by deadline
      return a.dateDeadline.compareTo(b.dateDeadline);
    });

    return filtered;
  }

  /// Counts by state
  int get overdueCount => activities.where((a) => a.isOverdue).length;
  int get todayCount => activities.where((a) => a.isDueToday).length;
  int get plannedCount => activities.where((a) => a.isUpcoming).length;

  /// Initial state
  factory ActivitiesState.initial() => const ActivitiesState();

  /// Loading state
  factory ActivitiesState.loading() => const ActivitiesState(isLoading: true);
}
