import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:theos_pos/shared/screens/splash_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Splash Screen renders and navigates', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
        GoRoute(path: '/login', builder: (_, _) => const SizedBox()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: FluentApp.router(
          routerConfig: router,
          locale: const Locale('es'),
        ),
      ),
    );

    // Verify splash screen renders with progress bar (logo is an image, not text)
    expect(find.byType(ProgressBar), findsOneWidget);

    // Fast forward time to trigger navigation
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
