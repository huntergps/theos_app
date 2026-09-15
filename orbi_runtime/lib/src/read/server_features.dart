import 'dart:convert';

import 'package:odoo_sdk/odoo_sdk.dart'
    show OdooAccessDeniedException, OdooNotFoundException;
import 'package:shared_preferences/shared_preferences.dart';

import 'json2_read_adapters.dart';

/// Áreas de negocio de las que theos_panel exige evidencia real del
/// servidor antes de encender una pantalla — orden del dueño, 14-sep-2026:
/// «theos_panel debe ser universal, no sólo funcionar con los módulos
/// custom que tiene newerp» (Mepriga, por ejemplo, no tiene ventas). Cada
/// valor es un HECHO DEL SERVIDOR (¿existe el modelo?), no un permiso de
/// usuario — eso lo sigue decidiendo `RouteAccessPolicy` con
/// `CapabilitySnapshot.permissions` (`capability_runtime.dart`), aparte.
enum ServerFeature { sales, cashbox, approvals, stock, envases }

/// El modelo cuya existencia se sonda para decidir si [ServerFeature] vive
/// en este servidor — el mismo modelo que la pantalla real lee, no uno
/// cualquiera del mismo módulo:
/// - `sales` → `ScopeOrderRepository`/`RuntimeLocalOrderReader` leen
///   `sale.order` (y Bodega hoy también, por eso Bodega comparte esta
///   feature — ver `RouteAccessPolicy`).
/// - `cashbox` → el hub de turno lee `collection.session`.
/// - `approvals` → `SessionApprovalPort` lee `approval.request`
///   (Enterprise; no todo Odoo lo trae).
/// - `stock` → reservado para picking/bodega nativo (`stock.picking`).
/// - `envases` → `l10n_ec.envases.operacion` (módulo custom EC).
extension ServerFeatureModel on ServerFeature {
  String get probeModel => switch (this) {
    ServerFeature.sales => 'sale.order',
    ServerFeature.cashbox => 'collection.session',
    ServerFeature.approvals => 'approval.request',
    ServerFeature.stock => 'stock.picking',
    ServerFeature.envases => 'l10n_ec.envases.operacion',
  };
}

/// `unknown` es DELIBERADAMENTE distinto de `unavailable` — mismo principio
/// que `OdooCapabilityState` (CLAUDE.md, «Odoo 19 frente a Odoo 20»: la
/// evidencia gana). Sin sondeo todavía, o un sondeo que no trajo evidencia
/// real (red, 401, 500), es `unknown`, y `unknown` no habilita nada — nunca
/// se confunde con `unavailable`, que sólo se alcanza con un 404 real de
/// modelo.
enum ServerFeatureState { available, unavailable, unknown }

/// Snapshot inmutable de lo que un servidor+base tienen, con la fecha en que
/// se comprobó cada [ServerFeature] (sólo diagnóstico, nunca se parsea).
final class ServerFeatures {
  const ServerFeatures._(this._states, this._checkedAt);

  static const empty = ServerFeatures._({}, {});

  final Map<ServerFeature, ServerFeatureState> _states;
  final Map<ServerFeature, DateTime> _checkedAt;

  ServerFeatureState stateOf(ServerFeature feature) =>
      _states[feature] ?? ServerFeatureState.unknown;

  /// `true` sólo con evidencia positiva. Ni `unavailable` ni `unknown`
  /// habilitan nada — ver el comentario de [ServerFeatureState].
  bool isAvailable(ServerFeature feature) =>
      stateOf(feature) == ServerFeatureState.available;

  DateTime? checkedAt(ServerFeature feature) => _checkedAt[feature];

  ServerFeatures withState(
    ServerFeature feature,
    ServerFeatureState state,
    DateTime checkedAt,
  ) => ServerFeatures._(
    {..._states, feature: state},
    {..._checkedAt, feature: checkedAt},
  );

  String toJson() => jsonEncode({
    for (final feature in ServerFeature.values)
      if (_states.containsKey(feature))
        feature.name: {
          'state': _states[feature]!.name,
          'checkedAt': _checkedAt[feature]?.toIso8601String(),
        },
  });

