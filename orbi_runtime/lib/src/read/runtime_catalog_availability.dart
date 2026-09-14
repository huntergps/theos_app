import 'package:odoo_sdk/odoo_sdk.dart'
    show OdooCapabilityState, OdooFieldNotFoundException, OdooNotFoundException;

import '../contracts.dart';
import '../sync/catalog_sync.dart';
import 'json2_read_adapters.dart';

/// Vista resuelta de un [RuntimeCatalogDescriptor] contra evidencia real del
/// servidor. Ver `docs/orbi_panel/decisions/E02-catalogos-segun-lo-que-tiene-el-servidor.md`.
final class ResolvedCatalogDescriptor {
  const ResolvedCatalogDescriptor({
    required this.state,
    required this.descriptor,
    this.reason,
  });

  /// [OdooCapabilityState.unknown] es intencionalmente distinto de
  /// [OdooCapabilityState.unsupported] (CLAUDE.md, «Odoo 19 frente a Odoo
  /// 20»: la evidencia gana): `unsupported` sólo se alcanza con evidencia
  /// positiva (el modelo no está en `ir.model`, o `fields_get` confirma que
  /// falta un campo obligatorio). Cualquier fallo al comprobar dice
  /// `unknown` y no apaga el catálogo.
  final OdooCapabilityState state;

  /// Descriptor efectivo con el que sincronizar: campos/filtros opcionales
  /// ausentes ya quitados. Cuando [state] es [OdooCapabilityState.unknown],
  /// es el descriptor ORIGINAL sin tocar — sin evidencia no hay base para
  /// quitar nada, así que se sigue pidiendo todo como siempre.
  final RuntimeCatalogDescriptor descriptor;

  /// Texto de diagnóstico, sólo para depuración/`/sync` — nunca se parsea.
  final String? reason;

  bool get canRun => state != OdooCapabilityState.unsupported;
}

/// Decide, con evidencia real del servidor, cuáles de los 17 catálogos
/// estáticos de [RuntimeCatalogComposition] puede correr esta instancia de
/// Odoo — en vez de que los 17 se declaren incondicionalmente y cada uno
/// falle por su cuenta (el defecto que describe E02).
///
/// Una instancia vive tanto como la composición que la crea (un
/// `SessionActivation`): el resultado se cachea en memoria por catálogo,
/// igual que `RuntimeCatalogLoader._deletedRecordSupported` cachea si
/// `sync.deleted.record` existe — mismo patrón, mismo motivo (es un hecho
/// del servidor, no algo que valga la pena repreguntar en cada ciclo).
/// [invalidate] fuerza un nuevo sondeo completo — lo usa "Forzar Sync
/// Completo" (E02, punto 5); un cambio de servidor/base o un reingreso ya
/// obtienen una instancia nueva porque `RuntimeCatalogComposition` se
/// reconstruye por activación.
final class RuntimeCatalogAvailability {
  RuntimeCatalogAvailability(
    this.reader, {
    required Map<String, RuntimeCatalogDescriptor> specs,
    DateTime Function()? clock,
  }) : _specs = Map.unmodifiable(specs),
       _now = clock ?? DateTime.now;

  final Json2ReadPort reader;
  final Map<String, RuntimeCatalogDescriptor> _specs;
  final DateTime Function() _now;

  final Map<String, ResolvedCatalogDescriptor> _resolved = {};
  Future<void>? _probing;
  DateTime? _probedAt;

  DateTime? get lastProbedAt => _probedAt;

  /// Borra lo cacheado: el próximo [resolve] vuelve a comprobar `ir.model`
  /// y `fields_get` de cero para todos los catálogos.
  void invalidate() {
    _resolved.clear();
    _probedAt = null;
  }

  /// Evidencia recogida EN TIEMPO DE EJECUCIÓN (un `search_read` real que
  /// respondió 404 de modelo o campo pese a que el sondeo previo lo daba por
  /// soportado o `unknown`) — ver E02, punto 3, y `catalogAvailabilityLoader`
  /// más abajo, que es quien la invoca.
  void markUnsupported(String key, {required String reason}) {
    final descriptor = _specs[key];
    if (descriptor == null) return;
    _resolved[key] = ResolvedCatalogDescriptor(
      state: OdooCapabilityState.unsupported,
      descriptor: descriptor,
      reason: reason,
    );
  }

