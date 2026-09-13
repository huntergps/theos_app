import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/ui/layouts/workspace_lock_screen.dart';

void main() {
  Future<void> pumpLock(WidgetTester tester, Brightness brightness) async {
    await tester.pumpWidget(
      FluentApp(
        theme: FluentThemeData(brightness: brightness),
        home: WorkspaceLockScreen(
          userLabel: 'vendedor@orbi',
          pendingSummary: '3 pendientes',
          onUnlock: (_) async => false,
        ),
      ),
    );
    await tester.pump();
  }

  void expectOpaqueMicaBackground(WidgetTester tester) {
    final coloredBox = tester.widget<ColoredBox>(
      find
          .descendant(
            of: find.byType(WorkspaceLockScreen),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    final theme = FluentTheme.of(
      tester.element(find.byType(WorkspaceLockScreen)),
    );
    expect(
      coloredBox.color.a,
      1.0,
      reason:
          'la pantalla de bloqueo es una compuerta de privacidad: un fondo '
          'translúcido deja ver Inicio por debajo',
    );
    expect(
      coloredBox.color,
      theme.micaBackgroundColor,
      reason: 'debe usar el fondo opaco de Fluent, no el del scaffold',
    );
  }

  testWidgets('con tema claro, el fondo de la pantalla bloqueada es opaco', (
    tester,
  ) async {
    await pumpLock(tester, Brightness.light);
    expectOpaqueMicaBackground(tester);
  });

  testWidgets('con tema oscuro, el fondo de la pantalla bloqueada es opaco', (
    tester,
  ) async {
    await pumpLock(tester, Brightness.dark);
    expectOpaqueMicaBackground(tester);
  });
}
