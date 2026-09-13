import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:theos_panel/features/sync/offline_queue_screen.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

class _MockOfflineQueuePort extends Mock implements OfflineQueuePort {}

Future<void> _pump(WidgetTester tester, OfflineQueuePort port) async {
  await tester.pumpWidget(
    FluentApp(
      theme: OrbiFluentTheme.light,
      home: ScaffoldPage(content: OfflineQueueScreen(port: port)),
    ),
  );
  // `pumpAndSettle`, no un número fijo de `pump()`: la carga inicial muestra
  // un `ProgressRing` (spinner indeterminado) hasta que `port.load()`
  // resuelve, y un par de `pump()` a ciegas asume cuántos frames hacen
  // falta. `pumpAndSettle` drena microtareas y frames hasta que de verdad
  // no queda nada pendiente — el spinner desaparece en cuanto `load()`
  // resuelve (es rápido, no es una animación permanente), así que no hay
  // riesgo de que nunca se asiente.
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'una operación manual_after_ambiguous no ofrece reintento y sí el aviso '
    'de revisar en Odoo',
    (tester) async {
      final port = _MockOfflineQueuePort();
      final entry = OfflineQueueEntryView(
        operationId: 42,
        documentLabel: 'sale.order #501',
        commandLabel: 'Confirmación de pedido',
        createdAt: DateTime(2026, 9, 1, 10, 30),
        attempts: 3,
        lastError: 'Tiempo de espera agotado',
        bucket: OfflineQueueBucket.manualAfterAmbiguous,
      );
      when(() => port.load()).thenAnswer((_) async => OfflineQueueSnapshot(entries: [entry]));

      await _pump(tester, port);

      expect(entry.canRetry, isFalse);
      expect(find.byKey(const Key('queue-entry-42-retry')), findsNothing);
      expect(find.byKey(const Key('queue-entry-42-discard')), findsOneWidget);
      expect(find.text('Revisa esto en Odoo antes de continuar'), findsOneWidget);
    },
  );

  testWidgets('una operación retry_safe en reintento sí ofrece el botón de reintentar', (
    tester,
  ) async {
    final port = _MockOfflineQueuePort();
    final entry = OfflineQueueEntryView(
      operationId: 7,
      documentLabel: 'account.move #10',
      commandLabel: 'Actualización',
      createdAt: DateTime(2026, 9, 1, 8),
      attempts: 2,
      lastError: 'Servidor no disponible',
      bucket: OfflineQueueBucket.retrySafeFailing,
    );
    when(() => port.load()).thenAnswer((_) async => OfflineQueueSnapshot(entries: [entry]));
    when(() => port.retry(7)).thenAnswer((_) async {});

    await _pump(tester, port);

    expect(find.byKey(const Key('queue-entry-7-retry')), findsOneWidget);
    await tester.tap(find.byKey(const Key('queue-entry-7-retry')));
    // `pumpAndSettle`, no un `pump()` fijo seguido de un número mágico de
    // milisegundos: además del timer de 100ms de `HoverButton` (que agenda
    // al soltar el toque para restablecer su estado de presionado), esto
    // también espera a que termine la cadena real `retry()` → `_refresh()`
    // → `load()` sin adivinar cuántos ciclos hacen falta.
    await tester.pumpAndSettle();
    verify(() => port.retry(7)).called(1);
  });

  testWidgets('sin operaciones pendientes muestra "Todo sincronizado"', (tester) async {
    final port = _MockOfflineQueuePort();
    when(() => port.load()).thenAnswer((_) async => const OfflineQueueSnapshot());

    await _pump(tester, port);

    expect(find.text('Todo sincronizado'), findsOneWidget);
  });
}
