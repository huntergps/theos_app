import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/features/auth/web_credential_store.dart';

import 'workspace_unlock_test_doubles.dart';

void main() {
  // The exact shape `controllers/web_token_auth.py` returns on 200, as
  // documented in `l10n_ec_collection_box_pos/WEB_AUTH.md`.
  Map<String, dynamic> response({
    String database = 'orbi',
    int uid = 7,
    String tokenType = 'bearer',
    String scope = 'rpc',
    String apiKey = 'clave-de-prueba',
    String expiresAt = '2026-09-13 04:00:00',
  }) => {
    'database': database,
    'uid': uid,
    'token_type': tokenType,
    'scope': scope,
    'api_key': apiKey,
    'expires_at': expiresAt,
  };

  group('expires_at del servidor', () {
    // 🔴 The trap this whole group exists for. Odoo serialises with
    // `fields.Datetime.to_string`, which is UTC with NO zone marker, and
    // `DateTime.parse` would read it as LOCAL time. In Ecuador (UTC−5) that
    // places the expiry five hours late and keeps a dead key in use.
    test('un valor sin zona se lee como UTC, no como hora local', () {
      final parsed = WebAuthCredential.parseServerExpiry(
        '2026-09-13 04:00:00',
      );
      expect(parsed.isUtc, isTrue);
      expect(parsed, DateTime.utc(2026, 9, 13, 4));
      expect(
        parsed,
        isNot(DateTime(2026, 9, 13, 4)),
        reason: 'leerlo como local es exactamente el defecto a evitar',
      );
    });

    test('un valor CON zona se respeta tal cual', () {
      expect(
        WebAuthCredential.parseServerExpiry('2026-09-13T04:00:00Z'),
        DateTime.utc(2026, 9, 13, 4),
      );
      expect(
        WebAuthCredential.parseServerExpiry('2026-09-13T04:00:00-05:00'),
        DateTime.utc(2026, 9, 13, 9),
      );
    });

    test('un valor vacío o ilegible se rechaza en vez de adivinarse', () {
      expect(
        () => WebAuthCredential.parseServerExpiry('  '),
        throwsFormatException,
      );
      expect(
        () => WebAuthCredential.parseServerExpiry('mañana'),
        throwsFormatException,
      );
    });
  });

  group('la respuesta de /orbi/auth/token', () {
    test('se lee completa, con la caducidad en UTC', () {
      final credential = WebAuthCredential.fromResponse(response());
      expect(credential.database, 'orbi');
      expect(credential.uid, 7);
      expect(credential.tokenType, 'bearer');
      expect(credential.scope, 'rpc');
      expect(credential.apiKey, 'clave-de-prueba');
      expect(credential.expiresAt, DateTime.utc(2026, 9, 13, 4));
    });

    test('una respuesta incompleta o rara se rechaza: una credencial que no '
        'entendemos del todo es una cuya caducidad no podríamos respetar', () {
      for (final broken in <Map<String, dynamic>>[
        response()..remove('api_key'),
        response()..remove('expires_at'),
        {...response(), 'api_key': ''},
        {...response(), 'uid': 0},
        {...response(), 'uid': '7'},
        {...response(), 'database': ''},
      ]) {
        expect(
          () => WebAuthCredential.fromResponse(broken),
          throwsFormatException,
          reason: 'aceptó $broken',
        );
      }
    });

    test('sobrevive un viaje completo por el almacén', () {
      final original = WebAuthCredential.fromResponse(response());
      final back = WebAuthCredential.decode(original.encode());
      expect(back.apiKey, original.apiKey);
      expect(back.expiresAt, original.expiresAt);
      expect(back.expiresAt.isUtc, isTrue);
      expect(back.uid, original.uid);
    });
  });

  group('WebCredentialStore', () {
    late FakeCredentialBackend backend;
    late WebCredentialStore store;
    final now = DateTime.utc(2026, 9, 12, 4);

    setUp(() {
      backend = FakeCredentialBackend();
      store = WebCredentialStore(backend);
    });

    test('guarda y recupera la credencial', () async {
      final credential = WebAuthCredential.fromResponse(response());
      expect(await store.save(credential, now: now), isTrue);
      final loaded = await store.load(now: now);
      expect(loaded?.apiKey, 'clave-de-prueba');
      expect(loaded?.remainingAt(now), const Duration(days: 1));
    });

    // Esta clase NO cifra y no debe pretenderlo: la confidencialidad la da el
    // respaldo de plataforma. Con un respaldo falso —que guarda texto llano— la
    // clave se ve, y está bien que se vea: lo afirma aquí para que nadie
    // confunda dónde vive esa garantía. La prueba de verdad, contra el respaldo
    // real del navegador, está en test/web/web_crypto_unlock_backend_test.dart.
    test('esta clase no aporta el cifrado: lo aporta el respaldo de '
        'plataforma, y conviene tenerlo explícito', () async {
      const secret = 'clave-secreta-de-verdad';
      await store.save(
        WebAuthCredential.fromResponse(response(apiKey: secret)),
        now: now,
      );
      expect(backend.entries.values.single.contains(secret), isTrue);
    });

    test('una credencial YA caducada no se guarda: sólo crearía un registro '
        'cuyo único destino es borrarse', () async {
      final expired = WebAuthCredential.fromResponse(
        response(expiresAt: '2026-09-11 04:00:00'),
      );
      expect(await store.save(expired, now: now), isFalse);
      expect(backend.entries, isEmpty);
    });

    test('al caducar, load devuelve null Y borra el registro: una clave muerta '
        'no se presenta ni se queda ahí', () async {
      await store.save(WebAuthCredential.fromResponse(response()), now: now);
      expect(backend.entries, isNotEmpty);

      final after = now.add(const Duration(days: 1, seconds: 1));
      expect(await store.load(now: after), isNull);
      expect(
        backend.entries,
        isEmpty,
        reason: 'la caducidad se cumple aquí también, no sólo en el servidor',
      );
    });

    test('justo antes de caducar sigue sirviendo', () async {
      await store.save(WebAuthCredential.fromResponse(response()), now: now);
      final justBefore = now.add(const Duration(days: 1) - const Duration(seconds: 1));
      expect(await store.load(now: justBefore), isNotNull);
    });

    test('una credencial de OTRA base no se ofrece y se descarta, igual que la '
        'ruta rechaza un db que no es el suyo', () async {
      await store.save(
        WebAuthCredential.fromResponse(response(database: 'otra_base')),
        now: now,
      );
      expect(
        await store.load(now: now, expectedDatabase: 'orbi'),
        isNull,
      );
      expect(backend.entries, isEmpty);
    });

    test('clear la borra — el gancho del cierre de sesión', () async {
      await store.save(WebAuthCredential.fromResponse(response()), now: now);
      await store.clear();
      expect(backend.entries, isEmpty);
      expect(await store.load(now: now), isNull);
    });

    test('un registro corrupto se descarta en vez de quedarse para siempre',
        () async {
      await backend.write('orbi/auth/web/credential/v1', 'basura');
      expect(await store.load(now: now), isNull);
      expect(backend.entries, isEmpty);
    });

    test('sin almacén durable no guarda nada y no rompe nada', () async {
      const nowhere = WebCredentialStore(null);
      expect(nowhere.isSupported, isFalse);
      expect(
        await nowhere.save(
          WebAuthCredential.fromResponse(response()),
          now: now,
        ),
        isFalse,
      );
      expect(await nowhere.load(now: now), isNull);
      await nowhere.clear();
    });

    test('un almacén que falla degrada a "la sesión no sobrevive a una '
        'recarga", nunca rompe el acceso que acaba de funcionar', () async {
      final hostile = WebCredentialStore(ThrowingCredentialBackend());
      expect(
        await hostile.save(
          WebAuthCredential.fromResponse(response()),
          now: now,
        ),
        isFalse,
      );
      expect(await hostile.load(now: now), isNull);
      await hostile.clear();
    });
  });
}
