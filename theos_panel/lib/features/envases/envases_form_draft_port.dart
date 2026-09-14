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
    try {
      final saved = await store.save(
        draftId,
        payload,
        expectedRevision: expected,
      );
      _revisions[draftId] = saved.revision;
    } on EditableDraftRevisionConflict {
      // «El último que escribe gana»: otra pestaña, otra sesión, o esta misma
      // antes de terminar su `read` ya movió la revisión real. Sin releer y
      // reintentar, la revisión en caché queda parada para siempre y todo
      // guardado futuro repite el mismo conflicto — el borrador no se vuelve
      // a guardar nunca más. Se relee la revisión real y se reintenta UNA
      // sola vez con el mismo payload.
      final current = await store.read(draftId);
      final retryRevision = current?.revision ?? 0;
      final saved = await store.save(
        draftId,
        payload,
        expectedRevision: retryRevision,
      );
      _revisions[draftId] = saved.revision;
    }
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
///
/// `clear()` y `dispose()` respetan ese mismo camino serializado:
///
/// - `clear()` espera a que termine cualquier guardado ya en vuelo ANTES de
///   borrar. Si borrara primero, ese guardado tardío podría terminar
///   DESPUÉS del borrado y resucitar un borrador que ya se registró — el
///   caso grave que puede llevar a enviarlo dos veces. Usa una generación:
///   un payload programado ANTES del `clear()` nunca se guarda después; uno
///   programado DESPUÉS sí, por si el formulario sigue abierto.
/// - `dispose()` guarda de inmediato (sin esperar el debounce, sin esperar
///   el resultado) el último cambio pendiente si lo hay y nadie llamó a
///   `clear()` después de programarlo — si no, lo tecleado en los últimos
///   milisegundos del debounce se perdería justo al salir de la pantalla.
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
  Map<String, dynamic>? _pendingPayload;
  int _pendingGeneration = 0;
  Future<void>? _inFlightSave;
  bool _draining = false;
  int _generation = 0;
  bool _disposed = false;

  /// Programa un guardado del [payload] tras el debounce. Llamar de nuevo
  /// antes de que expire reemplaza el payload pendiente y reinicia el plazo.
  void schedule(Map<String, dynamic> payload) {
    if (_disposed) return;
    _timer?.cancel();
    _pendingPayload = payload;
    _pendingGeneration = _generation;
    _timer = Timer(debounce, _fire);
  }

  void _fire() {
    _timer = null;
    _kick();
  }

  void _kick() {
    if (_draining || _pendingPayload == null) return;
    _draining = true;
    unawaited(_drain());
  }

  Future<void> _drain() async {
    try {
      while (_pendingPayload != null) {
        final payload = _pendingPayload!;
        final generation = _pendingGeneration;
        _pendingPayload = null;
        // Un `clear()` ocurrido entre que esto se programó y que le tocó su
        // turno lo invalida: ese payload ya no debe guardarse.
        if (generation != _generation) continue;
        final future = port.save(draftId, payload);
        _inFlightSave = future;
        try {
          await future;
        } catch (_) {
          // Persistencia de mejor esfuerzo: el formulario sigue en memoria.
        } finally {
          if (identical(_inFlightSave, future)) _inFlightSave = null;
        }
      }
    } finally {
      _draining = false;
    }
  }

  /// Cancela cualquier guardado pendiente que todavía no haya arrancado y
  /// borra el borrador durable. Se llama sólo cuando el registro ya fue
  /// aceptado (en línea o encolado sin conexión) — nunca cuando falló.
  Future<void> clear() async {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _pendingPayload = null;
    // Si ya hay un guardado en vuelo (arrancado antes de este `clear()`), se
    // espera a que termine antes de borrar — ver el docstring de la clase.
    final inFlight = _inFlightSave;
    if (inFlight != null) {
      try {
        await inFlight;
      } catch (_) {
        // Lo que haya fallado al guardar no impide borrar de todos modos.
      }
    }
    try {
      await port.clear(draftId);
    } catch (_) {
      // Mejor esfuerzo: si falla, el borrador simplemente queda huérfano.
    }
  }

  /// Guarda de inmediato lo tecleado en los últimos milisegundos del
  /// debounce, si lo hay y nadie llamó a [clear] después de programarlo. No
  /// se espera aquí (el llamador lo hace `unawaited`): el widget ya se está
  /// yendo, pero el guardado sigue el mismo camino serializado que cualquier
  /// otro cambio, así que nunca corre a la vez que uno ya en vuelo.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _kick();
  }
}
