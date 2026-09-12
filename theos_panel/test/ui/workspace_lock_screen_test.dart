import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/ui/layouts/workspace_lock_screen.dart';

void main() {
  Future<void> pumpLock(
    WidgetTester tester, {
    Future<bool> Function(String password)? onUnlock,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: WorkspaceLockScreen(
          userLabel: 'vendedor@orbi',
          pendingSummary: '3 pendientes',
          onUnlock: onUnlock ?? (_) async => false,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> attempt(WidgetTester tester, String password) async {
    if (password.isNotEmpty) {
      await tester.enterText(
        find.byKey(const Key('workspace-lock-password')),
        password,
      );
    }
    await tester.tap(find.byKey(const Key('workspace-unlock-button')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'un intento fallido se muestra en la superficie de error del tema, con '
    'icono y las dos mitades: qué pasó y qué hacer — no una frase roja',
    (tester) async {
      await pumpLock(tester);
      await attempt(tester, 'equivocada');

      expect(find.text('No se pudo verificar la contraseña'), findsOneWidget);
      expect(
        find.textContaining('Si la cambiaste hace poco'),
        findsOneWidget,
        reason: 'la segunda mitad dice qué hacer, no sólo qué falló',
      );
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      final colors = ThemeData(useMaterial3: true).colorScheme;
      final surface = tester.widget<DecoratedBox>(
        find.ancestor(
          of: find.byIcon(Icons.error_outline),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(
        (surface.decoration as BoxDecoration).color,
        colors.errorContainer,
        reason: 'usa el contenedor de error del tema, no un rojo suelto',
      );
    },
  );

  testWidgets(
    'el fallo se anuncia a lectores de pantalla con las dos mitades en una '
    'sola región viva, sin que el lector lea el panel dos veces',
    (tester) async {
      final handle = tester.ensureSemantics();
      await pumpLock(tester);
      await attempt(tester, 'equivocada');

      final finder = find.bySemanticsLabel(
        RegExp('No se pudo verificar la contraseña.*conexión'),
      );
      expect(finder, findsOneWidget, reason: 'las dos mitades en una etiqueta');
      expect(tester.getSemantics(finder), isSemantics(isLiveRegion: true));
      // Disposed inside the body, not in a tearDown: flutter_test verifies
      // handles before tearDowns run.
      handle.dispose();
    },
  );

  testWidgets(
    'dejar la contraseña vacía recibe el mismo trato, no un mensaje de '
    'segunda clase',
    (tester) async {
      await pumpLock(tester);
      await attempt(tester, '');

      expect(find.text('Falta tu contraseña'), findsOneWidget);
      expect(find.textContaining('Escríbela'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    },
  );

  testWidgets('un desbloqueo correcto no deja ningún panel de error detrás', (
    tester,
  ) async {
    await pumpLock(tester, onUnlock: (password) async => password == 'buena');
    await attempt(tester, 'equivocada');
    expect(find.byIcon(Icons.error_outline), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('workspace-lock-password')),
      'buena',
    );
    await tester.tap(find.byKey(const Key('workspace-unlock-button')));
    // Deliberately `pump`, never `pumpAndSettle`: on success this screen stays
    // in its submitting state — with the spinner turning — because in the real
    // app the shell is what removes it. Settling here would wait forever on
    // that animation, which is the correct behaviour, not a defect.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byIcon(Icons.error_outline), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets(
    'la pantalla bloqueada nunca muestra servidor ni base de datos, ni '
    'siquiera cuando falla',
    (tester) async {
      await pumpLock(tester);
      await attempt(tester, 'equivocada');

      expect(find.textContaining('erp'), findsNothing);
      expect(find.textContaining('orbi_demo'), findsNothing);
      expect(find.textContaining('https://'), findsNothing);
    },
  );
}
