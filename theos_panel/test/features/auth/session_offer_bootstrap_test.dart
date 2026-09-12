import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/app/bootstrap.dart';
import 'package:theos_panel/features/auth/session_provenance.dart';

/// The arranque's half of "offer, do not adopt". The decision itself lives in
/// `session_provenance.dart`; what is pinned here is what the application
/// STARTS AS once that decision is taken — which is the part that decides
/// whether someone begins selling under another person's name.
void main() {
  AuthProfile profileWith(String reference) => AuthProfile(
    serverUrl: 'https://erp2.test',
    database: 'orbi',
    login: 'jacqueline.rizo',
    userId: 155,
    installationId: 'inst-1',
    credentialReference: reference,
  );

  AuthServiceResult restoredWith(String reference) => AuthServiceResult(
    status: AuthServiceStatus.restored,
    profile: profileWith(reference),
  );

  test('una credencial propia se adopta en silencio, igual que antes: hacer '
      'pulsar un botón para entrar en tu propia cuenta es fricción sin '
      'ganancia', () {
    final restored = restoredWith('api-key');
    expect(sessionShouldBeOfferedNotAdopted(restored.profile), isFalse);

    final effective = effectiveRestoreResult(restored, offered: null);
    expect(effective.status, AuthServiceStatus.restored);
    expect(effective.profile?.login, 'jacqueline.rizo');
  });

  test('una sesión HEREDADA del navegador NO arranca autenticada: la '
      'aplicación empieza pidiendo acceso y la ofrece, en vez de suplantar', () {
    final restored = restoredWith('odoo-http-session');
    expect(sessionShouldBeOfferedNotAdopted(restored.profile), isTrue);

    final offered = OfferedSession(restored.profile!);
    final effective = effectiveRestoreResult(restored, offered: offered);

    expect(effective.status, AuthServiceStatus.required);
    expect(
      effective.profile,
      isNull,
      reason: 'el perfil ajeno no puede viajar al estado inicial',
    );
    // Y la identidad sigue disponible para OFRECERLA, con nombre.
    expect(offered.profile.login, 'jacqueline.rizo');
  });

  test('sin sesión ninguna, nada que ofrecer y nada que cambiar', () {
    const restored = AuthServiceResult(status: AuthServiceStatus.required);
    expect(sessionShouldBeOfferedNotAdopted(restored.profile), isFalse);
    expect(
      effectiveRestoreResult(restored, offered: null).status,
      AuthServiceStatus.required,
    );
  });
}
