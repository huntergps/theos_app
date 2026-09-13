/// Tests for the injectable real-time session on
/// [WebSocketConnectionManager] / [OdooWebSocketService]: the bus no longer
/// accepts a JSON-2 Bearer token (measured against ERP2, Odoo 19.5 closes
/// with 4001), so authentication moves to a single-use `ticket` query
/// parameter fetched from an injectable [RealtimeCredentialProvider] — never
/// the long-lived `session_id` a first design used, which would sit in
/// cleartext in every access/proxy log line for the handshake.
///
/// Covers, from the task contract (RED first):
///   A. the connect URL carries `ticket` from the provider, never
///      `session_id`, and no Authorization header is ever built;
///   B. an expired credential triggers a fresh provider call and an
///      immediate reconnect, without touching the failure-backoff counter;
///   D. `initialLast` seeds the very first `subscribe` message, and a live
///      message advances `lastNotificationIdStream`;
///   E. `disconnect()` leaves no pending timers (heartbeat, reconnection,
///      credential-expiry);
///   F. the ticket is never cached or reused: two connections in a row each
///      call the provider and each carry their own ticket in the URL.
///   G. `check_outdated` on `subscribe`: true only when a known `last` is
///      sent AND it is the first `subscribe` of this connection — replicates
///      the official worker's `minId !== null && !this.lastChannelSubscription`
///      (`bus/static/src/workers/websocket_worker.js`). Missing this key
///      entirely made ERP2's `ir.websocket._subscribe` crash with `KeyError:
///      'check_outdated'` on every single subscribe (measured 13-sep-2026).
///   H. the connect URL's `?version=` comes from the credential's
///      `websocketVersion` when the server provides one, falling back to the
///      registry default otherwise — the bus protocol version changes with
///      every Odoo series and a mismatch gets the socket closed CLEANLY
///      with reason `OUTDATED_VERSION` (measured against ERP2 19.5,
///      13-sep-2026: the SDK still hardcoded `19.0-2`).
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
  group('A — ticket in the URL, never session_id, never Authorization', () {
    test('the connect URL carries ticket from the provider, never session_id', () async {
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
          ticket: 'the-ticket',
          expiresAt: DateTime.now().add(const Duration(seconds: 30)),
          sessionExpiresAt: DateTime.now().add(const Duration(minutes: 10)),
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
      expect(capturedUri!.queryParameters['ticket'], equals('the-ticket'));
      expect(
        capturedUri!.queryParameters.containsKey('session_id'),
        isFalse,
        reason:
            'a 1h session id on the URL would sit in cleartext in every '
            'access/proxy log line for the handshake — only the short-lived, '
            'single-use ticket goes there now',
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
              ticket: 'ticket-$providerCalls',
              expiresAt: DateTime.now().add(const Duration(seconds: 30)),
              sessionExpiresAt: DateTime.now().add(const Duration(seconds: 5)),
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
            ticket: 'ticket',
            expiresAt: DateTime.now().add(const Duration(seconds: 30)),
            sessionExpiresAt: DateTime.now().add(const Duration(hours: 1)),
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
              ticket: 'ticket',
              expiresAt: DateTime.now().add(const Duration(seconds: 30)),
              sessionExpiresAt: DateTime.now().add(const Duration(hours: 1)),
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

  group('F — the ticket is never cached or reused', () {
    test(
      'two connections in a row each call the provider and each carry their own ticket',
      () async {
        var providerCalls = 0;
        final capturedTickets = <String>[];
        final manager = WebSocketConnectionManager(
          channelFactory: (uri, baseUrl, {database}) async {
            capturedTickets.add(uri.queryParameters['ticket']!);
            return FakeWebSocketChannel();
          },
        );

        final info = OdooWebSocketConnectionInfo(
          baseUrl: 'https://odoo.example.com',
          database: 'mydb',
          realtimeCredentialProvider: () async {
            providerCalls++;
            return RealtimeCredential(
              ticket: 'ticket-$providerCalls',
              expiresAt: DateTime.now().add(const Duration(seconds: 30)),
              sessionExpiresAt: DateTime.now().add(const Duration(minutes: 10)),
            );
          },
        );

        await manager.connect(
          info,
          onMessage: (_) {},
          onError: (_) {},
          onDone: () {},
          onCredentialExpired: () {},
        );
        manager.disconnect();

        await manager.connect(
          info,
          onMessage: (_) {},
          onError: (_) {},
          onDone: () {},
          onCredentialExpired: () {},
        );
        manager.disconnect();

        expect(
          providerCalls,
          equals(2),
          reason: 'a ticket is single-use: every connection asks for a new one',
        );
        expect(capturedTickets, equals(['ticket-1', 'ticket-2']));
        expect(
          capturedTickets.toSet(),
          hasLength(2),
          reason: 'the second connection must never reuse the first ticket',
        );
      },
    );
  });

  group(
    'G — check_outdated on subscribe: true only with a known last AND on the first subscription',
    () {
      test('a known last (non-zero) on the very first subscribe → true', () {
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

          final info = OdooWebSocketConnectionInfo(
            baseUrl: 'https://odoo.example.com',
            database: 'mydb',
            realtimeCredentialProvider: () async => RealtimeCredential(
              ticket: 'ticket',
              expiresAt: DateTime.now().add(const Duration(seconds: 30)),
              sessionExpiresAt: DateTime.now().add(const Duration(hours: 1)),
            ),
            initialLast: 120,
          );

          service.connect(info);
          async.flushMicrotasks();

          final subscribeMessage = channel!.sentMessages
              .map((m) => jsonDecode(m as String) as Map<String, dynamic>)
              .firstWhere((m) => m['event_name'] == 'subscribe');
          expect((subscribeMessage['data'] as Map)['check_outdated'], isTrue);

          service.disconnect();
          service.dispose();
        });
      });

      test('no known last (initialLast defaults to 0) → false', () {
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

          final info = OdooWebSocketConnectionInfo(
            baseUrl: 'https://odoo.example.com',
            database: 'mydb',
            realtimeCredentialProvider: () async => RealtimeCredential(
              ticket: 'ticket',
              expiresAt: DateTime.now().add(const Duration(seconds: 30)),
              sessionExpiresAt: DateTime.now().add(const Duration(hours: 1)),
            ),
            // initialLast defaults to 0 — never synced, nothing to check.
          );

          service.connect(info);
          async.flushMicrotasks();

          final subscribeMessage = channel!.sentMessages
              .map((m) => jsonDecode(m as String) as Map<String, dynamic>)
              .firstWhere((m) => m['event_name'] == 'subscribe');
          expect((subscribeMessage['data'] as Map)['check_outdated'], isFalse);

          service.disconnect();
          service.dispose();
        });
      });

      test(
        'a second subscribe on the SAME connection is never check_outdated, even with a known last',
        () {
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

            final info = OdooWebSocketConnectionInfo(
              baseUrl: 'https://odoo.example.com',
              database: 'mydb',
              realtimeCredentialProvider: () async => RealtimeCredential(
                ticket: 'ticket',
                expiresAt: DateTime.now().add(const Duration(seconds: 30)),
                sessionExpiresAt: DateTime.now().add(const Duration(hours: 1)),
              ),
              initialLast: 120,
            );

            service.connect(info);
            async.flushMicrotasks();
            service.addChannels(const ['extra_channel']);
            async.flushMicrotasks();

            final subscribeMessages = channel!.sentMessages
                .map((m) => jsonDecode(m as String) as Map<String, dynamic>)
                .where((m) => m['event_name'] == 'subscribe')
                .toList();
            expect(subscribeMessages, hasLength(2));
            expect(
              (subscribeMessages[0]['data'] as Map)['check_outdated'],
              isTrue,
              reason: 'primera suscripción de la conexión, con last conocido',
            );
            expect(
              (subscribeMessages[1]['data'] as Map)['check_outdated'],
              isFalse,
              reason: 'ya no es la primera suscripción de esta conexión',
            );

            service.disconnect();
            service.dispose();
          });
        },
      );
    },
  );

  group(
    'H — the ?version= comes from the credential, falling back to the registry default',
    () {
      test('a credential with websocketVersion overrides the ?version= sent', () async {
        Uri? capturedUri;
        final manager = WebSocketConnectionManager(
          channelFactory: (uri, baseUrl, {database}) async {
            capturedUri = uri;
            return FakeWebSocketChannel();
          },
        );

        final info = OdooWebSocketConnectionInfo(
          baseUrl: 'https://odoo.example.com',
          database: 'mydb',
          realtimeCredentialProvider: () async => RealtimeCredential(
            ticket: 'ticket',
            expiresAt: DateTime.now().add(const Duration(seconds: 30)),
            sessionExpiresAt: DateTime.now().add(const Duration(hours: 1)),
            websocketVersion: 'saas-19.5-1',
          ),
        );

        await manager.connect(
          info,
          onMessage: (_) {},
          onError: (_) {},
          onDone: () {},
          onCredentialExpired: () {},
        );

        expect(capturedUri!.queryParameters['version'], equals('saas-19.5-1'));

        manager.disconnect();
      });

      test(
        'no websocketVersion on the credential (server without the field yet) → registry default',
        () async {
          Uri? capturedUri;
          final manager = WebSocketConnectionManager(
            channelFactory: (uri, baseUrl, {database}) async {
              capturedUri = uri;
              return FakeWebSocketChannel();
            },
          );

          final info = OdooWebSocketConnectionInfo(
            baseUrl: 'https://odoo.example.com',
            database: 'mydb',
            realtimeCredentialProvider: () async => RealtimeCredential(
              ticket: 'ticket',
              expiresAt: DateTime.now().add(const Duration(seconds: 30)),
              sessionExpiresAt: DateTime.now().add(const Duration(hours: 1)),
              // websocketVersion left unset on purpose.
            ),
          );

          await manager.connect(
            info,
            onMessage: (_) {},
            onError: (_) {},
            onDone: () {},
            onCredentialExpired: () {},
          );

          expect(
            capturedUri!.queryParameters['version'],
            equals(WebSocketModelRegistry.instance.wsVersion),
          );

          manager.disconnect();
        },
      );
    },
  );

  group('I — a CLEAN close with reason OUTDATED_VERSION is visible, never silent', () {
    test('status leaves live for retrying, and it keeps reconnecting', () {
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

        final info = OdooWebSocketConnectionInfo(
          baseUrl: 'https://odoo.example.com',
          database: 'mydb',
          realtimeCredentialProvider: () async => RealtimeCredential(
            ticket: 'ticket',
            expiresAt: DateTime.now().add(const Duration(seconds: 30)),
            sessionExpiresAt: DateTime.now().add(const Duration(hours: 1)),
          ),
        );

        service.connect(info);
        async.flushMicrotasks();
        expect(service.isConnected, isTrue);

        channel!.simulateClose(1000, 'OUTDATED_VERSION');
        async.flushMicrotasks();

        expect(
          service.isConnected,
          isFalse,
          reason: 'un cierre por versión desactualizada no puede dejar el '
              'estado como si siguiera conectado',
        );
        expect(
          service.reconnectAttempts,
          greaterThan(0),
          reason: 'sigue reintentando — nunca se rinde silenciosamente',
        );

        service.disconnect();
        service.dispose();
      });
    });
  });
}
