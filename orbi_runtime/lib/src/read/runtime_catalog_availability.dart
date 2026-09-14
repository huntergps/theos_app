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
  /// positiva (`fields_get` respondió 404 de modelo, o confirmó que falta un
  /// campo obligatorio). Cualquier fallo al comprobar dice `unknown` y no
  /// apaga el catálogo.
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
/// 🔴 Corrección del 13-sep-2026 (ver el encabezado de la decisión): la
/// primera versión sondeaba existencia con una lectura de `ir.model` antes
/// de `fields_get`. Se retiró: en ERP2 un vendedor normal recibe 403 al leer
/// `ir.model` (exige `base.group_no_one`), así que con ese perfil TODO
/// quedaría en `unknown` para siempre y el defecto de Mepriga no se
/// arreglaría para la usuaria de bodega. `fields_get` sobre el propio modelo
/// da la misma evidencia (404 si no existe) sin depender de `ir.model`, y de
/// paso trae los campos en la misma llamada.
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

  /// Sondeo en vuelo por catálogo: dos `CatalogSyncJob` que piden el MISMO
  /// catálogo en el mismo ciclo comparten esta misma llamada a `fields_get`
  /// en vez de disparar dos — cada modelo se pregunta como máximo una vez
  /// por catálogo mientras el sondeo esté pendiente.
  final Map<String, Future<ResolvedCatalogDescriptor>> _inFlight = {};

  DateTime? _probedAt;
  DateTime? get lastProbedAt => _probedAt;

  /// Borra lo cacheado: el próximo [resolve] vuelve a comprobar `fields_get`
  /// de cero para todos los catálogos.
  void invalidate() {
    _resolved.clear();
    _probedAt = null;
  }

  /// Evidencia recogida EN TIEMPO DE EJECUCIÓN: un `search_read` real
  /// respondió 404 de modelo, o confirmó que falta un campo OBLIGATORIO,
  /// pese a que el sondeo previo lo daba por soportado o `unknown` — ver
  /// E02, punto 3, y [catalogAvailabilityLoader], que es quien la invoca.
  void markUnsupported(String key, {required String reason}) {
    final descriptor = _specs[key];
    if (descriptor == null) return;
    _resolved[key] = ResolvedCatalogDescriptor(
      state: OdooCapabilityState.unsupported,
      descriptor: descriptor,
      reason: reason,
    );
    _probedAt = _now();
  }

  /// Evidencia recogida EN TIEMPO DE EJECUCIÓN: un `search_read` con
  /// [attemptedDescriptor] respondió que [fieldName] no existe. Si es
  /// opcional o de filtro, lo quita y memoriza el descriptor sin él (para
  /// que las próximas pasadas no vuelvan a pedirlo) y lo devuelve para un
  /// reintento inmediato — E02, punto 2, última frase. `null` si [fieldName]
  /// es obligatorio: no hay nada que quitar, el llamador debe marcar
  /// `unsupported`.
  RuntimeCatalogDescriptor? dropFieldAndRetry(
    String key,
    RuntimeCatalogDescriptor attemptedDescriptor,
    String fieldName,
  ) {
    final isOptional = attemptedDescriptor.optionalFields.contains(fieldName);
    final isFilter = attemptedDescriptor.optionalFilterFields.contains(fieldName);
    if (!isOptional && !isFilter) return null;
    final updated = _withoutFields(
      attemptedDescriptor,
      droppedFields: isOptional ? {fieldName} : const {},
      droppedFilters: isFilter ? {fieldName} : const {},
    );
    _resolved[key] = ResolvedCatalogDescriptor(
      state: OdooCapabilityState.supported,
      descriptor: updated,
      reason: 'Campo $fieldName inexistente (confirmado al sincronizar)',
    );
    _probedAt = _now();
    return updated;
  }

  /// Resuelve [key]. Ya resuelto (`supported`/`unsupported`) → cache
  /// directa, sin red. Un sondeo ya en vuelo para el MISMO catálogo → se
  /// espera ese, nunca se dispara un segundo `fields_get` en paralelo.
  Future<ResolvedCatalogDescriptor> resolve(String key) {
    final cached = _resolved[key];
    if (cached != null) return Future.value(cached);
    final descriptor = _specs[key];
    if (descriptor == null) {
      throw ArgumentError.value(key, 'key', 'Unknown catalog');
    }
    final inFlight = _inFlight[key];
    if (inFlight != null) return inFlight;
    final future = _probe(key, descriptor).whenComplete(() {
      _inFlight.remove(key);
    });
    _inFlight[key] = future;
    return future;
  }

  /// Un solo `fields_get` por catálogo hace las dos preguntas a la vez: si
  /// el modelo no existe, Odoo responde 404 (`OdooNotFoundException`) antes
  /// de que importe qué campos se pidieron; si existe, la misma respuesta
  /// trae qué campos de [candidateFields] están presentes. `attributes:
  /// ['type']` reduce lo que el servidor devuelve por campo — no cambia qué
  /// campos aparecen como presentes.
  Future<ResolvedCatalogDescriptor> _probe(
    String key,
    RuntimeCatalogDescriptor descriptor,
  ) async {
    if (reader is! Json2FieldsGetPort) {
      // Sin `fields_get` no hay forma de distinguir obligatorio de opcional,
      // ni de existencia — sólo ocurre con dobles de prueba mínimos. Se
      // asume soportado tal cual viene declarado, el comportamiento de
      // siempre.
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
      metadata = await _fieldsGet(descriptor.model, candidateFields);
    } on OdooNotFoundException {
      final resolved = ResolvedCatalogDescriptor(
        state: OdooCapabilityState.unsupported,
        descriptor: descriptor,
        reason: '${descriptor.model} no existe en este servidor',
      );
      _resolved[key] = resolved;
      _probedAt = _now();
      return resolved;
    } catch (_) {
      // Red, 401/403, o cualquier otro fallo: sin evidencia. No se cachea —
      // el próximo `resolve()` vuelve a intentar el sondeo desde cero, y el
      // catálogo corre mientras tanto con su descriptor de siempre (E02,
      // punto 4).
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
      final resolved = ResolvedCatalogDescriptor(
        state: OdooCapabilityState.unsupported,
        descriptor: descriptor,
        reason: '${descriptor.model} no tiene ${missingRequired.join(', ')}',
      );
      _resolved[key] = resolved;
      _probedAt = _now();
      return resolved;
    }
    final droppedFields = descriptor.optionalFields
        .where((field) => !metadata.containsKey(field))
        .toSet();
    final droppedFilters = descriptor.optionalFilterFields
        .where((field) => !metadata.containsKey(field))
        .toSet();
    final resolved = ResolvedCatalogDescriptor(
      state: OdooCapabilityState.supported,
      descriptor: droppedFields.isEmpty && droppedFilters.isEmpty
          ? descriptor
          : _withoutFields(
              descriptor,
              droppedFields: droppedFields,
              droppedFilters: droppedFilters,
            ),
    );
    _resolved[key] = resolved;
    _probedAt = _now();
    return resolved;
  }

  /// Usa [Json2FieldsGetAttributesPort] cuando el lector lo ofrece (el
  /// cliente real siempre lo hace) para pedir sólo `attributes: ['type']` —
  /// ahorra ancho de banda sin cambiar qué campos aparecen como presentes.
  /// Cae a [Json2FieldsGetPort.fieldsGet] completo si no está disponible
  /// (dobles de prueba mínimos): misma evidencia, más bytes.
  Future<Map<String, dynamic>> _fieldsGet(
    String model,
    List<String> fields,
  ) {
    if (reader is Json2FieldsGetAttributesPort) {
      return (reader as Json2FieldsGetAttributesPort).fieldsGetAttributes(
        model: model,
        fields: fields,
        attributes: const ['type'],
      );
    }
    return (reader as Json2FieldsGetPort).fieldsGet(
      model: model,
      fields: fields,
    );
  }

  static RuntimeCatalogDescriptor _withoutFields(
    RuntimeCatalogDescriptor descriptor, {
    required Set<String> droppedFields,
    required Set<String> droppedFilters,
  }) {
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
    return RuntimeCatalogDescriptor(
      key: descriptor.key,
      model: descriptor.model,
      fields: effectiveFields,
      domain: effectiveDomain,
      order: descriptor.order,
      optionalFields: descriptor.optionalFields,
      optionalFilterFields: descriptor.optionalFilterFields,
    );
  }
}

