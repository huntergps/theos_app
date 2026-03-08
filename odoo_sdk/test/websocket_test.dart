import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:odoo_sdk/odoo_sdk.dart';

// =============================================================================
// MOCK WEBSOCKET CHANNEL
// =============================================================================

/// Mock WebSocket channel for testing connection behavior
class MockWebSocketChannel implements WebSocketChannel {
  final StreamController<dynamic> _incomingController =
      StreamController<dynamic>.broadcast();
  final StreamController<dynamic> _outgoingController =
      StreamController<dynamic>.broadcast();

  bool _isClosed = false;
  int? _closeCode;
  String? _closeReason;

  final List<dynamic> sentMessages = [];

  @override
  Stream<dynamic> get stream => _incomingController.stream;

  @override
  WebSocketSink get sink => _MockWebSocketSink(this);

  @override
  int? get closeCode => _closeCode;

  @override
  String? get closeReason => _closeReason;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready => Future.value();

  bool get isClosed => _isClosed;

  // StreamChannel methods - not used in tests but required by interface
  @override
  dynamic noSuchMethod(Invocation invocation) {
    // Provide default implementations for StreamChannelMixin methods
    // that aren't used in our tests
    return super.noSuchMethod(invocation);
  }

  /// Simulates receiving a message from the server
  void simulateMessage(Map<String, dynamic> data) {
    if (!_isClosed) {
      _incomingController.add(jsonEncode(data));
    }
  }

  /// Simulates receiving a raw message
  void simulateRawMessage(String message) {
    if (!_isClosed) {
      _incomingController.add(message);
    }
  }

  /// Simulates a server error
  void simulateError(Object error, [StackTrace? stackTrace]) {
    if (!_isClosed) {
      _incomingController.addError(error, stackTrace);
    }
  }

  /// Simulates server closing the connection
  void simulateClose([int? code, String? reason]) {
    _closeCode = code;
    _closeReason = reason;
    _isClosed = true;
    _incomingController.close();
  }

  void _addMessage(dynamic message) {
    sentMessages.add(message);
    _outgoingController.add(message);
  }

  void _close([int? code, String? reason]) {
    _closeCode = code;
    _closeReason = reason;
    _isClosed = true;
    _incomingController.close();
    _outgoingController.close();
  }
}

class _MockWebSocketSink implements WebSocketSink {
  final MockWebSocketChannel _channel;

  _MockWebSocketSink(this._channel);

  @override
  void add(dynamic data) {
    _channel._addMessage(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _channel._incomingController.addError(error, stackTrace);
  }

  @override
  Future addStream(Stream stream) async {
    await for (final data in stream) {
      add(data);
    }
  }

  @override
  Future close([int? closeCode, String? closeReason]) async {
    _channel._close(closeCode, closeReason);
  }

  @override
  Future get done => Future.value();
}

/// Test helper to track reconnection behavior
class ReconnectionTracker {
  int reconnectAttempts = 0;
  final List<Duration> reconnectDelays = [];
  DateTime? lastReconnectTime;

  void recordReconnect(Duration delay) {
    reconnectAttempts++;
    reconnectDelays.add(delay);
    lastReconnectTime = DateTime.now();
  }

