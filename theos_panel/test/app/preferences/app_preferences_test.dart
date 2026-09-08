import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/app/preferences/app_preferences.dart';
import 'package:theos_panel/app/theme/orbi_theme.dart';

void main() {
  test('preferences survive recreation and stay isolated by scope', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final firstScope = PreferencesScope(appId: 'panel', scopeKey: 'user-a');
    final secondScope = PreferencesScope(appId: 'panel', scopeKey: 'user-b');
    final first = AppPreferencesController(
      AppPreferencesStore(preferences: preferences, scope: firstScope),
    );
    await first.load();
    await first.setTheme(PreferenceThemeMode.dark);
    await first.setTextScale(1.8);
    final recreated = AppPreferencesController(
      AppPreferencesStore(preferences: preferences, scope: firstScope),
    );
    await recreated.load();
    expect(recreated.snapshot.themeMode, PreferenceThemeMode.dark);
    expect(recreated.snapshot.textScale, 1.8);
    final other = AppPreferencesController(
      AppPreferencesStore(preferences: preferences, scope: secondScope),
    );
    await other.load();
    expect(other.snapshot.themeMode, PreferenceThemeMode.system);
  });

  test('theme mode maps to Material and seed uses official ColorScheme', () {
    const snapshot = AppPreferencesSnapshot(
      themeMode: PreferenceThemeMode.dark,
      textScale: 1.15,
    );
    expect(snapshot.materialThemeMode, ThemeMode.dark);
    final theme = OrbiTheme.fromSeed(const Color(0xFF6750A4), Brightness.dark);
    expect(theme.colorScheme.primary, isNotNull);
    expect(snapshot.textScale, 1.15);
  });

  test('permission denial is returned only through explicit action', () async {
    final plugin = _Plugin()..permission = PermissionState.denied;
    final presenter = SystemNotificationPresenter(
      plugin,
      _Ids(),
      activeScopeKey: 'scope',
      platform: NotificationPlatform.android,
    );
    await presenter.initialize();
    final action = NotificationPermissionAction(presenter);
    expect(await action.requestFromUserGesture(), PermissionState.denied);
  });
}

final class _Plugin implements NotificationPluginPort {
  PermissionState permission = PermissionState.granted;
  @override
  Future<bool> initialize() async => true;
  @override
  Future<PermissionState> requestPermission() async => permission;
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

final class _Ids implements SystemIdPort {
  @override
  Future<int?> lookup({
    required String scopeKey,
    required String entryId,
    required NotificationChannel channel,
  }) async => 1;
}
