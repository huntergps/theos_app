/// Lightweight replacement for RxDart's BehaviorSubject and stream extensions.
///
/// Provides [ValueStream<T>] (a StreamController that remembers its last value)
/// and two extensions: [startWith] and [concatWith], which were the only RxDart
/// operators used in this package.
library;

import 'dart:async';

/// A broadcast [StreamController] that retains the most recent value.
///
/// Drop-in replacement for `BehaviorSubject` from RxDart.
/// - Synchronously exposes [value] / [valueOrNull].
/// - New listeners immediately receive the current value via [stream].
/// - Closing the controller is idempotent.
class ValueStream<T> {
  T _value;
  final StreamController<T> _controller = StreamController<T>.broadcast();
  bool _isClosed = false;

  /// Create a [ValueStream] with an initial seed value.
  ValueStream(T seed) : _value = seed;

  /// The most recent value.
  T get value => _value;

  /// Alias for [value] — matches RxDart's `BehaviorSubject.valueOrNull`.
  T get valueOrNull => _value;

  /// Whether this stream has been closed.
  bool get isClosed => _isClosed;

  /// A broadcast stream that replays the current [value] to each new listener,
  /// then forwards all subsequent [add] calls.
  Stream<T> get stream => _ReplayCurrentStream<T>(_controller.stream, () => _value);

  /// Push a new value. No-op if already closed.
  void add(T value) {
    if (!_isClosed) {
      _value = value;
      _controller.add(value);
    }
  }

  /// Close the underlying controller. Idempotent.
  Future<void> close() {
    if (_isClosed) return Future.value();
    _isClosed = true;
    return _controller.close();
  }
}

/// Internal stream wrapper that emits the current value upon listen,
/// then delegates to the underlying broadcast stream.
class _ReplayCurrentStream<T> extends Stream<T> {
  final Stream<T> _inner;
  final T Function() _currentValue;

  _ReplayCurrentStream(this._inner, this._currentValue);

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final controller = StreamController<T>();

    // Emit current value first (microtask to allow subscription setup)
    scheduleMicrotask(() {
      if (!controller.isClosed) {
        controller.add(_currentValue());
      }
    });

    // Forward all future events
    final sub = _inner.listen(
      (data) {
        if (!controller.isClosed) controller.add(data);
      },
      onError: (Object error, StackTrace stack) {
        if (!controller.isClosed) controller.addError(error, stack);
      },
      onDone: () {
        if (!controller.isClosed) controller.close();
      },
    );

    // When the returned subscription is cancelled, cancel the inner one
    controller.onCancel = () => sub.cancel();

    return controller.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

/// Extension providing `startWith` for standard Dart streams.
///
/// Replaces `package:rxdart`'s `StartWithExtension`.
extension StartWithExtension<T> on Stream<T> {
  /// Prepends [value] before this stream's events.
  Stream<T> startWith(T value) {
    return Stream<T>.multi((controller) {
      controller.add(value);
      listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
    });
  }
}

/// Extension providing `concatWith` for standard Dart streams.
///
/// Replaces `package:rxdart`'s `ConcatWithExtension`.
extension ConcatWithExtension<T> on Stream<T> {
  /// Concatenates this stream with [others], subscribing to each
  /// subsequent stream only after the previous one completes.
  Stream<T> concatWith(Iterable<Stream<T>> others) {
    final streams = [this, ...others];
    return Stream<T>.multi((controller) {
      void listenNext(int index) {
        if (index >= streams.length) {
          controller.close();
          return;
        }
        streams[index].listen(
          controller.add,
          onError: controller.addError,
          onDone: () => listenNext(index + 1),
        );
      }
      listenNext(0);
    });
  }
}
