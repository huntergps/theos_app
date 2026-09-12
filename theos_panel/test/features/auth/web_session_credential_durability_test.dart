import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/app/bootstrap.dart';

import 'workspace_unlock_test_doubles.dart';

/// W04's credential half, on the seam that actually decides it.
///
/// `WebSessionAuthService.close()` used to empty an in-memory map, which
/// deleted everything only because the browser stored nothing. Now that the
/// browser persists, the same code would have left a **live, replayable API
/// key** behind after a logout. These fail on that version and pass on the one
/// that delegates to the inner service.
void main() {
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  WebSessionAuthService build({CredentialBackend? backend}) =>
      WebSessionAuthService(
        runtime: SessionRuntime(),
        installationIds: InstallationIdStore(
          _InstallationBackend(),
          generator: () => 'install-1',
        ),
        identityReader: _Identity(),
        capabilityPort: _Capabilities(),
        preferences: preferences,
        credentialBackend: backend,
        apiKeyIdentityProbe: (client) async => (userId: 7, login: 'vendedor'),
        apiKeyRuntimePort: _FakeRuntimePort(),
      );

  test('sin respaldo durable sigue siendo de vida de pestaña, como antes', () {
    expect(build().keepsCredentialAcrossReloads, isFalse);
  });

  test('con respaldo durable la credencial sobrevive a la recarga', () {
    expect(
      build(backend: FakeCredentialBackend()).keepsCredentialAcrossReloads,
      isTrue,
    );
  });

  test('una clave pegada queda guardada en el respaldo durable, que es lo que '
      'hace que una recarga no cueste un acceso nuevo', () async {
    final backend = FakeCredentialBackend();
    final service = build(backend: backend);

    final result = await service.loginWithApiKey(
      serverUrl: 'https://erp2.test',
      database: 'orbi',
      login: 'vendedor',
      apiKey: 'clave-emitida',
    );

    expect(result.status, AuthServiceStatus.authenticated);
    expect(backend.entries, isNotEmpty);
    expect(
      backend.entries.values.any((value) => value == 'clave-emitida'),
      isTrue,
      reason: 'la clave tiene que llegar al respaldo para sobrevivir',
    );
  });

  test('CERRAR SESIÓN borra la credencial durable: ningún acceso puede dejar '
      'una clave replicable viva detrás', () async {
    final backend = FakeCredentialBackend();
    final service = build(backend: backend);
    await service.loginWithApiKey(
      serverUrl: 'https://erp2.test',
      database: 'orbi',
      login: 'vendedor',
      apiKey: 'clave-emitida',
    );
    expect(backend.entries, isNotEmpty);

    await service.close();

    expect(
      backend.entries.values.any((value) => value == 'clave-emitida'),
      isFalse,
      reason: 'limpiar un mapa en memoria ya no basta cuando el almacén es '
          'durable: hay que borrar la entrada con nombre de ámbito',
    );
  });

  test('RECARGAR LA PÁGINA recupera la sesión desde la credencial guardada: '
      'guardarla no sirve de nada si al recargar nadie la usa', () async {
    final backend = FakeCredentialBackend();
    await build(backend: backend).loginWithApiKey(
      serverUrl: 'https://erp2.test',
      database: 'orbi',
      login: 'vendedor',
      apiKey: 'clave-emitida',
    );

    // Otra instancia del servicio = la página recién recargada. La sonda de
    // sesión por cookie falla (no hay servidor), que es justo el camino donde
    // antes se devolvía `required` y se acababa.
    final afterReload = build(backend: backend);
    final restored = await afterReload.restore();

    expect(
      restored.status,
      anyOf(AuthServiceStatus.restored, AuthServiceStatus.authenticated),
      reason: 'la sesión tiene que volver sin volver a escribir la contraseña',
    );
    expect(restored.profile?.login, 'vendedor');
  });

  test('sin respaldo durable una recarga sigue pidiendo acceso, como antes',
      () async {
    final service = build();
    await service.loginWithApiKey(
      serverUrl: 'https://erp2.test',
      database: 'orbi',
      login: 'vendedor',
      apiKey: 'clave-emitida',
    );
    final restored = await build().restore();
    expect(restored.status, AuthServiceStatus.required);
  });

  test('una recarga sin conexión también recupera la sesión guardada: eso es '
      'lo que significa «igual que escritorio»', () async {
    final backend = FakeCredentialBackend();
    await build(backend: backend).loginWithApiKey(
      serverUrl: 'https://erp2.test',
      database: 'orbi',
      login: 'vendedor',
      apiKey: 'clave-emitida',
    );

    final restored = await build(backend: backend).restore(offline: true);
    expect(
      restored.status,
      anyOf(AuthServiceStatus.restored, AuthServiceStatus.authenticated),
    );
  });

  test('quien pide no persistir la credencial no deja nada, ni siquiera con '
      'respaldo durable', () async {
    final backend = FakeCredentialBackend();
    final service = build(backend: backend);

    await service.loginWithApiKey(
      serverUrl: 'https://erp2.test',
      database: 'orbi',
      login: 'vendedor',
      apiKey: 'clave-emitida',
      persistCredential: false,
    );

    expect(
      backend.entries.values.any((value) => value == 'clave-emitida'),
      isFalse,
    );
  });

  test('un respaldo que falla no rompe el cierre de sesión', () async {
    final service = build(backend: ThrowingCredentialBackend());
    await expectLater(service.close(), completes);
  });
}

final class _InstallationBackend implements InstallationIdBackend {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

final class _Identity implements ActiveIdentityReader {
  @override
  Future<({int companyId, List<int> allowedCompanyIds})> read(
    AppScope scope,
  ) async => (companyId: 1, allowedCompanyIds: const [1]);
}

final class _Capabilities implements CapabilitySnapshotPort {
  @override
  Future<CapabilitySnapshot?> refresh(AppScope scope, int companyId) async =>
      null;
  @override
  Future<CapabilitySnapshot?> offline(AppScope scope, int companyId) async =>
      null;
}

final class _FakeRuntimePort implements SessionRuntimePort {
  @override
  Future<void> activate(AppScope scope, {String? apiKey}) async {}
  @override
  Future<void> close() async {}
}
