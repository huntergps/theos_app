import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/features/envases/envases_traslado_detalle.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

final class _FakeEnvasesOperations implements EnvasesOperations {
  EnvasesRecibirCommand? recibido;
  EnvasesEnviarCommand? enviado;
  ({String operacionUuid, int pickingId})? perdido;

  @override
  Future<EnvasesOperacionLocal> darPorPerdido({required String operacionUuid, required int pickingId}) async {
    perdido = (operacionUuid: operacionUuid, pickingId: pickingId);
    return EnvasesOperacionLocal(
      operacionUuid: operacionUuid,
      tipo: 'perdido',
      estado: EnvasesOperacionEstado.pendienteDeEnviar,
      creadaEn: DateTime.now(),
      pickingId: pickingId,
    );
  }

  @override
  Future<EnvasesOperacionLocal> enviar(EnvasesEnviarCommand command) async {
    enviado = command;
    return EnvasesOperacionLocal(
      operacionUuid: command.operacionUuid,
      tipo: 'envio',
      estado: EnvasesOperacionEstado.pendienteDeEnviar,
      creadaEn: DateTime.now(),
    );
  }

  @override
  Future<EnvasesOperacionLocal> recibir(EnvasesRecibirCommand command) async {
    recibido = command;
    return EnvasesOperacionLocal(
      operacionUuid: command.operacionUuid,
      tipo: 'recepcion',
      estado: EnvasesOperacionEstado.pendienteDeEnviar,
      creadaEn: DateTime.now(),
      pickingId: command.pickingId,
    );
  }

  @override
  Stream<List<EnvasesOperacionLocal>> watchOperaciones() => const Stream.empty();
}

EnvasesPorRecibirRow _row() => EnvasesPorRecibirRow(
  id: 11,
  name: 'WH2/IN/000011',
  fechaSalida: DateTime.utc(2026, 9, 1, 8),
  origenId: 1,
  origenName: 'Guayaquil',
  destinoId: 2,
  destinoName: 'Manta',
  unidadesPendientes: 5,
);

Widget _host({required bool canManage, required EnvasesOperations operations, VoidCallback? onDarPorPerdido}) =>
    FluentApp(
      theme: OrbiFluentTheme.light,
      home: EnvasesTrasladoDetalle(
        row: _row(),
        operaciones: const Stream.empty(),
        operations: operations,
        canManage: canManage,
        onRegistrarRecepcion: () {},
        onDarPorPerdido: onDarPorPerdido,
      ),
    );

void main() {
  testWidgets('shows "Dar por perdido" only with canManage', (tester) async {
    await tester.pumpWidget(_host(canManage: false, operations: _FakeEnvasesOperations()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('envases-detalle-dar-por-perdido')), findsNothing);
  });

  testWidgets('offers "Dar por perdido" with canManage and calls the operation', (tester) async {
    final operations = _FakeEnvasesOperations();
    var called = false;
    await tester.pumpWidget(_host(canManage: true, operations: operations, onDarPorPerdido: () => called = true));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('envases-detalle-dar-por-perdido')), findsOneWidget);
    await tester.tap(find.byKey(const Key('envases-detalle-dar-por-perdido')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('envases-detalle-confirmar-perdido')));
    await tester.pumpAndSettle();

    expect(operations.perdido?.pickingId, 11);
    expect(operations.perdido?.operacionUuid, isNotEmpty);
    expect(called, isTrue);
  });

  testWidgets('registrar recepcion button triggers callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      FluentApp(
        theme: OrbiFluentTheme.light,
        home: EnvasesTrasladoDetalle(
          row: _row(),
          operaciones: const Stream.empty(),
          operations: _FakeEnvasesOperations(),
          canManage: false,
          onRegistrarRecepcion: () => tapped = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('envases-detalle-recibir')));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });
}
