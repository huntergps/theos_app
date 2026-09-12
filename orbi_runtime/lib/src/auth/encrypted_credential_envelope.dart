/// Password-derived encryption for a single secret, used where there is no
/// usable system keychain to hand the key to instead (see
/// `docs/orbi_panel/decisions/C01-credencial-en-archivo-cifrado.md` §8).
///
/// This is deliberately a different mechanism from `SecretDerivation`
/// (`secret_derivation.dart`), which only ever needs to *verify* a candidate
/// against a one-way hash. Here the secret must be *recovered*, so a one-way
/// hash cannot do the job: this derives a real symmetric key with Argon2id
/// and uses it to open an AES-256-GCM box. The two never share code or a
/// payload format, even though both are ultimately keyed off the same
/// operator password at different moments of the app's lifecycle.
///
/// ## Library choice, recorded so it is not re-litigated
///
/// `pointycastle` was chosen over `cryptography_plus` for its far larger
/// adoption (3.52M downloads vs 25.5k at the time of C01 §8.3) — the same
/// "who notices a vulnerability first" argument this project already used to
/// discard other candidates by adoption. The cost is a lower-level API where
/// nonce handling and AEAD verification are the caller's responsibility, not
/// the library's. That cost is paid down here, once, and pinned against
/// published test vectors (`encrypted_credential_envelope_test.dart`) instead
/// of trusted on inspection.
///
/// ## What pointycastle's `process()` actually does — verified, not assumed
///
/// `GCMBlockCipher.process()` (via `BaseAEADBlockCipher.process`) returns
/// ciphertext with the authentication tag appended on encryption, and on
/// decryption treats the trailing `macSize` bytes of its input as that tag,
/// calling `validateMac()` from `doFinal()` — which throws
/// `InvalidCipherTextException` when the tag does not match. That is a real,
/// automatic integrity check, not something this file bolts on: it just has
/// to call `process()` symmetrically (concatenated ciphertext‖tag on both
/// sides) and let a mismatched tag surface as that exception. Confirmed by
/// reading `pointycastle`'s own `base_aead_block_cipher.dart` and
/// `block/modes/gcm.dart`, not by trusting the higher-level convenience name.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Argon2id cost parameters, versioned and carried inside every envelope so
/// the cost can be raised later without invalidating what is already on
/// disk — same reasoning as `SecretDerivation`'s stored `iterations`.
///
/// Defaults are OWASP's minimum recommendation for interactive use (memory
/// ≥ 19 MiB, 2 iterations, parallelism 1), not a guess. They are a starting
/// point, not a final answer: raising them requires timing this on the
/// slowest hardware a counter actually uses, not assuming desktop-class CPU.
final class Argon2Cost {
  const Argon2Cost({
    this.memoryKiB = 19456,
    this.iterations = 2,
    this.lanes = 1,
    this.version = Argon2Parameters.ARGON2_VERSION_13,
  });

  final int memoryKiB;
  final int iterations;
  final int lanes;
  final int version;

  Map<String, dynamic> toJson() => {
    'memoryKiB': memoryKiB,
    'iterations': iterations,
    'lanes': lanes,
    'version': version,
  };

  factory Argon2Cost.fromJson(Map<String, dynamic> json) {
    final memoryKiB = json['memoryKiB'];
    final iterations = json['iterations'];
    final lanes = json['lanes'];
    final version = json['version'];
    if (memoryKiB is! int ||
        iterations is! int ||
        lanes is! int ||
        version is! int) {
      throw const FormatException('invalid Argon2 cost payload');
    }
    if (memoryKiB <= 0 || iterations <= 0 || lanes <= 0) {
      throw const FormatException('Argon2 cost fields must be > 0');
    }
    return Argon2Cost(
      memoryKiB: memoryKiB,
      iterations: iterations,
      lanes: lanes,
      version: version,
    );
  }
}

const int _keyLength = 32; // AES-256
const int _saltLength = 16;
const int _nonceLength = 12; // AES-GCM standard nonce size
const int _macSizeBits = 128;

/// Derives a 32-byte AES key from [password] and [salt] with Argon2id.
///
/// Runs synchronously: callers on the UI isolate must offload this (e.g. via
/// `compute()`) themselves — the same discipline `secret_derivation.dart`
/// documents for its own, much cheaper, derivation. Argon2id at any
/// reasonable memory cost is not something to run on a frame budget.
Uint8List deriveArgon2idKey(
  String password,
  Uint8List salt, {
  Argon2Cost cost = const Argon2Cost(),
}) => deriveArgon2idKeyWithExtras(
  passwordBytes: Uint8List.fromList(utf8.encode(password)),
  salt: salt,
  cost: cost,
  desiredKeyLength: _keyLength,
);

/// The fully-parameterised Argon2id derivation, including the `secret` and
/// `additional` (associated data) inputs the production path never uses.
/// Exists so the published RFC 9106 §5.3 test vector — which exercises both
/// — can be reproduced against the exact same code path production uses,
/// rather than against a second, untested implementation.
Uint8List deriveArgon2idKeyWithExtras({
  required Uint8List passwordBytes,
  required Uint8List salt,
  Uint8List? secret,
  Uint8List? additional,
  Argon2Cost cost = const Argon2Cost(),
  int desiredKeyLength = _keyLength,
}) {
  final parameters = Argon2Parameters(
    Argon2Parameters.ARGON2_id,
    salt,
    desiredKeyLength: desiredKeyLength,
    secret: secret,
    additional: additional,
    iterations: cost.iterations,
    memory: cost.memoryKiB,
    lanes: cost.lanes,
    version: cost.version,
  );
  final generator = Argon2BytesGenerator()..init(parameters);
  return generator.process(passwordBytes);
}

