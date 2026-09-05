/// Cache Encryption Support for PII Protection
///
/// SEC-05: Provides encryption for cached data to protect
/// Personally Identifiable Information (PII) at rest.
///
/// This module provides:
/// - [CacheEncryption] interface for custom implementations
/// - [AesCacheEncryption] for AES-256 encryption (requires `encrypt` package)
/// - [ObfuscationCacheEncryption] for basic obfuscation (development only)
///
/// For production use, implement [CacheEncryption] with a proper
/// cryptographic library like `encrypt` or `pointycastle`.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Interface for cache encryption.
///
/// Implement this interface to provide encryption/decryption
/// for cached values. The implementation should be thread-safe
/// and handle null values gracefully.
///
/// Example with `encrypt` package:
/// ```dart
/// import 'package:encrypt/encrypt.dart' as encrypt;
///
/// class AesCacheEncryption implements CacheEncryption {
///   final encrypt.Key _key;
///   final encrypt.IV _iv;
///   late final encrypt.Encrypter _encrypter;
///
///   AesCacheEncryption(String keyString) :
///     _key = encrypt.Key.fromUtf8(keyString.padRight(32).substring(0, 32)),
///     _iv = encrypt.IV.fromLength(16) {
///     _encrypter = encrypt.Encrypter(encrypt.AES(_key));
///   }
///
///   @override
///   String encrypt(String plaintext) {
///     return _encrypter.encrypt(plaintext, iv: _iv).base64;
///   }
///
///   @override
///   String decrypt(String ciphertext) {
///     return _encrypter.decrypt64(ciphertext, iv: _iv);
///   }
/// }
/// ```
abstract class CacheEncryption {
  /// Encrypt a plaintext string.
  ///
  /// Returns the encrypted ciphertext (typically base64 encoded).
  /// Should handle empty strings gracefully.
  String encrypt(String plaintext);

  /// Decrypt a ciphertext string.
  ///
  /// Returns the original plaintext.
  /// Should throw [CacheDecryptionException] if decryption fails.
  String decrypt(String ciphertext);
}

/// Extension methods for encrypting/decrypting JSON values.
extension CacheEncryptionExtension on CacheEncryption {
  /// Encrypt a JSON-serializable value.
  ///
  /// The value is first serialized to JSON, then encrypted.
  String encryptValue<T>(T value) {
    final json = jsonEncode(value);
    return encrypt(json);
  }

  /// Decrypt and deserialize a value.
  ///
  /// The ciphertext is decrypted and parsed as JSON.
  T decryptValue<T>(String ciphertext, T Function(dynamic json) fromJson) {
    final json = decrypt(ciphertext);
    final decoded = jsonDecode(json);
    return fromJson(decoded);
  }
}

/// Exception thrown when cache decryption fails.
class CacheDecryptionException implements Exception {
  final String message;
  final Object? cause;

  const CacheDecryptionException(this.message, [this.cause]);

  @override
  String toString() => 'CacheDecryptionException: $message';
}

/// Exception thrown when cache encryption fails.
class CacheEncryptionException implements Exception {
  final String message;
  final Object? cause;

  const CacheEncryptionException(this.message, [this.cause]);

  @override
  String toString() => 'CacheEncryptionException: $message';
}

/// Basic obfuscation for development/testing only.
///
/// WARNING: This is NOT cryptographically secure and should
/// NEVER be used in production. It only provides basic obfuscation
/// to prevent casual inspection of cached data.
///
/// For production, use [AesCacheEncryption] or implement [CacheEncryption]
/// with a proper cryptographic library.
class ObfuscationCacheEncryption implements CacheEncryption {
  final List<int> _key;

  /// Create an obfuscation encryptor with a key string.
  ///
  /// The key is used for XOR obfuscation. Longer keys provide
  /// better obfuscation but this is still NOT secure encryption.
  ObfuscationCacheEncryption(String key)
    : _key = utf8.encode(key.isEmpty ? 'default-key' : key);

  @override
  String encrypt(String plaintext) {
    if (plaintext.isEmpty) return '';

    try {
      final bytes = utf8.encode(plaintext);
      final obfuscated = _xorBytes(bytes);
      return base64Encode(obfuscated);
    } catch (e) {
      throw CacheEncryptionException('Obfuscation failed', e);
    }
  }

  @override
  String decrypt(String ciphertext) {
    if (ciphertext.isEmpty) return '';

    try {
      final obfuscated = base64Decode(ciphertext);
      final bytes = _xorBytes(obfuscated);
      return utf8.decode(bytes);
    } catch (e) {
      throw CacheDecryptionException('Deobfuscation failed', e);
    }
  }

  Uint8List _xorBytes(List<int> input) {
    final result = Uint8List(input.length);
    for (var i = 0; i < input.length; i++) {
      result[i] = input[i] ^ _key[i % _key.length];
    }
    return result;
  }
}

