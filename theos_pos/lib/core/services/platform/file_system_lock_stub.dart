/// Web stub — no file system lock support.
library;

import 'package:odoo_sdk/odoo_sdk.dart' as pkg;

/// No-op lock persistence for web.
class FileSystemLockPersistence implements pkg.ServerLockPersistence {
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

/// Stub — always assume process is running.
Future<bool> isProcessRunning(int pid) async => true;
