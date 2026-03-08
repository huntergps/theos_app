/// Server Database Service (Generic)
///
/// Manages database names and instance locks per Odoo server.
/// Enables multi-server support with isolated databases.
library;

import 'dart:async';

import 'device_service.dart';
import 'logger_service.dart';

// ============================================================================
// SERVER CONFIG
// ============================================================================

/// Configuration for an Odoo server connection
class ServerConfig {
  /// Display name for the server
  final String name;

  /// Server URL (e.g., "https://erp.company.com")
  final String url;

  /// Odoo database name
  final String database;

  const ServerConfig({
    required this.name,
    required this.url,
    required this.database,
  });

  @override
  String toString() => 'ServerConfig($name: $url/$database)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ServerConfig &&
        other.url == url &&
        other.database == database;
  }

  @override
  int get hashCode => Object.hash(url, database);
}

// ============================================================================
// LOCK FILE PERSISTENCE INTERFACE
// ============================================================================

/// Interface for persisting server lock files
///
/// Implement this for platform-specific file system access.
/// On web, implement as no-op (each tab is isolated).
abstract class ServerLockPersistence {
  /// Check if a lock file exists for the server
  Future<bool> lockExists(String identifier);

  /// Read lock file contents
  Future<Map<String, dynamic>?> readLock(String identifier);

  /// Write lock file
  Future<void> writeLock(String identifier, Map<String, dynamic> data);

  /// Delete lock file
  Future<void> deleteLock(String identifier);

  /// List all lock files
  Future<List<Map<String, dynamic>>> listLocks();

  /// Whether locks are supported on this platform
  bool get isSupported;
}

/// No-op implementation for platforms that don't support locks (web)
class NoOpServerLockPersistence implements ServerLockPersistence {
  @override
  bool get isSupported => false;

  @override
  Future<bool> lockExists(String identifier) async => false;

  @override
  Future<Map<String, dynamic>?> readLock(String identifier) async => null;

  @override
  Future<void> writeLock(String identifier, Map<String, dynamic> data) async {}

  @override
  Future<void> deleteLock(String identifier) async {}

  @override
  Future<List<Map<String, dynamic>>> listLocks() async => [];
}

// ============================================================================
// SERVER DATABASE SERVICE
// ============================================================================

/// Service for managing database names and instance locks per Odoo server
///
/// ## Features
/// - Generates unique DB names based on server URL + database
/// - Prevents multiple instances connected to the same server
/// - Allows multiple instances for DIFFERENT servers
///
/// ## Database Name Format
/// `theos_pos_{host_sanitized}_{db_sanitized}.sqlite`
///
/// Example:
/// - URL: https://erp1.tecnosmart.com.ec, DB: empresa_a
/// - Result: theos_pos_erp1_tecnosmart_com_ec_empresa_a.sqlite
class ServerDatabaseService {
  final DeviceService _deviceService;
  final ServerLockPersistence _lockPersistence;

  ServerDatabaseService(
    this._deviceService, {
    ServerLockPersistence? lockPersistence,
  }) : _lockPersistence = lockPersistence ?? NoOpServerLockPersistence();

  /// Generate a unique, filesystem-safe database name for a server
  ///
  /// Combines server URL + Odoo database name to create
  /// a unique identifier used as the SQLite filename.
  String generateDatabaseName(ServerConfig server) {
    final identifier = generateServerIdentifier(server);
    return 'theos_pos_$identifier';
  }

  /// Generate a short identifier for a server (used in locks and keys)
  String generateServerIdentifier(ServerConfig server) {
    // Parse URL to extract host
    final uri = Uri.parse(server.url);
    final host = uri.host.replaceAll('.', '_').replaceAll('-', '_');
    final port = uri.port != 80 && uri.port != 443 ? '_${uri.port}' : '';
    final db = server.database.replaceAll('.', '_').replaceAll('-', '_');

    // Sanitize to be filesystem-safe
    final identifier = '$host${port}_$db'
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')
        .toLowerCase();

    // Truncate if too long (max 100 chars for filename safety)
    if (identifier.length > 100) {
      // Use simple hash for long identifiers (sum of char codes)
      final hash =
          identifier.codeUnits.fold<int>(0, (a, b) => a + b).toRadixString(16);
      return '${identifier.substring(0, 90)}_$hash';
    }

    return identifier;
  }

