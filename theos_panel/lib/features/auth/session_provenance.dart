/// De dónde salió la sesión con la que alguien está dentro.
///
/// 🔴 Existe porque hoy la aplicación **cambia de identidad sin decir nada**.
/// Con una sesión de Odoo abierta en el navegador, Orbi la adopta en silencio:
/// no dice de quién es, no hay forma de llegar a su pantalla de acceso, y no se
/// puede entrar como otra persona.
///
/// En un equipo de una sola persona eso es una comodidad. **En un mostrador
/// compartido, quien abra Orbi empieza a vender, cobrar o mover existencias
/// con el nombre del compañero anterior, y ninguno de los dos se entera.**
///
/// Es el mismo patrón que el del acceso mudo y el del rechazo de permiso mudo,
/// y es el peor de los tres: cambiar de pantalla sin avisar molesta; cambiar
/// de identidad sin avisar deja hechos firmados por quien no los hizo.
///
/// **La distinción no hay que inventarla: ya está en los datos.**
/// `AuthProfile.credentialReference` vale `'api-key'` cuando la credencial la
/// probó esta persona con su contraseña (o la pegó), y `'odoo-http-session'`
/// cuando la sesión venía heredada del navegador. Nadie la leía: cero usos en
/// todo el árbol antes de este fichero.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbi_runtime/orbi_runtime.dart' show AuthProfile;

import '../../ui/components/copyable_message.dart';



/// La referencia que `NativeAuthService` escribe cuando la credencial se ganó
/// con una contraseña o una API key de esta persona.
const String ownCredentialReference = 'api-key';

/// La que escribe el puente web cuando la sesión ya estaba abierta en el
/// navegador — y que por tanto puede ser de cualquiera.
const String inheritedSessionReference = 'odoo-http-session';

enum SessionProvenance {
  /// Alguien demostró ser quien dice con su contraseña o su clave.
  ownCredential,

  /// La sesión estaba abierta en este navegador. **No sabemos quién la abrió.**
  inheritedBrowserSession,

  /// Sin perfil, o con una referencia que no reconocemos. Se trata como la
  /// heredada: ante la duda sobre una identidad, avisar de más es barato y
  /// callarse es caro.
  unknown,
}

SessionProvenance sessionProvenanceOf(AuthProfile? profile) {
  if (profile == null) return SessionProvenance.unknown;
  return switch (profile.credentialReference) {
    ownCredentialReference => SessionProvenance.ownCredential,
    inheritedSessionReference => SessionProvenance.inheritedBrowserSession,
    _ => SessionProvenance.unknown,
  };
}

/// Si esta sesión merece decirle a la persona con qué identidad entró.
///
/// Una credencial propia no lo merece: la puso quien está delante, y avisarle
/// de lo que acaba de hacer es ruido. Una sesión heredada sí, porque la abrió
/// alguien que puede no ser quien está mirando.
bool sessionNeedsIdentityNotice(AuthProfile? profile) =>
    sessionProvenanceOf(profile) != SessionProvenance.ownCredential;

/// El aviso de la primera vez.
///
/// Deliberadamente **nombra a la persona**: «entraste como jacqueline.rizo» es
/// accionable y «hay una sesión activa» no lo es. No revela nada que quien
/// está delante no pueda ver ya en el propio Odoo de la pestaña de al lado.
///
/// Severidad `warning`, no `error`: no ha fallado nada. Pero tampoco `info`,
/// porque **esto pide una decisión** — seguir o entrar como uno mismo.
CopyableMessage inheritedSessionNotice(AuthProfile profile) => CopyableMessage(
  title: 'Entraste como ${profile.login}',
  body:
      'Orbi encontró una sesión de Odoo ya abierta en este dispositivo y la '
      'está usando. Si no eres ${profile.login}, sal y entra con tu propia '
      'cuenta antes de vender o cobrar: lo que hagas quedará a su nombre.',
  severity: OrbiMessageSeverity.warning,
);

/// La frase corta para el avatar o la barra superior, una vez pasado el aviso.
///
/// `null` cuando la credencial es propia: ahí el nombre a secas basta y añadir
/// una explicación cada vez sería ruido diario.
String? inheritedSessionBadge(AuthProfile? profile) =>
    sessionNeedsIdentityNotice(profile) ? 'sesión heredada de Odoo' : null;

/// Una sesión heredada que está **ofrecida, no adoptada**.
///
/// 🔴 La diferencia entre ofrecer y adoptar es quién decide.
///
/// Hoy la aplicación adopta: encuentra una sesión de Odoo abierta y entra con
/// ella sin preguntar. El atajo es cómodo y el dueño lo quiere — pero esa
/// sesión la dejó **quien fuera** que usó el navegador, así que adoptarla es
/// suplantar por omisión. Ofrecerla conserva el atajo entero (sigue siendo un
/// clic) y sólo cambia de mano quién lo da.
///
/// El corte NO es por entorno —«equipo de una persona» contra «mostrador
/// compartido» es algo que la aplicación no puede saber— sino por el origen de
/// la credencial, que sí está en los datos: ver [sessionProvenanceOf].
final class OfferedSession {
  const OfferedSession(this.profile);

  final AuthProfile profile;

  /// Lo que dice el botón. Nombra a la persona a propósito: «continuar con la
  /// sesión abierta» no deja ver a quién estás a punto de suplantar.
  String get actionLabel => 'Continuar como ${profile.login}';

  /// La línea que acompaña al botón en la pantalla de acceso.
  String get explanation =>
      'Hay una sesión de Odoo abierta en este dispositivo. Si no eres '
      '${profile.login}, entra con tu propia cuenta: lo que hagas quedará a '
      'su nombre.';
}

/// Dónde el arranque deja la sesión que encontró y decidió NO adoptar.
///
/// Inerte por omisión, como el resto de puertos de este paquete: sin oferta,
/// la pantalla de acceso es exactamente la de siempre.
final offeredSessionProvider = Provider<OfferedSession?>((ref) => null);

/// Si una sesión restaurada debe ofrecerse en vez de adoptarse.
///
/// Devuelve `false` para una credencial propia: la puso quien está delante, y
/// hacerle pulsar un botón para entrar en su propia cuenta es fricción sin
/// ganancia.
bool sessionShouldBeOfferedNotAdopted(AuthProfile? profile) =>
    sessionProvenanceOf(profile) == SessionProvenance.inheritedBrowserSession;
