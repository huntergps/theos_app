import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odoo_sdk/odoo_sdk.dart' show logger;
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/features/auth/workspace_unlock_store.dart';

import 'workspace_unlock_test_doubles.dart';

void main() {
  const scopeKey = 'scope-uno';
  const otherScope = 'scope-dos';
  const password = 'Gal4pagos-Orbi!';

  late FakeCredentialBackend backend;
  late WorkspaceUnlockStore store;

  setUp(() {
    backend = FakeCredentialBackend();
    store = WorkspaceUnlockStore(backend);
  });

  test('a scope with nothing enrolled verifies nothing', () async {
    expect(await store.isRemembered(scopeKey), isFalse);
    expect(
      await store.verify(scopeKey, password),
      WorkspaceUnlockVerdict.notEnrolled,
    );
  });

  test('remembering then verifying the same password unlocks', () async {
    expect(await store.remember(scopeKey, password), isTrue);
    expect(await store.isRemembered(scopeKey), isTrue);
    expect(
      await store.verify(scopeKey, password),
      WorkspaceUnlockVerdict.unlocked,
    );
  });

  test('a wrong password is rejected, never unlocked', () async {
    await store.remember(scopeKey, password);
    expect(
      await store.verify(scopeKey, 'otra-cosa'),
      WorkspaceUnlockVerdict.rejected,
    );
    expect(
      await store.verify(scopeKey, password.toLowerCase()),
      WorkspaceUnlockVerdict.rejected,
    );
  });

  test('an empty password is never enrolled: an account with no password '
      'would otherwise become an unlock that always succeeds', () async {
    expect(await store.remember(scopeKey, ''), isFalse);
    expect(await store.isRemembered(scopeKey), isFalse);
  });

  // The non-negotiable rule: the derivation stands in for the real Odoo
  // account password, so nothing recoverable may ever reach storage. Asserted
  // against what the backend actually holds, keys included, not against the
  // store's own API.
  test('the raw password never appears anywhere in what gets stored, neither '
      'in a value nor in a key', () async {
    await store.remember(scopeKey, password);
    await store.verify(scopeKey, 'intento-fallido');
    expect(backend.entries, isNotEmpty);
    for (final entry in backend.entries.entries) {
      expect(entry.key.contains(password), isFalse);
      expect(entry.value.contains(password), isFalse);
      expect(entry.value.contains('intento-fallido'), isFalse);
      expect(
        entry.value.contains(base64Encode(utf8.encode(password))),
        isFalse,
        reason: 'a base64 of the password is still the password',
      );
    }
  });

  test('each enrolment draws a fresh salt, so the same password stored twice '
      'looks different at rest', () async {
    await store.remember(scopeKey, password);
    final first = backend.entries['orbi/auth/unlock/hash/$scopeKey'];
    await store.remember(scopeKey, password);
    final second = backend.entries['orbi/auth/unlock/hash/$scopeKey'];
    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(first, isNot(second));
    expect(
      await store.verify(scopeKey, password),
      WorkspaceUnlockVerdict.unlocked,
    );
  });

  test('scopes are isolated: one identity never verifies against another on '
      'the same device', () async {
    await store.remember(scopeKey, password);
    expect(
      await store.verify(otherScope, password),
      WorkspaceUnlockVerdict.notEnrolled,
    );
  });

  test('forget removes the derivation and its attempt bookkeeping', () async {
    await store.remember(scopeKey, password);
    await store.verify(scopeKey, 'mal');
    expect(backend.entries, isNotEmpty);
    await store.forget(scopeKey);
    expect(backend.entries, isEmpty);
    expect(await store.isRemembered(scopeKey), isFalse);
    expect(
      await store.verify(scopeKey, password),
      WorkspaceUnlockVerdict.notEnrolled,
    );
  });

  test('an unreadable payload is dropped instead of left as a dead entry that '
      'can never verify', () async {
    await backend.write('orbi/auth/unlock/hash/$scopeKey', 'basura');
    expect(
      await store.verify(scopeKey, password),
      WorkspaceUnlockVerdict.notEnrolled,
    );
    expect(backend.entries, isEmpty);
  });

  group('límite de intentos', () {
    final now = DateTime(2026, 9, 11, 22);

    test('wrong attempts below the cap stay merely rejected', () async {
      await store.remember(scopeKey, password);
      for (var i = 0; i < kWorkspaceUnlockMaxAttempts - 1; i++) {
        expect(
          await store.verify(scopeKey, 'mal', now: now),
          WorkspaceUnlockVerdict.rejected,
        );
      }
    });

    test('reaching the cap locks the scope out, and a locked-out scope stops '
        'evaluating candidates at all — the right password included', () async {
      await store.remember(scopeKey, password);
      for (var i = 0; i < kWorkspaceUnlockMaxAttempts - 1; i++) {
        await store.verify(scopeKey, 'mal', now: now);
      }
      expect(
        await store.verify(scopeKey, 'mal', now: now),
        WorkspaceUnlockVerdict.lockedOut,
      );
      expect(
        await store.verify(scopeKey, password, now: now),
        WorkspaceUnlockVerdict.lockedOut,
        reason: 'a cap that the right password walks past is not a cap',
      );
    });

    test('the lockout expires after kWorkspaceUnlockLockoutDuration', () async {
      await store.remember(scopeKey, password);
      for (var i = 0; i < kWorkspaceUnlockMaxAttempts; i++) {
        await store.verify(scopeKey, 'mal', now: now);
      }
      expect(
        await store.verify(
          scopeKey,
          password,
          now: now.add(
            kWorkspaceUnlockLockoutDuration - const Duration(seconds: 1),
          ),
        ),
        WorkspaceUnlockVerdict.lockedOut,
      );
      expect(
        await store.verify(
          scopeKey,
          password,
          now: now.add(
            kWorkspaceUnlockLockoutDuration + const Duration(seconds: 1),
          ),
        ),
        WorkspaceUnlockVerdict.unlocked,
      );
    });

    test('a successful unlock clears the counter, so earlier typos never '
        'accumulate into a later lockout', () async {
      await store.remember(scopeKey, password);
      for (var i = 0; i < kWorkspaceUnlockMaxAttempts - 1; i++) {
        await store.verify(scopeKey, 'mal', now: now);
      }
      expect(
        await store.verify(scopeKey, password, now: now),
        WorkspaceUnlockVerdict.unlocked,
      );
      expect(
        await store.verify(scopeKey, 'mal', now: now),
        WorkspaceUnlockVerdict.rejected,
      );
    });

    test('a fresh enrolment clears the counter: whoever just proved the '
        'password does not inherit an earlier lockout', () async {
      await store.remember(scopeKey, password);
      for (var i = 0; i < kWorkspaceUnlockMaxAttempts; i++) {
        await store.verify(scopeKey, 'mal', now: now);
      }
      await store.remember(scopeKey, 'contraseña-nueva');
      expect(
        await store.verify(scopeKey, 'contraseña-nueva', now: now),
        WorkspaceUnlockVerdict.unlocked,
      );
    });
  });

  group('plataformas sin almacén seguro', () {
    test('a platform with nowhere safe to store stores nothing and reports '
        'unavailable, so the caller keeps requiring the server', () async {
      const web = WorkspaceUnlockStore(null);
      expect(web.isSupported, isFalse);
      expect(await web.remember(scopeKey, password), isFalse);
      expect(await web.isRemembered(scopeKey), isFalse);
      expect(
        await web.verify(scopeKey, password),
        WorkspaceUnlockVerdict.unavailable,
      );
      await web.forget(scopeKey);
    });

    test('a secure store that throws degrades to "unlocking needs the '
        'network" instead of breaking the session', () async {
      final hostile = WorkspaceUnlockStore(ThrowingCredentialBackend());
      expect(hostile.isSupported, isTrue);
      expect(await hostile.remember(scopeKey, password), isFalse);
      expect(await hostile.isRemembered(scopeKey), isFalse);
      expect(
        await hostile.verify(scopeKey, password),
        WorkspaceUnlockVerdict.unavailable,
      );
      await hostile.forget(scopeKey);
    });
  });

  group('el fallo no es silencioso', () {
    // "Degrada con seguridad" y "nadie se entera" es el peor par posible: el
    // desbloqueo sin conexión desaparece y no hay rastro hasta que un operador
    // se queda tirado sin señal. Esto exige la constancia, y exige que la
    // constancia no lleve el secreto dentro.
    late List<String> lines;
    late void Function(Object?) previousOutput;

    setUp(() {
      lines = [];
      previousOutput = logger.logOutput;
      logger.logOutput = (message) => lines.add('$message');
    });

    tearDown(() => logger.logOutput = previousOutput);

    test('cuando el almacén seguro rechaza la escritura, queda constancia de '
        'que el desbloqueo sin conexión quedó inactivo y por qué', () async {
      final hostile = WorkspaceUnlockStore(ThrowingCredentialBackend());
      expect(await hostile.remember(scopeKey, password), isFalse);

      final reported = lines.where(
        (line) => line.contains('Desbloqueo sin conexión INACTIVO'),
      );
      expect(reported, isNotEmpty, reason: 'el fallo tiene que dejar rastro');
      expect(
        reported.single.contains('seguirá exigiendo red'),
        isTrue,
        reason: 'la constancia dice la consecuencia, no sólo que falló',
      );
    });

    test('una plataforma sin almacén durable también deja constancia', () async {
      const nowhere = WorkspaceUnlockStore(null);
      expect(await nowhere.remember(scopeKey, password), isFalse);
      expect(
        lines.where((line) => line.contains('INACTIVO')),
        isNotEmpty,
      );
    });

    test('la constancia NUNCA lleva la contraseña, ni el derivado, ni el '
        'ámbito de la identidad', () async {
      final hostile = WorkspaceUnlockStore(ThrowingCredentialBackend());
      await hostile.remember(scopeKey, password);
      for (final line in lines) {
        expect(line.contains(password), isFalse, reason: 'nunca la contraseña');
        expect(line.contains(scopeKey), isFalse, reason: 'ni el ámbito');
      }
    });

    test('un desbloqueo normal no escribe nada en el registro: esto avisa de '
        'una avería, no narra el uso corriente', () async {
      final store = WorkspaceUnlockStore(FakeCredentialBackend());
      await store.remember(scopeKey, password);
      await store.verify(scopeKey, 'mal');
      await store.verify(scopeKey, password);
      await store.forget(scopeKey);
      expect(lines, isEmpty);
    });
  });

  group('el backend por omisión es inerte', () {
    // This is a regression guard, not a preference. A plugin-backed platform
    // channel never completes inside a widget test's fake-async zone, and
    // `AuthNotifier.login`/`close` await this store — so a live default
    // deadlocks any widget test that does not override it. Measured: it hung
    // `test/app/workspace_switch_user_router_test.dart` for `pumpAndSettle`'s
    // whole ten-minute budget, a test that passes in two seconds otherwise.
    // The platform-backed backend therefore comes from the composition root.
    test('a plain container stores nothing, so no test can deadlock on a '
        'platform channel it never asked for', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(workspaceUnlockBackendProvider), isNull);
      final store = container.read(workspaceUnlockStoreProvider);
      expect(store.isSupported, isFalse);
      expect(await store.remember(scopeKey, password), isFalse);
      expect(
        await store.verify(scopeKey, password),
        WorkspaceUnlockVerdict.unavailable,
      );
    });

    test('the composition-root override is what turns storage on', () {
      final container = ProviderContainer(
        overrides: [workspaceUnlockBackendOverride],
      );
      addTearDown(container.dispose);
      expect(container.read(workspaceUnlockBackendProvider), isNotNull);
      expect(container.read(workspaceUnlockStoreProvider).isSupported, isTrue);
    });
  });

  group('workspaceUnlockScopeKeyFor', () {
    AuthProfile profileFor({String login = 'vendedor', int userId = 7}) =>
        AuthProfile(
          serverUrl: 'https://erp2.galapagos.tech',
          database: 'orbi',
          login: login,
          userId: userId,
          installationId: 'inst-1',
          credentialReference: 'api-key',
        );

    test('never embeds the server, database or login', () {
      final key = workspaceUnlockScopeKeyFor(profileFor());
      expect(key.contains('erp2'), isFalse);
      expect(key.contains('orbi'), isFalse);
      expect(key.contains('vendedor'), isFalse);
    });

    test('the same login pointing at a different user id is a different '
        'scope, so one user never verifies against another derivation', () {
      expect(
        workspaceUnlockScopeKeyFor(profileFor(userId: 8)),
        isNot(workspaceUnlockScopeKeyFor(profileFor(userId: 7))),
      );
      expect(
        workspaceUnlockScopeKeyFor(profileFor(login: 'cajero')),
        isNot(workspaceUnlockScopeKeyFor(profileFor())),
      );
      expect(
        workspaceUnlockScopeKeyFor(profileFor()),
        workspaceUnlockScopeKeyFor(profileFor()),
      );
    });
  });
}
