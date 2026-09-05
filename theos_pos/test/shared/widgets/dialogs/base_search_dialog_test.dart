import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/shared/widgets/dialogs/base_search_dialog.dart';

Widget _testApp(Future<List<String>> Function(String query) search) {
  return ProviderScope(
    child: FluentApp(
      home: ScaffoldPage(
        content: SimpleSearchDialog<String>(
          config: const SearchDialogConfig(title: 'Buscar', debounceMs: 0),
          onSearch: (_, query) => search(query),
          buildItem: (_, item, onSelect) =>
              Button(onPressed: onSelect, child: Text(item)),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('an older request cannot clear the current loading state', (
    tester,
  ) async {
    final requests = <String, Completer<List<String>>>{};
    await tester.pumpWidget(
      _testApp((query) {
        final completer = Completer<List<String>>();
        requests[query] = completer;
        return completer.future;
      }),
    );

    await tester.enterText(find.byType(TextBox), 'primera');
    await tester.pump();
    await tester.pump();
    expect(requests, contains('primera'));

    await tester.enterText(find.byType(TextBox), 'segunda');
    await tester.pump();
    await tester.pump();
    expect(requests, contains('segunda'));

    requests['primera']!.complete(const ['resultado obsoleto']);
    await tester.pump();
    expect(find.byType(ProgressRing), findsOneWidget);
    expect(find.text('resultado obsoleto'), findsNothing);

    requests['segunda']!.complete(const ['resultado vigente']);
    await tester.pumpAndSettle();
    expect(find.byType(ProgressRing), findsNothing);
    expect(find.text('resultado vigente'), findsOneWidget);
  });

  testWidgets('a failed search shows an error and retry action', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp((_) => Future<List<String>>.error(StateError('boom'))),
    );

    await tester.enterText(find.byType(TextBox), 'producto');
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text('Ocurrió un error inesperado. Intenta nuevamente.'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('No se encontraron resultados'), findsNothing);
  });
}
