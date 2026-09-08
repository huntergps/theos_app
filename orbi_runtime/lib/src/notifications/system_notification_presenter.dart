import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show
        NotificationCapabilities,
        NotificationCapability,
        NotificationChannel,
        NotificationPermission,
        NotificationScope,
        NotificationTarget;

enum NotificationPlatform { web, android, ios, macos, linux, windows, other }

enum PermissionState { granted, denied, unsupported }

enum SystemDeliveryState { shown, denied, unsupported, failed }

final class SystemNotificationRequest {
  SystemNotificationRequest({
    required this.scope,
    required this.target,
    required String entryId,
    required int revision,
    required this.channel,
    required String title,
    required String body,
  }) : entryId = _nonEmpty(entryId, 'entryId'),
       revision = _nonNegative(revision, 'revision'),
       title = _nonEmpty(title, 'title'),
       body = _nonEmpty(body, 'body');

  final NotificationScope scope;
  final NotificationTarget target;
  final String entryId;
  final int revision;
  final NotificationChannel channel;
  final String title;
  final String body;

  String get payload => jsonEncode({
    'v': 1,
    'entry': entryId,
    'target': {'type': target.type, 'reference': target.reference},
    'scope': scope.scopeKey,
    'partition': scope.partitionKey,
    'revision': revision,
  });
}

abstract interface class SystemIdPort {
  Future<int?> lookup({
    required String scopeKey,
    required String entryId,
    required NotificationChannel channel,
  });
}

abstract interface class NotificationPluginPort {
  Future<bool> initialize();
  Future<PermissionState> requestPermission();
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
  });
  Future<void> cancel(int id);
}

final class FlutterLocalNotificationPlugin implements NotificationPluginPort {
  FlutterLocalNotificationPlugin({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<bool> initialize() async {
    final result = await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permission prompts are an explicit user action in the app. The
        // plugin defaults these flags to true, which would prompt during
        // bootstrap on iOS/macOS merely by calling initialize().
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
          requestProvisionalPermission: false,
          requestCriticalPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
          requestProvisionalPermission: false,
          requestCriticalPermission: false,
        ),
        linux: LinuxInitializationSettings(defaultActionName: 'Open'),
        windows: WindowsInitializationSettings(
          appName: 'Orbi ERP',
          appUserModelId: 'OrbiERP.Panel',
          guid: '2f8f0e49-7294-4c4b-8b23-2d4f8de4d8a1',
        ),
        web: WebInitializationSettings(),
      ),
    );
    return result ?? false;
  }

  @override
  Future<PermissionState> requestPermission() async {
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows) {
      return PermissionState.unsupported;
    }
    final implementation = defaultTargetPlatform == TargetPlatform.android
        ? _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
        : defaultTargetPlatform == TargetPlatform.iOS
        ? _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
        : _plugin
              .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin
              >();
    if (implementation is AndroidFlutterLocalNotificationsPlugin) {
      return (await implementation.requestNotificationsPermission() ?? false)
          ? PermissionState.granted
          : PermissionState.denied;
    }
    if (implementation is IOSFlutterLocalNotificationsPlugin) {
      return (await implementation.requestPermissions()) == true
          ? PermissionState.granted
          : PermissionState.denied;
    }
    if (implementation is MacOSFlutterLocalNotificationsPlugin) {
      return (await implementation.requestPermissions()) == true
          ? PermissionState.granted
          : PermissionState.denied;
    }
    return PermissionState.unsupported;
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) => _plugin.show(
    id: id,
    title: title,
    body: body,
    payload: payload,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails('orbi', 'Orbi ERP'),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
      linux: LinuxNotificationDetails(),
      windows: WindowsNotificationDetails(),
      web: WebNotificationDetails(),
    ),
  );

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);
}

final class SystemNotificationPresenter {
  SystemNotificationPresenter(
    this._plugin,
    this._systemIds, {
    required this.activeScopeKey,
    NotificationPlatform? platform,
  }) : capabilities = _capabilities(platform ?? _platform());

  final NotificationPluginPort _plugin;
  final SystemIdPort _systemIds;
  final String activeScopeKey;
  final NotificationCapabilities capabilities;
  bool _initialized = false;

  Future<bool> initialize() async {
    _initialized = await _plugin.initialize();
    return _initialized;
  }

  Future<PermissionState> requestPermissionFromUserAction() async {
    if (capabilities.permission == NotificationPermission.unsupported) {
      return PermissionState.unsupported;
    }
    return _plugin.requestPermission();
  }

  Future<SystemDeliveryState> showOrReplace(
    SystemNotificationRequest request,
  ) async {
    if (!_initialized || !capabilities.supports(NotificationCapability.show)) {
      return SystemDeliveryState.unsupported;
    }
    if (request.scope.scopeKey != activeScopeKey) {
      return SystemDeliveryState.denied;
    }
    final id = await _systemIds.lookup(
      scopeKey: request.scope.scopeKey,
      entryId: request.entryId,
      channel: request.channel,
    );
    if (id == null) return SystemDeliveryState.unsupported;
    try {
      await _plugin.show(
        id: id,
        title: request.title,
        body: request.body,
        payload: request.payload,
      );
      return SystemDeliveryState.shown;
    } catch (_) {
      return SystemDeliveryState.failed;
    }
  }

  Future<SystemDeliveryState> cancel({
    required String scopeKey,
    required String entryId,
    required NotificationChannel channel,
  }) async {
    if (!_initialized ||
        !capabilities.supports(NotificationCapability.cancel)) {
      return SystemDeliveryState.unsupported;
    }
    if (scopeKey != activeScopeKey) return SystemDeliveryState.denied;
    final id = await _systemIds.lookup(
      scopeKey: scopeKey,
      entryId: entryId,
      channel: channel,
    );
    if (id == null) return SystemDeliveryState.unsupported;
    try {
      await _plugin.cancel(id);
      return SystemDeliveryState.shown;
    } catch (_) {
      return SystemDeliveryState.failed;
    }
  }

  static NotificationPlatform _platform() {
    if (kIsWeb) return NotificationPlatform.web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => NotificationPlatform.android,
      TargetPlatform.iOS => NotificationPlatform.ios,
      TargetPlatform.macOS => NotificationPlatform.macos,
      TargetPlatform.linux => NotificationPlatform.linux,
      TargetPlatform.windows => NotificationPlatform.windows,
      _ => NotificationPlatform.other,
    };
  }

  static NotificationCapabilities _capabilities(NotificationPlatform platform) {
    final native = switch (platform) {
      NotificationPlatform.android ||
      NotificationPlatform.ios ||
      NotificationPlatform.macos => true,
      _ => false,
    };
    final show = platform != NotificationPlatform.other;
    return NotificationCapabilities(
      supported: {
        if (show) NotificationCapability.show,
        if (native) ...{
          NotificationCapability.actions,
          NotificationCapability.launchHandling,
          NotificationCapability.schedule,
        },
        if (show) NotificationCapability.cancel,
      },
      permission: native
          ? NotificationPermission.supported
          : NotificationPermission.unsupported,
    );
  }
}

String _nonEmpty(String value, String name) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be empty');
  }
  return trimmed;
}

int _nonNegative(int value, String name) {
  if (value < 0) throw ArgumentError.value(value, name, 'Must not be negative');
  return value;
}