  /// Check if another instance is already connected to this server
  ///
  /// Returns the instance ID of the existing instance, or null if none.
  Future<String?> checkExistingInstance(ServerConfig server) async {
    if (!_lockPersistence.isSupported) return null;

    try {
      final identifier = generateServerIdentifier(server);
      final data = await _lockPersistence.readLock(identifier);

      if (data == null) return null;

      final instanceId = data['instance_id'] as String?;
      final timestamp = DateTime.tryParse(data['timestamp'] as String? ?? '');

      // Lock is stale if older than 30 seconds without heartbeat
      if (timestamp != null) {
        final age = DateTime.now().difference(timestamp);
        if (age.inSeconds > 30) {
          logger.d(
            '[ServerDbService]',
            'Found stale lock file, removing...',
          );
          await _lockPersistence.deleteLock(identifier);
          return null;
        }
      }

      return instanceId;
    } catch (e) {
      logger.d('[ServerDbService]', 'Error checking existing instance: $e');
      return null;
    }
  }

  /// Acquire lock for this server (prevent other instances)
  ///
  /// Returns true if lock acquired, false if another instance has it.
  Future<bool> acquireLock(ServerConfig server) async {
    if (!_lockPersistence.isSupported) return true;

    try {
      // First check if lock exists
      final existingInstance = await checkExistingInstance(server);
      if (existingInstance != null) {
        final ownInstanceId = _deviceService.getInstanceId();
        if (existingInstance != ownInstanceId) {
          logger.w(
            '[ServerDbService]',
            'Server ${server.name} already has instance: $existingInstance',
          );
          return false;
        }
        // It's our own lock, just update it
      }

      // Create/update lock file
      final identifier = generateServerIdentifier(server);
      final lockData = {
        'instance_id': _deviceService.getInstanceId(),
        'device_id': await _deviceService.getDeviceId(),
        'timestamp': DateTime.now().toIso8601String(),
        'server_name': server.name,
        'server_url': server.url,
        'server_db': server.database,
      };

      await _lockPersistence.writeLock(identifier, lockData);
      logger.d('[ServerDbService]', 'Lock acquired for ${server.name}');

      return true;
    } catch (e) {
      logger.e('[ServerDbService]', 'Error acquiring lock: $e');
      return false;
    }
  }

  /// Release lock for this server
  Future<void> releaseLock(ServerConfig server) async {
    if (!_lockPersistence.isSupported) return;

    try {
      final identifier = generateServerIdentifier(server);
      final data = await _lockPersistence.readLock(identifier);

      if (data != null) {
        // Verify it's our lock before deleting
        final lockInstanceId = data['instance_id'] as String?;
        final ownInstanceId = _deviceService.getInstanceId();

        if (lockInstanceId == ownInstanceId) {
          await _lockPersistence.deleteLock(identifier);
          logger.d('[ServerDbService]', 'Lock released for ${server.name}');
        } else {
          logger.w(
            '[ServerDbService]',
            'Lock belongs to another instance, not releasing',
          );
        }
      }
    } catch (e) {
      logger.d('[ServerDbService]', 'Error releasing lock: $e');
    }
  }

  /// Update lock heartbeat (call periodically to keep lock alive)
  Future<void> updateHeartbeat(ServerConfig server) async {
    if (!_lockPersistence.isSupported) return;

    try {
      final identifier = generateServerIdentifier(server);
      final data = await _lockPersistence.readLock(identifier);

      if (data != null) {
        // Only update if it's our lock
        final lockInstanceId = data['instance_id'] as String?;
        final ownInstanceId = _deviceService.getInstanceId();

        if (lockInstanceId == ownInstanceId) {
          data['timestamp'] = DateTime.now().toIso8601String();
          await _lockPersistence.writeLock(identifier, data);
        }
      }
    } catch (e) {
      logger.d('[ServerDbService]', 'Error updating heartbeat: $e');
    }
  }

  /// List all currently locked servers
  Future<List<Map<String, dynamic>>> getLockedServers() async {
    return await _lockPersistence.listLocks();
  }

  /// Clean up stale locks (older than specified duration)
  Future<int> cleanupStaleLocks({
    Duration maxAge = const Duration(minutes: 5),
  }) async {
    if (!_lockPersistence.isSupported) return 0;

    var cleaned = 0;
    try {
      final locks = await _lockPersistence.listLocks();

      for (final lock in locks) {
        final timestamp =
            DateTime.tryParse(lock['timestamp'] as String? ?? '');
        final identifier = lock['_identifier'] as String?;

        if (timestamp != null && identifier != null) {
          final age = DateTime.now().difference(timestamp);
          if (age > maxAge) {
            await _lockPersistence.deleteLock(identifier);
            cleaned++;
            logger.d('[ServerDbService]', 'Cleaned stale lock: $identifier');
          }
        }
      }
    } catch (e) {
      logger.d('[ServerDbService]', 'Error cleaning locks: $e');
    }
    return cleaned;
  }
}
