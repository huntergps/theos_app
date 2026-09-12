import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';
import 'dart:typed_data';

import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:web/web.dart' as web;

/// The browser's equivalent of a keychain, and the reason W04 could revoke
/// "the web persists nothing" without lowering the bar.
///
/// ## What makes it equivalent
///
/// A 256-bit AES-GCM key is generated with `extractable: false` and the
/// **key object** — not its bytes — is stored in IndexedDB. The browser
/// persists it across reloads and restarts, scoped to this origin and this
/// browser profile. The page's own code can *use* it to encrypt and decrypt
/// and **cannot read it**: `crypto.subtle.exportKey` rejects, in both `raw`
/// and `jwk` form. Measured in a real Chrome, not assumed — see
/// `test/web/web_crypto_unlock_backend_test.dart`.
///
/// That is the whole point of the design. The default mechanism of
/// `flutter_secure_storage_web` keeps its AES key in the same `localStorage`
/// as the ciphertext, so anything that can read the ciphertext can also read
/// the key and undo it — the key under the doormat. Here there is no key to
/// find: it never exists as bytes anywhere the page can reach.
///
/// ## What it does NOT protect against, stated plainly
///
/// A script injected into this origin — an XSS hole, a malicious extension
/// with access to the page, a compromised dependency — can still **call**
/// `decrypt` with the key, because the key is usable by definition. It cannot
/// carry the key away to another machine, and it cannot read the stored bytes
/// without running inside this origin. So this raises the cost of a stolen
/// device or a dumped profile directory from "trivial" to "needs code
/// execution in the page", and does nothing against code execution in the
/// page. Clearing site data destroys the key, which makes every stored record
/// unreadable — handled as "nothing stored", never as an error.
///
/// ## Why the payload is still only a derivation
///
/// What gets written here is what gets written on the desktop: the salted,
/// iterated [SecretDerivation] of the password, never the password and never
/// a credential that could be replayed against Odoo. A stolen derivation
/// cannot log in anywhere; it can only answer "is this the same string?".
/// The encryption is defence in depth on top of that, not a substitute for it.
final class WebCryptoCredentialBackend implements CredentialBackend {
  /// [databaseName] is injectable so each test gets its own IndexedDB and
  /// cannot inherit a key or a record from another one.
  WebCryptoCredentialBackend({this.databaseName = _defaultDatabase});


  static const _defaultDatabase = 'orbi_secure_unlock_store';
  static const _keyStore = 'keys';
  static const _recordStore = 'records';
  static const _keyId = 'unlock-aes-gcm-v1';
  static const _ivLength = 12;

  /// IndexedDB database this backend owns.
  final String databaseName;

  /// One in-flight setup at a time: two concurrent writes must never each
  /// generate a key and have the loser's records become undecryptable.
  Future<web.CryptoKey>? _keySetup;

  @override
  Future<void> write(String key, String value) async {
    final cryptoKey = await _keyOrCreate();
    final iv = _randomBytes(_ivLength);
    final cipher =
        await web.window.crypto.subtle
                .encrypt(
                  _gcmParams(iv),
                  cryptoKey,
                  // utf8, NOT `codeUnits`: a code unit above 255 — an accent
                  // in a database name, a non-ASCII character anywhere in the
                  // stored payload — is silently TRUNCATED by `codeUnits`, and
                  // the corruption only shows up on read, far from the cause.
                  Uint8List.fromList(utf8.encode(value)).toJS,
                )
                .toDart
            as JSArrayBuffer;
    // iv ‖ ciphertext in one blob: the IV is not a secret, it only has to be
    // unique per write, and keeping them together makes a record atomic.
    final sealed = Uint8List(iv.length + cipher.toDart.lengthInBytes)
      ..setRange(0, iv.length, iv)
      ..setRange(iv.length, iv.length + cipher.toDart.lengthInBytes,
          cipher.toDart.asUint8List());
    final db = await _open();
    try {
      final transaction = db.transaction(_recordStore.toJS, 'readwrite');
      await _await<JSAny?>(
        transaction.objectStore(_recordStore).put(sealed.toJS, key.toJS),
      );
    } finally {
      db.close();
    }
  }

