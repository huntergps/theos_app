/// Estado observable del tiempo real, para que un shell operativo lo pinte
/// sin tener que entender websockets, sesiones ni reintentos.
///
/// Deliberadamente sin UI aquí (`orbi_runtime` no importa widgets ni temas,
/// ver ADR-01 en `docs/orbi_panel/ARCHITECTURE.md`): esto es sólo el hecho.
enum RealtimeStatus {
  /// El servidor no tiene el módulo de tiempo real (`404` en
  /// `/app_sync/realtime/session`). La app sigue funcionando SOLO con
  /// sincronización periódica — esto no es un error, nunca se reintenta.
  disabled,

  /// Intentando la primera conexión de esta sesión (o la siguiente, tras
  /// volver la red).
  connecting,

  /// Socket conectado y suscrito: los avisos `app_sync/changed` están
  /// llegando.
  live,

  /// Se perdió la conexión y se está reintentando con retroceso
  /// exponencial (la sesión de tiempo real venció, el servidor cerró el
  /// socket, un error de red pasajero...).
  retrying,

  /// El dispositivo no tiene red. No hay reintentos en bucle mientras dure:
  /// se retoma solo en cuanto vuelva la conectividad.
  offline,
}

/// Etiqueta corta para pintar el estado de un vistazo, mismo patrón que
/// `connectionStatusLabel` (`connectivity_monitor.dart`) — texto puro, sin
/// widgets ni temas (ADR-01, `orbi_runtime` no importa nada de UI).
///
/// Vocabulario fijado por el dueño (14-sep-2026, hueco 1 de la auditoría de
/// tiempo real): cuatro lecturas, nunca una quinta inventada. `connecting` y
/// `retrying` comparten la misma palabra («reconectando») porque para quien
/// mira la barra superior son la misma espera — la diferencia entre "primera
/// conexión" y "se cayó y reintenta" no cambia lo que hay que hacer.
/// `disabled` NO es un error: es un servidor sin el módulo de tiempo real, y
/// el texto lo dice explícitamente para que la píldora no se pinte en rojo
/// como si algo se hubiera roto.
String realtimeStatusLabel(RealtimeStatus status) => switch (status) {
  RealtimeStatus.live => 'Tiempo real: conectado',
  RealtimeStatus.connecting => 'Tiempo real: reconectando',
  RealtimeStatus.retrying => 'Tiempo real: reconectando',
  RealtimeStatus.offline => 'Tiempo real: caído',
  RealtimeStatus.disabled => 'Tiempo real: no disponible en este servidor',
};
