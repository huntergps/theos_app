import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

import '../../dev/component_gallery.dart';

import 'package:theos_panel/ui/layouts/orbi_adaptive_layout.dart';

void main() {
  testWidgets('gallery reflows and preserves field state', (tester) async {
    final media = MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2)),
      child: const ComponentGallery(),
    );
    await tester.pumpWidget(
      FluentApp(theme: OrbiFluentTheme.dark, home: media),
    );
    expect(find.bySemanticsLabel('Logo de Orbi ERP'), findsOneWidget);
    final field = find.byType(ReactiveTextField<String>);
    expect(find.text('Cliente ficticio'), findsOneWidget);

    await tester.enterText(field, 'Acme largo');
    for (final width in [599.0, 600.0, 839.0, 840.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpAndSettle();
      expect(
        orbiLayoutSizeFor(width),
        width == 599
            ? OrbiLayoutSize.compact
            : width == 840
            ? OrbiLayoutSize.wide
            : OrbiLayoutSize.medium,
      );
      expect(find.text('Acme largo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}