  static ServerFeatures fromJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return ServerFeatures.empty;
      final states = <ServerFeature, ServerFeatureState>{};
      final checkedAt = <ServerFeature, DateTime>{};
      for (final feature in ServerFeature.values) {
        final entry = decoded[feature.name];
        if (entry is! Map) continue;
        final matches = ServerFeatureState.values.where(
          (candidate) => candidate.name == entry['state'],
        );
        if (matches.isEmpty) continue;
        states[feature] = matches.first;
        final rawCheckedAt = entry['checkedAt'];
        if (rawCheckedAt is String) {
          final parsed = DateTime.tryParse(rawCheckedAt);
          if (parsed != null) checkedAt[feature] = parsed;
        }
      }
      return ServerFeatures._(states, checkedAt);
    } catch (_) {
      // JSON corrupto o de una forma anterior: se trata como si no hubiera
      // nada guardado, igual que `NotificationSystemIdRegistry` NO hace —
      // aquí, a diferencia de esa cola, perder el caché no pierde datos de
      // negocio, sólo obliga a un sondeo más.
      return ServerFeatures.empty;
    }
  }
}

/// Llave de `SharedPreferences`, por servidor+base — mismo patrón que
/// `orbi/presence_supported/<url>|<db>` en `router.dart`.
String serverFeaturesPrefsKey(String serverUrl, String database) =>
    'orbi/server_features/$serverUrl|$database';

/// Sondea y persiste, por servidor+base, qué [ServerFeature] existen en este
/// Odoo. Un fallo de red o de permiso NUNCA borra lo ya sabido: sólo
/// evidencia positiva (un 404 de modelo, o una respuesta real) cambia el
/// estado guardado — mismo principio que `RuntimeCatalogAvailability`
/// (E02).
final class ServerFeatureStore {
  ServerFeatureStore({
    required this.preferences,
    required this.serverUrl,
    required this.database,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final SharedPreferences preferences;
  final String serverUrl;
  final String database;
  final DateTime Function() _now;

  String get _key => serverFeaturesPrefsKey(serverUrl, database);

  /// Lo guardado hasta ahora, sin red — es lo que hace que el menú sirva
  /// sin conexión.
  ServerFeatures read() {
    final raw = preferences.getString(_key);
    if (raw == null) return ServerFeatures.empty;
    return ServerFeatures.fromJson(raw);
  }

  /// Sondea [feature] con `fields_get` (`attributes: ['type']`, igual que
  /// `RuntimeCatalogAvailability`) contra [reader] y persiste el resultado
  /// — salvo que el sondeo no haya traído evidencia real, en cuyo caso lo
  /// guardado se deja tal cual. Devuelve el snapshot resultante (el mismo
  /// que ya había cuando no hubo evidencia nueva).
  Future<ServerFeatures> probe(ServerFeature feature, Object reader) async {
    final outcome = await _probeState(feature, reader);
    final current = read();
    if (outcome == null) return current;
    final updated = current.withState(feature, outcome, _now());
    await preferences.setString(_key, updated.toJson());
    return updated;
  }

  Future<ServerFeatureState?> _probeState(
    ServerFeature feature,
    Object reader,
  ) async {
    try {
      if (reader is Json2FieldsGetAttributesPort) {
        await reader.fieldsGetAttributes(
          model: feature.probeModel,
          fields: const [],
          attributes: const ['type'],
        );
      } else if (reader is Json2FieldsGetPort) {
        await reader.fieldsGet(model: feature.probeModel, fields: const []);
      } else {
        return null;
      }
      return ServerFeatureState.available;
    } on OdooNotFoundException {
      return ServerFeatureState.unavailable;
    } on OdooAccessDeniedException {
      // El modelo existe: esta sesión sólo no tiene permiso para
      // preguntarlo. El permiso real de la PANTALLA lo decide el grupo del
      // usuario (`RouteAccessPolicy`), no esta sonda.
      return ServerFeatureState.available;
    } catch (_) {
      // Red, 401, 500: sin evidencia de nada. No se toca lo guardado — el
      // próximo sondeo (siguiente sesión en línea) lo vuelve a intentar.
      return null;
    }
  }
}
