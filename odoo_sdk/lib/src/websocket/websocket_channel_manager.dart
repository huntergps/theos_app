/// Internal channel manager for OdooWebSocketService.
///
/// Handles channel subscription, default channel building, and
/// additional channel management.
library;

import 'dart:convert';

import '../services/logger_service.dart';
import 'odoo_websocket_service.dart';
import 'websocket_connection_manager.dart';
import 'websocket_model_registry.dart';

/// Manages WebSocket channel subscriptions.
class WebSocketChannelManager {
  /// Currently subscribed channels.
  final Set<String> subscribedChannels = {};

  /// Additional channels added externally.
  final Set<String> additionalChannels = {};

  /// Adds additional channels to subscribe to.
  ///
  /// If [connection] is connected, subscribes immediately.
  void addChannels(
    List<String> channels,
    WebSocketConnectionManager connection,
  ) {
    additionalChannels.addAll(channels);
    if (connection.isConnected && channels.isNotEmpty) {
      subscribeToChannels(channels, connection, lastNotificationId: 0);
    }
  }

  /// Builds the default channels for a database and optional partner.
  List<String> buildDefaultChannels(
    String database,
    int? partnerId,
    OdooWebSocketConnectionInfo? connectionInfo,
  ) {
    // If custom default channels are provided, use them
    if (connectionInfo?.defaultChannels != null) {
      final channels = connectionInfo!.defaultChannels!
          .map((c) => c.contains('.') ? c : '$database.$c')
          .toList();
      if (partnerId != null) {
        channels.add('$database.odoo-presence-res.partner_$partnerId');
        channels.add('$database.odoo-activity-res.partner_$partnerId');
      }
      return channels;
    }

    // Delegate to registry
    return WebSocketModelRegistry.instance.buildChannels(database, partnerId);
  }

  /// Sends a subscription message for the given channels.
  Future<void> subscribeToChannels(
    List<String> channels,
    WebSocketConnectionManager connection, {
    required int lastNotificationId,
  }) async {
    if (!connection.isConnected || connection.channel == null) return;

    subscribedChannels.addAll(channels);

    final message = {
      'event_name': 'subscribe',
      'data': {'channels': channels, 'last': lastNotificationId},
    };

    try {
      connection.channel!.sink.add(jsonEncode(message));
    } catch (e) {
      logger.e('[OdooWebSocket]', 'Error subscribing: $e');
    }
  }

  /// Clears all subscribed channels.
  void clear() {
    subscribedChannels.clear();
  }
}
