/// Native implementation of FileSystemLockPersistence using dart:io.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:odoo_sdk/odoo_sdk.dart' as pkg;

import '../logger_service.dart';

/// File system based lock persistence for desktop platforms.
class FileSystemLockPersistence implements pkg.ServerLockPersistence {
  static const _lockFilePrefix = 'theos_pos_lock_';

  @override
  bool get isSupported => true;

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
    final dir = await _getLockDirectory();
    final file = _getLockFile(dir, identifier);
    return file.exists();
  }

  @override
  Future<Map<String, dynamic>?> readLock(String identifier) async {
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
    final locks = <Map<String, dynamic>>[];
    try {
      final lockDir = await _getLockDirectory();
      if (!await lockDir.exists()) return [];

      await for (final file in lockDir.list()) {
        if (file is File && file.path.endsWith('.lock')) {
          try {
            final content = await file.readAsString();
            final data = jsonDecode(content) as Map<String, dynamic>;
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

/// Check if a process is still running (macOS/Linux only).
Future<bool> isProcessRunning(int pid) async {
  try {
    if (Platform.isMacOS || Platform.isLinux) {
      final result = await Process.run('kill', ['-0', pid.toString()]);
      return result.exitCode == 0;
    }
  } catch (_) {}
  return true; // Assume running if we can't check
}