/// Encrypts [plainText] under [key] with AES-256-GCM and no associated data,
/// returning ciphertext‖tag concatenated (what `process()` produces — see
/// the library note above). [nonce] must never repeat for the same [key]:
/// callers must draw it fresh, at random, for every call — never derive it
/// from anything predictable.
Uint8List encryptAesGcm({
  required Uint8List key,
  required Uint8List nonce,
  required Uint8List plainText,
}) => encryptAesGcmWithAad(
  key: key,
  nonce: nonce,
  plainText: plainText,
  aad: Uint8List(0),
);

/// The fully-parameterised AES-256-GCM seal, including associated
/// authenticated data ([aad]) the production path never uses. Exists so the
/// published McGrew-Viega test vectors — which include a case with real AAD
/// — can be reproduced against the exact same code path production uses.
Uint8List encryptAesGcmWithAad({
  required Uint8List key,
  required Uint8List nonce,
  required Uint8List plainText,
  required Uint8List aad,
}) {
  final cipher = GCMBlockCipher(AESEngine())
    ..init(true, AEADParameters(KeyParameter(key), _macSizeBits, nonce, aad));
  return cipher.process(plainText);
}

/// Decrypts [cipherTextWithTag] (ciphertext‖tag, as produced by
/// [encryptAesGcm]) under [key]. Throws [InvalidCipherTextException] when the
/// tag does not match — a wrong [key] (wrong password) or a tampered file are
/// indistinguishable from each other and from each other's plaintext: this
/// throws in both cases rather than ever returning a garbage plaintext.
Uint8List decryptAesGcm({
  required Uint8List key,
  required Uint8List nonce,
  required Uint8List cipherTextWithTag,
}) {
  final cipher = GCMBlockCipher(AESEngine())
    ..init(
      false,
      AEADParameters(KeyParameter(key), _macSizeBits, nonce, Uint8List(0)),
    );
  return cipher.process(cipherTextWithTag);
}

Uint8List randomBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256)),
  );
}

/// The versioned, self-describing payload written to disk for one secret.
/// Carries everything needed to derive the same key again from a candidate
/// password: nothing here is secret except [cipherTextWithTag], which is
/// exactly the point — the file alone, without the password, opens nothing.
final class EncryptedCredentialEnvelope {
  const EncryptedCredentialEnvelope({
    required this.cost,
    required this.salt,
    required this.nonce,
    required this.cipherTextWithTag,
  });

  /// Derives a fresh key from [password] with a freshly drawn salt and
  /// nonce, and seals [plainText] under it.
  factory EncryptedCredentialEnvelope.seal(
    String password,
    String plainText, {
    Argon2Cost cost = const Argon2Cost(),
  }) {
    final salt = randomBytes(_saltLength);
    final nonce = randomBytes(_nonceLength);
    final key = deriveArgon2idKey(password, salt, cost: cost);
    final cipherTextWithTag = encryptAesGcm(
      key: key,
      nonce: nonce,
      plainText: Uint8List.fromList(utf8.encode(plainText)),
    );
    return EncryptedCredentialEnvelope(
      cost: cost,
      salt: salt,
      nonce: nonce,
      cipherTextWithTag: cipherTextWithTag,
    );
  }

  final Argon2Cost cost;
  final Uint8List salt;
  final Uint8List nonce;
  final Uint8List cipherTextWithTag;

  /// Attempts to recover the plaintext with [password]. Returns `null` for
  /// both a wrong password and a corrupted/tampered file — the two are
  /// cryptographically indistinguishable from here, and both must fail
  /// closed, never with a garbage decode.
  String? open(String password) {
    final key = deriveArgon2idKey(password, salt, cost: cost);
    final Uint8List plainBytes;
    try {
      plainBytes = decryptAesGcm(
        key: key,
        nonce: nonce,
        cipherTextWithTag: cipherTextWithTag,
      );
    } on InvalidCipherTextException {
      return null;
    }
    try {
      return utf8.decode(plainBytes);
    } on FormatException {
      // Should not happen if the tag verified, but a corrupt-yet-matching
      // tag is not something to crash on — treat exactly like a wrong
      // password rather than let a decode error escape as an app crash.
      return null;
    }
  }

  /// The bytes to persist. Read back with [EncryptedCredentialEnvelope.decode].
  Uint8List encode() => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'version': 1,
        'argon2': cost.toJson(),
        'salt': base64Encode(salt),
        'nonce': base64Encode(nonce),
        'cipherText': base64Encode(cipherTextWithTag),
      }),
    ),
  );

  /// Reads back a payload written by [encode]. Throws [FormatException] on
  /// anything unrecognised — including a future payload version, so an older
  /// build never mishandles a format it cannot evaluate.
  factory EncryptedCredentialEnvelope.decode(Uint8List raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(raw));
    } catch (error) {
      throw FormatException('unreadable credential envelope: $error');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('credential envelope is not an object');
    }
    if (decoded['version'] != 1) {
      throw const FormatException('unknown credential envelope version');
    }
    final argon2 = decoded['argon2'];
    final salt = decoded['salt'];
    final nonce = decoded['nonce'];
    final cipherText = decoded['cipherText'];
    if (argon2 is! Map<String, dynamic> ||
        salt is! String ||
        nonce is! String ||
        cipherText is! String) {
      throw const FormatException('invalid credential envelope payload');
    }
    return EncryptedCredentialEnvelope(
      cost: Argon2Cost.fromJson(argon2),
      salt: Uint8List.fromList(base64Decode(salt)),
      nonce: Uint8List.fromList(base64Decode(nonce)),
      cipherTextWithTag: Uint8List.fromList(base64Decode(cipherText)),
    );
  }
}
