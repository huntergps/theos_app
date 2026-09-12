@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/features/auth/unlock_backend_factory_web.dart';
import 'package:theos_panel/features/auth/web_credential_store.dart';
import 'package:theos_panel/features/auth/workspace_unlock_store.dart';
import 'package:web/web.dart' as web;

/// Run with: `flutter test --platform chrome test/web/`
///
/// These cannot run on the VM: the backend under test is the browser one.
void main() {
  var counter = 0;
  late String databaseName;
  late WebCryptoCredentialBackend backend;

  setUp(() {
    // A fresh IndexedDB per test: no test may inherit another's key.
    databaseName = 'orbi_unlock_test_${DateTime.now().microsecondsSinceEpoch}'
        '_${counter++}';
    backend = WebCryptoCredentialBackend(databaseName: databaseName);
  });

  tearDown(() => web.window.indexedDB.deleteDatabase(databaseName));

  group('el respaldo de navegador', () {
    test('escribe, lee y borra, igual que el almacén del escritorio', () async {
      expect(await backend.read('k'), isNull);
      await backend.write('k', 'valor-uno');
      expect(await backend.read('k'), 'valor-uno');
      await backend.write('k', 'valor-dos');
      expect(await backend.read('k'), 'valor-dos');
      await backend.delete('k');
      expect(await backend.read('k'), isNull);
    });

    test('lo persistido NO contiene el texto en claro: está cifrado, no '
        'codificado', () async {
      const secret = 'derivado-que-no-debe-verse';
      await backend.write('k', secret);
      final raw = await _rawRecord(databaseName, 'k');
      expect(raw, isNotNull);
      final asText = String.fromCharCodes(raw!);
      expect(asText.contains(secret), isFalse);
      expect(base64Encode(raw).contains(base64Encode(secret.codeUnits)), isFalse);
    });

    test('cada escritura usa un vector distinto, así que el mismo valor nunca '
        'se ve igual dos veces', () async {
      await backend.write('k', 'mismo-valor');
      final first = await _rawRecord(databaseName, 'k');
      await backend.write('k', 'mismo-valor');
      final second = await _rawRecord(databaseName, 'k');
      expect(first, isNot(second));
      expect(await backend.read('k'), 'mismo-valor');
    });

    test('otra instancia sobre la misma base lo lee: la llave sobrevive a '
        'recargar la página', () async {
      await backend.write('k', 'sobrevive');
      final reopened = WebCryptoCredentialBackend(databaseName: databaseName);
      expect(await reopened.read('k'), 'sobrevive');
    });

    test('un valor con caracteres no ASCII vuelve INTACTO: `codeUnits` los '
        'truncaba en silencio y la corrupción sólo aparecía al leer', () async {
      const value = 'contraseña · año · ñandú · 漢字 · 🇪🇨';
      await backend.write('k', value);
      expect(await backend.read('k'), value);
    });

    test('un JSON con acentos en los campos sobrevive, que es lo que guarda '
        'de verdad una credencial con nombre de base acentuado', () async {
      const json = '{"database":"orbi_compañía","api_key":"ábc-123"}';
      await backend.write('k', json);
      expect(await backend.read('k'), json);
    });

    test('una base distinta NO lo lee: cada llave está atada a su almacén',
        () async {
      await backend.write('k', 'secreto');
      final other = WebCryptoCredentialBackend(
        databaseName: '${databaseName}_otra',
      );
      addTearDown(
        () => web.window.indexedDB.deleteDatabase('${databaseName}_otra'),
      );
      expect(await other.read('k'), isNull);
    });

    test('un registro manipulado no se descifra y se descarta, nunca devuelve '
        'basura como si fuera válida', () async {
      await backend.write('k', 'autentico');
      await _corruptRecord(databaseName, 'k');
      expect(await backend.read('k'), isNull);
      expect(await _rawRecord(databaseName, 'k'), isNull);
    });
  });

  group('el almacén de desbloqueo sobre el navegador', () {
    test('el navegador YA guarda: se desbloquea sin conexión, igual que el '
        'escritorio', () async {
      final store = WorkspaceUnlockStore(backend);
      expect(store.isSupported, isTrue);
      const scope = 'scope-web';
      const password = 'Gal4pagos-Orbi!';

      expect(await store.remember(scope, password), isTrue);
      expect(
        await store.verify(scope, password),
        WorkspaceUnlockVerdict.unlocked,
      );
      expect(
        await store.verify(scope, 'otra'),
        WorkspaceUnlockVerdict.rejected,
      );
    });

    test('el derivado desaparece al cerrar sesión, también en el navegador',
        () async {
      final store = WorkspaceUnlockStore(backend);
      const scope = 'scope-web';
      await store.remember(scope, 'contraseña');
      await store.verify(scope, 'mal');
      await store.forget(scope);
      expect(await store.isRemembered(scope), isFalse);
      expect(
        await store.verify(scope, 'contraseña'),
        WorkspaceUnlockVerdict.notEnrolled,
      );
    });

    test('la contraseña nunca llega al almacén, ni en claro ni en base64',
        () async {
      const password = 'Tr4nsp0rte-Gal4pagos';
      await WorkspaceUnlockStore(backend).remember('scope-web', password);
      for (final key in await _allKeys(databaseName)) {
        final raw = await _rawRecord(databaseName, key);
        if (raw == null) continue;
        expect(String.fromCharCodes(raw).contains(password), isFalse);
        expect(
          base64Encode(raw).contains(base64Encode(password.codeUnits)),
          isFalse,
        );
      }
    });
  });

  group('el registro de caducidad sobre el navegador', () {
    // La otra mitad de W04. Ojo con lo que este grupo NO afirma: la clave API
    // no se guarda aquí — la persiste NativeAuthService bajo su propia
    // referencia, sobre este mismo respaldo cifrado. Lo que se comprueba aquí
    // es que la puerta de caducidad sobrevive a recargar y se borra sola.
    final issued = WebAuthCredential.fromResponse(const {
      'database': 'orbi',
      'uid': 7,
      'token_type': 'bearer',
      'scope': 'rpc',
      'api_key': 'clave-api-que-no-debe-guardarse-aqui',
      'expires_at': '2026-09-13 04:00:00',
    });
    final now = DateTime.utc(2026, 9, 12, 4);

    test('sobrevive a recargar la página y sigue diciendo cuándo muere',
        () async {
      expect(await WebCredentialStore(backend).remember(issued, now: now),
          isTrue);

      final afterReload = WebCredentialStore(
        WebCryptoCredentialBackend(databaseName: databaseName),
      );
      final loaded = await afterReload.load(now: now);
      expect(loaded?.expiresAt, DateTime.utc(2026, 9, 13, 4));
      expect(loaded?.uid, 7);
    });

    test('la clave API NO llega a este registro, ni en claro ni en base64',
        () async {
      await WebCredentialStore(backend).remember(issued, now: now);
      for (final key in await _allKeys(databaseName)) {
        final raw = await _rawRecord(databaseName, key);
        if (raw == null) continue;
        expect(
          String.fromCharCodes(raw).contains('clave-api-que-no-debe-guardarse-aqui'),
          isFalse,
        );
        expect(
          base64Encode(raw).contains(
            base64Encode('clave-api-que-no-debe-guardarse-aqui'.codeUnits),
          ),
          isFalse,
        );
      }
    });

    test('al caducar se borra del navegador, no se queda ahí', () async {
      final store = WebCredentialStore(backend);
      await store.remember(issued, now: now);
      expect(await _allKeys(databaseName), isNotEmpty);

      expect(
        await store.load(now: now.add(const Duration(days: 1, seconds: 1))),
        isNull,
      );
      expect(await _allKeys(databaseName), isEmpty);
    });

    test('clear lo borra: el gancho del cierre de sesión funciona en el '
        'navegador', () async {
      final store = WebCredentialStore(backend);
      await store.remember(issued, now: now);
      await store.clear();
      expect(await store.load(now: now), isNull);
      expect(await _allKeys(databaseName), isEmpty);
    });
  });
}

