import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/app/preferences/app_preferences.dart';

void main() {
  test('text scale supports low-vision magnification up to 200 percent', () {
    final snapshot = const AppPreferencesSnapshot().copyWith(textScale: 2.0);
    expect(snapshot.textScale, 2.0);
  });

  test('text scale remains bounded above the supported range', () {
    final snapshot = const AppPreferencesSnapshot().copyWith(textScale: 3.0);
    expect(snapshot.textScale, 2.0);
  });
}
