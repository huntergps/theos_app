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
  ///
  /// `check_outdated` is a REQUIRED key for the server's `ir.websocket.
  /// _subscribe` (Odoo 19.5: `KeyError: 'check_outdated'` without it, on
  /// every single subscribe — measured against ERP2, 13-sep-2026). Set only
  /// when [lastNotificationId] is a genuinely known cursor (never `0`, the
  /// codebase's existing "never synced" sentinel — see
  /// `OdooWebSocketConnectionInfo.initialLast`) AND this is the first
  /// subscribe of this connection (`subscribedChannels` still empty) —
  /// replicates the official worker's `minId !== null &&
  /// !this.lastChannelSubscription`
  /// (`bus/static/src/workers/websocket_worker.js`). Only then does it make
  /// sense to ask the server "does my last id still exist" — a later
  /// subscribe on the same connection, or one with no prior cursor at all,
  /// has nothing meaningful to check.
  Future<void> subscribeToChannels(
    List<String> channels,
    WebSocketConnectionManager connection, {
    required int lastNotificationId,
  }) async {
    if (!connection.isConnected || connection.channel == null) return;

    final checkOutdated = lastNotificationId != 0 && subscribedChannels.isEmpty;
    subscribedChannels.addAll(channels);

    final message = {
      'event_name': 'subscribe',
      'data': {
        'channels': channels,
        'check_outdated': checkOutdated,
        'last': lastNotificationId,
      },
    };

    try {
      connection.channel!.sink.add(jsonEncode(message));
    } catch (e) {
      logger.e('[OdooWebSocket]', 'Error subscribing: $e');
    }
  }

  /// Clears subscribed channels.
  ///
  /// By default clears both [subscribedChannels] AND [additionalChannels]
  /// so that after a server-switch the stale channels are not re-subscribed
  /// to the new server.
  ///
  /// Pass [clearAdditional: false] when the disconnect is a transient network
  /// drop on the *same* server and you want to keep the extra subscriptions so
  /// they are reinstated automatically on reconnect.
  void clear({bool clearAdditional = true}) {
    subscribedChannels.clear();
    if (clearAdditional) {
      additionalChannels.clear();
    }
  }
}
