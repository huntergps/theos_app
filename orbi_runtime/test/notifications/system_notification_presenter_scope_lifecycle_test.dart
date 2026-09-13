// Mide el bug descrito en la auditoría de tiempo real (§4): el presentador se
// construye UNA sola vez en `bootstrap.dart` con `activeScopeKey:
// 'unconfigured'` y ese valor nunca se actualiza en todo el repo — así que
// ninguna notificación de sistema puede mostrarse jamás, para nadie. Este
// archivo prueba el contrato que debía tener el presentador para que ese
// cableado fuera posible: un scope activo que se pueda MOVER siguiendo la
// sesión real, y que cancele lo que quedó mostrado bajo el scope anterior al
// moverse.
//
// Antes del arreglo, esto ni compila: `activateScope`, `deactivateScope` y
// `SystemNotificationPresenter.unconfiguredScopeKey` no existen. Eso ya es la
// prueba roja — el presentador no tenía forma de seguir a la sesión real.
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/src/notifications/system_notification_presenter.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show NotificationChannel, NotificationScope, NotificationTarget;

final class _Plugin implements NotificationPluginPort {
  final shown = <int, String>{};
  final cancelled = <int>[];

  @override
  Future<bool> initialize() async => true;

  @override
  Future<PermissionState> requestPermission() async => PermissionState.granted;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    shown[id] = payload;
  }

  @override
  Future<void> cancel(int id) async {
    shown.remove(id);
    cancelled.add(id);
  }
}

final class _Ids implements SystemIdPort {
  final ids = <String, int>{};
  var _nextId = 1;

  int _allocate(String scopeKey, String entryId, NotificationChannel channel) =>
      ids['$scopeKey|$entryId|${channel.name}'] ??= _nextId++;

  @override
  Future<int?> lookup({
    required String scopeKey,
    required String entryId,
    required NotificationChannel channel,
  }) async => _allocate(scopeKey, entryId, channel);
}

SystemNotificationRequest _request(String scope, {String entryId = 'entry-1'}) =>
    SystemNotificationRequest(
      scope: NotificationScope(scopeKey: scope, partitionKey: 'global'),
      target: NotificationTarget(type: 'entry', reference: entryId),
      entryId: entryId,
      revision: 1,
      channel: NotificationChannel.system,
      title: 'Aviso',
      body: 'Detalle',
    );

void main() {
  group('SystemNotificationPresenter — el alcance sigue a la sesión real', () {
    test(
      'arranca en el alcance "sin configurar" y deniega cualquier sesión real',
      () async {
        final presenter = SystemNotificationPresenter(
          _Plugin(),
          _Ids(),
          activeScopeKey: SystemNotificationPresenter.unconfiguredScopeKey,
        );
        await presenter.initialize();

        final result = await presenter.showOrReplace(_request('erp2:7'));

        expect(result, SystemDeliveryState.denied);
      },
    );

    test(
      'activateScope mueve el alcance activo y permite mostrar avisos de la sesión que acaba de entrar',
      () async {
        final presenter = SystemNotificationPresenter(
          _Plugin(),
          _Ids(),
          activeScopeKey: SystemNotificationPresenter.unconfiguredScopeKey,
        );
        await presenter.initialize();

        await presenter.activateScope('erp2:7');

        expect(presenter.activeScopeKey, 'erp2:7');
        expect(
          await presenter.showOrReplace(_request('erp2:7')),
          SystemDeliveryState.shown,
        );
      },
    );

    test(
      'deactivateScope vuelve a "sin configurar" al cerrar sesión y deniega el alcance que se acaba de cerrar',
      () async {
        final presenter = SystemNotificationPresenter(
          _Plugin(),
          _Ids(),
          activeScopeKey: 'erp2:7',
        );
        await presenter.initialize();
        await presenter.showOrReplace(_request('erp2:7'));

        await presenter.deactivateScope();

        expect(
          presenter.activeScopeKey,
          SystemNotificationPresenter.unconfiguredScopeKey,
        );
        expect(
          await presenter.showOrReplace(_request('erp2:7')),
          SystemDeliveryState.denied,
        );
      },
    );

    test(
      'al cambiar de usuario, activar el alcance nuevo cancela lo que había quedado mostrado bajo el alcance anterior',
      () async {
        final plugin = _Plugin();
        final presenter = SystemNotificationPresenter(
          plugin,
          _Ids(),
          activeScopeKey: 'erp2:7',
        );
        await presenter.initialize();
        await presenter.showOrReplace(_request('erp2:7'));
        expect(plugin.shown, isNotEmpty);
        final shownId = plugin.shown.keys.single;

        await presenter.activateScope('erp2:9');

        expect(plugin.cancelled, contains(shownId));
        expect(plugin.shown, isEmpty);
        expect(
          await presenter.showOrReplace(_request('erp2:7')),
          SystemDeliveryState.denied,
        );
      },
    );

    test(
      'activar el mismo alcance dos veces no cancela lo ya mostrado',
      () async {
        final plugin = _Plugin();
        final presenter = SystemNotificationPresenter(
          plugin,
          _Ids(),
          activeScopeKey: 'erp2:7',
        );
        await presenter.initialize();
        await presenter.showOrReplace(_request('erp2:7'));
        final shownId = plugin.shown.keys.single;

        await presenter.activateScope('erp2:7');

        expect(plugin.cancelled, isEmpty);
        expect(plugin.shown.containsKey(shownId), isTrue);
      },
    );
  });
}
