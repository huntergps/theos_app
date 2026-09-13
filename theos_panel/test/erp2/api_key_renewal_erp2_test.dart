@TestOn('vm')
library;

// Medición OPT-IN de la renovación proactiva de la clave API (auditoría de
// sesión, 13-sep-2026) contra un ERP2 real — nunca simulada.
//
// Se salta sola cuando faltan sus variables (la misma convención que el
// resto del repo usa para un Odoo real: `ORBI_ERP2_SERVER_URL`,
// `ORBI_ERP2_DATABASE`, `ORBI_ERP2_SELLER_LOGIN`, `ORBI_ERP2_SELLER_PASSWORD`
// — las mismas claves que `Erp2HarnessConfig.fromEnvironment` y las que ya
// trae `~/.config/tecnosmart/orbi_erp2_actors.env`). Usa el vendedor REAL ya
// configurado para las auditorías de Orbi — nunca se crea un usuario de
// prueba nuevo.
//
// Nunca imprime el secreto de la clave, sólo su longitud y los códigos de
// estado/resultados de cada paso, igual que el resto de mediciones de
// auditoría.
//
// Qué mide, en un solo ciclo real:
// 1. Emitir una clave real vía `/orbi/auth/token`.
// 2. Renovarla con el código de PRODUCCIÓN
//    (`NativeAuthBootstrapAdapter.generateApiKey`, el mismo que
//    `NativeAuthService.renewApiKeyIfNeeded` usa) — nunca un mock.
// 3. Confirmar que la clave NUEVA funciona (`context_get`).
// 4. Revocar la clave VIEJA (`revokeOwnApiKey`, el mismo método que usa
//    `NativeAuthService.close`) y confirmar que con ella ya no se puede.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/features/auth/web_token_auth.dart';

void main() {
  final serverUrl = Platform.environment['ORBI_ERP2_SERVER_URL'];
  final database = Platform.environment['ORBI_ERP2_DATABASE'];
  final login = Platform.environment['ORBI_ERP2_SELLER_LOGIN'];
  final password = Platform.environment['ORBI_ERP2_SELLER_PASSWORD'];
  final missing = serverUrl == null ||
      serverUrl.isEmpty ||
      database == null ||
      database.isEmpty ||
      login == null ||
      login.isEmpty ||
      password == null ||
      password.isEmpty;

  group(
    'renovación de clave API contra ERP2 real (opt-in)',
    skip: missing
        ? 'set ORBI_ERP2_SERVER_URL/DATABASE/SELLER_LOGIN/SELLER_PASSWORD '
            '(p. ej. desde ~/.config/tecnosmart/orbi_erp2_actors.env) para '
            'correr esta medición'
        : null,
    () {
      test(
        'emite, renueva con el adaptador de producción, confirma que la '
        'nueva sirve y revoca la vieja — la vieja queda 401',
        () async {
          // 1) Emitir la clave real.
          final tokenClient = OrbiWebTokenAuthClient(
            transport: odooSdkTokenTransport(),
          );
          final issued = await tokenClient.issue(
            serverUrl: serverUrl!,
            login: login!,
            password: password!,
            database: database,
          );
          // ignore: avoid_print
          print(
            '[ERP2 renewal] clave inicial emitida '
            '(longitud=${issued.apiKey.length}, expira=${issued.expiresAt})',
          );
          expect(issued.apiKey, isNotEmpty);

          // 2) Renovar con el código de PRODUCCIÓN, nunca un mock.
          final adapter = NativeAuthBootstrapAdapter();
          final renewed = await adapter.generateApiKey(
            baseUrl: serverUrl,
            database: issued.database,
            currentApiKey: issued.apiKey,
            name: 'Orbi ERP renewal (auditoría 13-sep-2026)',
            // Lo que se PIDE es sólo orientativo — el servidor decide la
            // vida real; nunca se asume que la respetará literalmente.
            expirationDate: DateTime.now().toUtc().add(
              const Duration(hours: 24),
            ),
          );
          // ignore: avoid_print
          print(
            '[ERP2 renewal] clave renovada '
            '(longitud=${renewed.apiKey.length}, expira=${renewed.expiresAt})',
          );
          expect(renewed.apiKey, isNotEmpty);
          expect(
            renewed.apiKey,
            isNot(issued.apiKey),
            reason: 'generate debe devolver un secreto DISTINTO del actual',
          );

          // 3) La clave NUEVA sirve de verdad.
          final freshClient = OdooClient(
            config: OdooClientConfig(
              baseUrl: serverUrl,
              database: issued.database,
              apiKey: renewed.apiKey,
            ),
          );
          final context = await freshClient.call(
            model: 'res.users',
            method: 'context_get',
          );
          // ignore: avoid_print
          print('[ERP2 renewal] context_get con la clave nueva: $context');
          expect(context, isNotNull);

          // 4) Revocar la VIEJA (el mismo camino que usa el logout real) y
          // confirmar que, con ella, ya no se puede.
          await adapter.revokeOwnApiKey(
            baseUrl: serverUrl,
            database: issued.database,
            apiKey: issued.apiKey,
          );
          final staleClient = OdooClient(
            config: OdooClientConfig(
              baseUrl: serverUrl,
              database: issued.database,
              apiKey: issued.apiKey,
            ),
          );
          await expectLater(
            staleClient.call(model: 'res.users', method: 'context_get'),
            throwsA(isA<OdooException>()),
            reason:
                'la clave VIEJA, ya revocada, debe dar 401 — confirma que '
                'generate→revoke dejó la sesión sirviendo sólo con la nueva',
          );

          // Limpieza: la clave NUEVA emitida por este test también se
          // revoca al terminar, para no dejar credenciales vivas huérfanas
          // en el servidor real.
          await adapter.revokeOwnApiKey(
            baseUrl: serverUrl,
            database: issued.database,
            apiKey: renewed.apiKey,
          );
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );

      test(
        'el umbral de renovación (25% de vida, o 6h, lo que llegue antes) '
        'coincide con lo medido para orbi.web_auth_key_days=1',
        () async {
          final tokenClient = OrbiWebTokenAuthClient(
            transport: odooSdkTokenTransport(),
          );
          final issued = await tokenClient.issue(
            serverUrl: serverUrl!,
            login: login!,
            password: password!,
            database: database,
          );
          final now = DateTime.now().toUtc();
          final life = issued.expiresAt.difference(now);
          // ignore: avoid_print
          print(
            '[ERP2 renewal] vida real de la clave recién emitida: $life',
          );
          // Medido ya en la auditoría del 12/13-sep-2026: ~24h exactas.
          expect(life, greaterThan(const Duration(hours: 20)));
          expect(life, lessThanOrEqualTo(const Duration(hours: 25)));

          final threshold = ApiKeyRenewalDecision.thresholdFor(life);
          // Para una vida de ~1 día, 25% y 6h coinciden: el umbral debe
          // rondar las 6 horas, nunca la vida entera ni unos minutos.
          expect(threshold, greaterThanOrEqualTo(const Duration(hours: 5)));
          expect(threshold, lessThanOrEqualTo(const Duration(hours: 7)));

          final adapter = NativeAuthBootstrapAdapter();
          await adapter.revokeOwnApiKey(
            baseUrl: serverUrl,
            database: issued.database,
            apiKey: issued.apiKey,
          );
        },
        timeout: const Timeout(Duration(seconds: 45)),
      );
    },
  );
}
