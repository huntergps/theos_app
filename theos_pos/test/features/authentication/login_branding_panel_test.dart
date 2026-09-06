import 'dart:convert';
import 'dart:typed_data';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/features/authentication/services/branding_service.dart';
import 'package:theos_pos/features/authentication/widgets/login_branding_panel.dart';

final _pixel = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  ),
);

void main() {
  Future<void> pump(
    WidgetTester tester,
    Brightness brightness,
    AppBranding branding,
  ) => tester.pumpWidget(
    FluentApp(
      home: FluentTheme(
        data: FluentThemeData(brightness: brightness),
        child: SizedBox.expand(
          child: LoginBrandingPanel(
            branding: branding,
            child: const Text('Formulario'),
          ),
        ),
      ),
    ),
  );

  testWidgets('default has solid fallback and no image', (tester) async {
    await pump(tester, Brightness.light, const AppBranding());
    expect(find.byKey(const Key('login-branding-background')), findsNothing);
    expect(find.text('Formulario'), findsOneWidget);
  });

  testWidgets('uses cover image and Odoo dark tint weight semantics', (
    tester,
  ) async {
    AppBranding branding(double darkTint) => AppBranding(
      backgroundBytes: _pixel,
      darkBackgroundBytes: _pixel,
      theme: BrandingThemeTokens.fromJson({
        'brand_color': '#336699',
        'dark_tint': darkTint,
      }),
    );
    await pump(tester, Brightness.light, branding(12));
    final decoration = tester.widget<DecoratedBox>(
      find.byKey(const Key('login-branding-background')),
    );
    expect((decoration.decoration as BoxDecoration).image?.fit, BoxFit.cover);

    Future<int> darkVeilAt(double percent) async {
      await pump(tester, Brightness.dark, branding(percent));
      return tester
          .widget<ColoredBox>(find.byKey(const Key('login-branding-veil')))
          .color
          .toARGB32();
    }

    final neutral = await darkVeilAt(0);
    final recommended = await darkVeilAt(12);
    final branded = await darkVeilAt(100);
    expect(neutral, const Color(0x921c1c20).toARGB32());
    expect(recommended, isNot(neutral));
    expect(recommended, isNot(branded));
    expect(branded, const Color(0x92336699).toARGB32());
  });
}
