import 'package:flutter_test/flutter_test.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

final class _Reader implements Json2ReadPort {
  _Reader(this.outcome);

  final Object? outcome;
  int calls = 0;
  String? lastModel;
  int? lastLimit;

  @override
  Future<List<Map<String, dynamic>>> searchRead({
    required String model,
    required List<String> fields,
    List<dynamic>? domain,
    int? limit,
    int? offset,
    String? order,
  }) async {
    calls++;
    lastModel = model;
    lastLimit = limit;
    if (outcome != null) throw outcome!;
    return const [
      {'id': 1},
    ];
  }
}

void main() {
  final scope = AppScope(
    appId: 'panel',
    installationId: 'i',
    normalizedServerUrl: 'https://erp.test',
    database: 'db',
    userId: 2,
  );

  test('un servidor que contesta se declara alcanzable', () async {
    final reader = _Reader(null);
    final result = await Json2BackendProbe(reader).probe(scope);

    expect(result.state, BackendProbeState.reachable);
    // El sondeo tiene que ser barato: una fila, un campo. Si algún día alguien
    // lo convierte en una lectura de negocio, esto se pone rojo.
    expect(reader.lastLimit, 1);
    expect(reader.lastModel, 'res.users');
  });

  // Que el servidor diga «no» NO es quedarse sin red. Confundirlos manda a la
  // persona a mirar el wifi cuando lo que tiene que hacer es volver a entrar.
  test('una credencial rechazada no se confunde con falta de red', () async {
    for (final error in [
      OdooAuthenticationException('caducada'),
      OdooSessionExpiredException('caducada'),
      OdooAccessDeniedException('sin permiso'),
    ]) {
      final result = await Json2BackendProbe(_Reader(error)).probe(scope);
      expect(
        result.state,
        BackendProbeState.unauthorized,
        reason: '$error debería contarse como servidor sin autorizar',
      );
    }
  });

  test('cualquier otro fallo se declara inalcanzable, nunca sano', () async {
    for (final error in <Object>[
      OdooConnectionException('sin ruta'),
      OdooTimeoutException('tardó demasiado'),
      OdooServerException('500'),
      StateError('algo raro que nadie previó'),
    ]) {
      final result = await Json2BackendProbe(_Reader(error)).probe(scope);
      expect(
        result.state,
        BackendProbeState.unreachable,
        reason: '$error nunca puede leerse como servidor sano',
      );
    }
  });
}
