import 'dart:convert';

import 'package:test/test.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

void main() {
  group('CacheEncryption', () {
    group('NoCacheEncryption', () {
      test('passes through plaintext unchanged', () {
        const encryption = NoCacheEncryption();

        expect(encryption.encrypt('hello'), equals('hello'));
        expect(encryption.decrypt('hello'), equals('hello'));
      });

      test('handles empty strings', () {
        const encryption = NoCacheEncryption();

        expect(encryption.encrypt(''), equals(''));
        expect(encryption.decrypt(''), equals(''));
      });

      test('handles special characters', () {
        const encryption = NoCacheEncryption();
        const text = 'Hello "World" with \'quotes\' and émojis 🎉';

        expect(encryption.decrypt(encryption.encrypt(text)), equals(text));
      });
    });

    group('ObfuscationCacheEncryption', () {
      test('encrypts and decrypts correctly', () {
        final encryption = ObfuscationCacheEncryption('test-key');

        const original = 'Hello, World!';
        final encrypted = encryption.encrypt(original);
        final decrypted = encryption.decrypt(encrypted);

        expect(encrypted, isNot(equals(original)));
        expect(decrypted, equals(original));
      });

      test('handles empty strings', () {
        final encryption = ObfuscationCacheEncryption('test-key');

        expect(encryption.encrypt(''), equals(''));
        expect(encryption.decrypt(''), equals(''));
      });

      test('handles unicode and emojis', () {
        final encryption = ObfuscationCacheEncryption('test-key');

        const original = '你好世界 🌍 مرحبا';
        final encrypted = encryption.encrypt(original);
        final decrypted = encryption.decrypt(encrypted);

        expect(decrypted, equals(original));
      });

      test('different keys produce different output', () {
        final encryption1 = ObfuscationCacheEncryption('key1');
        final encryption2 = ObfuscationCacheEncryption('key2');

        const original = 'test message';
        final encrypted1 = encryption1.encrypt(original);
        final encrypted2 = encryption2.encrypt(original);

        expect(encrypted1, isNot(equals(encrypted2)));
      });

      test('uses default key for empty key string', () {
        final encryption = ObfuscationCacheEncryption('');

        const original = 'test';
        final encrypted = encryption.encrypt(original);
        final decrypted = encryption.decrypt(encrypted);

        expect(decrypted, equals(original));
      });

      test('handles long strings', () {
        final encryption = ObfuscationCacheEncryption('key');

        final original = 'x' * 10000;
        final encrypted = encryption.encrypt(original);
        final decrypted = encryption.decrypt(encrypted);

        expect(decrypted, equals(original));
      });
    });

    group('AesCacheEncryption', () {
      test('encrypts and decrypts correctly', () {
        final encryption = AesCacheEncryption.fromPassword('test-password');

        const original = 'Secret data!';
        final encrypted = encryption.encrypt(original);
        final decrypted = encryption.decrypt(encrypted);

        expect(encrypted, isNot(equals(original)));
        expect(decrypted, equals(original));
      });

      test('handles empty strings', () {
        final encryption = AesCacheEncryption.fromPassword('password');

        expect(encryption.encrypt(''), equals(''));
        expect(encryption.decrypt(''), equals(''));
      });

      test('handles unicode and emojis', () {
        final encryption = AesCacheEncryption.fromPassword('secret');

        const original = 'Données secrètes 🔐';
        final encrypted = encryption.encrypt(original);
        final decrypted = encryption.decrypt(encrypted);

        expect(decrypted, equals(original));
      });

      test('different passwords produce different output', () {
        final encryption1 = AesCacheEncryption.fromPassword('password1');
        final encryption2 = AesCacheEncryption.fromPassword('password2');

        const original = 'test message';
        final encrypted1 = encryption1.encrypt(original);
        final encrypted2 = encryption2.encrypt(original);

        expect(encrypted1, isNot(equals(encrypted2)));
      });

      test('same password with different salt produces different output', () {
        final encryption1 = AesCacheEncryption.fromPassword(
          'password',
          salt: 'salt1',
        );
        final encryption2 = AesCacheEncryption.fromPassword(
          'password',
          salt: 'salt2',
        );

        const original = 'test message';
        final encrypted1 = encryption1.encrypt(original);
        final encrypted2 = encryption2.encrypt(original);

        expect(encrypted1, isNot(equals(encrypted2)));
      });

      test('throws on invalid ciphertext', () {
        final encryption = AesCacheEncryption.fromPassword('password');

        expect(
          () => encryption.decrypt('not-valid-base64!!!'),
          throwsA(isA<CacheDecryptionException>()),
        );
      });

      test('throws on tampered ciphertext', () {
        final encryption = AesCacheEncryption.fromPassword('password');

        final encrypted = encryption.encrypt('test');
        // Tamper with the middle of the ciphertext
        final bytes = base64Decode(encrypted);
        if (bytes.length > 10) {
          bytes[5] = (bytes[5] + 1) % 256;
        }
        final tampered = base64Encode(bytes);

        expect(
          () => encryption.decrypt(tampered),
          throwsA(isA<CacheDecryptionException>()),
        );
      });

      test('handles JSON data', () {
        final encryption = AesCacheEncryption.fromPassword('password');

        final original = {
          'name': 'John',
          'email': 'john@example.com',
          'age': 30,
        };
        final json = jsonEncode(original);
        final encrypted = encryption.encrypt(json);
        final decrypted = encryption.decrypt(encrypted);
        final restored = jsonDecode(decrypted);

        expect(restored, equals(original));
      });
    });

    group('CacheEncryptionExtension', () {
      test('encryptValue serializes and encrypts', () {
        final encryption = ObfuscationCacheEncryption('key');

        final original = {'name': 'Test', 'value': 123};
        final encrypted = encryption.encryptValue(original);

        expect(encrypted, isNot(contains('Test')));
        expect(encrypted, isNot(contains('123')));
      });

      test('decryptValue decrypts and deserializes', () {
        final encryption = ObfuscationCacheEncryption('key');

        final original = {'name': 'Test', 'value': 123};
        final encrypted = encryption.encryptValue(original);
        final decrypted = encryption.decryptValue<Map<String, dynamic>>(
          encrypted,
          (json) => json as Map<String, dynamic>,
        );

        expect(decrypted, equals(original));
      });
    });
  });

  group('EncryptedRecordCache', () {
    late EncryptedRecordCache<int, Map<String, dynamic>> cache;

    setUp(() {
      cache = EncryptedRecordCache<int, Map<String, dynamic>>(
        config: EncryptedCacheConfig.obfuscated(key: 'test-key'),
        serialize: (value) => jsonEncode(value),
        deserialize: (json) => jsonDecode(json) as Map<String, dynamic>,
      );
    });

    tearDown(() {
      cache.dispose();
    });

    test('put and get work correctly', () {
      final data = {'name': 'John', 'email': 'john@example.com'};
      cache.put(1, data);

      final retrieved = cache.get(1);
      expect(retrieved, equals(data));
    });

    test('returns null for non-existent key', () {
      expect(cache.get(999), isNull);
    });

    test('contains key works correctly', () {
      cache.put(1, {'test': true});

      expect(cache.containsKey(1), isTrue);
      expect(cache.containsKey(2), isFalse);
    });

    test('remove works correctly', () {
      cache.put(1, {'test': true});
      expect(cache.containsKey(1), isTrue);

      final removed = cache.remove(1);
      expect(removed, equals({'test': true}));
      expect(cache.containsKey(1), isFalse);
    });

    test('clear removes all entries', () {
      cache.put(1, {'a': 1});
      cache.put(2, {'b': 2});
      cache.put(3, {'c': 3});

      expect(cache.length, equals(3));

      cache.clear();
      expect(cache.isEmpty, isTrue);
    });

    test('putAll works correctly', () {
      cache.putAll({
        1: {'a': 1},
        2: {'b': 2},
        3: {'c': 3},
      });

      expect(cache.length, equals(3));
      expect(cache.get(1), equals({'a': 1}));
      expect(cache.get(2), equals({'b': 2}));
      expect(cache.get(3), equals({'c': 3}));
    });

    test('values returns all decrypted values', () {
      cache.put(1, {'a': 1});
      cache.put(2, {'b': 2});

      final values = cache.values;
      expect(values.length, equals(2));
      expect(values[1], equals({'a': 1}));
      expect(values[2], equals({'b': 2}));
    });

    test('keys returns all keys', () {
      cache.put(1, {'a': 1});
      cache.put(2, {'b': 2});

      expect(cache.keys.toSet(), equals({1, 2}));
    });

    test('length tracks entries correctly', () {
      expect(cache.length, equals(0));
      expect(cache.isEmpty, isTrue);

      cache.put(1, {'a': 1});
      expect(cache.length, equals(1));
      expect(cache.isNotEmpty, isTrue);

      cache.put(2, {'b': 2});
      expect(cache.length, equals(2));

      cache.remove(1);
      expect(cache.length, equals(1));
    });

    test('getOrComputeSync returns cached value', () {
      cache.put(1, {'cached': true});

      var computed = false;
      final result = cache.getOrComputeSync(1, () {
        computed = true;
        return {'computed': true};
      });

      expect(result, equals({'cached': true}));
      expect(computed, isFalse);
    });

    test('getOrComputeSync computes on miss', () {
      var computed = false;
      final result = cache.getOrComputeSync(1, () {
        computed = true;
        return {'computed': true};
      });

      expect(result, equals({'computed': true}));
      expect(computed, isTrue);
      expect(cache.get(1), equals({'computed': true}));
    });

    test('invalidateWhere removes matching entries', () {
      cache.put(1, {'type': 'a', 'value': 1});
      cache.put(2, {'type': 'b', 'value': 2});
      cache.put(3, {'type': 'a', 'value': 3});

      final removed = cache.invalidateWhere(
        (key, value) => value['type'] == 'a',
      );

      expect(removed, equals(2));
      expect(cache.length, equals(1));
      expect(cache.get(2), equals({'type': 'b', 'value': 2}));
    });

    test('tracks encryption stats', () {
      cache.put(1, {'a': 1});
      cache.put(2, {'b': 2});
      cache.get(1);
      cache.get(2);

      final stats = cache.encryptionStats;
      expect(stats.encryptionCount, equals(2));
      expect(stats.decryptionCount, greaterThanOrEqualTo(2));
      expect(stats.encryptionErrors, equals(0));
      expect(stats.decryptionErrors, equals(0));
    });

    test('handles encryption errors gracefully', () {
      var errorCaught = false;

      final badCache = EncryptedRecordCache<int, Map<String, dynamic>>(
        config: EncryptedCacheConfig(
          encryption: _FailingEncryption(),
          onEncryptionError: (e, s) => errorCaught = true,
        ),
        serialize: (value) => jsonEncode(value),
        deserialize: (json) => jsonDecode(json) as Map<String, dynamic>,
      );

      expect(
        () => badCache.put(1, {'test': true}),
        throwsA(isA<CacheEncryptionException>()),
      );
      expect(errorCaught, isTrue);

      badCache.dispose();
    });

    test('emits change events', () async {
      final events = <CacheChangeEvent<int, Map<String, dynamic>>>[];
      cache.changes.listen(events.add);

      cache.put(1, {'a': 1});
      await Future.delayed(const Duration(milliseconds: 50));

      expect(events, isNotEmpty);
      expect(events.first.type, equals(CacheChangeType.added));
      expect(events.first.key, equals(1));
    });

    test('valuesStream emits updated values', () async {
      final valueSnapshots = <Map<int, Map<String, dynamic>>>[];
      cache.valuesStream.listen(valueSnapshots.add);

      cache.put(1, {'a': 1});
      await Future.delayed(const Duration(milliseconds: 50));

      cache.put(2, {'b': 2});
      await Future.delayed(const Duration(milliseconds: 50));

      expect(valueSnapshots.length, greaterThanOrEqualTo(2));
    });

    test('refresh extends TTL', () {
      cache.put(1, {'a': 1});
      expect(cache.refresh(1), isTrue);
      expect(cache.refresh(999), isFalse);
    });

    test('dispose prevents further operations', () {
      cache.dispose();

      expect(() => cache.put(1, {'a': 1}), throwsA(isA<StateError>()));
    });
  });

  group('EncryptedCacheConfig', () {
    test('withPassword creates AES encryption', () {
      final config = EncryptedCacheConfig.withPassword(
        password: 'test-password',
        salt: 'test-salt',
      );

      expect(config.encryption, isA<AesCacheEncryption>());
    });

    test('obfuscated creates obfuscation encryption', () {
      final config = EncryptedCacheConfig.obfuscated(key: 'test-key');

      expect(config.encryption, isA<ObfuscationCacheEncryption>());
    });

    test('accepts custom cache config', () {
      const cacheConfig = RecordCacheConfig(
        maxSize: 500,
        ttl: Duration(minutes: 10),
      );

      final config = EncryptedCacheConfig.withPassword(
        password: 'password',
        cacheConfig: cacheConfig,
      );

      expect(config.cacheConfig.maxSize, equals(500));
      expect(config.cacheConfig.ttl, equals(const Duration(minutes: 10)));
    });

    test('validateOnDecrypt can be enabled', () {
      final config = EncryptedCacheConfig.withPassword(
        password: 'password',
        validateOnDecrypt: true,
      );

      expect(config.validateOnDecrypt, isTrue);
    });
  });

  group('EncryptedCacheStats', () {
    test('calculates error rates correctly', () {
      const stats = EncryptedCacheStats(
        encryptionCount: 100,
        decryptionCount: 100,
        encryptionErrors: 5,
        decryptionErrors: 10,
      );

      expect(stats.encryptionErrorRate, equals(0.05));
      expect(stats.decryptionErrorRate, equals(0.10));
    });

    test('handles zero counts', () {
      const stats = EncryptedCacheStats();

      expect(stats.encryptionErrorRate, equals(0.0));
      expect(stats.decryptionErrorRate, equals(0.0));
    });

    test('toString includes all info', () {
      const stats = EncryptedCacheStats(
        encryptionCount: 10,
        decryptionCount: 20,
        encryptionErrors: 1,
        decryptionErrors: 2,
      );

      final str = stats.toString();
      expect(str, contains('10'));
      expect(str, contains('20'));
      expect(str, contains('1'));
      expect(str, contains('2'));
    });
  });
}

/// Mock encryption that always fails.
class _FailingEncryption implements CacheEncryption {
  @override
  String encrypt(String plaintext) {
    throw const CacheEncryptionException('Simulated failure');
  }

  @override
  String decrypt(String ciphertext) {
    throw const CacheDecryptionException('Simulated failure');
  }
}
