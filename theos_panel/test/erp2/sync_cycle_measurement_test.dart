@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/features/auth/web_token_auth.dart';

/// Auditoría de conectividad/sincronización (13-sep-2026), frente
/// «conectividad, sincronización, offline-first».
///
/// Mide un ciclo de sincronización REAL contra ERP2, en el mismo orden en
/// que `RuntimeCatalogComposition` construye el mapa de jobs
/// (`orbi_runtime/lib/src/read/runtime_catalog_composition.dart:90-107`):
/// los 14 catálogos, EN ORDEN, y el job de operaciones al final — porque así
/// es como el `Map<String, SyncJob>` los inserta y `SyncCoordinatorImpl`
/// preserva el orden de inserción al iterar `_jobs` (`sync_coordinator_impl.dart:120`).
///
/// Esta prueba no reconstruye el `SyncCoordinatorImpl` completo (exigiría
/// todo el aparataje de sesión/Drift); mide el mismo tráfico HTTP que cada
/// `CatalogSyncJob.run()` produciría, en el mismo orden, con el mismo
/// vendedor con el que un cajero real entraría — y cronometra cada llamada.
///
/// Se salta sola sin `ORBI_ERP2_SERVER_URL/DATABASE/SELLER_LOGIN/PASSWORD`.
/// Nunca registra ninguna credencial.
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
    'ciclo de sincronización de catálogos contra un ERP2 real',
    skip: missing
        ? 'define ORBI_ERP2_SERVER_URL, ORBI_ERP2_DATABASE, '
              'ORBI_ERP2_SELLER_LOGIN y ORBI_ERP2_SELLER_PASSWORD para correrla'
        : null,
    () {
      test(
        'mide llamadas y tiempo del ciclo tal como lo ejecutaría el coordinador',
        () async {
          final credential = await OrbiWebTokenAuthClient(
            transport: odooSdkTokenTransport(),
          ).issue(
            serverUrl: baseUrl!,
            login: login!,
            password: password!,
            database: database,
          );

          final client = HttpClient();
          addTearDown(() => client.close(force: true));

          Future<Duration> timeOne(RuntimeCatalogDescriptor catalog) async {
            final sw = Stopwatch()..start();
            final uri = Uri.parse(
              '${baseUrl.replaceAll(RegExp(r'/+$'), '')}'
              '/json/2/${catalog.model}/search_read',
            );
            final request = await client.postUrl(uri);
            request.headers.set('content-type', 'application/json');
            request.headers.set(
              'authorization',
              'Bearer ${credential.apiKey}',
            );
            request.headers.set('x-odoo-database', credential.database);
            request.write(
              jsonEncode({
                'domain': catalog.domain,
                'fields': catalog.fields,
                'limit': 200,
                'order': catalog.order,
              }),
            );
            final response = await request.close();
            final body = await response.transform(utf8.decoder).join();
            sw.stop();
            // El fallo se reporta, no se descarta: es exactamente lo que
            // `CatalogSyncJob.run()` traduciría en `SyncJobResult.failed`.
            if (response.statusCode != 200) {
              // ignore: avoid_print
              print(
                '  [FALLA] ${catalog.key} (${catalog.model}): '
                'HTTP ${response.statusCode} en ${sw.elapsedMilliseconds}ms — '
                '${body.substring(0, body.length.clamp(0, 200))}',
              );
            }
            return sw.elapsed;
          }

          final order = <String>[];
          final timings = <String, Duration>{};
          final overall = Stopwatch()..start();

          // Mismo orden de `RuntimeCatalogComposition`: los 14 catálogos
          // primero (líneas 41-56/91-104), la cola de operaciones NO
          // participa aquí porque no hay una operación real que drenar en
          // este scope de sólo-lectura, pero el punto que esta medición deja
          // sentado es que, en el coordinador real, ese job correría DESPUÉS
          // de estos catorce, nunca antes.
          for (final catalog in RuntimeCatalogs.all) {
            order.add(catalog.key);
            timings[catalog.key] = await timeOne(catalog);
          }
          overall.stop();

          // ignore: avoid_print
          print('--- Ciclo de sincronización medido contra ERP2 ---');
          // ignore: avoid_print
          print('Orden de ejecución: ${order.join(' -> ')}');
          for (final key in order) {
            // ignore: avoid_print
            print('  $key: ${timings[key]!.inMilliseconds}ms');
          }
          // ignore: avoid_print
          print('Llamadas HTTP: ${order.length}');
          // ignore: avoid_print
          print('Tiempo total del ciclo: ${overall.elapsedMilliseconds}ms');

          expect(order.length, RuntimeCatalogs.all.length);
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );
    },
  );
}