/// Envuelve el `CatalogLoader` real de [loader] con la comprobación de
/// disponibilidad: si [availability] dice `unsupported`, ni siquiera se
/// intenta el `search_read` — se devuelve un lote vacío sin cursor, que
/// `CatalogSyncJob` confirma (`committed`) igual que cualquier otro lote, así
/// que NO cuenta como error (E02, punto 1). Con `supported`/`unknown`, corre
/// el descriptor resuelto (o el original, si es `unknown`) y, si el servidor
/// responde con evidencia nueva pese a eso:
/// - 404 de modelo → `unsupported`, lote vacío;
/// - campo opcional/de filtro inexistente → se quita y se reintenta UNA
///   vez (E02, punto 2); si el reintento también falla, el error se propaga
///   tal cual, sin un segundo intento silencioso;
/// - campo OBLIGATORIO inexistente → `unsupported`, lote vacío, sin
///   reintento (no hay nada que quitar).
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
      final retryDescriptor = availability.dropFieldAndRetry(
        key,
        resolved.descriptor,
        error.fieldName,
      );
      if (retryDescriptor == null) {
        availability.markUnsupported(
          key,
          reason: 'Campo obligatorio ${error.fieldName} inexistente en '
              '${resolved.descriptor.model} (confirmado al sincronizar)',
        );
        return const CatalogBatch(records: [], cursor: null);
      }
      return await loader.loader(retryDescriptor)(scope, cursorRaw);
    }
  };
}
