/// Native Dart 3.x Result type replacing dartz Either.
///
/// A sealed class that represents either a success ([Ok]) or a failure ([Err]).
/// Uses exhaustive pattern matching for compile-time safety.
///
/// ```dart
/// final result = await fetchUser(id);
/// switch (result) {
///   case Ok(:final value):
///     print('User: ${value.name}');
///   case Err(:final error):
///     print('Error: ${error.message}');
/// }
/// ```
library;

import 'failures.dart';

/// Sealed result type: either [Ok] with a value or [Err] with a [Failure].
sealed class Result<T> {
  const Result();

  /// Whether this is a success result.
  bool get isOk => this is Ok<T>;

  /// Whether this is a failure result.
  bool get isErr => this is Err<T>;

  /// Returns the value if [Ok], or throws if [Err].
  T getOrThrow() => switch (this) {
        Ok(:final value) => value,
        Err(:final error) => throw Exception(error.message),
      };

  /// Returns the value if [Ok], or [defaultValue] if [Err].
  T getOrElse(T defaultValue) => switch (this) {
        Ok(:final value) => value,
        Err() => defaultValue,
      };

  /// Returns the value if [Ok], or computes a value from the failure.
  T getOrCompute(T Function(Failure failure) onFailure) => switch (this) {
        Ok(:final value) => value,
        Err(:final error) => onFailure(error),
      };

  /// Maps the success value to a new type.
  Result<R> map<R>(R Function(T value) mapper) => switch (this) {
        Ok(:final value) => Ok(mapper(value)),
        Err(:final error) => Err(error),
      };

  /// Chains another Result-returning operation.
  Future<Result<R>> flatMapAsync<R>(
    Future<Result<R>> Function(T value) mapper,
  ) async =>
      switch (this) {
        Ok(:final value) => await mapper(value),
        Err(:final error) => Err(error),
      };

  /// Chains a synchronous Result-returning operation.
  Result<R> flatMap<R>(Result<R> Function(T value) mapper) => switch (this) {
        Ok(:final value) => mapper(value),
        Err(:final error) => Err(error),
      };

  /// Execute side effect on success, returns self for chaining.
  Result<T> onOk(void Function(T value) action) {
    if (this case Ok(:final value)) action(value);
    return this;
  }

  /// Execute side effect on failure, returns self for chaining.
  Result<T> onErr(void Function(Failure error) action) {
    if (this case Err(:final error)) action(error);
    return this;
  }

  /// Convert to nullable (null on failure).
  T? toNullable() => switch (this) {
        Ok(:final value) => value,
        Err() => null,
      };

  /// Check if this is a specific failure type.
  bool isFailureType<F extends Failure>() => switch (this) {
        Ok() => false,
        Err(:final error) => error is F,
      };

  /// Pattern-matching fold (for migration from dartz Either).
  R fold<R>(R Function(Failure error) onErr, R Function(T value) onOk) =>
      switch (this) {
        Ok(:final value) => onOk(value),
        Err(:final error) => onErr(error),
      };
}

/// Success result containing a value.
final class Ok<T> extends Result<T> {
  final T value;
  const Ok(this.value);

  @override
  String toString() => 'Ok($value)';
}

/// Failure result containing an error.
final class Err<T> extends Result<T> {
  final Failure error;
  const Err(this.error);

  @override
  String toString() => 'Err(${error.message})';
}

/// Helper functions for creating Result values.
class ResultHelper {
  /// Execute an async operation and wrap in Result.
  static Future<Result<T>> tryAsync<T>(
    Future<T> Function() operation, {
    Failure Function(dynamic error, StackTrace stack)? onError,
  }) async {
    try {
      return Ok(await operation());
    } catch (e, stack) {
      if (onError != null) return Err(onError(e, stack));
      return Err(_exceptionToFailure(e));
    }
  }

  /// Execute a sync operation and wrap in Result.
  static Result<T> trySync<T>(
    T Function() operation, {
    Failure Function(dynamic error, StackTrace stack)? onError,
  }) {
    try {
      return Ok(operation());
    } catch (e, stack) {
      if (onError != null) return Err(onError(e, stack));
      return Err(_exceptionToFailure(e));
    }
  }

  static Failure _exceptionToFailure(dynamic e) {
    if (e is Failure) return e;
    return ServerFailure(message: e.toString(), originalError: e);
  }
}

/// Shorthand for ResultHelper.tryAsync.
Future<Result<T>> tryAsyncResult<T>(Future<T> Function() operation) =>
    ResultHelper.tryAsync(operation);

/// Shorthand for ResultHelper.trySync.
Result<T> trySyncResult<T>(T Function() operation) =>
    ResultHelper.trySync(operation);