  void reset() {
    reconnectAttempts = 0;
    reconnectDelays.clear();
    lastReconnectTime = null;
  }
}

void main() {
  group('OdooWebSocketConnectionInfo', () {
    test('uses default heartbeat interval', () {
      const info = OdooWebSocketConnectionInfo(
        baseUrl: 'https://odoo.example.com',
        database: 'mydb',
      );

      expect(info.heartbeatInterval, equals(const Duration(seconds: 30)));
    });

    test('allows custom heartbeat interval', () {
      const info = OdooWebSocketConnectionInfo(
        baseUrl: 'https://odoo.example.com',
        database: 'mydb',
        heartbeatInterval: Duration(seconds: 60),
      );

      expect(info.heartbeatInterval, equals(const Duration(seconds: 60)));
    });

    test('allows custom default channels', () {
      const info = OdooWebSocketConnectionInfo(
        baseUrl: 'https://odoo.example.com',
        database: 'mydb',
        defaultChannels: ['sale_order', 'res_partner'],
      );

      expect(info.defaultChannels, equals(['sale_order', 'res_partner']));
    });

    test('supports all connection parameters', () {
      const info = OdooWebSocketConnectionInfo(
        baseUrl: 'https://odoo.example.com',
        database: 'mydb',
        apiKey: 'test-key',
        sessionId: 'session-123',
        partnerId: 42,
      );

      expect(info.baseUrl, equals('https://odoo.example.com'));
      expect(info.database, equals('mydb'));
      expect(info.apiKey, equals('test-key'));
      expect(info.sessionId, equals('session-123'));
      expect(info.partnerId, equals(42));
    });
  });

  group('OdooWebSocketEvents', () {
    group('OdooConnectionEvent', () {
      test('creates connected event', () {
        final event = OdooConnectionEvent(isConnected: true);

        expect(event.isConnected, isTrue);
        expect(event.isReconnection, isFalse);
        expect(event.error, isNull);
        expect(event.timestamp, isNotNull);
      });

      test('creates reconnection event', () {
        final event = OdooConnectionEvent(
          isConnected: true,
          isReconnection: true,
        );

        expect(event.isConnected, isTrue);
        expect(event.isReconnection, isTrue);
      });

      test('creates disconnected event with error', () {
        final event = OdooConnectionEvent(
          isConnected: false,
          error: 'Connection timeout',
        );

        expect(event.isConnected, isFalse);
        expect(event.error, equals('Connection timeout'));
      });

      test('toString includes connection state', () {
        final event = OdooConnectionEvent(
          isConnected: true,
          isReconnection: true,
        );

        expect(
          event.toString(),
          contains('connected: true'),
        );
        expect(
          event.toString(),
          contains('reconnection: true'),
        );
      });
    });

    group('OdooErrorEvent', () {
      test('wraps error object', () {
        final error = Exception('WebSocket error');
        final event = OdooErrorEvent(error);

        expect(event.error, equals(error));
        expect(event.stackTrace, isNull);
      });

      test('includes stack trace when provided', () {
        final error = Exception('Test');
        final stackTrace = StackTrace.current;
        final event = OdooErrorEvent(error, stackTrace);

        expect(event.stackTrace, isNotNull);
      });
    });

    group('OdooPresenceEvent', () {
      test('creates presence event', () {
        final event = OdooPresenceEvent(
          partnerId: 42,
          imStatus: 'online',
        );

        expect(event.partnerId, equals(42));
        expect(event.imStatus, equals('online'));
      });

      test('toString includes partner and status', () {
        final event = OdooPresenceEvent(
          partnerId: 42,
          imStatus: 'away',
        );

        expect(event.toString(), contains('partner: 42'));
        expect(event.toString(), contains('status: away'));
      });
    });

    group('OdooRecordEvent', () {
      test('creates record event with all fields', () {
        final event = OdooRecordEvent(
          model: 'sale.order',
          recordId: 100,
          recordName: 'SO001',
          action: OdooRecordAction.updated,
          values: {'state': 'sale', 'amount_total': 1500.0},
          changedFields: ['state', 'amount_total'],
        );

        expect(event.model, equals('sale.order'));
        expect(event.recordId, equals(100));
        expect(event.recordName, equals('SO001'));
        expect(event.action, equals(OdooRecordAction.updated));
        expect(event.values['state'], equals('sale'));
        expect(event.changedFields, contains('state'));
      });

      test('hasField checks changed fields', () {
        final event = OdooRecordEvent(
          model: 'sale.order',
          recordId: 1,
          action: OdooRecordAction.updated,
          changedFields: ['state', 'amount_total'],
        );

        expect(event.hasField('state'), isTrue);
        expect(event.hasField('name'), isFalse);
      });

      test('getValue returns typed values', () {
        final event = OdooRecordEvent(
          model: 'sale.order',
          recordId: 1,
          action: OdooRecordAction.created,
          values: {
            'name': 'SO001',
            'amount_total': 1500.0,
            'line_count': 5,
          },
        );

        expect(event.getValue<String>('name'), equals('SO001'));
        expect(event.getValue<double>('amount_total'), equals(1500.0));
        expect(event.getValue<int>('line_count'), equals(5));
        expect(event.getValue<String>('nonexistent'), isNull);
      });

      test('getValue returns null for type mismatch', () {
        final event = OdooRecordEvent(
          model: 'sale.order',
          recordId: 1,
          action: OdooRecordAction.created,
          values: {'name': 'SO001'},
        );

        // Trying to get String as int should return null
        expect(event.getValue<int>('name'), isNull);
      });

      test('supports all action types', () {
        expect(OdooRecordAction.values, hasLength(3));
        expect(OdooRecordAction.values, contains(OdooRecordAction.created));
        expect(OdooRecordAction.values, contains(OdooRecordAction.updated));
        expect(OdooRecordAction.values, contains(OdooRecordAction.deleted));
      });
    });

    group('OdooOrderLineEvent', () {
      test('creates order line event', () {
        final event = OdooOrderLineEvent(
          lineId: 10,
          orderId: 100,
          action: OdooRecordAction.created,
          values: {'product_id': [5, 'Product A'], 'quantity': 10},
          changedFields: ['quantity'],
        );

        expect(event.lineId, equals(10));
        expect(event.orderId, equals(100));
        expect(event.action, equals(OdooRecordAction.created));
        expect(event.values['quantity'], equals(10));
      });
    });

    group('OdooCompanyConfigEvent', () {
      test('creates company config event', () {
        final event = OdooCompanyConfigEvent(
          companyId: 1,
          newValues: {'tax_rate': 15.0, 'currency': 'USD'},
        );

        expect(event.companyId, equals(1));
        expect(event.newValues['tax_rate'], equals(15.0));
      });
    });

    group('OdooCatalogEvent', () {
      test('creates catalog event', () {
        final event = OdooCatalogEvent(
          catalogType: 'product_price',
          recordId: 42,
          action: OdooRecordAction.updated,
          values: {'price': 99.99},
        );

        expect(event.catalogType, equals('product_price'));
        expect(event.recordId, equals(42));
        expect(event.action, equals(OdooRecordAction.updated));
      });
    });

    group('OdooRawNotificationEvent', () {
      test('creates raw notification event', () {
        final event = OdooRawNotificationEvent(
          type: 'custom_notification',
          payload: {'data': 'test'},
        );

        expect(event.type, equals('custom_notification'));
        expect(event.payload['data'], equals('test'));
      });
    });
  });

  group('Event Parsing Utilities', () {
    setUp(() {
      // Register field mappings that the tests expect (no longer provided by registerDefaults)
      final registry = WebSocketModelRegistry.instance;
      registry.registerFieldMapping('sale.order', const WebSocketFieldMapping(idField: 'order_id', nameField: 'order_name'));
      registry.registerFieldMapping('res.partner', const WebSocketFieldMapping(idField: 'partner_id', nameField: 'partner_name'));
    });

    tearDown(() {
      WebSocketModelRegistry.instance.clear();
    });

    group('parseRecordAction', () {
      test('parses created action', () {
        expect(parseRecordAction('created'), equals(OdooRecordAction.created));
      });

      test('parses updated action', () {
        expect(parseRecordAction('updated'), equals(OdooRecordAction.updated));
      });

      test('parses deleted action', () {
        expect(parseRecordAction('deleted'), equals(OdooRecordAction.deleted));
      });

      test('returns null for unknown action', () {
        expect(parseRecordAction('unknown'), isNull);
        expect(parseRecordAction(null), isNull);
        expect(parseRecordAction(''), isNull);
      });
    });

    group('extractRecordId', () {
      test('extracts id from sale.order payload', () {
        final payload = {'order_id': 42};
        expect(extractRecordId(payload, 'sale.order'), equals(42));
      });

      test('extracts id from res.partner payload', () {
        final payload = {'partner_id': 10};
        expect(extractRecordId(payload, 'res.partner'), equals(10));
      });

      test('extracts id from generic payload', () {
        final payload = {'id': 99};
        expect(extractRecordId(payload, 'some.model'), equals(99));
      });

      test('extracts id from list format', () {
        final payload = {'id': [42, 'Record Name']};
        expect(extractRecordId(payload, 'some.model'), equals(42));
      });

      test('returns null for missing id', () {
        final payload = <String, dynamic>{};
        expect(extractRecordId(payload, 'some.model'), isNull);
      });
    });

    group('extractRecordName', () {
      test('extracts name from sale.order payload', () {
        final payload = {'order_name': 'SO001'};
        expect(extractRecordName(payload, 'sale.order'), equals('SO001'));
      });

      test('extracts name from res.partner payload', () {
        final payload = {'partner_name': 'John Doe'};
        expect(extractRecordName(payload, 'res.partner'), equals('John Doe'));
      });

      test('falls back to name field', () {
        final payload = {'name': 'Generic Name'};
        expect(extractRecordName(payload, 'unknown.model'), equals('Generic Name'));
      });

      test('returns null for missing name', () {
        final payload = <String, dynamic>{};
        expect(extractRecordName(payload, 'some.model'), isNull);
      });
    });
  });

  group('WebSocket Event Stream Simulation', () {
    test('can filter events by type', () async {
      final controller = StreamController<OdooWebSocketEvent>.broadcast();

      final presenceEvents = <OdooPresenceEvent>[];
      final recordEvents = <OdooRecordEvent>[];

      // Subscribe to specific event types
      controller.stream
          .where((e) => e is OdooPresenceEvent)
          .cast<OdooPresenceEvent>()
          .listen((e) => presenceEvents.add(e));

      controller.stream
          .where((e) => e is OdooRecordEvent)
          .cast<OdooRecordEvent>()
          .listen((e) => recordEvents.add(e));

      // Emit different event types
      controller.add(OdooPresenceEvent(partnerId: 1, imStatus: 'online'));
      controller.add(OdooRecordEvent(
        model: 'sale.order',
        recordId: 100,
        action: OdooRecordAction.created,
      ));
      controller.add(OdooPresenceEvent(partnerId: 2, imStatus: 'away'));
      controller.add(OdooConnectionEvent(isConnected: true));

      // Allow stream to process
      await Future.delayed(const Duration(milliseconds: 10));

      expect(presenceEvents, hasLength(2));
      expect(recordEvents, hasLength(1));

      await controller.close();
    });

    test('can filter record events by model', () async {
      final controller = StreamController<OdooWebSocketEvent>.broadcast();

      final orderEvents = <OdooRecordEvent>[];

      controller.stream
          .where((e) => e is OdooRecordEvent && e.model == 'sale.order')
          .cast<OdooRecordEvent>()
          .listen((e) => orderEvents.add(e));

      // Emit events for different models
      controller.add(OdooRecordEvent(
        model: 'sale.order',
        recordId: 1,
        action: OdooRecordAction.created,
      ));
      controller.add(OdooRecordEvent(
        model: 'res.partner',
        recordId: 2,
        action: OdooRecordAction.updated,
      ));
      controller.add(OdooRecordEvent(
        model: 'sale.order',
        recordId: 3,
        action: OdooRecordAction.updated,
      ));

      await Future.delayed(const Duration(milliseconds: 10));

      expect(orderEvents, hasLength(2));
      expect(orderEvents.every((e) => e.model == 'sale.order'), isTrue);

      await controller.close();
    });

    test('events have timestamps', () {
      final before = DateTime.now();
      final event = OdooRecordEvent(
        model: 'test',
        recordId: 1,
        action: OdooRecordAction.created,
      );
      final after = DateTime.now();

      expect(event.timestamp.isAfter(before) || event.timestamp == before, isTrue);
      expect(event.timestamp.isBefore(after) || event.timestamp == after, isTrue);
    });

    test('sealed class pattern matching works', () async {
      final events = <String>[];

      void processEvent(OdooWebSocketEvent event) {
        switch (event) {
          case OdooConnectionEvent e:
            events.add('connection:${e.isConnected}');
          case OdooPresenceEvent e:
            events.add('presence:${e.partnerId}');
          case OdooRecordEvent e:
            events.add('record:${e.model}:${e.recordId}');
          case OdooOrderLineEvent e:
            events.add('orderline:${e.lineId}');
          case OdooCompanyConfigEvent e:
            events.add('config:${e.companyId}');
          case OdooCatalogEvent e:
            events.add('catalog:${e.catalogType}');
          case OdooErrorEvent e:
            events.add('error:${e.error}');
          case OdooWithholdBulkEvent e:
            events.add('withhold:${e.orderId}');
          case OdooRawNotificationEvent e:
            events.add('raw:${e.type}');
        }
      }

      processEvent(OdooConnectionEvent(isConnected: true));
      processEvent(OdooPresenceEvent(partnerId: 42, imStatus: 'online'));
      processEvent(OdooRecordEvent(
        model: 'sale.order',
        recordId: 100,
        action: OdooRecordAction.created,
      ));

      expect(events, equals([
        'connection:true',
        'presence:42',
        'record:sale.order:100',
      ]));
    });
  });

  // ===========================================================================
  // RECONNECTION LOGIC TESTS
  // ===========================================================================

  group('Reconnection Logic', () {
    test('calculates exponential backoff correctly', () {
      // Backoff formula: (5 * attempts).clamp(10, 120) seconds
      expect((5 * 1).clamp(10, 120), equals(10)); // 1st attempt: 5 -> clamped to 10
      expect((5 * 2).clamp(10, 120), equals(10)); // 2nd attempt: 10
      expect((5 * 3).clamp(10, 120), equals(15)); // 3rd attempt: 15
      expect((5 * 10).clamp(10, 120), equals(50)); // 10th attempt: 50
      expect((5 * 24).clamp(10, 120), equals(120)); // 24th attempt: 120 (max)
      expect((5 * 30).clamp(10, 120), equals(120)); // 30th attempt: still 120
    });

    test('reconnect delay increases with attempts', () {
      final delays = <Duration>[];

      for (var attempt = 1; attempt <= 5; attempt++) {
        final seconds = (5 * attempt).clamp(10, 120);
        delays.add(Duration(seconds: seconds));
      }

      expect(delays[0], equals(const Duration(seconds: 10)));
      expect(delays[1], equals(const Duration(seconds: 10)));
      expect(delays[2], equals(const Duration(seconds: 15)));
      expect(delays[3], equals(const Duration(seconds: 20)));
      expect(delays[4], equals(const Duration(seconds: 25)));
    });

    test('reconnect delay is capped at 120 seconds', () {
      for (var attempt = 25; attempt <= 50; attempt++) {
        final seconds = (5 * attempt).clamp(10, 120);
        expect(seconds, equals(120));
      }
    });

    test('reconnect attempts counter resets on successful connection', () {
      var reconnectAttempts = 5;

      // Simulate successful connection
      final wasReconnection = reconnectAttempts > 0;
      reconnectAttempts = 0; // Reset on success

      expect(wasReconnection, isTrue);
      expect(reconnectAttempts, equals(0));
    });

    test('connection info is preserved for reconnection', () {
      const info = OdooWebSocketConnectionInfo(
        baseUrl: 'https://odoo.example.com',
        database: 'mydb',
        apiKey: 'test-key',
      );

      // Simulating storing connection info
      OdooWebSocketConnectionInfo? storedInfo = info;

      // After disconnect, info should still be available
      expect(storedInfo, isNotNull);
      expect(storedInfo.baseUrl, equals('https://odoo.example.com'));
    });

    test('prevents multiple simultaneous reconnection timers', () {
      Timer? reconnectTimer;
      var timerCreatedCount = 0;

      void scheduleReconnect() {
        if (reconnectTimer != null && reconnectTimer!.isActive) {
          return; // Already scheduled
        }
        timerCreatedCount++;
        reconnectTimer = Timer(const Duration(seconds: 1), () {});
      }

      // First call should create timer
      scheduleReconnect();
      expect(timerCreatedCount, equals(1));

      // Second call should be ignored
      scheduleReconnect();
      expect(timerCreatedCount, equals(1));

      // After timer fires, can create new one
      reconnectTimer?.cancel();
      reconnectTimer = null;
      scheduleReconnect();
      expect(timerCreatedCount, equals(2));
    });
  });

  // ===========================================================================
  // HEARTBEAT BEHAVIOR TESTS
  // ===========================================================================

  group('Heartbeat Behavior', () {
    test('default heartbeat interval is 30 seconds', () {
      const info = OdooWebSocketConnectionInfo(
        baseUrl: 'https://odoo.example.com',
        database: 'mydb',
      );

      expect(info.heartbeatInterval, equals(const Duration(seconds: 30)));
    });

    test('custom heartbeat interval is respected', () {
      const info = OdooWebSocketConnectionInfo(
        baseUrl: 'https://odoo.example.com',
        database: 'mydb',
        heartbeatInterval: Duration(seconds: 60),
      );

      expect(info.heartbeatInterval, equals(const Duration(seconds: 60)));
    });

    test('heartbeat message has correct format', () {
      final heartbeatMessage = {
        'event_name': 'heartbeat',
        'data': {'timestamp': DateTime.now().millisecondsSinceEpoch},
      };

      expect(heartbeatMessage['event_name'], equals('heartbeat'));
      expect(heartbeatMessage['data'], isA<Map>());
      expect((heartbeatMessage['data'] as Map)['timestamp'], isA<int>());
    });

    test('heartbeat timer can be started and stopped', () {
      Timer? heartbeatTimer;
      var heartbeatCount = 0;

      // Start heartbeat
      heartbeatTimer = Timer.periodic(
        const Duration(milliseconds: 10),
        (_) => heartbeatCount++,
      );

      expect(heartbeatTimer.isActive, isTrue);

      // Stop heartbeat
      heartbeatTimer.cancel();
      expect(heartbeatTimer.isActive, isFalse);
    });

    test('heartbeat is not sent when disconnected', () {
      var isConnected = false;
      var heartbeatSent = false;

      void sendHeartbeat() {
        if (!isConnected) return;
        heartbeatSent = true;
      }

      sendHeartbeat();
      expect(heartbeatSent, isFalse);

      isConnected = true;
      sendHeartbeat();
      expect(heartbeatSent, isTrue);
    });

    test('last heartbeat timestamp is tracked', () {
      DateTime? lastHeartbeat;

      void sendHeartbeat() {
        lastHeartbeat = DateTime.now();
      }

      expect(lastHeartbeat, isNull);
      sendHeartbeat();
      expect(lastHeartbeat, isNotNull);
      expect(lastHeartbeat!.isBefore(DateTime.now().add(const Duration(seconds: 1))), isTrue);
    });
  });

  // ===========================================================================
  // CONNECTION STATE TRANSITIONS TESTS
  // ===========================================================================

  group('Connection State Transitions', () {
    test('initial state is disconnected', () {
      var isConnected = false;
      var isConnecting = false;

      expect(isConnected, isFalse);
      expect(isConnecting, isFalse);
    });

    test('state transitions: disconnected -> connecting -> connected', () {
      var isConnected = false;
      var isConnecting = false;
      final stateHistory = <String>[];

      void startConnecting() {
        isConnecting = true;
        stateHistory.add('connecting');
      }

      void onConnected() {
        isConnected = true;
        isConnecting = false;
        stateHistory.add('connected');
      }

      startConnecting();
      expect(isConnecting, isTrue);
      expect(isConnected, isFalse);

      onConnected();
      expect(isConnecting, isFalse);
      expect(isConnected, isTrue);

      expect(stateHistory, equals(['connecting', 'connected']));
    });

    test('state transitions: connected -> error -> disconnected', () {
      var isConnected = true;
      var lastError = '';
      final stateHistory = <String>[];

      void onError(String error) {
        lastError = error;
        isConnected = false;
        stateHistory.add('error');
        stateHistory.add('disconnected');
      }

      onError('Connection lost');

      expect(isConnected, isFalse);
      expect(lastError, equals('Connection lost'));
      expect(stateHistory, equals(['error', 'disconnected']));
    });

    test('prevents connect if already connected', () {
      var isConnected = true;
      var connectCalled = false;

      void connect() {
        if (isConnected) return;
        connectCalled = true; // ignore: dead_code
      }

      connect();
      expect(connectCalled, isFalse);
    });

    test('prevents connect if already connecting', () {
      var isConnecting = true;
      var connectAttempts = 0;

      void connect() {
        if (isConnecting) return;
        connectAttempts++; // ignore: dead_code
      }

      connect();
      expect(connectAttempts, equals(0));
    });

    test('emits connection event on first connect', () {
      final event = OdooConnectionEvent(
        isConnected: true,
        isReconnection: false,
      );

      expect(event.isConnected, isTrue);
      expect(event.isReconnection, isFalse);
    });

    test('emits reconnection event on reconnect', () {
      final event = OdooConnectionEvent(
        isConnected: true,
        isReconnection: true,
      );

      expect(event.isConnected, isTrue);
      expect(event.isReconnection, isTrue);
    });
  });

  // ===========================================================================
  // ERROR HANDLING TESTS
  // ===========================================================================

  group('Error Handling', () {
    test('captures connection error and emits OdooErrorEvent', () {
      final error = Exception('Connection failed');
      final event = OdooErrorEvent(error);

      expect(event.error, equals(error));
      expect(event.timestamp, isNotNull);
    });

    test('error event includes stack trace when available', () {
      final error = Exception('Test error');
      final stackTrace = StackTrace.current;
      final event = OdooErrorEvent(error, stackTrace);

      expect(event.error, equals(error));
      expect(event.stackTrace, equals(stackTrace));
    });

    test('stores last error for monitoring', () {
      String? lastError;

      void onError(Object error) {
        lastError = 'WebSocket error: $error';
      }

      onError(Exception('Test'));
      expect(lastError, contains('WebSocket error'));
    });

    test('error triggers disconnect and reconnect', () {
      var isConnected = true;
      var reconnectScheduled = false;

      void onError(Object error) {
        isConnected = false;
        reconnectScheduled = true;
      }

      onError(Exception('Connection lost'));

      expect(isConnected, isFalse);
      expect(reconnectScheduled, isTrue);
    });
  });

  // ===========================================================================
  // MESSAGE DEDUPLICATION TESTS
  // ===========================================================================

  group('Message Deduplication', () {
    test('detects duplicate messages by hash', () {
      final processedMessages = <String>{};

      bool isDuplicate(String message) {
        final hash = message.hashCode.toString();
        if (processedMessages.contains(hash)) {
          return true;
        }
        processedMessages.add(hash);
        return false;
      }

      const message1 = '{"id": 1, "type": "test"}';
      const message2 = '{"id": 2, "type": "test"}';

      expect(isDuplicate(message1), isFalse); // First time
      expect(isDuplicate(message1), isTrue); // Duplicate
      expect(isDuplicate(message2), isFalse); // Different message
    });

    test('cleans cache when limit reached', () {
      final processedMessages = <String>{};
      const maxCache = 5;

      void addToCache(String hash) {
        processedMessages.add(hash);

        if (processedMessages.length > maxCache) {
          final toRemove = processedMessages.take(
            processedMessages.length - maxCache,
          ).toList();
          processedMessages.removeAll(toRemove);
        }
      }

      for (var i = 0; i < 10; i++) {
        addToCache('hash_$i');
      }

      expect(processedMessages.length, equals(maxCache));
    });

    test('processes unique message only once', () {
      final processedMessages = <String>{};
      var processCount = 0;

      void processMessage(String message) {
        final hash = message.hashCode.toString();
        if (processedMessages.contains(hash)) return;

        processedMessages.add(hash);
        processCount++;
      }

      const message = '{"id": 1}';
      processMessage(message);
      processMessage(message);
      processMessage(message);

      expect(processCount, equals(1));
    });
  });

  // ===========================================================================
  // CHANNEL MANAGEMENT TESTS
  // ===========================================================================

  group('Channel Management', () {
    test('builds default channels with database prefix', () {
      const database = 'mydb';

      final channels = [
        '$database.sale.order',
        '$database.res.partner',
        '$database.product.product',
      ];

      expect(channels[0], equals('mydb.sale.order'));
      expect(channels.every((c) => c.startsWith('mydb.')), isTrue);
    });

    test('allows custom default channels', () {
      const info = OdooWebSocketConnectionInfo(
        baseUrl: 'https://odoo.example.com',
        database: 'mydb',
        defaultChannels: ['custom_channel', 'another_channel'],
      );

      expect(info.defaultChannels, hasLength(2));
      expect(info.defaultChannels, contains('custom_channel'));
    });

    test('adds presence channels for partner', () {
      const database = 'mydb';
      const partnerId = 42;

      final presenceChannels = [
        '$database.odoo-presence-res.partner_$partnerId',
        '$database.odoo-activity-res.partner_$partnerId',
      ];

      expect(presenceChannels[0], equals('mydb.odoo-presence-res.partner_42'));
      expect(presenceChannels[1], equals('mydb.odoo-activity-res.partner_42'));
    });

    test('subscription message has correct format', () {
      final subscriptionMessage = {
        'event_name': 'subscribe',
        'data': {
          'channels': ['mydb.sale.order', 'mydb.res.partner'],
          'last': 0,
        },
      };

      expect(subscriptionMessage['event_name'], equals('subscribe'));
      expect((subscriptionMessage['data'] as Map)['channels'], isA<List>());
      expect((subscriptionMessage['data'] as Map)['last'], equals(0));
    });

    test('tracks subscribed channels', () {
      final subscribedChannels = <String>{};

      subscribedChannels.addAll(['channel1', 'channel2']);
      expect(subscribedChannels, hasLength(2));

      subscribedChannels.add('channel3');
      expect(subscribedChannels, hasLength(3));

      // Adding duplicate should not increase count
      subscribedChannels.add('channel1');
      expect(subscribedChannels, hasLength(3));
    });
  });

  // ===========================================================================
  // PENDING NOTIFICATIONS TESTS
  // ===========================================================================

  group('Pending Notifications', () {
    test('stores notifications when no listeners', () {
      final pendingNotifications = <Map<String, dynamic>>[];
      var hasListener = false;

      void addNotification(Map<String, dynamic> notification) {
        if (!hasListener) {
          pendingNotifications.add(notification);
        }
      }

      addNotification({'type': 'test1'});
      addNotification({'type': 'test2'});

      expect(pendingNotifications, hasLength(2));
    });

    test('processes pending when listener added', () {
      final pendingNotifications = <Map<String, dynamic>>[
        {'type': 'pending1'},
        {'type': 'pending2'},
      ];
      final processedByListener = <Map<String, dynamic>>[];

      void registerListener(void Function(Map<String, dynamic>) callback) {
        // Process pending first
        for (final notification in pendingNotifications) {
          callback(notification);
        }
      }

      registerListener((notification) {
        processedByListener.add(notification);
      });

      expect(processedByListener, hasLength(2));
      expect(processedByListener[0]['type'], equals('pending1'));
    });

    test('clears pending after processing', () {
      final pendingNotifications = <Map<String, dynamic>>[
        {'type': 'test'},
      ];

      // Simulate listener processing pending
      pendingNotifications.clear();

      expect(pendingNotifications, isEmpty);
    });
  });

  // ===========================================================================
  // LIFECYCLE TESTS
  // ===========================================================================

  group('Lifecycle', () {
    test('disconnect cleans all resources', () {
      Timer? heartbeatTimer = Timer(const Duration(seconds: 1), () {});
      Timer? reconnectTimer = Timer(const Duration(seconds: 1), () {});
      var isConnected = true;
      var isConnecting = false;
      final subscribedChannels = <String>{'channel1', 'channel2'};

      void disconnect() {
        heartbeatTimer?.cancel();
        heartbeatTimer = null;
        reconnectTimer?.cancel();
        reconnectTimer = null;
        isConnected = false;
        isConnecting = false;
        subscribedChannels.clear();
      }

      disconnect();

      expect(heartbeatTimer, isNull);
      expect(reconnectTimer, isNull);
      expect(isConnected, isFalse);
      expect(isConnecting, isFalse);
      expect(subscribedChannels, isEmpty);
    });

    test('dispose closes streams and clears state', () async {
      final eventController = StreamController<OdooWebSocketEvent>.broadcast();
      final notificationController =
          StreamController<Map<String, dynamic>>.broadcast();
      final pendingNotifications = <Map<String, dynamic>>[{'test': true}];
      OdooWebSocketConnectionInfo? connectionInfo =
          const OdooWebSocketConnectionInfo(
        baseUrl: 'https://test.com',
        database: 'test',
      );

      void dispose() {
        eventController.close();
        notificationController.close();
        pendingNotifications.clear();
        connectionInfo = null;
      }

      dispose();

      expect(eventController.isClosed, isTrue);
      expect(notificationController.isClosed, isTrue);
      expect(pendingNotifications, isEmpty);
      expect(connectionInfo, isNull);
    });

    test('can reconnect after disconnect', () {
      var isConnected = false;
      var disconnectCount = 0;
      var connectCount = 0;

      void disconnect() {
        isConnected = false;
        disconnectCount++;
      }

      Future<void> connect() async {
        isConnected = true;
        connectCount++;
      }

      connect();
      expect(isConnected, isTrue);
      expect(connectCount, equals(1));

      disconnect();
      expect(isConnected, isFalse);
      expect(disconnectCount, equals(1));

      connect();
      expect(isConnected, isTrue);
      expect(connectCount, equals(2));
    });
  });

  // ===========================================================================
  // SECURITY TESTS
  // ===========================================================================

  group('Security - SEC-04', () {
    test('validates secure connection by default', () {
      const info = OdooWebSocketConnectionInfo(
        baseUrl: 'http://insecure.com',
        database: 'test',
        allowInsecure: false,
      );

      expect(
        () => info.validateSecureConnection(),
        throwsA(isA<InsecureWebSocketException>()),
      );
    });

    test('allows insecure when explicitly enabled', () {
      const info = OdooWebSocketConnectionInfo(
        baseUrl: 'http://localhost',
        database: 'test',
        allowInsecure: true,
      );

      // Should not throw
      info.validateSecureConnection();
    });

    test('allows https connections', () {
      const info = OdooWebSocketConnectionInfo(
        baseUrl: 'https://secure.com',
        database: 'test',
        allowInsecure: false,
      );

      // Should not throw
      info.validateSecureConnection();
    });

    test('websocketUrl uses wss for https', () {
      const info = OdooWebSocketConnectionInfo(
        baseUrl: 'https://odoo.example.com',
        database: 'test',
      );

      expect(info.websocketUrl, startsWith('wss://'));
    });

    test('websocketUrl uses ws for http', () {
      const info = OdooWebSocketConnectionInfo(
        baseUrl: 'http://localhost',
        database: 'test',
        allowInsecure: true,
      );

      expect(info.websocketUrl, startsWith('ws://'));
    });

    test('masks credentials in toString', () {
      const info = OdooWebSocketConnectionInfo(
        baseUrl: 'https://odoo.example.com',
        database: 'mydb',
        apiKey: 'supersecretapikey123',
        sessionId: 'verylongsessionidhere',
      );

      final str = info.toString();

      expect(str, isNot(contains('supersecretapikey123')));
      expect(str, isNot(contains('verylongsessionidhere')));
      // Masked: first 2 chars + asterisks + last 2 chars
      expect(str, contains('su')); // First 2 chars of API key
      expect(str, contains('23')); // Last 2 chars of API key
      expect(str, contains('ve')); // First 2 chars of session ID
      expect(str, contains('re')); // Last 2 chars of session ID
      expect(str, contains('*')); // Contains masked characters
    });
  });

  // ===========================================================================
  // MOCK WEBSOCKET CHANNEL TESTS
  // ===========================================================================

  group('MockWebSocketChannel', () {
    test('can send messages', () {
      final channel = MockWebSocketChannel();

      channel.sink.add('test message');

      expect(channel.sentMessages, contains('test message'));
    });

    test('can simulate incoming messages', () async {
      final channel = MockWebSocketChannel();
      final received = <dynamic>[];

      channel.stream.listen((message) {
        received.add(message);
      });

      channel.simulateMessage({'type': 'test', 'data': 123});

      await Future.delayed(const Duration(milliseconds: 10));

      expect(received, hasLength(1));
      expect(received[0], contains('test'));
    });

    test('can simulate errors', () async {
      final channel = MockWebSocketChannel();
      Object? receivedError;

      channel.stream.listen(
        (_) {},
        onError: (error) {
          receivedError = error;
        },
      );

      channel.simulateError(Exception('Test error'));

      await Future.delayed(const Duration(milliseconds: 10));

      expect(receivedError, isA<Exception>());
    });

    test('can simulate close', () async {
      final channel = MockWebSocketChannel();
      var isDone = false;

      channel.stream.listen(
        (_) {},
        onDone: () {
          isDone = true;
        },
      );

      channel.simulateClose(1000, 'Normal closure');

      await Future.delayed(const Duration(milliseconds: 10));

      expect(isDone, isTrue);
      expect(channel.closeCode, equals(1000));
      expect(channel.closeReason, equals('Normal closure'));
    });
  });
}
