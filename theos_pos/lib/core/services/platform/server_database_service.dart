/// Server Database Service - App Integration
///
/// Wraps the generic ServerDatabaseService from odoo_offline_core
/// with file system lock persistence for desktop platforms.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import package with alias to avoid ServerConfig conflict
import 'package:odoo_sdk/odoo_sdk.dart' as pkg;

import '../logger_service.dart';
import 'device_service.dart';
import '../../../features/authentication/services/server_service.dart';

// Re-export package types for external use (except ServerConfig)
export 'package:odoo_sdk/odoo_sdk.dart'
    show ServerLockPersistence;

// ============================================================================
// FILE SYSTEM LOCK PERSISTENCE (Desktop platforms)
// ============================================================================

/// File system based lock persistence for desktop platforms
class FileSystemLockPersistence implements pkg.ServerLockPersistence {
  static const _lockFilePrefix = 'theos_pos_lock_';

  @override
  bool get isSupported => !kIsWeb;

  Future<Directory> _getLockDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    final lockDir = Directory('${appDir.path}/locks');
    if (!await lockDir.exists()) {
      await lockDir.create(recursive: true);
    }
    return lockDir;
  }

  File _getLockFile(Directory dir, String identifier) {
    return File('${dir.path}/$_lockFilePrefix$identifier.lock');
  }

  @override
  Future<bool> lockExists(String identifier) async {
    if (!isSupported) return false;
    final dir = await _getLockDirectory();
    final file = _getLockFile(dir, identifier);
    return file.exists();
  }

  @override
  Future<Map<String, dynamic>?> readLock(String identifier) async {
    if (!isSupported) return null;
    try {
      final dir = await _getLockDirectory();
      final file = _getLockFile(dir, identifier);
      if (await file.exists()) {
        final content = await file.readAsString();
        return jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (e) {
      logger.d('[FileSystemLock]', 'Error reading lock: $e');
    }
    return null;
  }

  @override
  Future<void> writeLock(String identifier, Map<String, dynamic> data) async {
    if (!isSupported) return;
    try {
      final dir = await _getLockDirectory();
      final file = _getLockFile(dir, identifier);
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      logger.e('[FileSystemLock]', 'Error writing lock: $e');
    }
  }

  @override
  Future<void> deleteLock(String identifier) async {
    if (!isSupported) return;
    try {
      final dir = await _getLockDirectory();
      final file = _getLockFile(dir, identifier);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      logger.d('[FileSystemLock]', 'Error deleting lock: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listLocks() async {
    if (!isSupported) return [];
    final locks = <Map<String, dynamic>>[];
    try {
      final lockDir = await _getLockDirectory();
      if (!await lockDir.exists()) return [];

      await for (final file in lockDir.list()) {
        if (file is File && file.path.endsWith('.lock')) {
          try {
            final content = await file.readAsString();
            final data = jsonDecode(content) as Map<String, dynamic>;
            // Add identifier for cleanup
            final filename = file.path.split('/').last;
            data['_identifier'] = filename
                .replaceFirst(_lockFilePrefix, '')
                .replaceFirst('.lock', '');
            locks.add(data);
          } catch (_) {
            // Skip invalid lock files
          }
        }
      }
    } catch (e) {
      logger.d('[FileSystemLock]', 'Error listing locks: $e');
    }
    return locks;
  }
}

// ============================================================================
// APP SERVER DATABASE SERVICE
// ============================================================================

/// App-specific wrapper that extends package's ServerDatabaseService
///
/// Adds:
/// - File system lock persistence for desktop platforms
/// - SharedPreferences integration for current server tracking
/// - Process ID checking for stale lock detection (macOS/Linux)
class AppServerDatabaseService {
  static const _currentServerKey = 'current_server_db_identifier';

  final pkg.DeviceService _deviceService;
  late final pkg.ServerDatabaseService _service;

  AppServerDatabaseService(this._deviceService) {
    _service = pkg.ServerDatabaseService(
      _deviceService,
      lockPersistence: kIsWeb
          ? pkg.NoOpServerLockPersistence()
          : FileSystemLockPersistence(),
    );
  }

  /// Generate a unique, filesystem-safe database name for a server
  String generateDatabaseName(ServerConfig server) {
    return _service.generateDatabaseName(_toPackageConfig(server));
  }

  /// Get the server identifier (for keys and locks)
  String getServerIdentifier(ServerConfig server) {
    return _service.generateServerIdentifier(_toPackageConfig(server));
  }

  /// Check if another instance is already connected to this server
  Future<String?> checkExistingInstance(ServerConfig server) async {
    if (kIsWeb) return null;

    // First check via package service
    final existingId = await _service.checkExistingInstance(
      _toPackageConfig(server),
    );

    if (existingId == null) return null;

    // Additional check: verify process is still running (macOS/Linux)
    try {
      final lockData = await (FileSystemLockPersistence()).readLock(
        _service.generateServerIdentifier(_toPackageConfig(server)),
      );

      if (lockData != null) {
        final pid = lockData['pid'] as int?;
        if (pid != null && (Platform.isMacOS || Platform.isLinux)) {
          final result = await Process.run('kill', ['-0', pid.toString()]);
          if (result.exitCode != 0) {
            // Process not running, release the stale lock
            logger.d('[ServerDbService]', 'Process $pid not running, removing lock');
            await _service.releaseLock(_toPackageConfig(server));
            return null;
          }
        }
      }
    } catch (_) {
      // If check fails, assume instance might still be running
    }

    return existingId;
  }

  /// Acquire lock for this server
  Future<bool> acquireLock(ServerConfig server) async {
    final acquired = await _service.acquireLock(_toPackageConfig(server));

    if (acquired) {
      // Save current server identifier to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _currentServerKey,
        _service.generateServerIdentifier(_toPackageConfig(server)),
      );
    }

    return acquired;
  }

  /// Release lock for this server
  Future<void> releaseLock(ServerConfig server) async {
    await _service.releaseLock(_toPackageConfig(server));
  }

  /// Update lock heartbeat
  Future<void> updateHeartbeat(ServerConfig server) async {
    await _service.updateHeartbeat(_toPackageConfig(server));
  }

  /// List all currently locked servers
  Future<List<Map<String, dynamic>>> getLockedServers() async {
    return _service.getLockedServers();
  }

  /// Clean up stale locks
  Future<int> cleanupStaleLocks({
    Duration maxAge = const Duration(minutes: 5),
  }) async {
    return _service.cleanupStaleLocks(maxAge: maxAge);
  }

  /// Convert app's ServerConfig to package's ServerConfig
  pkg.ServerConfig _toPackageConfig(ServerConfig server) {
    return pkg.ServerConfig(
      name: server.name,
      url: server.url,
      database: server.database,
    );
  }
}

// ============================================================================
// PROVIDERS
// ============================================================================

/// Provider for AppServerDatabaseService
final serverDatabaseServiceProvider = Provider<AppServerDatabaseService>((ref) {
  final deviceService = ref.watch(deviceServiceProvider);
  return AppServerDatabaseService(deviceService);
});

/// Provider for the current database name (based on connected server)
final currentDatabaseNameProvider = FutureProvider<String?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final identifier = prefs.getString('current_server_db_identifier');
  if (identifier == null) return null;
  return 'theos_pos_$identifier';
});
