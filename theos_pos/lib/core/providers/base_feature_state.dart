/// Base interface for all feature states
///
/// Defines common fields that all feature states should implement.
/// This ensures consistent loading, error handling, and sync status
/// across all features.
///
/// ## Usage
/// Your freezed state class should implement this interface:
/// ```dart
/// @freezed
/// abstract class MyFeatureState with _$MyFeatureState implements BaseFeatureState {
///   const factory MyFeatureState({
///     @Default(false) bool isLoading,
///     @Default(false) bool isSaving,
///     String? errorMessage,
///     DateTime? lastSyncAt,
///     // Your custom fields...
///   }) = _MyFeatureState;
///
///   const MyFeatureState._();
///
///   @override
///   bool get hasError => errorMessage != null;
///
///   @override
///   bool get isProcessing => isLoading || isSaving;
/// }
/// ```
abstract interface class BaseFeatureState {
  /// Whether data is currently being loaded
  bool get isLoading;

  /// Whether data is currently being saved/synced
  bool get isSaving;

  /// Error message if an operation failed
  String? get errorMessage;

  /// Last sync timestamp (for offline-first tracking)
  DateTime? get lastSyncAt;

  /// Whether there is an error
  bool get hasError;

  /// Whether any operation is in progress
  bool get isProcessing;
}

/// Mixin providing default implementations for BaseFeatureState computed properties
///
/// Use this mixin in your freezed state class to avoid boilerplate:
/// ```dart
/// @freezed
/// abstract class MyState with _$MyState, BaseFeatureStateMixin implements BaseFeatureState {
///   // Your factory constructors...
/// }
/// ```
mixin BaseFeatureStateMixin {
  bool get isLoading;
  bool get isSaving;
  String? get errorMessage;

  bool get hasError => errorMessage != null;
  bool get isProcessing => isLoading || isSaving;
}

/// Extension for working with BaseFeatureState in a type-safe manner
extension BaseFeatureStateX on BaseFeatureState {
  /// Returns true if there are no errors and no operations in progress
  bool get isIdle => !hasError && !isProcessing;

  /// Returns true if data was synced at least once
  bool get hasSynced => lastSyncAt != null;

  /// Returns a human-readable last sync status
  String get lastSyncStatus {
    if (lastSyncAt == null) return 'Nunca sincronizado';
    final diff = DateTime.now().difference(lastSyncAt!);
    if (diff.inMinutes < 1) return 'Justo ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    return 'Hace ${diff.inDays} días';
  }
}
