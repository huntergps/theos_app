import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/utils/error_utils.dart';
import '../errors/errors.dart';
import '../services/logger_service.dart';
import 'base_feature_state.dart';

/// Mixin providing common notifier functionality for feature notifiers
///
/// Reduces boilerplate for:
/// - Loading state management
/// - Error handling with Either pattern
/// - Async operation execution
/// - Logging
///
/// ## Usage
/// ```dart
/// class MyNotifier extends Notifier<MyState> with BaseNotifierMixin<MyState> {
///   @override
///   String get logTag => '[MyNotifier]';
///
///   @override
///   MyState copyWithLoading(bool loading) => state.copyWith(isLoading: loading);
///
///   @override
///   MyState copyWithError(String? error) => state.copyWith(errorMessage: error);
///
///   Future<void> loadData() async {
///     await executeAsync(
///       action: () => repository.getData(),
///       onSuccess: (data) {
///         state = state.copyWith(data: data);
///       },
///     );
///   }
/// }
/// ```
mixin BaseNotifierMixin<S extends BaseFeatureState> on Notifier<S> {
  /// Tag for logging - override in subclasses
  String get logTag => '[$runtimeType]';

  /// Create a copy of state with updated loading flag
  /// Must be implemented by subclass since freezed copyWith is generated
  S copyWithLoading(bool loading);

  /// Create a copy of state with updated error message
  /// Must be implemented by subclass since freezed copyWith is generated
  S copyWithError(String? error);

  /// Set loading state
  void setLoading(bool loading) {
    state = copyWithLoading(loading);
  }

  /// Set error message
  void setError(String? error) {
    state = copyWithError(error);
  }

  /// Clear error message
  void clearError() => setError(null);

  /// Log debug message
  void logDebug(String message) => logger.d(logTag, message);

  /// Log info message
  void logInfo(String message) => logger.i(logTag, message);

  /// Log warning message
  void logWarning(String message) => logger.w(logTag, message);

  /// Log error message
  void logError(String message, [dynamic error]) => logger.e(logTag, message, error);

  /// Execute an async operation with automatic loading/error handling
  ///
  /// [action] - The async operation to execute
  /// [onSuccess] - Called with the result on success
  /// [onError] - Optional custom error handler
  /// [showLoading] - Whether to set loading state (default: true)
  Future<T?> executeAsync<T>({
    required Future<T> Function() action,
    required void Function(T result) onSuccess,
    void Function(dynamic error)? onError,
    bool showLoading = true,
  }) async {
    if (showLoading) setLoading(true);
    clearError();

    try {
      final result = await action();
      if (showLoading) setLoading(false);
      onSuccess(result);
      return result;
    } catch (e) {
      if (showLoading) setLoading(false);
      logError('Operation failed', e);
      if (onError != null) {
        onError(e);
      } else {
        setError(friendlyErrorMessage(e));
      }
      return null;
    }
  }

  /// Execute an Either-returning operation with automatic state handling
  ///
  /// [action] - The async operation returning `Either<Failure, T>`
  /// [onSuccess] - Called with the result on success
  /// [onFailure] - Optional custom failure handler
  /// [showLoading] - Whether to set loading state (default: true)
  Future<T?> executeEither<T>({
    required Future<Either<Failure, T>> Function() action,
    required void Function(T result) onSuccess,
    void Function(Failure failure)? onFailure,
    bool showLoading = true,
  }) async {
    if (showLoading) setLoading(true);
    clearError();

    try {
      final result = await action();
      if (showLoading) setLoading(false);

      return result.fold(
        (failure) {
          logError('Operation failed: ${failure.message}');
          if (onFailure != null) {
            onFailure(failure);
          } else {
            setError(failure.message);
          }
          return null;
        },
        (data) {
          onSuccess(data);
          return data;
        },
      );
    } catch (e) {
      if (showLoading) setLoading(false);
      logError('Unexpected error', e);
      setError(friendlyErrorMessage(e));
      return null;
    }
  }

  /// Execute an optimistic update with rollback on failure
  ///
  /// [optimisticUpdate] - Apply changes immediately
  /// [action] - The actual operation
  /// [rollback] - Restore previous state on failure
  /// [onSuccess] - Called on success
  Future<bool> executeOptimistic<T>({
    required void Function() optimisticUpdate,
    required Future<Either<Failure, T>> Function() action,
    required void Function() rollback,
    void Function(T result)? onSuccess,
  }) async {
    optimisticUpdate();

    try {
      final result = await action();

      return result.fold(
        (failure) {
          rollback();
          setError(failure.message);
          return false;
        },
        (data) {
          onSuccess?.call(data);
          return true;
        },
      );
    } catch (e) {
      rollback();
      setError(friendlyErrorMessage(e));
      return false;
    }
  }
}

/// Operation result types for methods that need detailed results
///
/// Use when you need to return more than just success/failure,
/// such as when the caller needs to decide navigation or UI feedback.
sealed class OperationResult<T> {
  const OperationResult();

  /// Whether the operation was successful
  bool get isSuccess => this is OperationSuccess<T>;

  /// Whether the operation failed
  bool get isFailure => this is OperationFailure<T>;

  /// Fold the result like Either
  R fold<R>(
    R Function(String message, String? code) onFailure,
    R Function(T? data, String? message) onSuccess,
  );
}

class OperationSuccess<T> extends OperationResult<T> {
  final T? data;
  final String? message;

  const OperationSuccess({this.data, this.message});

  @override
  R fold<R>(
    R Function(String message, String? code) onFailure,
    R Function(T? data, String? message) onSuccess,
  ) => onSuccess(data, message);
}

class OperationFailure<T> extends OperationResult<T> {
  final String message;
  final String? code;

  const OperationFailure({required this.message, this.code});

  @override
  R fold<R>(
    R Function(String message, String? code) onFailure,
    R Function(T? data, String? message) onSuccess,
  ) => onFailure(message, code);
}
