import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';
import 'package:theos_panel/ui/shell/desktop_close_guard.dart';

/// Sólo el diálogo, sin `DesktopCloseGuard`: éste habla con `window_manager`
/// por canal de plataforma, que no existe dentro de `flutter test` (ver la
/// nota de la clase). Lo que sí se puede —y debe— probar aquí es el
/// contenido exacto que ve la persona y qué responde cada botón.
Widget _host(VoidCallback onOpen) => FluentApp(
  theme: OrbiFluentTheme.light,
  home: Builder(
    builder: (context) => Button(
      onPressed: () async {
        final confirmed = await showConfirmCloseDialog(context);
        if (confirmed == true) onOpen();
      },
      child: const Text('abrir'),
    ),
  ),
);

void main() {
  testWidgets('pide confirmar cierre con el mismo texto que theos_pos', (
    tester,
  ) async {
    await tester.pumpWidget(_host(() {}));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Confirmar cierre'), findsOneWidget);
    expect(
      find.text('¿Estás seguro de que deseas cerrar la aplicación?'),
      findsOneWidget,
    );
    expect(find.text('No'), findsOneWidget);
    expect(find.text('Sí'), findsOneWidget);
  });

  testWidgets('"No" cierra el diálogo sin confirmar', (tester) async {
    var confirmado = false;
    await tester.pumpWidget(_host(() => confirmado = true));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();

    expect(confirmado, isFalse);
    expect(find.text('Confirmar cierre'), findsNothing);
  });

  testWidgets('"Sí" confirma el cierre', (tester) async {
    var confirmado = false;
    await tester.pumpWidget(_host(() => confirmado = true));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirm-close-yes')));
    await tester.pumpAndSettle();

    expect(confirmado, isTrue);
    expect(find.text('Confirmar cierre'), findsNothing);
  });
}
