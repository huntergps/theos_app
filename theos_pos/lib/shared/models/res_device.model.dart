import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

part 'res_device.model.freezed.dart';
part 'res_device.model.g.dart';

/// Odoo model: res.device
@OdooModel('res.device', tableName: 'res_devices')
@freezed
abstract class ResDevice with _$ResDevice, OdooRecord<ResDevice> {
  const ResDevice._();

  // ═══════════════════ OdooRecord Implementation ═══════════════════

  @override
  int get odooId => id;

  @override
  String? get uuid => sessionIdentifier; // Use session identifier as UUID

  @override
  bool get isSynced => true; // Devices are managed by Odoo

  /// Validates the device before saving.
  @override
  Map<String, String> validate() => {}; // Read-only model

  /// Convert to Odoo-compatible map
  @override
  Map<String, dynamic> toOdoo() => {}; // Read-only model

  const factory ResDevice({
    @Default(0) int id,
    String? sessionIdentifier,
    String? platform,
    String? browser,
    String? ipAddress,
    String? country,
    String? city,
    String? deviceType,
    int? userId,
    DateTime? firstActivity,
    DateTime? lastActivity,
    @Default(false) bool revoked,
  }) = _ResDevice;

  factory ResDevice.fromJson(Map<String, dynamic> json) =>
      _$ResDeviceFromJson(json);

  /// Create from Odoo JSON response
  factory ResDevice.fromOdoo(Map<String, dynamic> json) {
    String? safeStr(dynamic val) =>
        (val != null && val != false) ? val.toString() : null;

    return ResDevice(
      id: json['id'] as int,
      sessionIdentifier: safeStr(json['session_identifier']),
      platform: safeStr(json['platform']),
      browser: safeStr(json['browser']),
      ipAddress: safeStr(json['ip_address']),
      country: safeStr(json['country']),
      city: safeStr(json['city']),
      deviceType: safeStr(json['device_type']),
      userId: json['user_id'] is int ? json['user_id'] as int : null,
      firstActivity:
          json['first_activity'] != null && json['first_activity'] != false
              ? DateTime.tryParse('${json['first_activity']}Z')
              : null,
      lastActivity:
          json['last_activity'] != null && json['last_activity'] != false
              ? DateTime.tryParse('${json['last_activity']}Z')
              : null,
      revoked: json['revoked'] == true,
    );
  }

  // ═══════════════════ Computed Fields ═══════════════════

  String get displayName {
    final parts = <String>[];
    if (platform != null) parts.add(platform!);
    if (browser != null) parts.add(browser!);
    return parts.isNotEmpty ? parts.join(' ') : 'Dispositivo desconocido';
  }

  String get location {
    final parts = <String>[];
    if (city != null) parts.add(city!);
    if (country != null) parts.add(country!);
    return parts.isNotEmpty
        ? parts.join(', ')
        : ipAddress ?? 'Ubicación desconocida';
  }

  String getRelativeTime() {
    if (lastActivity == null) return 'Nunca';

    final now = DateTime.now().toUtc();
    final difference = now.difference(lastActivity!);

    if (difference.inMinutes < 1) {
      return 'Ahora';
    } else if (difference.inMinutes < 60) {
      return 'hace ${difference.inMinutes} minutos';
    } else if (difference.inHours < 24) {
      return 'hace ${difference.inHours} horas';
    } else if (difference.inDays < 30) {
      return 'hace ${difference.inDays} días';
    } else {
      return 'hace más de un mes';
    }
  }

  static const List<String> odooFields = [
    'id',
    'session_identifier',
    'platform',
    'browser',
    'ip_address',
    'country',
    'city',
    'device_type',
    'user_id',
    'first_activity',
    'last_activity',
    'revoked',
  ];
}
