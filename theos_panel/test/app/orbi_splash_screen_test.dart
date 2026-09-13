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
        // ProgressBar (the line), not ProgressRing (the circle) — matches
        // theos_pos's own splash screen (orden del dueño, 12-sep-2026).
        expect(find.byType(ProgressBar), findsOneWidget);
        expect(find.byType(ProgressRing), findsNothing);
        expect(find.text('Preparando Orbi ERP…'), findsOneWidget);
        // ScaffoldPage's own default padding is 24px top, painted with
        // scaffoldBackgroundColor UNDER the content — a solid strip showing
        // above the photo. orbi_splash_screen.dart sets
        // `padding: EdgeInsets.zero` precisely so the photo starts at y=0.
        expect(tester.getTopLeft(find.byType(OrbiAuthBackdrop)).dy, 0.0);
        expect(tester.takeException(), isNull);
      }
    }
    await tester.binding.setSurfaceSize(null);
  });

  // Both tests below read the rendered Transform's matrix rather than the
  // AnimationController's own `.value` — asserting what the screen actually
  // draws, not an implementation detail. An infinite AnimationController
  // (`.repeat()`) never settles, so `pump(Duration)` is used instead of
  // `pumpAndSettle()`, which would hang forever waiting for it to finish.

  testWidgets('the brand logo spins while the platform allows animations', (
    tester,
  ) async {
    await tester.pumpWidget(
      FluentApp(theme: OrbiFluentTheme.light, home: const OrbiSplashScreen()),
    );
    await tester.pump();
    final before = tester
        .widget<Transform>(find.byKey(const Key('splash-logo-rotation')))
        .transform;
    await tester.pump(const Duration(seconds: 5));
    final after = tester
        .widget<Transform>(find.byKey(const Key('splash-logo-rotation')))
        .transform;
    expect(
      after,
      isNot(equals(before)),
      reason: 'The logo did not rotate over 5 elapsed seconds.',
    );
  });

  testWidgets(
    'the brand logo does NOT spin when the platform disables animations',
    (tester) async {
      // Wrapping the app in an outer MediaQuery override is the standard way
      // to force MediaQueryData.disableAnimations in a widget test: the test
      // harness's own View sits above this, so this override is the nearest
      // ancestor OrbiSplashScreen actually reads.
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: FluentApp(home: OrbiSplashScreen()),
        ),
      );
      await tester.pump();
      final before = tester
          .widget<Transform>(find.byKey(const Key('splash-logo-rotation')))
          .transform;
      await tester.pump(const Duration(seconds: 5));
      final after = tester
          .widget<Transform>(find.byKey(const Key('splash-logo-rotation')))
          .transform;
      expect(
        after,
        equals(before),
        reason:
            'The logo kept rotating with disableAnimations set — reduce '
            'motion was not respected.',
      );
    },
  );
}
