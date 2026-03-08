/// Device Service - App Integration
///
/// This file provides Riverpod providers that wrap the generic DeviceService
/// from odoo_offline_core with SharedPreferences persistence.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

// Re-export types from package for backward compatibility
export 'package:odoo_sdk/odoo_sdk.dart'
    show DeviceService, DeviceIdPersistence, UuidGenerator;

// ============================================================================
// FACTORY FUNCTION (for use outside provider context)
// ============================================================================

/// Creates a DeviceService with default SharedPreferences persistence.
/// Use this when you need a DeviceService outside of Riverpod context.
///
/// For normal usage within widgets/providers, use [deviceServiceProvider] instead.
DeviceService createDeviceService() {
  return DeviceService(
    persistence: _SharedPrefsDevicePersistence(),
    generateUuid: () => const Uuid().v4(),
  );
}

// ============================================================================
// SHARED PREFERENCES IMPLEMENTATION
// ============================================================================

/// SharedPreferences-based persistence for device identification
class _SharedPrefsDevicePersistence implements DeviceIdPersistence {
  static const _keyDeviceId = 'device_id';
  static const _keyDeviceName = 'device_name';
  static const _keyDeviceCreatedAt = 'device_created_at';

  @override
  Future<String?> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDeviceId);
  }

  @override
  Future<void> setDeviceId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDeviceId, id);
  }

  @override
  Future<String?> getDeviceName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDeviceName);
  }

  @override
  Future<void> setDeviceName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDeviceName, name);
  }

  @override
  Future<DateTime?> getDeviceCreatedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyDeviceCreatedAt);
    return str != null ? DateTime.tryParse(str) : null;
  }

  @override
  Future<void> setDeviceCreatedAt(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDeviceCreatedAt, date.toIso8601String());
  }

  @override
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDeviceId);
    await prefs.remove(_keyDeviceName);
    await prefs.remove(_keyDeviceCreatedAt);
  }
}

// ============================================================================
// PROVIDERS
// ============================================================================

/// Provider for DeviceService (singleton per app instance)
final deviceServiceProvider = Provider<DeviceService>((ref) {
  return DeviceService(
    persistence: _SharedPrefsDevicePersistence(),
    generateUuid: () => const Uuid().v4(),
  );
});

/// Provider for device ID (async) - persistent across restarts
final deviceIdProvider = FutureProvider<String>((ref) async {
  final deviceService = ref.watch(deviceServiceProvider);
  return deviceService.getDeviceId();
});

/// Provider for instance ID (sync) - unique per app execution
final instanceIdProvider = Provider<String>((ref) {
  final deviceService = ref.watch(deviceServiceProvider);
  return deviceService.getInstanceId();
});

/// Provider for full instance ID (async) - "deviceId:instanceId"
final fullInstanceIdProvider = FutureProvider<String>((ref) async {
  final deviceService = ref.watch(deviceServiceProvider);
  return deviceService.getFullInstanceId();
});

/// Provider for device name (async)
final deviceNameProvider = FutureProvider<String>((ref) async {
  final deviceService = ref.watch(deviceServiceProvider);
  return deviceService.getDeviceName();
});

/// Provider for full device info (async)
final deviceInfoProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final deviceService = ref.watch(deviceServiceProvider);
  return deviceService.getDeviceInfo();
});
