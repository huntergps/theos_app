@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/features/auth/web_token_auth.dart';

/// Pregunta a un Odoo de verdad si los catorce catálogos existen tal como los
/// pide el cliente.
///
/// 🔴 Por qué existe. Los catorce descriptores se escribieron de una sola vez,
/// en un único commit, y **ninguno se comprobó contra un servidor**. Medido el
/// 12-sep-2026 contra ERP2: cuatro estaban mal y llevaban así desde entonces.
/// Dos pedían un modelo con el nombre equivocado —`account.card.brand` en vez
/// de `account.credit.card.brand`— y dos pedían campos que **nunca existieron
/// en ninguna versión**: `collection.session.currency_symbol` y
/// `deadline_days`/`percentage` en los plazos de tarjeta. El usuario sólo veía
/// «5 con error» en el pie, sin poder saber qué eran.
///
/// Lo que esta prueba comprueba es lo único que ninguna prueba con dobles
/// puede comprobar: **que el nombre existe al otro lado**. No comprueba que el
/// campo signifique lo que creemos, que es una pregunta distinta y más difícil.
///
/// Se salta sola sin credenciales, como el resto de las pruebas contra un Odoo
/// real de este repositorio, y nunca registra un valor de credencial.
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
    'los catálogos que pide el cliente existen en el servidor',
    skip: missing
        ? 'define ORBI_ERP2_SERVER_URL, ORBI_ERP2_DATABASE, '
              'ORBI_ERP2_SELLER_LOGIN y ORBI_ERP2_SELLER_PASSWORD para correrla'
        : null,
    () {
      test('ninguno pide un modelo o un campo que no exista', () async {
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

        final rejected = <String>[];
        for (final catalog in RuntimeCatalogs.all) {
          final uri = Uri.parse(
            '${baseUrl.replaceAll(RegExp(r'/+$'), '')}'
            '/json/2/${catalog.model}/search_read',
          );
          final request = await client.postUrl(uri);
          request.headers.set('content-type', 'application/json');
          request.headers.set('authorization', 'Bearer ${credential.apiKey}');
          request.headers.set('x-odoo-database', credential.database);
          request.write(
            jsonEncode({
              'domain': catalog.domain,
              'fields': catalog.fields,
              'limit': 1,
              'order': catalog.order,
            }),
          );
          final response = await request.close();
          final body = await response.transform(utf8.decoder).join();
          if (response.statusCode != 200) {
            // El cuerpo trae el modelo o el campo exacto que el servidor
            // rechaza; se conserva entero porque es justo el dato que hacía
            // falta y que el contador de fallos tiraba.
            rejected.add(
              '${catalog.key} (${catalog.model}): '
              'HTTP ${response.statusCode} — ${body.trim()}',
            );
          }
        }

        expect(
          rejected,
          isEmpty,
          reason:
              'Estos catálogos piden al servidor algo que no tiene. Corrige el '
              'descriptor en json2_read_adapters.dart antes de seguir: cada uno '
              'de estos deja la sincronización fallando en silencio y sólo se '
              've como un número en el pie.\n${rejected.join('\n')}',
        );
      }, timeout: const Timeout(Duration(minutes: 3)));
    },
  );
}
