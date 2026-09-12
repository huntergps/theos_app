import 'dart:io';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/src/auth/credential_store.dart';
import 'package:orbi_runtime/src/auth/encrypted_file_credential_backend.dart';
import 'package:orbi_runtime/src/auth/linux_secret_service_fallback_credential_backend.dart';

/// Hand-rolled test double, same style as the fakes already used elsewhere
/// in this repo for small interfaces (`native_macos_app_test.dart`) — no new
/// mocking dependency for one interface with three methods.
final class _FakeCredentialBackend implements CredentialBackend {
  _FakeCredentialBackend({this.throwsOn = const {}});

  /// Method name -> the exception to throw for every call to that method.
  /// A method absent from this map behaves like a normal in-memory store.
  final Map<String, Object> throwsOn;
  final Map<String, String> _values = {};
  final List<String> calls = [];

  @override
  Future<void> write(String key, String value) async {
    calls.add('write($key)');
    final error = throwsOn['write'];
    if (error != null) throw error;
    _values[key] = value;
  }

  @override
  Future<String?> read(String key) async {
    calls.add('read($key)');
    final error = throwsOn['read'];
    if (error != null) throw error;
    return _values[key];
  }

  @override
  Future<void> delete(String key) async {
    calls.add('delete($key)');
    final error = throwsOn['delete'];
    if (error != null) throw error;
    _values.remove(key);
  }
}

PlatformException _libsecretError() =>
    PlatformException(code: 'Libsecret error', message: 'no service');

PlatformException _keyringLocked() =>
    PlatformException(code: 'KeyringLocked', message: 'locked');

PlatformException _unrelatedError() => PlatformException(
  code: 'Bad arguments',
  message: 'not a secret-service failure',
);

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('orbi_linux_fallback_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group(
    'camino feliz: libsecret funciona, el respaldo nunca es la fuente de verdad',
    () {
      test('el valor viene siempre del nativo, nunca del respaldo', () async {
        final native = _FakeCredentialBackend();
        final fallback = _FakeCredentialBackend();
        final backend = LinuxSecretServiceFallbackCredentialBackend(
          password: 'x',
          directory: tempDir,
          native: native,
          fallback: fallback,
        );

        await backend.write('k', 'v');
        expect(await backend.read('k'), 'v');
        await backend.delete('k');

        // El respaldo SÍ recibe `delete` en el camino feliz — es la limpieza
        // de higiene documentada en el propio backend (después de un write
        // exitoso, y en todo delete) para que una copia vieja del respaldo
        // nunca reviva si el nativo falla más tarde. Lo que nunca debe pasar
        // es que el respaldo sea la fuente del valor leído.
        expect(fallback.calls.where((c) => c.startsWith('write')), isEmpty);
        expect(fallback.calls.where((c) => c.startsWith('read')), isEmpty);
      });
    },
  );

  group('caída acotada a los dos códigos conocidos', () {
    for (final entry in {
      'Libsecret error': _libsecretError,
      'KeyringLocked': _keyringLocked,
    }.entries) {
      test('write cae al respaldo cuando el nativo lanza "${entry.key}"', () async {
        final native = _FakeCredentialBackend(throwsOn: {'write': entry.value()});
        final backend = LinuxSecretServiceFallbackCredentialBackend(
          password: 'la-contraseña',
          directory: tempDir,
          native: native,
        );

        await backend.write('api-key', 'un-valor');
        expect(await backend.read('api-key'), 'un-valor');
      });

      test('read cae al respaldo cuando el nativo lanza "${entry.key}"', () async {
        final fallback = EncryptedFileCredentialBackend(
          directory: tempDir,
          password: 'la-contraseña',
        );
        await fallback.write('api-key', 'guardado-antes-en-el-respaldo');

        final native = _FakeCredentialBackend(throwsOn: {'read': entry.value()});
        final backend = LinuxSecretServiceFallbackCredentialBackend(
          password: 'la-contraseña',
          directory: tempDir,
          native: native,
          fallback: fallback,
        );

        expect(
          await backend.read('api-key'),
          'guardado-antes-en-el-respaldo',
        );
      });
    }
  });

  group('un código que no es de la lista falla y se ve — nunca cae en silencio', () {
    test('write relanza la excepción tal cual', () async {
      final native = _FakeCredentialBackend(
        throwsOn: {'write': _unrelatedError()},
      );
      final backend = LinuxSecretServiceFallbackCredentialBackend(
        password: 'x',
        directory: tempDir,
        native: native,
      );

      await expectLater(
        () => backend.write('k', 'v'),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'Bad arguments',
          ),
        ),
      );
    });

    test('read relanza la excepción tal cual, nunca cae al respaldo', () async {
      final fallback = _FakeCredentialBackend();
      final native = _FakeCredentialBackend(
        throwsOn: {'read': _unrelatedError()},
      );
      final backend = LinuxSecretServiceFallbackCredentialBackend(
        password: 'x',
        directory: tempDir,
        native: native,
        fallback: fallback,
      );

      await expectLater(
        () => backend.read('k'),
        throwsA(isA<PlatformException>()),
      );
      expect(fallback.calls, isEmpty);
    });

    test('delete relanza la excepción tal cual', () async {
      final native = _FakeCredentialBackend(
        throwsOn: {'delete': _unrelatedError()},
      );
      final backend = LinuxSecretServiceFallbackCredentialBackend(
        password: 'x',
        directory: tempDir,
        native: native,
      );

      await expectLater(
        () => backend.delete('k'),
        throwsA(isA<PlatformException>()),
      );
    });
  });

  group('consistencia entre nativo y respaldo', () {
    test(
      'un write nativo exitoso borra cualquier copia vieja del respaldo',
      () async {
        final fallback = EncryptedFileCredentialBackend(
          directory: tempDir,
          password: 'x',
        );
        // Simula una salida vieja del servicio de secretos que ya se
        // recuperó: hay un valor viejo en el respaldo.
        await fallback.write('api-key', 'valor-viejo-de-una-caída-pasada');

        final native = _FakeCredentialBackend();
        final backend = LinuxSecretServiceFallbackCredentialBackend(
          password: 'x',
          directory: tempDir,
          native: native,
          fallback: fallback,
        );

        await backend.write('api-key', 'valor-nuevo');

        // read() ahora debe ver el nuevo valor del nativo, no arrastrar el
        // viejo del respaldo si el nativo llegara a fallar más tarde.
        expect(await fallback.read('api-key'), isNull);
        expect(await native.read('api-key'), 'valor-nuevo');
      },
    );

    test(
      'delete limpia el respaldo aunque el nativo no tuviera nada que borrar',
      () async {
        final fallback = EncryptedFileCredentialBackend(
          directory: tempDir,
          password: 'x',
        );
        await fallback.write('api-key', 'huérfano-del-respaldo');

        final native = _FakeCredentialBackend();
        final backend = LinuxSecretServiceFallbackCredentialBackend(
          password: 'x',
          directory: tempDir,
          native: native,
          fallback: fallback,
        );

        await backend.delete('api-key');

        expect(await fallback.read('api-key'), isNull);
      },
    );
  });
}
