import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/app/orbi_splash_screen.dart';
import 'package:theos_panel/ui/components/orbi_brand.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

void main() {
  testWidgets('splash keeps approved photo branding across viewports/themes', (
    tester,
  ) async {
    const sizes = [
      Size(1440, 900),
      Size(1180, 820),
      Size(820, 1180),
      Size(1024, 1366),
      Size(390, 844),
    ];
    for (final theme in [OrbiFluentTheme.light, OrbiFluentTheme.dark]) {
      for (final size in sizes) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          FluentApp(theme: theme, home: const OrbiSplashScreen()),
        );
        await tester.pump();
        expect(find.byKey(const Key('orbi-splash')), findsOneWidget);
        final background = tester.widget<Image>(find.byType(Image));
        expect(background.image, isA<AssetImage>());
        expect(
          (background.image as AssetImage).assetName,
          orbiAuthBackgroundAsset,
        );
        expect(find.byType(ProgressRing), findsOneWidget);
        expect(find.text('Preparando Orbi ERP…'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
    await tester.binding.setSurfaceSize(null);
  });
}