  @override
  Future<String?> read(String key) async {
    final db = await _open();
    Uint8List? sealed;
    try {
      final transaction = db.transaction(_recordStore.toJS, 'readonly');
      final stored = await _await<JSAny?>(
        transaction.objectStore(_recordStore).get(key.toJS),
      );
      if (stored == null) return null;
      sealed = (stored as JSUint8Array).toDart;
    } finally {
      db.close();
    }
    if (sealed.length <= _ivLength) {
      await delete(key);
      return null;
    }
    final cryptoKey = await _keyOrNull();
    if (cryptoKey == null) {
      // The key is gone (site data cleared) so every record is permanently
      // unreadable. Drop it rather than keep an entry that can never verify.
      await delete(key);
      return null;
    }
    try {
      final plain =
          await web.window.crypto.subtle
                  .decrypt(
                    _gcmParams(Uint8List.sublistView(sealed, 0, _ivLength)),
                    cryptoKey,
                    Uint8List.sublistView(sealed, _ivLength).toJS,
                  )
                  .toDart
              as JSArrayBuffer;
      return utf8.decode(plain.toDart.asUint8List());
    } catch (_) {
      // Authentication failure: tampered, or written under an older key.
      await delete(key);
      return null;
    }
  }

  @override
  Future<void> delete(String key) async {
    final db = await _open();
    try {
      final transaction = db.transaction(_recordStore.toJS, 'readwrite');
      await _await<JSAny?>(
        transaction.objectStore(_recordStore).delete(key.toJS),
      );
    } finally {
      db.close();
    }
  }

  JSAny _gcmParams(Uint8List iv) =>
      {'name': 'AES-GCM', 'iv': iv.toJS}.jsify()!;

  Future<web.CryptoKey> _keyOrCreate() =>
      _keySetup ??= _loadOrGenerateKey().onError<Object>((error, stack) {
        _keySetup = null;
        throw error;
      });

  Future<web.CryptoKey?> _keyOrNull() async {
    try {
      return await _keyOrCreate();
    } catch (_) {
      return null;
    }
  }

  Future<web.CryptoKey> _loadOrGenerateKey() async {
    final db = await _open();
    try {
      final existing = await _await<JSAny?>(
        db.transaction(_keyStore.toJS, 'readonly').objectStore(_keyStore).get(
          _keyId.toJS,
        ),
      );
      if (existing != null) {
        final key = existing as web.CryptoKey;
        // A key that somehow came back extractable is not the key this class
        // promises, so it is replaced rather than trusted.
        if (!key.extractable) return key;
      }
      final generated =
          await web.window.crypto.subtle
                  .generateKey(
                    {'name': 'AES-GCM', 'length': 256}.jsify()!,
                    // The entire guarantee: the browser keeps it, the page
                    // uses it, nothing can read it back out.
                    false,
                    ['encrypt', 'decrypt'].jsify()! as JSArray<JSString>,
                  )
                  .toDart
              as web.CryptoKey;
      await _await<JSAny?>(
        db
            .transaction(_keyStore.toJS, 'readwrite')
            .objectStore(_keyStore)
            .put(generated as JSAny, _keyId.toJS),
      );
      return generated;
    } finally {
      db.close();
    }
  }

  Future<web.IDBDatabase> _open() {
    final completer = Completer<web.IDBDatabase>();
    final open = web.window.indexedDB.open(databaseName, 1);
    open.onupgradeneeded = ((web.Event _) {
      final db = open.result as web.IDBDatabase;
      if (!db.objectStoreNames.contains(_keyStore)) {
        db.createObjectStore(_keyStore);
      }
      if (!db.objectStoreNames.contains(_recordStore)) {
        db.createObjectStore(_recordStore);
      }
    }).toJS;
    open.onsuccess = ((web.Event _) {
      completer.complete(open.result as web.IDBDatabase);
    }).toJS;
    open.onerror = ((web.Event _) {
      completer.completeError(
        StateError('IndexedDB no se pudo abrir: ${open.error?.name}'),
      );
    }).toJS;
    open.onblocked = ((web.Event _) {
      completer.completeError(StateError('IndexedDB bloqueado'));
    }).toJS;
    return completer.future;
  }

  static Future<T> _await<T extends JSAny?>(web.IDBRequest request) {
    final completer = Completer<T>();
    request.onsuccess = ((web.Event _) {
      completer.complete(request.result as T);
    }).toJS;
    request.onerror = ((web.Event _) {
      completer.completeError(
        StateError('IndexedDB falló: ${request.error?.name}'),
      );
    }).toJS;
    return completer.future;
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}

/// Web: a non-extractable AES-GCM key in IndexedDB. See
/// [WebCryptoCredentialBackend] for what that protects and what it does not.
CredentialBackend createUnlockCredentialBackend() =>
    WebCryptoCredentialBackend();
