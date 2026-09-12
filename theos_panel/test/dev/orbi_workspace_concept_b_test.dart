import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../dev/orbi_workspace_concept_b.dart';

void main() {
  for (final size in const [Size(390, 844), Size(820, 1180), Size(1440, 900)]) {
    testWidgets('concept B adapts at ${size.width.toInt()}px', (tester) async {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(const MaterialApp(home: OrbiWorkspaceConceptB()));
      await tester.pump();
      expect(
        find.text('ORBI'),
        size.width < 600 ? findsNothing : findsOneWidget,
      );
      expect(find.text('Trabajo prioritario'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
