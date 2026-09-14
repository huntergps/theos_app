/// search_read transport shape shared by the read-only `search_read`-based
/// Envases bindings in this package.
///
/// 🔴 The `l10n_ec.envases.panel` dashboard model this file used to bind
/// (`EnvasesDashboardReader`/`EnvasesDashboardRow`) was retired in Odoo
/// (13-sep-2026) and replaced by `l10n_ec.envases.existencias.datos()` — see
/// `envases_existencias_reader.dart`. Those classes were removed here. This
/// filename and typedef stay in place because `EnvasesPartnerBalanceReader`
/// and `EnvasesPorRecibirReader` still import it for their own
/// `search_read`-shaped `transport` field; renaming or moving it would touch
/// both, and neither belongs to this change.
typedef EnvasesSearchReadTransport =
    Future<List<Map<String, dynamic>>> Function({
      required String model,
      required List<dynamic> domain,
      required List<String> fields,
      required Map<String, dynamic> context,
      required int limit,
      required int offset,
      required String order,
    });
