import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import '../../core/database/repositories/repository_providers.dart';
import '../../core/services/platform/server_connectivity_service.dart';

/// Holds the server information displayed in the bottom status bar.
class ServerInfo {
  final String serverUrl;
  final String database;
  final String odooVersion;

  /// The offset between server UTC time and local device UTC time.
  /// serverUtc = DateTime.now().toUtc().add(serverTimeOffset)
  final Duration serverTimeOffset;

  /// When the server time was last synced.
  final DateTime? lastSynced;

  const ServerInfo({
    this.serverUrl = '',
    this.database = '',
    this.odooVersion = '',
    this.serverTimeOffset = Duration.zero,
    this.lastSynced,
  });

  /// Get the current server time (UTC adjusted by offset, then to local).
  DateTime get serverTime =>
      DateTime.now().toUtc().add(serverTimeOffset).toLocal();

  ServerInfo copyWith({
    String? serverUrl,
    String? database,
    String? odooVersion,
    Duration? serverTimeOffset,
    DateTime? lastSynced,
  }) {
    return ServerInfo(
      serverUrl: serverUrl ?? this.serverUrl,
      database: database ?? this.database,
      odooVersion: odooVersion ?? this.odooVersion,
      serverTimeOffset: serverTimeOffset ?? this.serverTimeOffset,
      lastSynced: lastSynced ?? this.lastSynced,
    );
  }
}

/// Provider that manages server info: URL, database, version, and synced time.
///
/// Syncs server time on startup, every 10 minutes, and on connectivity restore.
final serverInfoProvider =
    NotifierProvider<ServerInfoNotifier, ServerInfo>(() => ServerInfoNotifier());

class ServerInfoNotifier extends Notifier<ServerInfo> {
  Timer? _syncTimer;
  bool _wasOffline = true;

  @override
  ServerInfo build() {
    // Read static info from OdooClient config
    final odooClient = ref.watch(odooClientProvider);
    if (odooClient != null) {
      final config = odooClient.config;
      final version = odooClient.version;

      // Set up periodic sync timer
      _syncTimer?.cancel();
      _syncTimer = Timer.periodic(
        const Duration(minutes: 10),
        (_) => _syncServerTime(),
      );

      // Listen to connectivity changes for re-sync on reconnect
      ref.listen<AsyncValue<ConnectivityStatus>>(
        connectivityStatusProvider,
        (previous, next) {
          next.whenData((status) {
            final isOnline =
                status.serverState == ServerConnectionState.online;
            if (isOnline && _wasOffline) {
              _syncServerTime();
            }
            _wasOffline = !isOnline;
          });
        },
      );

      // Clean up timer on dispose
      ref.onDispose(() {
        _syncTimer?.cancel();
      });

      // Initial sync
      Future.microtask(() => _syncServerTime());

      // Extract host from URL for display
      final displayUrl = _extractDisplayUrl(config.baseUrl);

      return ServerInfo(
        serverUrl: displayUrl,
        database: config.database ?? '',
        odooVersion: version.isUnknown ? '' : 'Odoo $version',
      );
    }

    return const ServerInfo();
  }

  /// Extract a compact display URL (host:port or host).
  String _extractDisplayUrl(String baseUrl) {
    try {
      final uri = Uri.parse(baseUrl);
      final host = uri.host;
      final port = uri.port;
      // Show port only if non-standard
      if ((uri.scheme == 'https' && port == 443) ||
          (uri.scheme == 'http' && port == 80) ||
          port == 0) {
        return host;
      }
      return '$host:$port';
    } catch (_) {
      return baseUrl;
    }
  }

  /// Sync server time by calling a lightweight Odoo method.
  ///
  /// Uses `res.users.search_count` (always accessible with API key) to
  /// confirm the server is reachable, and captures the round-trip midpoint
  /// as the sync reference. The display clock runs locally and resets its
  /// offset on each sync.
  Future<void> _syncServerTime() async {
    final odooClient = ref.read(odooClientProvider);
    if (odooClient == null) return;

    try {
      final localBefore = DateTime.now().toUtc();

      // Lightweight call — res.users is always accessible with API key auth
      await odooClient.call(
        model: 'res.users',
        method: 'search_count',
        kwargs: {'domain': []},
      );

      final localAfter = DateTime.now().toUtc();

      // Use the midpoint of the round-trip as the sync timestamp
      final midpoint = localBefore.add(
        localAfter.difference(localBefore) ~/ 2,
      );

      state = state.copyWith(
        serverTimeOffset: Duration.zero,
        lastSynced: midpoint,
        // Update version if it was fetched after initial build
        odooVersion: odooClient.version.isUnknown
            ? state.odooVersion
            : 'Odoo ${odooClient.version}',
      );
    } catch (e) {
      // Sync failed — keep last known state. This is non-critical;
      // the timer will retry on the next interval.
      logger.d('[ServerInfo] Time sync failed (non-critical): $e');
    }
  }
}
