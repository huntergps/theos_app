import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/src/auth/encrypted_credential_envelope.dart';
import 'package:pointycastle/export.dart' show InvalidCipherTextException;

Uint8List _hex(String value) => Uint8List.fromList(
  List<int>.generate(
    value.length ~/ 2,
    (i) => int.parse(value.substring(i * 2, i * 2 + 2), radix: 16),
  ),
);

void main() {
  group('vectores publicados — obligatorio', () {
    // RFC 9106 §5.3, el vector oficial de Argon2id (no Argon2i/Argon2d).
    // Verificado contra el texto de la RFC, no de memoria.
    test('Argon2id reproduce el vector de RFC 9106 §5.3', () {
      final password = _hex('01' * 32);
      final salt = _hex('02' * 16);
      final secret = _hex('03' * 8);
      final additional = _hex('04' * 12);
      final expectedTag = _hex(
        '0d640df58d78766c08c037a34a8b53c9'
        'd01ef0452d75b65eb52520e96b01e659',
      );

      final key = deriveArgon2idKeyWithExtras(
        passwordBytes: password,
        salt: salt,
        secret: secret,
        additional: additional,
        cost: const Argon2Cost(memoryKiB: 32, iterations: 3, lanes: 4),
        desiredKeyLength: 32,
      );

      expect(key, equals(expectedTag));
    });

    // McGrew & Viega, los vectores de referencia de AES-256-GCM que también
    // trae la propia suite de pointycastle (test/modes/gcm_test.dart) —
    // Test Case 13 (todo cero, sin AAD) y Test Case 16 (con AAD real).
    // Extraídos del archivo fuente instalado, no de memoria.
    test('AES-256-GCM reproduce McGrew-Viega Test Case 13 (todo cero)', () {
      final key = _hex('00' * 32);
      final nonce = _hex('00' * 12);
      final expectedTag = _hex('530f8afbc74536b9a963b4f1c4cb738b');

      final sealed = encryptAesGcm(
        key: key,
        nonce: nonce,
        plainText: Uint8List(0),
      );
      // process() devuelve ciphertext‖tag; con texto plano vacío, sealed
      // es sólo la etiqueta.
      expect(sealed, equals(expectedTag));
    });

    test(
      'AES-256-GCM reproduce McGrew-Viega Test Case 16 (con datos autenticados)',
      () {
        final key = _hex(
          'feffe9928665731c6d6a8f9467308308feffe9928665731c6d6a8f9467308308',
        );
        final nonce = _hex('cafebabefacedbaddecaf888');
        final plainText = _hex(
          'd9313225f88406e5a55909c5aff5269a86a7a9531534f7da2e4c303d8a318a7'
          '21c3c0c95956809532fcf0e2449a6b525b16aedf5aa0de657ba637b39',
        );
        final expectedCipherText = _hex(
          '522dc1f099567d07f47f37a32a84427d643a8cdcbfe5c0c97598a2bd2555d1a'
          'a8cb08e48590dbb3da7b08b1056828838c5f61e6393ba7a0abcc9f662',
        );
        final expectedTag = _hex('76fc6ece0f4e1768cddf8853bb2d551b');

        // encryptAesGcm/decryptAesGcm no llevan AAD propio (el diseño de
        // §8.4 no lo necesita), así que este vector se reproduce llamando
        // directo al cifrador con AAD para probar la primitiva subyacente,
        // sin pasar por el envoltorio de más alto nivel.
        final sealed = encryptAesGcmWithAad(
          key: key,
          nonce: nonce,
          plainText: plainText,
          aad: _hex('feedfacedeadbeeffeedfacedeadbeefabaddad2'),
        );
        expect(
          sealed,
          equals(Uint8List.fromList([...expectedCipherText, ...expectedTag])),
        );
      },
    );
  });

  group('unicidad del nonce — obligatorio', () {
    test(
      'sellar el mismo texto dos veces con la misma contraseña nunca repite el nonce ni el cifrado',
      () {
        const password = 'la-misma-contraseña';
        const plainText = 'el mismo secreto, dos sellados distintos';

        final first = EncryptedCredentialEnvelope.seal(password, plainText);
        final second = EncryptedCredentialEnvelope.seal(password, plainText);

        expect(
          first.nonce,
          isNot(equals(second.nonce)),
          reason:
              'un nonce de AES-GCM repetido bajo la misma llave rompe el '
              'cifrado de verdad, no es un fallo menor',
        );
        expect(
          first.cipherTextWithTag,
          isNot(equals(second.cipherTextWithTag)),
        );
        // Las sales también deben variar: si compartieran sal, la llave
        // derivada sería idéntica y la única variable que evitaría repetir
        // el cifrado sería el nonce — hay que probar ambas, no una sola.
        expect(first.salt, isNot(equals(second.salt)));
      },
    );

    test('cien sellados seguidos nunca repiten un nonce', () {
      const password = 'contraseña-de-prueba';
      final seen = <String>{};
      for (var i = 0; i < 100; i++) {
        final envelope = EncryptedCredentialEnvelope.seal(password, 'valor');
        final nonceHex = base64Encode(envelope.nonce);
        expect(
          seen.contains(nonceHex),
          isFalse,
          reason: 'nonce repetido en la iteración $i',
        );
        seen.add(nonceHex);
      }
    });
  });

  group('funcional', () {
    test('sella y abre con la contraseña correcta', () {
      final envelope = EncryptedCredentialEnvelope.seal(
        'correcta',
        'el api key de verdad',
      );
      expect(envelope.open('correcta'), 'el api key de verdad');
    });

    test('abrir con la contraseña equivocada devuelve null, nunca basura', () {
      final envelope = EncryptedCredentialEnvelope.seal(
        'correcta',
        'el api key de verdad',
      );
      expect(envelope.open('incorrecta'), isNull);
    });

    test('un archivo manipulado (un byte del cifrado) falla, no decodifica basura', () {
      final envelope = EncryptedCredentialEnvelope.seal('correcta', 'valor');
      final tampered = Uint8List.fromList(envelope.cipherTextWithTag);
      tampered[0] ^= 0xFF;
      final tamperedEnvelope = EncryptedCredentialEnvelope(
        cost: envelope.cost,
        salt: envelope.salt,
        nonce: envelope.nonce,
        cipherTextWithTag: tampered,
      );
      expect(tamperedEnvelope.open('correcta'), isNull);
    });

    test('codifica y decodifica un envoltorio de ida y vuelta', () {
      final envelope = EncryptedCredentialEnvelope.seal('x', 'y');
      final decoded = EncryptedCredentialEnvelope.decode(envelope.encode());
      expect(decoded.open('x'), 'y');
    });

    test('decode rechaza una versión desconocida', () {
      final payload = Uint8List.fromList(
        utf8.encode('{"version": 99, "argon2": {}, "salt": "", "nonce": "", "cipherText": ""}'),
      );
      expect(
        () => EncryptedCredentialEnvelope.decode(payload),
        throwsFormatException,
      );
    });

    test('decode rechaza basura ilegible', () {
      expect(
        () => EncryptedCredentialEnvelope.decode(
          Uint8List.fromList(utf8.encode('no es json')),
        ),
        throwsFormatException,
      );
    });

    test(
      'decryptAesGcm lanza InvalidCipherTextException con la llave equivocada',
      () {
        final key = Uint8List(32);
        final wrongKey = Uint8List(32)..[0] = 1;
        final nonce = Uint8List(12);
        final sealed = encryptAesGcm(
          key: key,
          nonce: nonce,
          plainText: Uint8List.fromList(utf8.encode('secreto')),
        );
        expect(
          () => decryptAesGcm(
            key: wrongKey,
            nonce: nonce,
            cipherTextWithTag: sealed,
          ),
          throwsA(isA<InvalidCipherTextException>()),
        );
      },
    );
  });
}
