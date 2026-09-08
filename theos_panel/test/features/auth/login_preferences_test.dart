import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/features/auth/login_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('restores server database and user without storing a secret', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = LoginPreferencesStore(preferences);

    await store.save(
      const LoginPreferences(
        serverUrl: 'https://erp2.example.test',
        database: 'erp2_test',
        login: 'cashier',
      ),
    );

    expect(
      store.load().toJson(),
      containsPair('serverUrl', 'https://erp2.example.test'),
    );
    expect(store.load().database, 'erp2_test');
    expect(store.load().login, 'cashier');
    expect(
      preferences.getString(LoginPreferencesStore.key),
      isNot(contains('password')),
    );
    expect(
      preferences.getString(LoginPreferencesStore.key),
      isNot(contains('apiKey')),
    );
  });

  test('ignores corrupt persisted values', () async {
    SharedPreferences.setMockInitialValues({
      LoginPreferencesStore.key: '{broken',
    });
    final preferences = await SharedPreferences.getInstance();

    expect(LoginPreferencesStore(preferences).load().isEmpty, isTrue);
  });
}
