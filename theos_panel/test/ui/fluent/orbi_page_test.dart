import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/app/theme/orbi_theme.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';
import 'package:theos_panel/ui/fluent/orbi_page.dart';

/// El marco Fluent de Orbi, comprobado contra el estándar escrito en
/// `SHELL_AND_INTERACTION_SPEC.md`, no contra el gusto de quien lo escribió.
void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget page, {
    Size size = const Size(1440, 900),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      FluentApp(theme: OrbiFluentTheme.light, home: page),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('el título y el subtítulo se ven, y el código de pantalla no', (
    tester,
  ) async {
    await pump(
      tester,
      const OrbiPage(
        title: 'Órdenes y cotizaciones',
        subtitle: 'Lo que está pendiente de cobrar y de despachar',
        child: Text('contenido'),
      ),
    );

    expect(find.text('Órdenes y cotizaciones'), findsOneWidget);
    expect(
      find.text('Lo que está pendiente de cobrar y de despachar'),
      findsOneWidget,
    );
    // El código de lámina es control de calidad, no producto. Si alguien lo
    // mete en el título, esto lo caza.
    expect(find.textContaining('VEN-01'), findsNothing);
  });

  testWidgets('sin acciones no dibuja una barra de acciones vacía', (
    tester,
  ) async {
    await pump(
      tester,
      const OrbiPage(title: 'Detalle', child: Text('contenido')),
    );

    expect(find.byType(CommandBar), findsNothing);
  });

  // El recorte silencioso es lo que deja botones inalcanzables en tableta: la
  // barra tiene que plegarse, no cortarse.
  testWidgets('las acciones se pliegan solas cuando la ventana estrecha', (
    tester,
  ) async {
    final page = OrbiPage(
      title: 'Caja',
      commands: [
        for (final label in [
          'Nuevo cobro',
          'Depósito',
          'Retención',
          'Arqueo',
          'Cerrar turno',
          'Exportar a Excel',
        ])
          CommandBarButton(
            icon: const Icon(FluentIcons.add),
            label: Text(label),
            onPressed: () {},
          ),
      ],
      child: const Text('contenido'),
    );

    await pump(tester, page, size: const Size(700, 900));

    final bar = tester.widget<CommandBar>(find.byType(CommandBar));
    expect(bar.overflowBehavior, CommandBarOverflowBehavior.dynamicOverflow);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'el par de acciones va secundario a la izquierda y primario a la derecha',
    (tester) async {
      await pump(
        tester,
        OrbiPage(
          title: 'Cobro',
          child: OrbiActionBar(
            primaryLabel: 'Confirmar',
            onPrimary: () {},
            onSecondary: () {},
          ),
        ),
      );

      final secundario = tester.getCenter(find.text('Cancelar'));
      final primario = tester.getCenter(find.text('Confirmar'));
      expect(
        secundario.dx < primario.dx,
        isTrue,
        reason:
            'Las 39 láminas ponen el secundario a la izquierda. Invertirlo es '
            'como se cancela creyendo que se confirma.',
      );
    },
  );

  testWidgets('un primario deshabilitado se ve, no desaparece', (tester) async {
    await pump(
      tester,
      const OrbiPage(
        title: 'Cobro',
        child: OrbiActionBar(primaryLabel: 'Confirmar', onPrimary: null),
      ),
    );

    expect(find.text('Confirmar'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  test('el color de acento sale de la marca, no de una segunda semilla', () {
    // Dos semillas distintas darían dos productos distintos en la misma
    // ventana mientras convivan las dos interfaces.
    expect(OrbiFluentTheme.accent.toString(), contains('AccentColor'));
    expect(OrbiFluentTheme.light.accentColor.normal, isNotNull);
    expect(
      OrbiFluentTheme.accent.normal.toARGB32(),
      OrbiTheme.brand.toAccentColor().normal.toARGB32(),
    );
  });
}