  /// Resuelve [key]. La PRIMERA llamada de un ciclo dispara un sondeo que
  /// cubre TODOS los catálogos todavía sin resolver (nunca uno por
  /// catálogo) — así se cumple "una sola lectura de `ir.model`" aunque cada
  /// `CatalogSyncJob` pida su propio catálogo por separado; las llamadas
  /// siguientes del mismo ciclo esperan ese mismo sondeo en vuelo.
  Future<ResolvedCatalogDescriptor> resolve(String key) async {
    final descriptor = _specs[key];
    if (descriptor == null) {
      throw ArgumentError.value(key, 'key', 'Unknown catalog');
    }
    await _ensureProbe();
    return _resolved[key] ??
        ResolvedCatalogDescriptor(
          state: OdooCapabilityState.unknown,
          descriptor: descriptor,
        );
  }

  Future<void> _ensureProbe() {
    final pending = _probing;
    if (pending != null) return pending;
    final missing = _specs.keys
        .where((key) => !_resolved.containsKey(key))
        .toList(growable: false);
    if (missing.isEmpty) return Future.value();
    final future = _runProbe(missing);
    _probing = future.whenComplete(() => _probing = null);
    return _probing!;
  }

  Future<void> _runProbe(List<String> pendingKeys) async {
    final pendingSpecs = {for (final key in pendingKeys) key: _specs[key]!};
    final modelExistence = await _probeModelExistence(pendingSpecs.values);
    if (modelExistence == null) {
      // Sin evidencia (red, 401/403, cualquier fallo de `ir.model`): nada se
      // cachea, todo sigue `unknown` — el próximo `resolve()` reintenta el
      // sondeo completo desde cero (E02, punto 4).
      return;
    }
    for (final entry in pendingSpecs.entries) {
      final descriptor = entry.value;
      if (!modelExistence.contains(descriptor.model)) {
        _resolved[entry.key] = ResolvedCatalogDescriptor(
          state: OdooCapabilityState.unsupported,
          descriptor: descriptor,
          reason: '${descriptor.model} no existe en este servidor',
        );
        continue;
      }
      _resolved[entry.key] = await _resolveFields(descriptor);
    }
    _probedAt = _now();
  }

  /// `null` significa "no hay evidencia" (la llamada a `ir.model` falló por
  /// cualquier motivo — red, sesión caducada, o el 403 documentado en el
  /// mapa de envases para un vendedor sin `base.group_no_one`). Un conjunto
  /// vacío es evidencia válida de verdad: "se preguntó y ninguno existe".
  Future<Set<String>?> _probeModelExistence(
    Iterable<RuntimeCatalogDescriptor> descriptors,
  ) async {
    final models = descriptors.map((d) => d.model).toSet().toList()..sort();
    if (models.isEmpty) return const <String>{};
    try {
      final rows = await reader.searchRead(
        model: 'ir.model',
        fields: const ['model'],
        domain: [
          ['model', 'in', models],
        ],
        limit: models.length,
      );
      return rows.map((row) => row['model']).whereType<String>().toSet();
    } catch (_) {
      return null;
    }
  }

