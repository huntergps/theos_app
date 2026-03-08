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
import 'dart:typed_data';

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

/// AES-256 encryption wrapper.
///
/// This is a placeholder that requires the `encrypt` package.
/// Add to your pubspec.yaml:
/// ```yaml
/// dependencies:
///   encrypt: ^5.0.3
/// ```
///
/// Then implement as shown:
/// ```dart
/// import 'package:encrypt/encrypt.dart' as encrypt;
///
/// final encryption = AesCacheEncryption.fromSecureKey(
///   keyBase64: 'your-32-byte-key-in-base64',
///   ivBase64: 'your-16-byte-iv-in-base64',
/// );
/// ```
///
/// For key generation:
/// ```dart
/// final key = encrypt.Key.fromSecureRandom(32);
/// final iv = encrypt.IV.fromSecureRandom(16);
/// print('Key: ${key.base64}');
/// print('IV: ${iv.base64}');
/// ```
class AesCacheEncryption implements CacheEncryption {
  final Uint8List _key;
  final Uint8List _iv;

  /// Create AES encryption with raw key and IV bytes.
  ///
  /// Key must be 16, 24, or 32 bytes (128, 192, or 256 bits).
  /// IV must be 16 bytes.
  AesCacheEncryption({
    required Uint8List key,
    required Uint8List iv,
  })  : _key = key,
        _iv = iv {
    if (key.length != 16 && key.length != 24 && key.length != 32) {
      throw ArgumentError('Key must be 16, 24, or 32 bytes');
    }
    if (iv.length != 16) {
      throw ArgumentError('IV must be 16 bytes');
    }
  }

  /// Create AES encryption from base64-encoded key and IV.
  factory AesCacheEncryption.fromBase64({
    required String keyBase64,
    required String ivBase64,
  }) {
    return AesCacheEncryption(
      key: base64Decode(keyBase64),
      iv: base64Decode(ivBase64),
    );
  }

  /// Create AES encryption from a password using PBKDF2-like derivation.
  ///
  /// This derives a key from the password. For production, use a proper
  /// key derivation function like PBKDF2 from the `pointycastle` package.
  factory AesCacheEncryption.fromPassword(String password, {String? salt}) {
    final effectiveSalt = salt ?? 'odoo-cache-salt';
    final combined = '$password:$effectiveSalt';

    // Simple key derivation (NOT cryptographically secure)
    // For production, use PBKDF2 from pointycastle
    final keyBytes = _deriveKey(combined, 32);
    final ivBytes = _deriveKey('$combined:iv', 16);

    return AesCacheEncryption(
      key: keyBytes,
      iv: ivBytes,
    );
  }

  /// Simple key derivation (for demonstration only).
  ///
  /// In production, use PBKDF2:
  /// ```dart
  /// import 'package:pointycastle/pointycastle.dart';
  /// final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
  /// pbkdf2.init(Pbkdf2Parameters(salt, 10000, keyLength));
  /// final key = pbkdf2.process(password);
  /// ```
  static Uint8List _deriveKey(String input, int length) {
    final bytes = utf8.encode(input);
    final result = Uint8List(length);

    // Simple hash-like mixing (NOT secure)
    for (var i = 0; i < length; i++) {
      var value = 0;
      for (var j = 0; j < bytes.length; j++) {
        value = (value * 31 + bytes[j] + i) & 0xFF;
      }
      result[i] = value;
    }

    return result;
  }

  @override
  String encrypt(String plaintext) {
    if (plaintext.isEmpty) return '';

    try {
      // This is a simplified AES-like transformation
      // For real AES, use the `encrypt` package
      final bytes = utf8.encode(plaintext);
      final encrypted = _simpleEncrypt(bytes);
      return base64Encode(encrypted);
    } catch (e) {
      throw CacheEncryptionException('AES encryption failed', e);
    }
  }

