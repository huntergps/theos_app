import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../dev/operational_shell_gallery.dart';

void main() {
  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF007E82)),
        ),
        home: const OperationalShellGallery(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('compact uses bottom navigation without overflow', (
    tester,
  ) async {
    await pumpAt(tester, const Size(390, 844));

    expect(find.text('Inicio'), findsWidgets);
    expect(find.text('Nueva venta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('medium uses rail and supervisor priorities', (tester) async {
    await pumpAt(tester, const Size(820, 1180));

    await tester.tap(
      find.byWidgetPredicate((widget) => widget is DropdownButton<GalleryRole>),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supervisor').last);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.home_outlined), findsWidgets);
    expect(find.text('Revisar aprobaciones'), findsOneWidget);
    expect(find.text('Ventas del día'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded uses persistent drawer and four metric cards', (
    tester,
  ) async {
    await pumpAt(tester, const Size(1440, 900));

    expect(find.text('OPERACIONES'), findsOneWidget);
    expect(find.text('OPERACIONES'), findsOneWidget);
    expect(find.text('Orbi ERP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
