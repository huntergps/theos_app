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
