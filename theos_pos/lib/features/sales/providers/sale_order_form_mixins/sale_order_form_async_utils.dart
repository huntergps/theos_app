/// Helper para ejecutar Future sin esperar (similar a unawaited de dart:async)
///
/// Extraído de `sale_order_form_notifier.dart` (refactor de descomposición en
/// mixins, Fase E2b) para que los mixins del notifier — que viven en
/// archivos separados — puedan usarlo sin depender de
/// `sale_order_form_notifier.dart` (evita import circular).
void unawaited(Future<void>? future) {}