/// Authenticated AES-GCM encryption for cache values.
///
/// Every value contains a format version, a fresh 96-bit nonce and the GCM
/// authentication tag. Callers never provide an IV, preventing accidental
/// nonce reuse with the same key.
class AesCacheEncryption implements CacheEncryption {
  static const _version = 1;
  static const _nonceLength = 12;
  static const _tagLengthBits = 128;
  static const _derivedKeyLength = 32;
  static const _defaultPbkdf2Iterations = 210000;

  final Uint8List _key;

  /// Creates an AES-GCM encryptor with a raw AES key.
  AesCacheEncryption({required Uint8List key})
    : _key = Uint8List.fromList(key) {
    if (key.length != 16 && key.length != 24 && key.length != 32) {
      throw ArgumentError('Key must be 16, 24, or 32 bytes');
    }
  }

  /// Creates an AES-GCM encryptor from a base64-encoded AES key.
  factory AesCacheEncryption.fromBase64({required String keyBase64}) {
    return AesCacheEncryption(key: base64Decode(keyBase64));
  }

  /// Derives an AES-256 key using PBKDF2-HMAC-SHA256.
  ///
  /// For persistent caches, [salt] must be application-specific random data
  /// persisted alongside the cache. When omitted, a secure random salt is
  /// generated and the resulting instance is intentionally session-only.
  factory AesCacheEncryption.fromPassword(
    String password, {
    String? salt,
    int iterations = _defaultPbkdf2Iterations,
  }) {
    if (password.isEmpty) {
      throw ArgumentError.value(password, 'password', 'Must not be empty');
    }
    if (salt != null && salt.isEmpty) {
      throw ArgumentError.value(salt, 'salt', 'Must not be empty');
    }
    if (iterations < 100000) {
      throw ArgumentError.value(
        iterations,
        'iterations',
        'Must be at least 100000',
      );
    }

    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(
        Pbkdf2Parameters(
          salt == null
              ? _secureRandomBytes(32)
              : Uint8List.fromList(utf8.encode(salt)),
          iterations,
          _derivedKeyLength,
        ),
      );
    final key = derivator.process(Uint8List.fromList(utf8.encode(password)));
    return AesCacheEncryption(key: key);
  }

  @override
  String encrypt(String plaintext) {
    if (plaintext.isEmpty) return '';

    try {
      final nonce = _secureRandomBytes(_nonceLength);
      final cipher = GCMBlockCipher(AESEngine())
        ..init(
          true,
          AEADParameters(
            KeyParameter(_key),
            _tagLengthBits,
            nonce,
            Uint8List(0),
          ),
        );
      final encrypted = cipher.process(
        Uint8List.fromList(utf8.encode(plaintext)),
      );
      return base64Encode(
        Uint8List.fromList(<int>[_version, ...nonce, ...encrypted]),
      );
    } catch (e) {
      throw CacheEncryptionException('AES encryption failed', e);
    }
  }

  @override
  String decrypt(String ciphertext) {
    if (ciphertext.isEmpty) return '';

    try {
      final envelope = base64Decode(ciphertext);
      const minimumLength = 1 + _nonceLength + (_tagLengthBits ~/ 8);
      if (envelope.length < minimumLength || envelope.first != _version) {
        throw const CacheDecryptionException(
          'Invalid or unsupported encrypted cache value',
        );
      }
      final nonce = Uint8List.fromList(envelope.sublist(1, 1 + _nonceLength));
      final encrypted = Uint8List.fromList(envelope.sublist(1 + _nonceLength));
      final cipher = GCMBlockCipher(AESEngine())
        ..init(
          false,
          AEADParameters(
            KeyParameter(_key),
            _tagLengthBits,
            nonce,
            Uint8List(0),
          ),
        );
      return utf8.decode(cipher.process(encrypted));
    } on CacheDecryptionException {
      rethrow;
    } catch (e) {
      throw CacheDecryptionException('AES decryption failed', e);
    }
  }

  static Uint8List _secureRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}

/// No-op encryption that passes values through unchanged.
///
/// Use this for testing or when encryption is not needed
/// but a [CacheEncryption] instance is required.
class NoCacheEncryption implements CacheEncryption {
  const NoCacheEncryption();

  @override
  String encrypt(String plaintext) => plaintext;

  @override
  String decrypt(String ciphertext) => ciphertext;
}

/// Wrapper that encrypts cached record values.
///
/// This is a helper class that wraps a record value for encrypted storage.
/// The record is serialized to JSON, encrypted, and stored as a string.
class EncryptedCacheValue<T> {
  /// The encrypted data.
  final String encryptedData;

  /// Timestamp when the value was encrypted.
  final DateTime encryptedAt;

  EncryptedCacheValue({required this.encryptedData, DateTime? encryptedAt})
    : encryptedAt = encryptedAt ?? DateTime.now();

  /// Create from a value using the provided encryption.
  factory EncryptedCacheValue.fromValue(
    T value,
    CacheEncryption encryption,
    String Function(T) toJson,
  ) {
    final json = toJson(value);
    return EncryptedCacheValue(encryptedData: encryption.encrypt(json));
  }

  /// Decrypt and deserialize the value.
  T toValue(CacheEncryption encryption, T Function(String json) fromJson) {
    final json = encryption.decrypt(encryptedData);
    return fromJson(json);
  }
}
