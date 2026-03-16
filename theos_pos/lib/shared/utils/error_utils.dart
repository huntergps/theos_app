/// Utility for converting raw exceptions into user-friendly Spanish messages.
///
/// Use this for any error text that reaches the UI (state, snackbars, dialogs).
/// Keep raw `e.toString()` in logger calls for debugging.
String friendlyErrorMessage(Object error) {
  final msg = error.toString().toLowerCase();

  if (msg.contains('connection') ||
      msg.contains('timeout') ||
      msg.contains('socketexception') ||
      msg.contains('handshake') ||
      msg.contains('network')) {
    return 'Error de conexion. Verifique su red e intente nuevamente.';
  }
  if (msg.contains('permission') ||
      msg.contains('denied') ||
      msg.contains('403') ||
      msg.contains('unauthorized') ||
      msg.contains('401')) {
    return 'No tiene permisos para esta operacion.';
  }
  if (msg.contains('not found') || msg.contains('404')) {
    return 'El recurso solicitado no fue encontrado.';
  }
  if (msg.contains('500') || msg.contains('server error') || msg.contains('internal server')) {
    return 'Error del servidor. Intente nuevamente mas tarde.';
  }
  if (msg.contains('duplicate') || msg.contains('unique constraint')) {
    return 'El registro ya existe.';
  }
  if (msg.contains('cancel')) {
    return 'Operacion cancelada.';
  }

  return 'Ocurrio un error inesperado. Intente nuevamente.';
}
