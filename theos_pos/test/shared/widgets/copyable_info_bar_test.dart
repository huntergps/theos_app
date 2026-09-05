import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/shared/widgets/dialogs/copyable_info_bar.dart';

void main() {
  for (final size in [const Size(800, 600), const Size(390, 500)]) {
    testWidgets('long errors remain scrollable at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final message = List.filled(60, 'Detalle de conexión de prueba.').join('\n');
      await tester.pumpWidget(
        FluentApp(
          home: ScaffoldPage(
            content: Builder(
              builder: (context) => Button(
                onPressed: () => CopyableInfoBar.showError(
                  context,
                  title: 'Error de conexión',
                  message: message,
                ),
                child: const Text('Mostrar'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mostrar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.byType(SelectableText), findsOneWidget);
      final scroll = find.descendant(
        of: find.byType(InfoBar),
        matching: find.byType(SingleChildScrollView),
      );
      expect(scroll, findsOneWidget);
      await tester.drag(scroll, const Offset(0, -200));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();
    });
  }
}
