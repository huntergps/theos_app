import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/app/orbi_app.dart';
import 'package:theos_panel/app/preferences/app_preferences.dart';

void main() {
  testWidgets('renders the independent Orbi shell', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const OrbiApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Orbi ERP'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
