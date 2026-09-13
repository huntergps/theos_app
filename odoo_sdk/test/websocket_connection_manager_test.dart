/// Tests for the injectable real-time session on
/// [WebSocketConnectionManager] / [OdooWebSocketService]: the bus no longer
/// accepts a JSON-2 Bearer token (measured against ERP2, Odoo 19.5 closes
/// with 4001), so authentication moves to a `session_id` query parameter
/// fetched from an injectable [RealtimeCredentialProvider].
///
/// Covers, from the task contract (RED first):
///   A. the connect URL carries `session_id` from the provider, and no
///      Authorization header is ever built;
///   B. an expired credential triggers a fresh provider call and an
///      immediate reconnect, without touching the failure-backoff counter;
///   D. `initialLast` seeds the very first `subscribe` message, and a live
///      message advances `lastNotificationIdStream`;
///   E. `disconnect()` leaves no pending timers (heartbeat, reconnection,
///      credential-expiry).
///
/// (Letter C — action read from `payload.action` — lives in
/// websocket_event_parser_test.dart, since it only needs the parser.)
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:test/test.dart';

import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:odoo_sdk/src/websocket/platform/websocket_connect_io.dart';

import 'mocks/fake_websocket_channel.dart';

void main() {
  group('A — session_id in the URL, never Authorization', () {
    test('the connect URL carries session_id from the provider', () async {
      Uri? capturedUri;
      String? capturedBaseUrl;
      final manager = WebSocketConnectionManager(
        channelFactory: (uri, baseUrl, {database}) async {
          capturedUri = uri;
          capturedBaseUrl = baseUrl;
          return FakeWebSocketChannel();
        },
      );

      final info = OdooWebSocketConnectionInfo(
        baseUrl: 'https://odoo.example.com',
        database: 'mydb',
        realtimeCredentialProvider: () async => RealtimeCredential(
          sessionId: 'the-session-id',
          expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        ),
      );

      await manager.connect(
        info,
        onMessage: (_) {},
        onError: (_) {},
        onDone: () {},
        onCredentialExpired: () {},
      );

      expect(capturedUri, isNotNull);
      expect(capturedUri!.path, equals('/websocket'));
      expect(
        capturedUri!.queryParameters['session_id'],
        equals('the-session-id'),
      );
      expect(capturedBaseUrl, equals('https://odoo.example.com'));

      manager.disconnect();
    });

    test('native (io) headers carry Origin, never Authorization', () {
      final headers = buildRealtimeSocketHeaders(
        'https://odoo.example.com',
        database: 'mydb',
      );

      expect(headers['Origin'], equals('https://odoo.example.com'));
      expect(headers.containsKey('Authorization'), isFalse);
      expect(headers['X-Odoo-Database'], equals('mydb'));
    });
  });

  group('B — an expired credential renews itself before any backoff', () {
    test(
      'reconnects and calls the provider again on expiry, without touching reconnectAttempts',
      () {
        fakeAsync((async) {
          var providerCalls = 0;
          Future<RealtimeCredential> provider() async {
            providerCalls++;
            return RealtimeCredential(
              sessionId: 'sid-$providerCalls',
              expiresAt: DateTime.now().add(const Duration(seconds: 5)),
            );
          }

          final connectionManager = WebSocketConnectionManager(
            channelFactory: (uri, baseUrl, {database}) async =>
                FakeWebSocketChannel(),
          );
          final service = OdooWebSocketService(
            connectionManager: connectionManager,
          );

          final info = OdooWebSocketConnectionInfo(
            baseUrl: 'https://odoo.example.com',
            database: 'mydb',
            realtimeCredentialProvider: provider,
            // Keep the heartbeat out of the way of this test's timeline.
            heartbeatInterval: const Duration(minutes: 10),
          );

          service.connect(info);
          async.flushMicrotasks();

          expect(providerCalls, equals(1));
          expect(service.isConnected, isTrue);
          expect(service.reconnectAttempts, equals(0));

          // Past the 5s expiry of the first credential.
          async.elapse(const Duration(seconds: 6));
          async.flushMicrotasks();

          expect(
            providerCalls,
            equals(2),
            reason: 'expiry must trigger a fresh provider call',
          );
          expect(service.isConnected, isTrue);
          expect(
            service.reconnectAttempts,
            equals(0),
            reason:
                'a proactive renewal is not a failure: it must never go '
                'through WebSocketReconnectionManager backoff',
          );

          service.disconnect();
          service.dispose();
        });
      },
    );
  });

  group('D — initialLast seeds the first subscribe, live messages advance it', () {
    test('subscribe carries last:120, then a new id is reported on the stream', () {
      fakeAsync((async) {
        FakeWebSocketChannel? channel;
        final connectionManager = WebSocketConnectionManager(
          channelFactory: (uri, baseUrl, {database}) async {
            channel = FakeWebSocketChannel();
            return channel!;
          },
        );
        final service = OdooWebSocketService(
          connectionManager: connectionManager,
        );

        final reportedIds = <int>[];
        service.lastNotificationIdStream.listen(reportedIds.add);

        final info = OdooWebSocketConnectionInfo(
          baseUrl: 'https://odoo.example.com',
          database: 'mydb',
          realtimeCredentialProvider: () async => RealtimeCredential(
            sessionId: 'sid',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          ),
          initialLast: 120,
        );

        service.connect(info);
        async.flushMicrotasks();

        final subscribeMessage = channel!.sentMessages
            .map((m) => jsonDecode(m as String) as Map<String, dynamic>)
            .firstWhere((m) => m['event_name'] == 'subscribe');
        expect((subscribeMessage['data'] as Map)['last'], equals(120));

        channel!.addIncoming(
          jsonEncode({
            'id': 121,
            'message': {'type': 'unmapped_type', 'payload': {}},
          }),
        );
        async.flushMicrotasks();

        expect(reportedIds, equals([121]));

        service.disconnect();
        service.dispose();
      });
    });
  });

  group('E — disconnect() leaves no pending timers', () {
    test(
      'heartbeat, reconnection and credential-expiry timers are all cancelled',
      () {
        fakeAsync((async) {
          final connectionManager = WebSocketConnectionManager(
            channelFactory: (uri, baseUrl, {database}) async =>
                FakeWebSocketChannel(),
          );
          final service = OdooWebSocketService(
            connectionManager: connectionManager,
          );

          final info = OdooWebSocketConnectionInfo(
            baseUrl: 'https://odoo.example.com',
            database: 'mydb',
            realtimeCredentialProvider: () async => RealtimeCredential(
              sessionId: 'sid',
              expiresAt: DateTime.now().add(const Duration(hours: 1)),
            ),
            heartbeatInterval: const Duration(seconds: 30),
          );

          service.connect(info);
          async.flushMicrotasks();

          expect(service.isConnected, isTrue);
          expect(
            async.pendingTimers,
            isNotEmpty,
            reason: 'heartbeat + credential-expiry timers should be alive',
          );

          service.disconnect();

          expect(async.pendingTimers, isEmpty);

          service.dispose();
        });
      },
    );
  });
}
