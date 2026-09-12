import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart' show AuthProfile;
import 'package:theos_panel/features/auth/session_provenance.dart';
import 'package:theos_panel/ui/components/copyable_message.dart';

AuthProfile _profile(String reference, {String login = 'jacqueline.rizo'}) =>
    AuthProfile(
      serverUrl: 'https://erp2.tecnosmart.com.ec',
      database: 'erp2_tecnosmart_com_ec',
      login: login,
      userId: 23,
      installationId: 'i',
      credentialReference: reference,
    );

void main() {
  group('de dónde vino la sesión, que ya estaba en los datos', () {
    test('una credencial propia se reconoce como propia', () {
      expect(
        sessionProvenanceOf(_profile(ownCredentialReference)),
        SessionProvenance.ownCredential,
      );
    });

    test('una sesión del navegador se reconoce como heredada', () {
      expect(
        sessionProvenanceOf(_profile(inheritedSessionReference)),
        SessionProvenance.inheritedBrowserSession,
      );
    });

    test('sin perfil, o con una referencia desconocida, es desconocida', () {
      expect(sessionProvenanceOf(null), SessionProvenance.unknown);
      expect(
        sessionProvenanceOf(_profile('algo-que-no-existe')),
        SessionProvenance.unknown,
      );
    });
  });

  group('a quién se le avisa y a quién no', () {
    test('a quien puso su propia credencial NO se le avisa', () {
      // Avisar a alguien de lo que acaba de hacer es ruido, y el ruido diario
      // es cómo se deja de leer los avisos.
      expect(
        sessionNeedsIdentityNotice(_profile(ownCredentialReference)),
        isFalse,
      );
      expect(inheritedSessionBadge(_profile(ownCredentialReference)), isNull);
    });

    test('a quien heredó una sesión SÍ se le avisa', () {
      expect(
        sessionNeedsIdentityNotice(_profile(inheritedSessionReference)),
        isTrue,
      );
      expect(
        inheritedSessionBadge(_profile(inheritedSessionReference)),
        isNotNull,
      );
    });

    test('ante la duda se avisa, no se calla', () {
      // Una referencia que no reconocemos podría ser una identidad ajena.
      // Avisar de más cuesta una línea; callarse cuesta que alguien cobre con
      // el nombre de un compañero.
      expect(sessionNeedsIdentityNotice(null), isTrue);
      expect(sessionNeedsIdentityNotice(_profile('futuro-modo')), isTrue);
    });
  });

  group('qué dice el aviso', () {
    test('nombra a la persona, porque «hay una sesión activa» no es accionable', () {
      final notice = inheritedSessionNotice(
        _profile(inheritedSessionReference, login: 'jacqueline.rizo'),
      );
      expect(notice.title, contains('jacqueline.rizo'));
      expect(notice.body, contains('jacqueline.rizo'));
    });

    test('dice la consecuencia, no sólo el hecho', () {
      // Lo que convierte esto en accionable es la última frase: lo que hagas
      // queda a nombre de otro.
      final notice = inheritedSessionNotice(_profile(inheritedSessionReference));
      expect(notice.body, contains('quedará a su nombre'));
      expect(notice.body.toLowerCase(), contains('antes de vender o cobrar'));
    });

    test('es un aviso, no un error: no ha fallado nada', () {
      // Pero tampoco es información a secas: pide una decisión.
      final notice = inheritedSessionNotice(_profile(inheritedSessionReference));
      expect(notice.severity, OrbiMessageSeverity.warning);
      expect(notice.severity, isNot(OrbiMessageSeverity.error));
      expect(notice.severity, isNot(OrbiMessageSeverity.info));
    });

    test('se puede copiar entero, como todo lo demás', () {
      final notice = inheritedSessionNotice(_profile(inheritedSessionReference));
      expect(notice.clipboardText, contains(notice.title));
      expect(notice.clipboardText, contains(notice.body));
    });

    test('no filtra el servidor ni la base en el texto', () {
      // SHELL_AND_INTERACTION_SPEC prohíbe exponer servidor/BD fuera del pie;
      // este aviso puede acabar en una pantalla compartida.
      final notice = inheritedSessionNotice(_profile(inheritedSessionReference));
      final text = '${notice.title} ${notice.body}';
      expect(text, isNot(contains('erp2.tecnosmart.com.ec')));
      expect(text, isNot(contains('erp2_tecnosmart_com_ec')));
    });
  });
}
