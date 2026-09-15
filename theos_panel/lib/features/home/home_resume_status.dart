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
