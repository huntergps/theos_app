/// Device Service (Generic)
///
/// Manages device and instance identification for multi-device tracking
/// and offline operation attribution.
///
/// This is a framework-agnostic implementation that uses dependency injection
/// for persistence.
library;

import 'logger_service.dart';

// ============================================================================
// PERSISTENCE INTERFACE
// ============================================================================

/// Interface for persisting device identification data
abstract class DeviceIdPersistence {
  /// Get stored device ID (null if not set)
  Future<String?> getDeviceId();

  /// Store device ID
  Future<void> setDeviceId(String id);

  /// Get stored device name (null if not set)
  Future<String?> getDeviceName();

  /// Store device name
  Future<void> setDeviceName(String name);

  /// Get stored device creation date (null if not set)
  Future<DateTime?> getDeviceCreatedAt();

  /// Store device creation date
  Future<void> setDeviceCreatedAt(DateTime date);

  /// Clear all device data
  Future<void> clearAll();
}

/// Callback to generate a UUID
typedef UuidGenerator = String Function();

// ============================================================================
// DEVICE SERVICE (Generic)
// ============================================================================

/// Service for managing device and instance identification.
///
/// ## Identifiers
/// - **deviceId**: Unique per device, persisted via [DeviceIdPersistence]
/// - **instanceId**: Unique per app instance/window, generated at startup
/// - **fullInstanceId**: Combination of both for complete identification
///
/// ## Usage
/// ```dart
/// final service = DeviceService(
///   persistence: MyDevicePersistence(),
///   generateUuid: () => Uuid().v4(),
/// );
///
/// final fullId = await service.getFullInstanceId();
/// // Result: "abc-123-def:a1b2c3d4" (deviceId:instanceId)
/// ```
class DeviceService {
  final DeviceIdPersistence _persistence;
  final UuidGenerator _generateUuid;

  String? _cachedDeviceId;
  String? _cachedDeviceName;
  DateTime? _cachedCreatedAt;

  /// Instance ID unique to this app execution
  /// Generated at startup and NOT persisted
  late final String _instanceId;

  /// Timestamp when this instance started
  late final DateTime _instanceStartedAt;

  DeviceService({
    required DeviceIdPersistence persistence,
    required UuidGenerator generateUuid,
  })  : _persistence = persistence,
        _generateUuid = generateUuid {
    // Generate unique instanceId for this execution
    // Use last 8 characters of UUID to keep it short
    final uuid = _generateUuid();
    _instanceId = uuid.length > 8 ? uuid.substring(uuid.length - 8) : uuid;
    _instanceStartedAt = DateTime.now();
    logger.d('[DeviceService]', 'Instance ID generated: $_instanceId');
  }

  /// Get or generate a unique device ID.
  /// This ID is persistent across app restarts.
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    var deviceId = await _persistence.getDeviceId();

    if (deviceId == null) {
      deviceId = _generateUuid();
      await _persistence.setDeviceId(deviceId);
      await _persistence.setDeviceCreatedAt(DateTime.now());
      logger.d('[DeviceService]', 'New device ID generated: $deviceId');
    } else {
      logger.d('[DeviceService]', 'Device ID loaded: $deviceId');
    }

    _cachedDeviceId = deviceId;
    return deviceId;
  }

  /// Get device name (user-configurable)
  Future<String> getDeviceName() async {
    if (_cachedDeviceName != null) {
      return _cachedDeviceName!;
    }

    var deviceName = await _persistence.getDeviceName();

    if (deviceName == null) {
      deviceName = 'Device ${DateTime.now().millisecondsSinceEpoch % 10000}';
      await _persistence.setDeviceName(deviceName);
    }

    _cachedDeviceName = deviceName;
    return deviceName;
  }

  /// Set device name
  Future<void> setDeviceName(String name) async {
    await _persistence.setDeviceName(name);
    _cachedDeviceName = name;
    logger.d('[DeviceService]', 'Device name updated: $name');
  }

  /// Get device creation date
  Future<DateTime?> getDeviceCreatedAt() async {
    if (_cachedCreatedAt != null) {
      return _cachedCreatedAt;
    }

    _cachedCreatedAt = await _persistence.getDeviceCreatedAt();
    return _cachedCreatedAt;
  }

  /// Get the instance ID (unique per app execution/window).
  /// This is NOT persisted - each instance gets a new one.
  String getInstanceId() => _instanceId;

  /// Get when this instance started
  DateTime getInstanceStartedAt() => _instanceStartedAt;

  /// Get the full instance identifier combining device + instance.
  /// Format: "deviceId:instanceId" (e.g., "abc-123-def:a1b2c3d4")
  Future<String> getFullInstanceId() async {
    final deviceId = await getDeviceId();
    return '$deviceId:$_instanceId';
  }

  /// Check if a fullInstanceId belongs to this instance
  Future<bool> isOwnInstance(String fullInstanceId) async {
    final ownFullId = await getFullInstanceId();
    return fullInstanceId == ownFullId;
  }

  /// Check if a fullInstanceId belongs to this device (any instance)
  Future<bool> isOwnDevice(String fullInstanceId) async {
    final deviceId = await getDeviceId();
    return fullInstanceId.startsWith('$deviceId:');
  }

  /// Get device info as a map (useful for sending to server)
  Future<Map<String, dynamic>> getDeviceInfo() async {
    return {
      'device_id': await getDeviceId(),
      'device_name': await getDeviceName(),
      'instance_id': _instanceId,
      'full_instance_id': await getFullInstanceId(),
      'created_at': (await getDeviceCreatedAt())?.toIso8601String(),
      'instance_started_at': _instanceStartedAt.toIso8601String(),
    };
  }

  /// Reset device ID (useful for testing or device transfer).
  /// WARNING: This will create a new device identity.
  Future<void> resetDeviceId() async {
    await _persistence.clearAll();
    _cachedDeviceId = null;
    _cachedDeviceName = null;
    _cachedCreatedAt = null;
    logger.w('[DeviceService]', 'Device ID reset');
  }
}
