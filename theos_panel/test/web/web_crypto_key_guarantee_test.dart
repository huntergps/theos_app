@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

Future<T> _request<T extends JSAny?>(web.IDBRequest request) {
  final completer = Completer<T>();
  request.onsuccess = ((web.Event _) {
    completer.complete(request.result as T);
  }).toJS;
  request.onerror = ((web.Event _) {
    completer.completeError(StateError('idb error: ${request.error?.name}'));
  }).toJS;
  return completer.future;
}

Future<web.IDBDatabase> _openDb(String name) {
  final completer = Completer<web.IDBDatabase>();
  final open = web.window.indexedDB.open(name, 1);
  open.onupgradeneeded = ((web.Event _) {
    final db = open.result as web.IDBDatabase;
    db.createObjectStore('keys');
  }).toJS;
  open.onsuccess = ((web.Event _) {
    completer.complete(open.result as web.IDBDatabase);
  }).toJS;
  open.onerror = ((web.Event _) {
    completer.completeError(StateError('open failed'));
  }).toJS;
  return completer.future;
}

/// The measurement W04 rests on. It does not test our code: it tests the
/// BROWSER PLATFORM GUARANTEE our code depends on, so that if a future browser
/// or a future `package:web` ever stops honouring `extractable: false`, this
/// fails instead of the guarantee quietly evaporating.
///
/// Run with: `flutter test --platform chrome test/web/`
void main() {
  test('una llave AES-GCM NO extraíble sobrevive a IndexedDB, sirve para '
      'cifrar y descifrar, y el código de la página no la puede leer', () async {
    // 1. Generar la llave con extractable: false.
    final key =
        await web.window.crypto.subtle
                .generateKey(
                  {'name': 'AES-GCM', 'length': 256}.jsify()!,
                  false,
                  ['encrypt', 'decrypt'].jsify()! as JSArray<JSString>,
                )
                .toDart
            as web.CryptoKey;
    expect(key.extractable, isFalse, reason: 'la llave no debe ser extraíble');

    // 2. Guardar el OBJETO de la llave en IndexedDB.
    const dbName = 'orbi-webcrypto-probe';
    final db = await _openDb(dbName);
    final write = db.transaction('keys'.toJS, 'readwrite');
    await _request<JSAny?>(
      write.objectStore('keys').put(key as JSAny, 'unlock-key'.toJS),
    );
    db.close();

    // 3. Reabrir la base (simula otra carga de la página) y recuperarla.
    final reopened = await _openDb(dbName);
    final read = reopened.transaction('keys'.toJS, 'readonly');
    final restored =
        await _request<JSAny?>(
              read.objectStore('keys').get('unlock-key'.toJS),
            )
            as web.CryptoKey;
    expect(restored.extractable, isFalse);
    expect(restored.type, 'secret');

    // 4. Sigue sirviendo para cifrar y descifrar.
    final iv = Uint8List.fromList(List<int>.generate(12, (i) => i + 1));
    final plaintext = Uint8List.fromList('derivado-de-prueba'.codeUnits);
    final algorithm = {'name': 'AES-GCM', 'iv': iv.toJS}.jsify()!;
    final cipher =
        await web.window.crypto.subtle
                .encrypt(algorithm, restored, plaintext.toJS)
                .toDart
            as JSArrayBuffer;
    final back =
        await web.window.crypto.subtle
                .decrypt(algorithm, restored, cipher)
                .toDart
            as JSArrayBuffer;
    expect(back.toDart.asUint8List(), plaintext);

    // 5. LO QUE IMPORTA: el código de la página NO puede leer la llave.
    Object? rawError;
    try {
      await web.window.crypto.subtle.exportKey('raw', restored).toDart;
    } catch (error) {
      rawError = error;
    }
    expect(
      rawError,
      isNotNull,
      reason: 'exportKey debe fallar con una llave no extraíble',
    );

    Object? jwkError;
    try {
      await web.window.crypto.subtle.exportKey('jwk', restored).toDart;
    } catch (error) {
      jwkError = error;
    }
    expect(jwkError, isNotNull, reason: 'tampoco por JWK');

    reopened.close();
    await _request<JSAny?>(web.window.indexedDB.deleteDatabase(dbName));
  });
}
