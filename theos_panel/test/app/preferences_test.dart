import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/app/preferences/app_preferences.dart';

void main() {
  test('preferences persist and remain isolated by scope', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final a = AppPreferencesStore(
      preferences: prefs,
      scope: const PreferencesScope(appId: 'panel', scopeKey: 'a'),
    );
    final b = AppPreferencesStore(
      preferences: prefs,
      scope: const PreferencesScope(appId: 'panel', scopeKey: 'b'),
    );
    await a.save(
      const AppPreferencesSnapshot(
        themeMode: PreferenceThemeMode.dark,
        syncRetries: 5,
      ),
    );
    expect((await a.load()).themeMode, PreferenceThemeMode.dark);
    expect((await b.load()).themeMode, PreferenceThemeMode.system);
  });
}
