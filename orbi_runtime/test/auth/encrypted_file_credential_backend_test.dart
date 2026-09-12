import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/src/auth/encrypted_file_credential_backend.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('orbi_encrypted_cred_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'write antes de fijar una contraseña falla con StateError, no en silencio',
    () async {
      final backend = EncryptedFileCredentialBackend(directory: tempDir);
      await expectLater(
        () => backend.write('api-key', 'valor'),
        throwsA(isA<StateError>()),
      );
    },
  );

  test(
    'la contraseña se puede fijar tarde, después de construir el backend',
    () async {
      final backend = EncryptedFileCredentialBackend(directory: tempDir);
      backend.password = 'fijada-después';
      await backend.write('api-key', 'valor');
      expect(await backend.read('api-key'), 'valor');
    },
  );

  test('escribe y lee de vuelta con la misma contraseña', () async {
    final backend = EncryptedFileCredentialBackend(
      directory: tempDir,
      password: 'la-contraseña-del-operador',
    );
    await backend.write('api-key', 'un-api-key-de-verdad');
    expect(await backend.read('api-key'), 'un-api-key-de-verdad');
  });

  test('leer con la contraseña equivocada devuelve null, no truena', () async {
    await EncryptedFileCredentialBackend(
      directory: tempDir,
      password: 'correcta',
    ).write('api-key', 'valor');

    final wrong = EncryptedFileCredentialBackend(
      directory: tempDir,
      password: 'incorrecta',
    );
    expect(await wrong.read('api-key'), isNull);
  });

  test('leer una clave que nunca se escribió devuelve null', () async {
    final backend = EncryptedFileCredentialBackend(
      directory: tempDir,
      password: 'x',
    );
    expect(await backend.read('nunca-escrita'), isNull);
  });

  test('delete quita el archivo y una lectura posterior da null', () async {
    final backend = EncryptedFileCredentialBackend(
      directory: tempDir,
      password: 'x',
    );
    await backend.write('api-key', 'valor');
    await backend.delete('api-key');
    expect(await backend.read('api-key'), isNull);
  });

  test('delete de una clave inexistente no truena', () async {
    final backend = EncryptedFileCredentialBackend(
      directory: tempDir,
      password: 'x',
    );
    await backend.delete('nunca-existió');
  });

  test('el nombre del archivo nunca contiene la clave en claro', () async {
    final backend = EncryptedFileCredentialBackend(
      directory: tempDir,
      password: 'x',
    );
    await backend.write(
      'orbi/scope-secreto/reference-secreta',
      'valor',
    );
    final names = await tempDir
        .list()
        .map((entity) => entity.uri.pathSegments.last)
        .toList();
    expect(names, isNotEmpty);
    for (final name in names) {
      expect(name.contains('scope-secreto'), isFalse);
      expect(name.contains('reference-secreta'), isFalse);
    }
  });

  test('escrituras distintas para la misma clave no colisionan con otra clave', () async {
    final backend = EncryptedFileCredentialBackend(
      directory: tempDir,
      password: 'x',
    );
    await backend.write('clave-a', 'valor-a');
    await backend.write('clave-b', 'valor-b');
    expect(await backend.read('clave-a'), 'valor-a');
    expect(await backend.read('clave-b'), 'valor-b');
  });

  test('reescribir la misma clave reemplaza el valor anterior', () async {
    final backend = EncryptedFileCredentialBackend(
      directory: tempDir,
      password: 'x',
    );
    await backend.write('api-key', 'primero');
    await backend.write('api-key', 'segundo');
    expect(await backend.read('api-key'), 'segundo');
  });

  test('un archivo corrupto en disco se lee como null, no truena', () async {
    final backend = EncryptedFileCredentialBackend(
      directory: tempDir,
      password: 'x',
    );
    await backend.write('api-key', 'valor');
    // Corrompe el único archivo que haya en el directorio de prueba.
    final files = await tempDir.list().toList();
    expect(files, hasLength(1));
    await File(files.single.path).writeAsString('esto no es json válido');
    expect(await backend.read('api-key'), isNull);
  });
}
