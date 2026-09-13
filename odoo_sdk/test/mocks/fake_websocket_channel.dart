/// Shared fake [WebSocketChannel] for WebSocket tests.
///
/// Unlike a real socket, this never touches the network: [sink.add] records
/// every outgoing message in [sentMessages] and [addIncoming] lets a test
/// push a server message into [stream] on demand. Injected via
/// `WebSocketConnectionManager(channelFactory: ...)` so
/// `WebSocketConnectionManager.connect()` and `OdooWebSocketService.connect()`
/// can be exercised end-to-end without a real WebSocket server.
library;

import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

class FakeWebSocketChannel implements WebSocketChannel {
  final StreamController<dynamic> _incoming =
      StreamController<dynamic>.broadcast();

  /// Every message pushed through [sink.add], in order.
  final List<dynamic> sentMessages = [];

  bool _closed = false;
  int? _closeCode;
  String? _closeReason;

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  WebSocketSink get sink => _FakeWebSocketSink(this);

  @override
  int? get closeCode => _closeCode;

  @override
  String? get closeReason => _closeReason;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready => Future.value();

  bool get isClosed => _closed;

  /// Simulates a message arriving from the server.
  void addIncoming(String message) {
    if (!_closed) _incoming.add(message);
  }

  /// Simulates the server closing the connection.
  void simulateClose([int? code, String? reason]) {
    _closeCode = code;
    _closeReason = reason;
    _closed = true;
    _incoming.close();
  }

  void _recordSent(dynamic message) => sentMessages.add(message);

  Future<void> _close([int? code, String? reason]) async {
    _closeCode = code;
    _closeReason = reason;
    _closed = true;
    await _incoming.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWebSocketSink implements WebSocketSink {
  _FakeWebSocketSink(this._channel);
  final FakeWebSocketChannel _channel;

  @override
  void add(dynamic data) => _channel._recordSent(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream stream) async {
    await for (final data in stream) {
      add(data);
    }
  }

  @override
  Future close([int? closeCode, String? closeReason]) =>
      _channel._close(closeCode, closeReason);

  @override
  Future get done => Future.value();
}
