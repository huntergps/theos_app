/// Read-only contract supplied by l10n_ec_collection_box_pos and extended by
/// optional addons. A null policy map means the panel extension is absent.
class PosAppCapabilities {
  static const booleanPolicyNames = <String>[
    'panel_validar_despacho',
    'panel_bloquear_sin_stock',
    'panel_teclado_tactil',
    'panel_editar_precio',
    'panel_editar_descuento',
    'panel_cajero_crea_ventas',
    'panel_accion_visible_pago',
    'panel_accion_visible_anticipo',
    'panel_accion_visible_retencion_sri',
    'panel_accion_visible_retencion',
    'panel_accion_visible_salida_efectivo',
    'panel_accion_visible_deposito',
    'panel_accion_visible_cruce',
  ];

  final int configId;
  final int companyId;
  final Map<String, bool>? counterPolicies;
  final int? pendingDays;

  const PosAppCapabilities._({
    required this.configId,
    required this.companyId,
    required this.counterPolicies,
    required this.pendingDays,
  });

  factory PosAppCapabilities.fromJson(Map<String, dynamic> json) {
    final configId = json['config_id'];
    final companyId = json['company_id'];
    if (json['version'] != 1 ||
        configId is! int ||
        configId <= 0 ||
        companyId is! int ||
        companyId <= 0 ||
        !json.containsKey('counter_policies')) {
      throw const FormatException('Invalid POS capability identity/version');
    }
    final rawPolicies = json['counter_policies'];
    if (rawPolicies == null) {
      return PosAppCapabilities._(
        configId: configId,
        companyId: companyId,
        counterPolicies: null,
        pendingDays: null,
      );
    }
    if (rawPolicies is! Map ||
        booleanPolicyNames.any((name) => rawPolicies[name] is! bool) ||
        rawPolicies['panel_dias_pendientes'] is! int ||
        (rawPolicies['panel_dias_pendientes'] as int) <= 0) {
      throw const FormatException('Incomplete or unresolved POS policies');
    }
    return PosAppCapabilities._(
      configId: configId,
      companyId: companyId,
      counterPolicies: Map.unmodifiable({
        for (final name in booleanPolicyNames) name: rawPolicies[name] as bool,
      }),
      pendingDays: rawPolicies['panel_dias_pendientes'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'config_id': configId,
    'company_id': companyId,
    'counter_policies': counterPolicies == null
        ? null
        : {...counterPolicies!, 'panel_dias_pendientes': pendingDays},
  };
}
