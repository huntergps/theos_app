import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/features/envases/envases_recibir_form.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

/// Cubre la queja del dueño del 14-sep-2026 (revisión visual contra las
/// láminas aprobadas): la cifra de «Enviados» se veía más chica que sus
/// vecinas «Aptos»/«Pendiente» en el mismo formulario de recepción.
///
/// Causa raíz: «Aptos»/«Pendiente» usan `typography.bodyStrong` (14px
/// semibold); «Enviados» usaba `typography.caption` (12px regular) tanto en
/// la fila de escritorio como en la tarjeta de teléfono. Esta prueba mide el
/// `fontSize` efectivo de la cifra — contra `b0645cd` falla porque ahí es
/// 12px, no 14px.
final class _NoopEnvasesOperations implements EnvasesOperations {
  @override
  Future<EnvasesOperacionLocal> darPorPerdido({required String operacionUuid, required int pickingId}) async =>
      throw UnimplementedError();

  @override
  Future<EnvasesOperacionLocal> enviar(EnvasesEnviarCommand command) async => throw UnimplementedError();

  @override
  Future<EnvasesOperacionLocal> recibir(EnvasesRecibirCommand command) async => throw UnimplementedError();

  @override
  Stream<List<EnvasesOperacionLocal>> watchOperaciones() => const Stream.empty();
}

EnvasesPorRecibirRow _row() => const EnvasesPorRecibirRow(id: 11, name: 'WH2/IN/000011', unidadesPendientes: 8);

EnvasesPickingLineaRow _linea() => const EnvasesPickingLineaRow(
  moveId: 1,
  productId: 50,
  productName: 'Jaba 12',
  uomId: 1,
  uomName: 'Unidades',
  pendientes: 8,
);

Widget _host() => FluentApp(
  theme: OrbiFluentTheme.light,
  home: EnvasesRecibirForm(
    row: _row(),
    lineasLoader: () async => [_linea()],
    operations: _NoopEnvasesOperations(),
  ),
);

void setDesktopSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
}

void setPhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
}

void main() {
  final expectedFontSize = OrbiFluentTheme.light.typography.bodyStrong!.fontSize;

  testWidgets('desktop table: sent quantity uses the same type token as Aptos/Pendiente', (tester) async {
    setDesktopSize(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    final enviados = tester.widget<Text>(find.byKey(const Key('envases-recibir-enviados-1')));
    final aptos = tester.widget<Text>(find.byKey(const Key('envases-recibir-aptos-1')));

    expect(
      enviados.style?.fontSize,
      expectedFontSize,
      reason: 'La cifra de «Enviados» debe usar el mismo token (bodyStrong) que «Aptos»/«Pendiente», no `caption`.',
    );
    expect(enviados.style?.fontSize, aptos.style?.fontSize);
  });

  testWidgets('phone card: sent quantity uses the same type token as Aptos/Pendiente', (tester) async {
    setPhoneSize(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    final enviadosFinder = find.byKey(const Key('envases-recibir-enviados-1'));
    expect(enviadosFinder, findsOneWidget);
    final enviados = tester.widget<Text>(enviadosFinder);
    final span = enviados.textSpan! as TextSpan;
    final cifraSpan = span.children!.last as TextSpan;

    expect(
      cifraSpan.style?.fontSize,
      expectedFontSize,
      reason: 'La cifra de «Enviados» debe usar el mismo token (bodyStrong) que «Aptos»/«Pendiente», no `caption`.',
    );
  });
}
