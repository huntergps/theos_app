import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../dev/orbi_workspace_concept_a.dart';

void main() {
  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: OrbiWorkspaceConceptA()));
    await tester.pump();
  }

  testWidgets('mobile stays filled and exposes compact navigation', (
    tester,
  ) async {
    await pumpAt(tester, const Size(390, 844));
    expect(find.byKey(const Key('concept-bottom-navigation')), findsOneWidget);
    expect(find.text('Nueva venta'), findsOneWidget);
    expect(find.text('Cola prioritaria'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet uses rail and two content columns', (tester) async {
    await pumpAt(tester, const Size(820, 1180));
    expect(find.byKey(const Key('concept-navigation-rail')), findsOneWidget);
    expect(find.byKey(const Key('concept-side-column')), findsOneWidget);
    await tester.tap(find.byKey(const Key('concept-role-selector')));
    await tester.pump();
    await tester.tap(find.text('Supervisor').last);
    await tester.pump();
    expect(find.text('Todo el equipo, bajo control'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop uses 240px navigation and priority split', (
    tester,
  ) async {
    await pumpAt(tester, const Size(1440, 900));
    expect(find.byKey(const Key('concept-navigation-drawer')), findsOneWidget);
    expect(find.byKey(const Key('concept-priority-queue')), findsOneWidget);
    expect(find.byKey(const Key('concept-side-column')), findsOneWidget);
    expect(find.text('Panel de operaciones'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