Future<web.IDBDatabase> _open(String name) {
  final completer = Completer<web.IDBDatabase>();
  final open = web.window.indexedDB.open(name, 1);
  open.onupgradeneeded = ((web.Event _) {
    final db = open.result as web.IDBDatabase;
    if (!db.objectStoreNames.contains('keys')) db.createObjectStore('keys');
    if (!db.objectStoreNames.contains('records')) {
      db.createObjectStore('records');
    }
  }).toJS;
  open.onsuccess = ((web.Event _) {
    completer.complete(open.result as web.IDBDatabase);
  }).toJS;
  open.onerror = ((web.Event _) {
    completer.completeError(StateError('open failed'));
  }).toJS;
  return completer.future;
}

Future<T> _await<T extends JSAny?>(web.IDBRequest request) {
  final completer = Completer<T>();
  request.onsuccess = ((web.Event _) {
    completer.complete(request.result as T);
  }).toJS;
  request.onerror = ((web.Event _) {
    completer.completeError(StateError('request failed'));
  }).toJS;
  return completer.future;
}

/// Reads what is PHYSICALLY stored, bypassing the backend entirely — the only
/// honest way to assert "the secret is not in there".
Future<Uint8List?> _rawRecord(String database, String key) async {
  final db = await _open(database);
  try {
    final stored = await _await<JSAny?>(
      db.transaction('records'.toJS, 'readonly').objectStore('records').get(
        key.toJS,
      ),
    );
    return stored == null ? null : (stored as JSUint8Array).toDart;
  } finally {
    db.close();
  }
}

Future<List<String>> _allKeys(String database) async {
  final db = await _open(database);
  try {
    final keys = await _await<JSAny?>(
      db.transaction('records'.toJS, 'readonly').objectStore('records').getAllKeys(),
    );
    return ((keys as JSArray).toDart)
        .map((item) => (item as JSString).toDart)
        .toList(growable: false);
  } finally {
    db.close();
  }
}

Future<void> _corruptRecord(String database, String key) async {
  final current = (await _rawRecord(database, key))!;
  final tampered = Uint8List.fromList(current)
    ..[current.length - 1] = current[current.length - 1] ^ 0xFF;
  final db = await _open(database);
  try {
    await _await<JSAny?>(
      db
          .transaction('records'.toJS, 'readwrite')
          .objectStore('records')
          .put(tampered.toJS, key.toJS),
    );
  } finally {
    db.close();
  }
}