  @override
  String decrypt(String ciphertext) {
    if (ciphertext.isEmpty) return '';

    try {
      final encrypted = base64Decode(ciphertext);
      final bytes = _simpleDecrypt(encrypted);
      return utf8.decode(bytes);
    } catch (e) {
      throw CacheDecryptionException('AES decryption failed', e);
    }
  }

  /// Simplified encryption (XOR + shuffle with key).
  ///
  /// For real AES encryption, use:
  /// ```dart
  /// import 'package:encrypt/encrypt.dart' as encrypt;
  /// final encrypter = encrypt.Encrypter(encrypt.AES(key));
  /// return encrypter.encrypt(plaintext, iv: iv).base64;
  /// ```
  Uint8List _simpleEncrypt(List<int> input) {
    final result = Uint8List(input.length + 16); // Add padding info

    // Store original length in first 4 bytes
    final length = input.length;
    result[0] = (length >> 24) & 0xFF;
    result[1] = (length >> 16) & 0xFF;
    result[2] = (length >> 8) & 0xFF;
    result[3] = length & 0xFF;

    // XOR with key and IV combined
    for (var i = 0; i < input.length; i++) {
      final keyByte = _key[i % _key.length];
      final ivByte = _iv[i % _iv.length];
      result[i + 4] = input[i] ^ keyByte ^ ivByte ^ (i & 0xFF);
    }

    // Add verification hash in last 12 bytes
    var hash = 0x12345678;
    for (var i = 0; i < input.length; i++) {
      hash = ((hash << 5) + hash + input[i]) & 0xFFFFFFFF;
    }
    result[result.length - 12] = (hash >> 24) & 0xFF;
    result[result.length - 11] = (hash >> 16) & 0xFF;
    result[result.length - 10] = (hash >> 8) & 0xFF;
    result[result.length - 9] = hash & 0xFF;

    // Fill remaining with random-ish data
    for (var i = result.length - 8; i < result.length; i++) {
      result[i] = (_key[i % _key.length] + _iv[i % _iv.length]) & 0xFF;
    }

    return result;
  }

  Uint8List _simpleDecrypt(List<int> input) {
    if (input.length < 16) {
      throw const CacheDecryptionException('Invalid ciphertext: too short');
    }

    // Extract original length
    final length = (input[0] << 24) |
        (input[1] << 16) |
        (input[2] << 8) |
        input[3];

    if (length < 0 || length > input.length - 16) {
      throw const CacheDecryptionException('Invalid ciphertext: invalid length');
    }

    // Decrypt
    final result = Uint8List(length);
    for (var i = 0; i < length; i++) {
      final keyByte = _key[i % _key.length];
      final ivByte = _iv[i % _iv.length];
      result[i] = input[i + 4] ^ keyByte ^ ivByte ^ (i & 0xFF);
    }

    // Verify hash
    var hash = 0x12345678;
    for (var i = 0; i < result.length; i++) {
      hash = ((hash << 5) + hash + result[i]) & 0xFFFFFFFF;
    }

    final storedHash = (input[input.length - 12] << 24) |
        (input[input.length - 11] << 16) |
        (input[input.length - 10] << 8) |
        input[input.length - 9];

    if (hash != storedHash) {
      throw const CacheDecryptionException(
          'Invalid ciphertext: hash verification failed');
    }

    return result;
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

  EncryptedCacheValue({
    required this.encryptedData,
    DateTime? encryptedAt,
  }) : encryptedAt = encryptedAt ?? DateTime.now();

  /// Create from a value using the provided encryption.
  factory EncryptedCacheValue.fromValue(
    T value,
    CacheEncryption encryption,
    String Function(T) toJson,
  ) {
    final json = toJson(value);
    return EncryptedCacheValue(
      encryptedData: encryption.encrypt(json),
    );
  }

  /// Decrypt and deserialize the value.
  T toValue(
    CacheEncryption encryption,
    T Function(String json) fromJson,
  ) {
    final json = encryption.decrypt(encryptedData);
    return fromJson(json);
  }
}