  Future<ResolvedCatalogDescriptor> _resolveFields(
    RuntimeCatalogDescriptor descriptor,
  ) async {
    if (reader is! Json2FieldsGetPort) {
      // Sin `fields_get` no hay forma de distinguir obligatorio de opcional
      // — sólo ocurre con dobles de prueba mínimos. Se asume soportado tal
      // cual viene declarado, el comportamiento de siempre.
      return ResolvedCatalogDescriptor(
        state: OdooCapabilityState.supported,
        descriptor: descriptor,
      );
    }
    final requiredFields = descriptor.fields
        .where((field) => !descriptor.optionalFields.contains(field))
        .toList(growable: false);
    final candidateFields = <String>{
      ...requiredFields,
      ...descriptor.optionalFields,
      ...descriptor.optionalFilterFields,
    }.toList(growable: false);
    final Map<String, dynamic> metadata;
    try {
      metadata = await (reader as Json2FieldsGetPort).fieldsGet(
        model: descriptor.model,
        fields: candidateFields,
      );
    } catch (_) {
      return ResolvedCatalogDescriptor(
        state: OdooCapabilityState.unknown,
        descriptor: descriptor,
        reason: 'No se pudo comprobar fields_get de ${descriptor.model}',
      );
    }
    final missingRequired = requiredFields
        .where((field) => !metadata.containsKey(field))
        .toList(growable: false);
    if (missingRequired.isNotEmpty) {
      return ResolvedCatalogDescriptor(
        state: OdooCapabilityState.unsupported,
        descriptor: descriptor,
        reason: '${descriptor.model} no tiene ${missingRequired.join(', ')}',
      );
    }
    final droppedFields = descriptor.optionalFields
        .where((field) => !metadata.containsKey(field))
        .toSet();
    final droppedFilters = descriptor.optionalFilterFields
        .where((field) => !metadata.containsKey(field))
        .toSet();
    if (droppedFields.isEmpty && droppedFilters.isEmpty) {
      return ResolvedCatalogDescriptor(
        state: OdooCapabilityState.supported,
        descriptor: descriptor,
      );
    }
    final effectiveFields = descriptor.fields
        .where((field) => !droppedFields.contains(field))
        .toList(growable: false);
    final effectiveDomain = descriptor.domain
        .where(
          (clause) =>
              !(clause is List &&
                  clause.isNotEmpty &&
                  droppedFilters.contains(clause.first)),
        )
        .toList(growable: false);
    return ResolvedCatalogDescriptor(
      state: OdooCapabilityState.supported,
      descriptor: RuntimeCatalogDescriptor(
        key: descriptor.key,
        model: descriptor.model,
        fields: effectiveFields,
        domain: effectiveDomain,
        order: descriptor.order,
        optionalFields: descriptor.optionalFields,
        optionalFilterFields: descriptor.optionalFilterFields,
      ),
      reason: [
        if (droppedFields.isNotEmpty)
          'sin ${droppedFields.join(', ')} (no existe en este servidor)',
        if (droppedFilters.isNotEmpty)
          'filtro por ${droppedFilters.join(', ')} omitido (no existe en '
              'este servidor)',
      ].join('; '),
    );
  }
}

/// Envuelve el `CatalogLoader` real de [loader] con la comprobación de
/// disponibilidad: si [availability] dice `unsupported`, ni siquiera se
/// intenta el `search_read` — se devuelve un lote vacío sin cursor, que
/// `CatalogSyncJob` confirma (`committed`) igual que cualquier otro lote, así
/// que NO cuenta como error (E02, punto 1). Con `supported`/`unknown`, corre
/// el descriptor resuelto (o el original, si es `unknown`) y, si el servidor
/// responde con un 404 de modelo o de campo pese a eso, lo trata como
/// evidencia recién llegada: marca el catálogo `unsupported` para los
/// próximos ciclos y confirma este lote como vacío en vez de fallar (E02,
/// punto 3).
CatalogLoader<Map<String, dynamic>> catalogAvailabilityLoader({
  required RuntimeCatalogAvailability availability,
  required String key,
  required RuntimeCatalogLoader loader,
}) {
  return (AppScope scope, String? cursorRaw) async {
    final resolved = await availability.resolve(key);
    if (!resolved.canRun) {
      return const CatalogBatch(records: [], cursor: null);
    }
    try {
      return await loader.loader(resolved.descriptor)(scope, cursorRaw);
    } on OdooNotFoundException {
      availability.markUnsupported(
        key,
        reason: '${resolved.descriptor.model} no existe (confirmado al '
            'sincronizar)',
      );
      return const CatalogBatch(records: [], cursor: null);
    } on OdooFieldNotFoundException catch (error) {
      availability.markUnsupported(
        key,
        reason: 'Campo ${error.fieldName} inexistente en '
            '${resolved.descriptor.model} (confirmado al sincronizar)',
      );
      return const CatalogBatch(records: [], cursor: null);
    }
  };
}
