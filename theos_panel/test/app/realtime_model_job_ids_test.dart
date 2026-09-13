import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:odoo_sdk/odoo_sdk.dart' show OdooRawNotificationEvent;
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/app/router.dart';

/// Bloque de sync-cuenta (13-sep-2026), para la presencia y las preferencias
/// personales: un aviso de `res.partner` también debe disparar el catálogo
/// del propio usuario, y uno de `res.users` debe existir como entrada nueva.
/// `_realtimeModelJobIds` es privado — la prueba (f) lo comprueba por su
/// EFECTO real, con `RealtimeChangeDebouncer` (la pieza que de verdad
/// traduce un aviso `app_sync/changed` en los `jobIds` a correr), no
/// abriendo un socket de verdad.
void main() {
  test(
    '(f) res.partner dispara también catalog:currentUserPartner, sin '
    'perder catalog:partner',
    () {
      expect(
        realtimeModelJobIdsForTesting['res.partner'],
        {'catalog:partner', 'catalog:currentUserPartner'},
      );
    },
  );

  test('(f) res.users dispara catalog:currentUser', () {
    expect(
      realtimeModelJobIdsForTesting['res.users'],
      {'catalog:currentUser'},
    );
  });

  test(
    '(f) un aviso app_sync/changed de res.users pide catalog:currentUser '
    'al coordinador',
    () async {
      final notifications = StreamController<OdooRawNotificationEvent>();
      final requested = <Set<String>>[];
      final debouncer = RealtimeChangeDebouncer(
        notifications: notifications.stream,
        modelJobIds: realtimeModelJobIdsForTesting,
        activeCompanyId: () => null,
        onDebounced: requested.add,
        debounce: const Duration(milliseconds: 10),
      );
      addTearDown(debouncer.dispose);

      notifications.add(
        OdooRawNotificationEvent(
          type: 'app_sync/changed',
          payload: const {'model': 'res.users'},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(requested, [
        {'catalog:currentUser'},
      ]);
      await notifications.close();
    },
  );

  test(
    '(f) un aviso app_sync/changed de res.partner pide los DOS catálogos',
    () async {
      final notifications = StreamController<OdooRawNotificationEvent>();
      final requested = <Set<String>>[];
      final debouncer = RealtimeChangeDebouncer(
        notifications: notifications.stream,
        modelJobIds: realtimeModelJobIdsForTesting,
        activeCompanyId: () => null,
        onDebounced: requested.add,
        debounce: const Duration(milliseconds: 10),
      );
      addTearDown(debouncer.dispose);

      notifications.add(
        OdooRawNotificationEvent(
          type: 'app_sync/changed',
          payload: const {'model': 'res.partner'},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(requested, [
        {'catalog:partner', 'catalog:currentUserPartner'},
      ]);
      await notifications.close();
    },
  );
}
