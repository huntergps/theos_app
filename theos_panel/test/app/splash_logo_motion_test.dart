import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/app/orbi_splash_screen.dart';
import 'package:theos_panel/ui/components/orbi_brand.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';
import 'package:fluent_ui/fluent_ui.dart';

// Orden del dueño, 13-sep-2026: en el splash de Orbi giraba TODO el logo
// (símbolo + texto "ORBI ERP"), porque el `Transform.rotate` envolvía la
// marca combinada entera. En theos_pos sólo gira el símbolo (`TheosLogo`);
// el texto (`TheosNameSvg`) es un widget aparte y queda quieto.
void main() {
  testWidgets(
    'only the orbit symbol rotates; the ORBI ERP wordmark stays static',
    (tester) async {
      await tester.pumpWidget(
        FluentApp(
          theme: OrbiFluentTheme.light,
          home: const OrbiSplashScreen(),
        ),
      );
      await tester.pump();
      // Infinite AnimationController (.repeat()) never settles, so advance a
      // fixed duration instead of pumpAndSettle(), which would hang forever.
      await tester.pump(const Duration(milliseconds: 500));

      final rotatingTransform = find.byKey(const Key('splash-logo-rotation'));

      expect(
        find.ancestor(of: find.byType(OrbiSymbol), matching: rotatingTransform),
        findsOneWidget,
        reason:
            'El símbolo debe girar, igual que TheosLogo en theos_pos: falta '
            'el Transform de rotación como ancestro de OrbiSymbol.',
      );

      expect(
        find.ancestor(
          of: find.byType(OrbiWordmark),
          matching: rotatingTransform,
        ),
        findsNothing,
        reason:
            'El texto "ORBI ERP" no debe girar: el Transform de rotación no '
            'puede ser ancestro de OrbiWordmark.',
      );

      expect(
        find.ancestor(
          of: find.byType(OrbiWordmark),
          matching: find.byType(RotationTransition),
        ),
        findsNothing,
        reason:
            'El texto "ORBI ERP" no debe girar mediante RotationTransition '
            'tampoco.',
      );
    },
  );
}
