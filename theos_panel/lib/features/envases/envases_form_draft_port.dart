import 'dart:async';

import 'package:orbi_runtime/orbi_runtime.dart';

/// Puerto pequeño para que los formularios de envases (envío y recepción)
/// guarden su estado a medio llenar sin importar `EditableDraftStore`,
/// `RuntimeDatabaseOwner` ni ningún otro detalle de almacenamiento — la misma
/// frontera que respeta cualquier otra pantalla de esta app. `draftId`
/// identifica el documento (`envases.envio`, `envases.recepcion.<pickingId>`);
/// el payload es un `Map<String, dynamic>` que cada formulario decide cómo
/// codificar.
///
/// Sin sesión activa (o sin base local abierta) no hay dónde guardar: la
/// implementación indisponible no hace nada y nunca lanza, así el formulario
/// sigue funcionando sólo en memoria, igual que antes de que existiera este
/// puerto.
abstract interface class EnvasesFormDraftPort {
  Future<Map<String, dynamic>?> read(String draftId);
  Future<void> save(String draftId, Map<String, dynamic> payload);
  Future<void> clear(String draftId);
}

/// Variante sin efecto: usada cuando no hay sesión, empresa o base local
/// activa para el borrador.
final class UnavailableEnvasesFormDraftPort implements EnvasesFormDraftPort {
  const UnavailableEnvasesFormDraftPort();

  @override
  Future<Map<String, dynamic>?> read(String draftId) async => null;

  @override
  Future<void> save(String draftId, Map<String, dynamic> payload) async {}

  @override
  Future<void> clear(String draftId) async {}
}

/// Implementación durable sobre `EditableDraftStore`, con el mismo manejo de
/// lease/empresa que `DurableSaleDraftStore`
/// (`theos_panel/lib/features/sales/durable_sale_draft_store.dart`). A
/// diferencia de ese adaptador, este puerto no protege una identidad de
/// comando ni asume un único `draftId` por instancia: un mismo formulario de
/// recepción puede haber varios traslados pendientes a la vez, cada uno con
/// su propio `draftId`, así que la revisión de concurrencia optimista de
/// `EditableDraftStore` se sigue por `draftId`.
final class DurableEnvasesFormDraftPort implements EnvasesFormDraftPort {
  DurableEnvasesFormDraftPort({required this.store});

  final EditableDraftStore store;
  final Map<String, int> _revisions = {};

  @override
  Future<Map<String, dynamic>?> read(String draftId) async {
    final record = await store.read(draftId);
    _revisions[draftId] = record?.revision ?? 0;
    return record?.payload;
  }

  @override
  Future<void> save(String draftId, Map<String, dynamic> payload) async {
    final expected = _revisions[draftId] ?? 0;
    final saved = await store.save(
      draftId,
      payload,
      expectedRevision: expected,
    );
    _revisions[draftId] = saved.revision;
  }

  @override
  Future<void> clear(String draftId) async {
    await store.delete(draftId);
    _revisions.remove(draftId);
  }
}

/// Guarda en cada cambio, con debounce corto y una sola escritura en vuelo a
/// la vez: si llegan varios cambios mientras se está guardando, sólo el
/// último payload sobrevive, pero nunca se pierde el último — al terminar el
/// guardado en curso, si hay un payload pendiente más nuevo, se guarda
/// también. Un fallo al guardar el borrador es silencioso a propósito: es
/// persistencia de mejor esfuerzo, nunca debe impedir que el usuario siga
/// escribiendo en el formulario.
final class EnvasesFormDraftAutoSave {
  EnvasesFormDraftAutoSave({
    required this.port,
    required this.draftId,
    this.debounce = const Duration(milliseconds: 300),
  });

  final EnvasesFormDraftPort port;
  final String draftId;
  final Duration debounce;

  Timer? _timer;
  Map<String, dynamic>? _pending;
  bool _saving = false;
  bool _disposed = false;

  /// Programa un guardado del [payload] tras el debounce. Llamar de nuevo
  /// antes de que expire reemplaza el payload pendiente y reinicia el plazo.
  void schedule(Map<String, dynamic> payload) {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer(debounce, () => _enqueue(payload));
  }

  void _enqueue(Map<String, dynamic> payload) {
    if (_disposed) return;
    _pending = payload;
    if (_saving) return;
    _saving = true;
    unawaited(_drain());
  }

  Future<void> _drain() async {
    try {
      while (_pending != null) {
        final next = _pending!;
        _pending = null;
        try {
          await port.save(draftId, next);
        } catch (_) {
          // Persistencia de mejor esfuerzo: el formulario sigue en memoria.
        }
      }
    } finally {
      _saving = false;
    }
  }

  /// Cancela cualquier guardado pendiente y borra el borrador durable. Se
  /// llama sólo cuando el registro ya fue aceptado (en línea o encolado sin
  /// conexión) — nunca cuando falló.
  Future<void> clear() async {
    _timer?.cancel();
    _timer = null;
    _pending = null;
    try {
      await port.clear(draftId);
    } catch (_) {
      // Mejor esfuerzo: si falla, el borrador simplemente queda huérfano.
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }
}
