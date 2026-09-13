/// Tests for [WebSocketEventParser] covering the POS-style payload shape
/// (`*_updated` type with the real action inside `payload.action`) and the
/// `last` seeding contract used to persist a scope's cursor.
///
/// See docs/orbi_panel/reports/TIEMPO_REAL_Y_GLOBAL_REFERENCIA_2026_09_13.md
/// section 3 for the two payload shapes emitted by
/// l10n_ec_collection_box / l10n_ec_collection_box_pos.
import 'dart:convert';

import 'package:test/test.dart';

import 'package:odoo_sdk/src/websocket/odoo_websocket_events.dart';
import 'package:odoo_sdk/src/websocket/websocket_event_parser.dart';
import 'package:odoo_sdk/src/websocket/websocket_model_registry.dart';

String _envelope(int id, Map<String, dynamic> message) =>
    jsonEncode({'id': id, 'message': message});

void main() {
  late WebSocketEventParser parser;

  setUp(() {
    parser = WebSocketEventParser();
  });

  tearDown(() {
    WebSocketModelRegistry.instance.clear();
  });

  group('C — action is read from payload.action when present (POS style)', () {
    test('sale_order_updated with action=deleted is parsed as a delete', () {
      WebSocketModelRegistry.instance.registerNotification(
        'sale_order_updated',
        const WebSocketNotificationMapping(
          model: 'sale.order',
          idField: 'order_id',
          nameField: 'order_name',
        ),
      );

      final events = <OdooWebSocketEvent>[];
      parser.parseMessage(
        _envelope(55, {
          'type': 'sale_order_updated',
          'payload': {'action': 'deleted', 'order_id': 7},
        }),
        onEvent: events.add,
      );

      final recordEvent = events.whereType<OdooRecordEvent>().single;
      expect(recordEvent.model, equals('sale.order'));
      expect(recordEvent.recordId, equals(7));
      expect(recordEvent.action, equals(OdooRecordAction.deleted));
    });

    test(
      'falls back to the type suffix when payload carries no action (base style)',
      () {
        WebSocketModelRegistry.instance.registerNotification(
          'sale_order_created',
          const WebSocketNotificationMapping(
            model: 'sale.order',
            idField: 'id',
            nameField: 'name',
          ),
        );

        final events = <OdooWebSocketEvent>[];
        parser.parseMessage(
          _envelope(1, {
            'type': 'sale_order_created',
            'payload': {'id': 42, 'name': 'SO042'},
          }),
          onEvent: events.add,
        );

        final recordEvent = events.whereType<OdooRecordEvent>().single;
        expect(recordEvent.recordId, equals(42));
        expect(recordEvent.action, equals(OdooRecordAction.created));
      },
    );

    test('catalog events also prefer payload.action over the type suffix', () {
      WebSocketModelRegistry.instance.registerNotification(
        'tax_updated',
        const WebSocketNotificationMapping(
          model: 'account.tax',
          idField: 'tax_id',
          nameField: 'name',
          isCatalogEvent: true,
          catalogType: 'tax',
        ),
      );

      final events = <OdooWebSocketEvent>[];
      parser.parseMessage(
        _envelope(2, {
          'type': 'tax_updated',
          'payload': {'action': 'deleted', 'tax_id': 9},
        }),
        onEvent: events.add,
      );

      final catalogEvent = events.whereType<OdooCatalogEvent>().single;
      expect(catalogEvent.recordId, equals(9));
      expect(catalogEvent.action, equals(OdooRecordAction.deleted));
    });

    test('order-line events also prefer payload.action over the type suffix', () {
      WebSocketModelRegistry.instance.registerNotification(
        'sale_order_line_updated',
        const WebSocketNotificationMapping(
          model: 'sale.order.line',
          idField: 'id',
          nameField: 'name',
          isOrderLineEvent: true,
        ),
      );

      final events = <OdooWebSocketEvent>[];
      parser.parseMessage(
        _envelope(3, {
          'type': 'sale_order_line_updated',
          'payload': {'action': 'deleted', 'id': 11, 'order_id': 100},
        }),
        onEvent: events.add,
      );

      final lineEvent = events.whereType<OdooOrderLineEvent>().single;
      expect(lineEvent.lineId, equals(11));
      expect(lineEvent.orderId, equals(100));
      expect(lineEvent.action, equals(OdooRecordAction.deleted));
    });
  });

  group('idField is declared per notification type', () {
    test('different types for the same model can use different id keys', () {
      final registry = WebSocketModelRegistry.instance;
      registry.registerNotification(
        'sale_order_created',
        const WebSocketNotificationMapping(
          model: 'sale.order',
          idField: 'id', // base style: flat id
          nameField: 'name',
        ),
      );
      registry.registerNotification(
        'sale_order_updated',
        const WebSocketNotificationMapping(
          model: 'sale.order',
          idField: 'order_id', // POS style: nested under order_id
          nameField: 'order_name',
        ),
      );

      final events = <OdooWebSocketEvent>[];
      parser.parseMessage(
        _envelope(1, {
          'type': 'sale_order_created',
          'payload': {'id': 5, 'name': 'SO005'},
        }),
        onEvent: events.add,
      );
      parser.parseMessage(
        _envelope(2, {
          'type': 'sale_order_updated',
          'payload': {'action': 'updated', 'order_id': 6, 'order_name': 'SO006'},
        }),
        onEvent: events.add,
      );

      final recordEvents = events.whereType<OdooRecordEvent>().toList();
      expect(recordEvents[0].recordId, equals(5));
      expect(recordEvents[1].recordId, equals(6));
    });
  });

  group('D — internal worker messages (subscribe bookkeeping)', () {
    test(
      'bus/subscription_outdated emits OdooSubscriptionOutdatedEvent, never a notification',
      () {
        final events = <OdooWebSocketEvent>[];
        final notifications = parser.parseMessage(
          jsonEncode([
            {'type': 'bus/subscription_outdated', 'internal': true, 'payload': null},
          ]),
          onEvent: events.add,
        );

        expect(events.whereType<OdooSubscriptionOutdatedEvent>(), hasLength(1));
        expect(
          notifications,
          isEmpty,
          reason: 'un mensaje interno no es una notificación real',
        );
      },
    );

    test(
      'bus/last_id_reset emits OdooLastIdResetEvent and adopts the corrected id',
      () {
        final events = <OdooWebSocketEvent>[];
        parser.seedLastNotificationId(5);

        parser.parseMessage(
          jsonEncode([
            {'type': 'bus/last_id_reset', 'internal': true, 'payload': 99},
          ]),
          onEvent: events.add,
        );

        final resetEvent = events.whereType<OdooLastIdResetEvent>().single;
        expect(resetEvent.lastNotificationId, equals(99));
        expect(
          parser.lastNotificationId,
          equals(99),
          reason: 'el cursor local debe adoptar el id que el servidor corrigió',
        );
      },
    );
  });

  group('seedLastNotificationId', () {
    test('seeds the initial last, then live messages advance it', () {
      expect(parser.lastNotificationId, equals(0));

      parser.seedLastNotificationId(120);
      expect(parser.lastNotificationId, equals(120));

      parser.parseMessage(
        _envelope(121, {'type': 'unmapped_type', 'payload': {}}),
        onEvent: (_) {},
      );
      expect(parser.lastNotificationId, equals(121));
    });
  });
}
