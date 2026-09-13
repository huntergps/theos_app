@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/features/auth/web_token_auth.dart';

/// Auditoría de conectividad/sincronización (13-sep-2026).
///
/// El commit 7acf837 ya corrigió un 403 real: la sincronización pedía
/// `sale.payment` para CUALQUIER sesión, y ERP2 se lo negaba a un vendedor.
/// Esta prueba pregunta lo mismo para los 14 catálogos que
/// `RuntimeCatalogComposition` sincroniza siempre, sin mirar capacidades
/// (`orbi_runtime/lib/src/read/runtime_catalog_composition.dart:41-56`):
/// ¿hay algún otro catálogo que un VENDEDOR no pueda leer y que la
/// sincronización pida de todas formas?
///
/// Compara vendedor contra supervisor (que casi siempre tiene más grupos) en
/// el mismo servidor: una diferencia real de HTTP 200 en supervisor y
/// 403/otro código en vendedor es evidencia de un catálogo con el mismo
/// problema que `sale.payment`, no una sospecha.
///
/// Se salta sola sin ORBI_ERP2_SERVER_URL/DATABASE + credenciales de ambos
/// actores. Nunca registra ninguna credencial.
void main() {
  final baseUrl =
      Platform.environment['ORBI_ERP2_BASE_URL'] ??
      Platform.environment['ORBI_ERP2_SERVER_URL'];
  final database = Platform.environment['ORBI_ERP2_DATABASE'];
  final sellerLogin = Platform.environment['ORBI_ERP2_SELLER_LOGIN'];
  final sellerPassword = Platform.environment['ORBI_ERP2_SELLER_PASSWORD'];
  final supervisorLogin = Platform.environment['ORBI_ERP2_SUPERVISOR_LOGIN'];
  final supervisorPassword =
      Platform.environment['ORBI_ERP2_SUPERVISOR_PASSWORD'];

  final missing =
      [
        baseUrl,
        database,
        sellerLogin,
        sellerPassword,
        supervisorLogin,
        supervisorPassword,
      ].any((v) => v == null || v.isEmpty);

  group(
    'catálogos de sincronización frente a permisos por rol en ERP2',
    skip: missing
        ? 'define ORBI_ERP2_SERVER_URL, ORBI_ERP2_DATABASE, '
              'ORBI_ERP2_SELLER_LOGIN/PASSWORD y '
              'ORBI_ERP2_SUPERVISOR_LOGIN/PASSWORD para correrla'
        : null,
    () {
      test(
        'todo lo que un vendedor sincroniza, lo puede leer; si no, se compara '
        'contra un supervisor para confirmar que es un problema de permisos',
        () async {
          final resolvedBaseUrl = baseUrl!;
          final resolvedDatabase = database!;
          final client = HttpClient();
          addTearDown(() => client.close(force: true));

          Future<String> apiKeyFor(String user, String pass) async {
            final credential = await OrbiWebTokenAuthClient(
              transport: odooSdkTokenTransport(),
            ).issue(
              serverUrl: resolvedBaseUrl,
              login: user,
              password: pass,
              database: resolvedDatabase,
            );
            return credential.apiKey;
          }

          final sellerKey = await apiKeyFor(sellerLogin!, sellerPassword!);
          final supervisorKey = await apiKeyFor(
            supervisorLogin!,
            supervisorPassword!,
          );

          Future<int> statusFor(
            RuntimeCatalogDescriptor catalog,
            String apiKey,
          ) async {
            final uri = Uri.parse(
              '${resolvedBaseUrl.replaceAll(RegExp(r'/+$'), '')}'
              '/json/2/${catalog.model}/search_read',
            );
            final request = await client.postUrl(uri);
            request.headers.set('content-type', 'application/json');
            request.headers.set('authorization', 'Bearer $apiKey');
            request.headers.set('x-odoo-database', resolvedDatabase);
            request.write(
              jsonEncode({
                'domain': catalog.domain,
                'fields': catalog.fields,
                'limit': 1,
                'order': catalog.order,
              }),
            );
            final response = await request.close();
            await response.drain<void>();
            return response.statusCode;
          }

          final denied = <String>[];
          for (final catalog in RuntimeCatalogs.all) {
            final sellerStatus = await statusFor(catalog, sellerKey);
            if (sellerStatus == 200) continue;
            final supervisorStatus = await statusFor(catalog, supervisorKey);
            denied.add(
              '${catalog.key} (${catalog.model}): vendedor=$sellerStatus, '
              'supervisor=$supervisorStatus',
            );
          }

          // ignore: avoid_print
          print('--- Catálogos negados a un vendedor en ERP2 ---');
          // ignore: avoid_print
          print(denied.isEmpty ? '(ninguno)' : denied.join('\n'));

          expect(
            denied,
            isEmpty,
            reason:
                'Estos catálogos los pide la sincronización para TODA sesión '
                '(runtime_catalog_composition.dart:41-56), pero ERP2 se los '
                'niega a un vendedor. Mismo patrón que sale.payment '
                '(commit 7acf837): hay que leer capacidades antes de pedirlos, '
                'o el catálogo debe quedar fuera de la lista para ese rol.\n'
                '${denied.join('\n')}',
          );
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );
    },
  );
}
