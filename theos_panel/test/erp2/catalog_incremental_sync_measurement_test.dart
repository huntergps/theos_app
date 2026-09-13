@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/features/auth/web_token_auth.dart';

/// Requisito E del encargo de sincronización incremental (13-sep-2026):
/// correr `RuntimeCatalogLoader` DOS VECES seguidas contra un ERP2 real —el
/// mismo código de producción, no una simulación— y comprobar que la segunda
/// pasada trae menos filas (idealmente ninguna, porque nada cambió entre las
/// dos) que la primera carga completa.
///
/// Es de sólo lectura: nunca escribe en ERP2. Se salta sola sin
/// `ORBI_ERP2_SERVER_URL/DATABASE/SELLER_LOGIN/PASSWORD` y nunca registra
/// ninguna credencial.
void main() {
  final baseUrl =
      Platform.environment['ORBI_ERP2_BASE_URL'] ??
      Platform.environment['ORBI_ERP2_SERVER_URL'];
  final database = Platform.environment['ORBI_ERP2_DATABASE'];
  final login = Platform.environment['ORBI_ERP2_SELLER_LOGIN'];
  final password = Platform.environment['ORBI_ERP2_SELLER_PASSWORD'];

  final missing =
      baseUrl == null ||
      baseUrl.isEmpty ||
      database == null ||
      database.isEmpty ||
      login == null ||
      login.isEmpty ||
      password == null ||
      password.isEmpty;

  group(
    'cursor incremental del catálogo contra un ERP2 real',
    skip: missing
        ? 'define ORBI_ERP2_SERVER_URL, ORBI_ERP2_DATABASE, '
              'ORBI_ERP2_SELLER_LOGIN y ORBI_ERP2_SELLER_PASSWORD para correrla'
        : null,
    () {
      test(
        'la segunda pasada trae menos filas que la primera carga completa',
        () async {
          final credential = await OrbiWebTokenAuthClient(
            transport: odooSdkTokenTransport(),
          ).issue(
            serverUrl: baseUrl!,
            login: login!,
            password: password!,
            database: database,
          );

          final client = OdooClient(
            config: OdooClientConfig(
              baseUrl: baseUrl,
              database: credential.database,
              apiKey: credential.apiKey,
            ),
          );

          final scope = AppScope(
            appId: 'panel-erp2-measurement',
            installationId: 'erp2-measurement',
            normalizedServerUrl: baseUrl,
            database: credential.database,
            userId: 1,
          );

          // `uoms` (unidades de medida) es de los catorce catálogos más
          // pequeños: mantiene la primera carga completa en pocas llamadas
          // sin dejar de ejercer el mismo `RuntimeCatalogLoader` que usan los
          // otros trece.
          const catalog = RuntimeCatalogs.uoms;
          final loader = RuntimeCatalogLoader(
            OdooJson2ReadPort(client),
            pageSize: 50,
          );

          String? cursor;
          var firstPassCalls = 0;
          var firstPassRows = 0;
          while (true) {
            firstPassCalls++;
            final batch = await loader.loader(catalog)(scope, cursor);
            firstPassRows += batch.records.length;
            cursor = batch.cursor;
            if (batch.records.length < 50) break;
          }

          final secondPass = await loader.loader(catalog)(scope, cursor);

          // ignore: avoid_print
          print('--- Cursor incremental medido contra ERP2 (uoms) ---');
          // ignore: avoid_print
          print('Pasada 1 (carga completa): $firstPassCalls llamada(s), '
              '$firstPassRows fila(s)');
          // ignore: avoid_print
          print(
            'Pasada 2 (incremental): 1 llamada(s), '
            '${secondPass.records.length} fila(s)',
          );
          // `uoms` tiene dominio (`active=true`), así que esta pasada
          // también ejercita el escaneo de "salida de dominio" nuevo — lo
          // que importa aquí es que no haya reventado con un error real del
          // servidor (context/dominio negado rechazados) y cuántas filas
          // trajo.
          // ignore: avoid_print
          print(
            'Escaneo de salida de dominio (incluido en deletedIds): '
            '${secondPass.deletedIds.length} fila(s)',
          );

          expect(
            firstPassRows,
            greaterThan(0),
            reason:
                'uom.uom debería tener al menos una unidad de medida activa '
                'en este servidor; si no, cambia el catálogo medido',
          );
          expect(
            secondPass.records.length,
            lessThan(firstPassRows),
            reason:
                'la segunda pasada debe traer menos filas que la carga '
                'completa — hoy (antes de este cambio) traía TODO otra vez, '
                'siempre. Si esto falla, alguien modificó una unidad de '
                'medida en el servidor entre las dos pasadas.',
          );
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );
    },
  );
}
