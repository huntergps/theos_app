/// Contrato: el aviso `app_sync/changed` es una pista, no la verdad — sólo
/// debe traducirse en UNA petición de sincronización incremental por ráfaga,
/// y sólo para los catálogos que la app realmente sincroniza y para la
/// empresa activa.
///
/// Antes de este archivo no existía traducción alguna entre el bus de tiempo
/// real y `SyncCoordinator`: un aviso no disparaba nada.
library;

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odoo_sdk/odoo_sdk.dart' show OdooRawNotificationEvent;
import 'package:orbi_runtime/src/realtime/realtime_change_debouncer.dart';

OdooRawNotificationEvent _appSyncChanged(
  String model, {
  int? companyId,
}) => OdooRawNotificationEvent(
  type: 'app_sync/changed',
  payload: {
    'model': model,
    'ids': [7],
    'count': 1,
    'action': 'updated',
    'company_id': companyId,
    'write_date': '2026-09-13 15:04:05',
  },
);

void main() {
  group('A — una ráfaga de un catálogo sincronizado dispara UNA sola vez', () {
    test('10 avisos seguidos de product.product producen un solo flush', () {
      fakeAsync((async) {
        final notifications = StreamController<OdooRawNotificationEvent>();
        final debounced = <Set<String>>[];
        final debouncer = RealtimeChangeDebouncer(
          notifications: notifications.stream,
          modelJobIds: const {
            'product.product': {'products'},
          },
          activeCompanyId: () => null,
          debounce: const Duration(milliseconds: 400),
          onDebounced: debounced.add,
        );

        for (var i = 0; i < 10; i++) {
          notifications.add(_appSyncChanged('product.product'));
          async.elapse(const Duration(milliseconds: 50));
        }
        // Todavía dentro de la ventana de antirrebote de la última: nada aún.
        expect(debounced, isEmpty);

        async.elapse(const Duration(milliseconds: 400));

        expect(debounced, hasLength(1));
        expect(debounced.single, {'products'});

        unawaited(debouncer.dispose());
        unawaited(notifications.close());
      });
    });

    test(
      'avisos de dos catálogos sincronizados distintos se funden en un solo flush con ambos ids',
      () {
        fakeAsync((async) {
          final notifications = StreamController<OdooRawNotificationEvent>();
          final debounced = <Set<String>>[];
          final debouncer = RealtimeChangeDebouncer(
            notifications: notifications.stream,
            modelJobIds: const {
              'product.product': {'products'},
              'res.partner': {'partners'},
            },
            activeCompanyId: () => null,
            debounce: const Duration(milliseconds: 300),
            onDebounced: debounced.add,
          );

          notifications.add(_appSyncChanged('product.product'));
          async.elapse(const Duration(milliseconds: 50));
          notifications.add(_appSyncChanged('res.partner'));
          async.elapse(const Duration(milliseconds: 300));

          expect(debounced, hasLength(1));
          expect(debounced.single, {'products', 'partners'});

          unawaited(debouncer.dispose());
          unawaited(notifications.close());
        });
      },
    );
  });

  group('B — lo no sincronizado o de otra empresa no dispara nada', () {
    test('un modelo ausente del mapa no dispara nunca', () {
      fakeAsync((async) {
        final notifications = StreamController<OdooRawNotificationEvent>();
        final debounced = <Set<String>>[];
        final debouncer = RealtimeChangeDebouncer(
          notifications: notifications.stream,
          modelJobIds: const {
            'product.product': {'products'},
          },
          activeCompanyId: () => null,
          onDebounced: debounced.add,
        );

        notifications.add(_appSyncChanged('stock.quant.package'));
        async.elapse(const Duration(seconds: 2));

        expect(debounced, isEmpty);

        unawaited(debouncer.dispose());
        unawaited(notifications.close());
      });
    });

    test('company_id distinto de la empresa activa se ignora', () {
      fakeAsync((async) {
        final notifications = StreamController<OdooRawNotificationEvent>();
        final debounced = <Set<String>>[];
        final debouncer = RealtimeChangeDebouncer(
          notifications: notifications.stream,
          modelJobIds: const {
            'product.product': {'products'},
          },
          activeCompanyId: () => 1,
          onDebounced: debounced.add,
        );

        notifications.add(_appSyncChanged('product.product', companyId: 2));
        async.elapse(const Duration(seconds: 2));

        expect(debounced, isEmpty);

        unawaited(debouncer.dispose());
        unawaited(notifications.close());
      });
    });

    test(
      'company_id presente pero empresa activa aun desconocida (null) no se filtra',
      () {
        fakeAsync((async) {
          final notifications = StreamController<OdooRawNotificationEvent>();
          final debounced = <Set<String>>[];
          final debouncer = RealtimeChangeDebouncer(
            notifications: notifications.stream,
            modelJobIds: const {
              'product.product': {'products'},
            },
            activeCompanyId: () => null,
            onDebounced: debounced.add,
          );

          notifications.add(_appSyncChanged('product.product', companyId: 2));
          async.elapse(const Duration(seconds: 2));

          expect(debounced, hasLength(1));

          unawaited(debouncer.dispose());
          unawaited(notifications.close());
        });
      },
    );

    test('un tipo de notificación distinto de app_sync/changed se ignora', () {
      fakeAsync((async) {
        final notifications = StreamController<OdooRawNotificationEvent>();
        final debounced = <Set<String>>[];
        final debouncer = RealtimeChangeDebouncer(
          notifications: notifications.stream,
          modelJobIds: const {
            'product.product': {'products'},
          },
          activeCompanyId: () => null,
          onDebounced: debounced.add,
        );

        notifications.add(
          OdooRawNotificationEvent(
            type: 'bus.bus/im_status_updated',
            payload: {'model': 'product.product', 'im_status': 'online'},
          ),
        );
        async.elapse(const Duration(seconds: 2));

        expect(debounced, isEmpty);

        unawaited(debouncer.dispose());
        unawaited(notifications.close());
      });
    });
  });
}
