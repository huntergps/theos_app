import 'package:fluent_ui/fluent_ui.dart';

/// Estado visual de una fila de «Documentos a continuar». Cuatro nada más,
/// por orden del dueño (lámina ACC-03, «Inicio operativo»): un documento
/// nuevo que no encaje en ninguno se queda sin insignia (`null`) antes que
/// inventar una quinta categoría.
enum HomeResumeStatus {
  /// Ya se envió/confirmó localmente y está en camino de sincronizar, o una
  /// operación de la cola que ya se está reintentando.
  enProceso,

  /// Todavía necesita una acción de la persona: un borrador sin confirmar,
  /// un cobro que falta, una operación que ni siquiera ha empezado a
  /// reintentarse.
  pendiente,

  /// Falló de forma que necesita revisión — nunca se reintenta sola.
  error,

  /// Traslado de envases que ya salió de una sede y espera confirmación de
  /// la sede destino.
  porRecibir,
}

/// Texto de la insignia. `null` (documento sin estado conocido) se lee como
/// un guion, nunca como una palabra inventada.
String homeResumeStatusLabel(HomeResumeStatus? status) => switch (status) {
  null => '—',
  HomeResumeStatus.enProceso => 'En proceso',
  HomeResumeStatus.pendiente => 'Pendiente',
  HomeResumeStatus.error => 'Error',
  HomeResumeStatus.porRecibir => 'Por recibir',
};

/// Color de tema para la insignia — siempre un token de
/// `FluentThemeData.resources`/`accentColor`, nunca un hexadecimal a mano
/// (orden del dueño, punto 6 de ACC-03). «En proceso» y «Por recibir» usan el
/// acento (la lámina no les da un tono de sistema propio); «Pendiente» usa
/// precaución y «Error» usa crítico, igual que el resto de listados de Orbi
/// (`lista_estado_chip.dart`).
Color homeResumeStatusColor(FluentThemeData theme, HomeResumeStatus? status) =>
    switch (status) {
      null => theme.resources.textFillColorDisabled,
      HomeResumeStatus.enProceso => theme.accentColor.normal,
      HomeResumeStatus.pendiente => theme.resources.systemFillColorCaution,
      HomeResumeStatus.error => theme.resources.systemFillColorCritical,
      HomeResumeStatus.porRecibir => theme.accentColor.normal,
    };

/// Fondo SÓLIDO para la insignia, cuando quien la pinta controla también el
/// texto (la tarjeta compacta de teléfono, vía `cardBuilder`) — un color de
/// intensidad plena, no un tinte al 16 % del mismo color sobre sí mismo. Ese
/// tinte es lo que usa el `_orbiPill` interno de `OrbiListing`
/// (columnas/tabla), y ahí «En proceso»/«Error» casi no se leían en tema
/// oscuro (orden del dueño, 15-sep-2026, viendo
/// `inicio-completo-390-oscuro.png`) — el tinte vive en el paquete
/// compartido y lo usan otras pantallas a propósito
/// (`clients_screen_composition_test.dart`), así que este par sólo se aplica
/// donde Inicio pinta su propia insignia, no en la tabla ancha.
Color homeResumeStatusSolidBackground(
  FluentThemeData theme,
  HomeResumeStatus? status,
) => switch (status) {
  null => theme.resources.subtleFillColorSecondary,
  HomeResumeStatus.enProceso || HomeResumeStatus.porRecibir =>
    theme.accentColor.normal,
  HomeResumeStatus.pendiente => theme.resources.systemFillColorCaution,
  HomeResumeStatus.error => theme.resources.systemFillColorCritical,
};

/// Texto de contraste para [homeResumeStatusSolidBackground].
///
/// 🔴 No usa el `textOnAccentFillColorPrimary` de `InfoBadge`
/// (`fluent_ui/lib/src/controls/utils/info_badge.dart`) a propósito: medido
/// el 15-sep-2026, ese token vale NEGRO en tema oscuro, y el fondo que
/// `InfoBadge` empareja con «precaución»
/// (`systemFillColorSolidAttentionBackground`) es un gris casi negro en ese
/// mismo tema — negro sobre gris casi negro da un contraste de 1.5:1, muy
/// por debajo del 4.5:1 mínimo. En vez de confiar en ese par fijo, el
/// texto se calcula a partir de la LUMINANCIA real del fondo elegido — negro
/// sobre un fondo claro, blanco sobre uno oscuro — así que sigue siendo
/// correcto sin importar qué claro u oscuro resulte cada color en cada tema.
Color homeResumeStatusSolidForeground(
  FluentThemeData theme,
  HomeResumeStatus? status,
) {
  if (status == null) return theme.resources.textFillColorPrimary;
  final background = homeResumeStatusSolidBackground(theme, status);
  return background.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}
