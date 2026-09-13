import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/app/bootstrap.dart';

/// Measured 12-sep-2026: the web build got stuck on "Preparando Orbi ERP…"
/// for minutes with several Orbi tabs open. The only asynchronous, cross-tab
/// step awaited before the login screen or a restored session was
/// `notificationPresenter.initialize()`, which reaches
/// `serviceWorker.getRegistration()`/`.register()` with no timeout of its
/// own. Notifications are optional; startup must never be their hostage —
/// pin that here with a plugin double that never resolves, and one that
/// throws.
class _HangingNotificationPlugin implements NotificationPluginPort {
  /// Deliberately never completed.
  final Completer<bool> _initializeCompleter = Completer<bool>();

  @override
  Future<bool> initialize() => _initializeCompleter.future;

  @override
  Future<PermissionState> requestPermission() async =>
      PermissionState.unsupported;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {}

  @override
  Future<void> cancel(int id) async {}
}

class _ThrowingNotificationPlugin implements NotificationPluginPort {
  @override
  Future<bool> initialize() =>
      Future<bool>.error(StateError('notification plugin unavailable'));

  @override
  Future<PermissionState> requestPermission() async =>
      PermissionState.unsupported;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {}

  @override
  Future<void> cancel(int id) async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'startup reaches a restored session or the login screen even when the '
    'notification plugin never finishes initializing',
    () async {
      final widget = await buildInitializedApplication(
        notificationPlugin: _HangingNotificationPlugin(),
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException(
          'bootstrap waited on notification initialization instead of '
          'reaching restore/login',
        ),
      );

      expect(widget, isA<ProviderScope>());
    },
  );

  test(
    'startup reaches a restored session or the login screen even when the '
    'notification plugin fails to initialize',
    () async {
      final widget = await buildInitializedApplication(
        notificationPlugin: _ThrowingNotificationPlugin(),
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException(
          'bootstrap did not tolerate a failed notification initialization',
        ),
      );

      expect(widget, isA<ProviderScope>());
    },
  );
}
