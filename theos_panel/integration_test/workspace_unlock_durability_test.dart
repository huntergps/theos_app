import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:odoo_sdk/odoo_sdk.dart' show logger;
import 'package:theos_panel/features/auth/unlock_backend_factory.dart';
import 'package:theos_panel/features/auth/workspace_unlock_store.dart';

/// Runs the offline unlock against **the real platform store** — the operating
/// system keychain on a native target — which no widget test can do: a
/// plugin-backed platform channel never completes inside a widget test's
/// fake-async zone, which is why `workspaceUnlockBackendProvider` is inert by
/// default and the composition root hands the real one in.
///
/// Run with: `flutter test integration_test/ -d macos`
///
/// ## The one thing only this file can answer
///
/// Whether the derivation **survives closing and reopening the application**.
/// A single process proves the store accepts and returns a value; it cannot
/// prove the value outlived the process. So [_durabilityMarker] is deliberately
/// NOT cleaned up: run this twice, and the second run finds what the first one
/// left.
///
/// * first run  — plants the marker and says so;
/// * second run — finds it, which is the proof;
/// * with `ORBI_UNLOCK_EXPECT_PERSISTED=1` — **requires** it, so a scripted
///   two-run check fails instead of quietly passing as a first run.
///
/// Nothing here needs an ERP2 credential, a password or a network: a derivation
/// is local by nature. The password used is a synthetic literal, never a real
/// one, and never reaches a log line.
///
/// ## 🔴 On macOS this is RED today, on purpose
///
/// Measured 11-sep-2026 on a real macOS debug build: `SecItemAdd` fails with
/// **−34018**, so nothing is ever stored and the offline unlock does not exist
/// on this platform — not a durability problem, an "it never gets written"
/// problem. `secd` demands a keychain-access-group for any Keychain Services
/// call from an ad-hoc signed binary, sandboxed or not; only a real Apple
/// signing team unblocks it (see the comment in
/// `macos/Runner/DebugProfile.entitlements`, verified against secd's own logs).
///
/// It is deliberately NOT skipped. A skip would hide a live blocker behind a
/// green tick, and this file is not part of `make verify` (`flutter test` only
/// walks `test/`), so the red costs no gate — it is the record of what is
/// missing. The day the signing account exists, this file is the proof that
/// it worked.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const scopeKey = 'integration-scope';
  const durabilityScope = 'integration-durability-scope';
  const password = 'contraseña-sintetica-de-prueba';

  late WorkspaceUnlockStore store;

  setUp(() => store = WorkspaceUnlockStore(createUnlockCredentialBackend()));

  testWidgets('el almacén real de la plataforma acepta el derivado y lo '
      'verifica, sin red', (tester) async {
    addTearDown(() => store.forget(scopeKey));
    await store.forget(scopeKey);

    expect(
      store.isSupported,
      isTrue,
      reason: 'esta plataforma debería tener almacén durable',
    );
    expect(
      await store.remember(scopeKey, password),
      isTrue,
      reason:
          'el almacén de la plataforma rechazó la escritura. En macOS esto es '
          '−34018 ("a required entitlement isn\'t present"): secd exige un '
          'keychain-access-group para CUALQUIER llamada al llavero desde un '
          'binario firmado de forma improvisada, con o sin confinamiento. No '
          'hay arreglo por código — hace falta un equipo de firma de Apple. '
          'Ver el comentario de macos/Runner/DebugProfile.entitlements. '
          'MIENTRAS ESTO ESTÉ ROJO, EL DESBLOQUEO SIN CONEXIÓN NO EXISTE EN '
          'macOS, ni en depuración ni en distribución.',
    );
    expect(
      await store.verify(scopeKey, password),
      WorkspaceUnlockVerdict.unlocked,
    );
    expect(
      await store.verify(scopeKey, 'otra-cosa'),
      WorkspaceUnlockVerdict.rejected,
    );
  });

  testWidgets('otra instancia del almacén lo lee: salió de la memoria de este '
      'objeto y llegó al almacén del sistema', (tester) async {
    addTearDown(() => store.forget(scopeKey));
    await store.remember(scopeKey, password);

    final fresh = WorkspaceUnlockStore(createUnlockCredentialBackend());
    expect(
      await fresh.verify(scopeKey, password),
      WorkspaceUnlockVerdict.unlocked,
    );
  });

  testWidgets('el derivado desaparece al cerrar sesión, también contra el '
      'almacén real', (tester) async {
    await store.remember(scopeKey, password);
    await store.forget(scopeKey);

    final fresh = WorkspaceUnlockStore(createUnlockCredentialBackend());
    expect(await fresh.isRemembered(scopeKey), isFalse);
    expect(
      await fresh.verify(scopeKey, password),
      WorkspaceUnlockVerdict.notEnrolled,
    );
  });

  testWidgets('SUPERVIVENCIA ENTRE ARRANQUES: lo que dejó la ejecución '
      'anterior sigue ahí', (tester) async {
    final mustBeThere =
        Platform.environment['ORBI_UNLOCK_EXPECT_PERSISTED'] == '1';
    final found = await store.isRemembered(durabilityScope);

    if (mustBeThere) {
      expect(
        found,
        isTrue,
        reason:
            'se exigió encontrar el derivado de una ejecución anterior y no '
            'está: el almacén no sobrevive al cierre de la aplicación',
      );
    }
    if (found) {
      // The proof: a value written by a DIFFERENT process still verifies.
      expect(
        await store.verify(durabilityScope, password),
        WorkspaceUnlockVerdict.unlocked,
        reason: 'sobrevivió al arranque pero ya no verifica',
      );
      // ignore: avoid_print
      print(
        'DURABILIDAD: el derivado de una ejecución ANTERIOR sigue válido. '
        'Sobrevive a cerrar y reabrir la aplicación.',
      );
    } else {
      expect(await store.remember(durabilityScope, password), isTrue);
      // ignore: avoid_print
      print(
        'DURABILIDAD: primera ejecución, marcador plantado. Vuelve a correr '
        'con ORBI_UNLOCK_EXPECT_PERSISTED=1 para exigir que siga ahí.',
      );
    }
    // Deliberately NOT cleaned up: the next run is the measurement.
  });

  testWidgets('cuando el almacén falla, alguien se entera: queda constancia '
      'en el registro y sin el secreto dentro', (tester) async {
    final lines = <String>[];
    final previous = logger.logOutput;
    logger.logOutput = (message) => lines.add('$message');
    addTearDown(() => logger.logOutput = previous);

    const nowhere = WorkspaceUnlockStore(null);
    expect(await nowhere.remember(scopeKey, password), isFalse);

    final reported = lines.where(
      (line) => line.contains('Desbloqueo sin conexión INACTIVO'),
    );
    expect(reported, isNotEmpty);
    for (final line in lines) {
      expect(line.contains(password), isFalse);
      expect(line.contains(scopeKey), isFalse);
    }
  });
}
