import 'package:flutter_test/flutter_test.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

final class _Call {
  const _Call(this.model, this.method, this.ids, this.kwargs);
  final String model;
  final String method;
  final List<int>? ids;
  final Map<String, dynamic>? kwargs;
}

final class _FakeActions implements SaleOdooActions {
  final calls = <_Call>[];
  dynamic Function(_Call call)? onCall;

  @override
  Future<dynamic> call({
    required String model,
    required String method,
    List<int>? ids,
    Map<String, dynamic>? kwargs,
  }) async {
    final invocation = _Call(model, method, ids, kwargs);
    calls.add(invocation);
    final handler = onCall;
    if (handler == null) return true;
    final result = handler(invocation);
    if (result is Exception) throw result;
    return result;
  }
}

void main() {
  group('CollectionSessionSupervisionPort — las cinco acciones, en línea', () {
    test('pause llama action_session_pause con el id del turno ajeno', () async {
      final actions = _FakeActions();
      final port = CollectionSessionSupervisionPort(actions);

      final result = await port.pause(11);

      expect(result.isSuccess, isTrue);
      expect(actions.calls, hasLength(1));
      expect(actions.calls.single.model, 'collection.session');
      expect(actions.calls.single.method, 'action_session_pause');
      expect(actions.calls.single.ids, [11]);
    });

    test('resume llama action_session_resume', () async {
      final actions = _FakeActions();
      final result = await CollectionSessionSupervisionPort(actions).resume(11);
      expect(result.isSuccess, isTrue);
      expect(actions.calls.single.method, 'action_session_resume');
    });

    test('validate llama action_session_validate', () async {
      final actions = _FakeActions();
      final result = await CollectionSessionSupervisionPort(actions).validate(11);
      expect(result.isSuccess, isTrue);
      expect(actions.calls.single.method, 'action_session_validate');
    });

    test('close llama action_session_close', () async {
      final actions = _FakeActions();
      final result = await CollectionSessionSupervisionPort(actions).close(11);
      expect(result.isSuccess, isTrue);
      expect(actions.calls.single.method, 'action_session_close');
    });

    test('reopenClosed llama action_session_reabrir_cerrada', () async {
      final actions = _FakeActions();
      final result = await CollectionSessionSupervisionPort(
        actions,
      ).reopenClosed(11);
      expect(result.isSuccess, isTrue);
      expect(actions.calls.single.method, 'action_session_reabrir_cerrada');
    });
  });

  group('el rechazo del servidor se muestra tal cual, nunca se inventa', () {
    test('un UserError de Odoo llega íntegro en serverMessage', () async {
      final actions = _FakeActions()
        ..onCall = (_) => OdooValidationException(
          'No puedes cerrar la sesión: no se ha registrado el depósito del '
          'dinero cobrado (86,00).',
        );
      final result = await CollectionSessionSupervisionPort(actions).validate(11);

      expect(result.isSuccess, isFalse);
      expect(
        result.serverMessage,
        'No puedes cerrar la sesión: no se ha registrado el depósito del '
        'dinero cobrado (86,00).',
      );
    });

    test('un False plano del wizard se marca rechazado sin inventar texto', () async {
      final actions = _FakeActions()..onCall = (_) => false;
      final result = await CollectionSessionSupervisionPort(actions).close(11);

      expect(result.isSuccess, isFalse);
      expect(result.serverMessage, isNull);
    });
  });

}
