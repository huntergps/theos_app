import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

part 'collection_config.model.freezed.dart';
part 'collection_config.model.g.dart';

/// Collection Config model migrated to @OdooModel annotation pattern.
///
/// ## Computed fields (equivalent to @api.depends in Odoo)
///
/// - [hasOpenSession] -> depends: [numberOfOpenedSession]
/// - [hasRescueSessions] -> depends: [numberOfRescueSession]
/// - [canOpenSession] -> depends: [numberOfOpenedSession]
/// - [hasDifferenceLimit] -> depends: [setMaximumDifference, amountAuthorizedDiff]
@OdooModel('collection.config', tableName: 'collection_config')
@freezed
abstract class CollectionConfig with _$CollectionConfig {
  const CollectionConfig._();

  // ═══════════════════ Validation ═══════════════════

  /// Validates the config before saving.
  Map<String, String> validate() {
    final errors = <String, String>{};
    if (name.isEmpty) {
      errors['name'] = 'Nombre es requerido';
    }
    if (code.isEmpty) {
      errors['code'] = 'Código es requerido';
    }
    return errors;
  }

  /// Validates for specific actions.
  Map<String, String> validateFor(String action) {
    final errors = validate();
    switch (action) {
      case 'open_session':
        if (!canOpenSession) {
          errors['session'] = 'Ya existe una sesión abierta para este punto';
        }
        if (!active) {
          errors['active'] = 'El punto de cobranza está inactivo';
        }
        break;

      case 'open_existing_session':
        if (!hasOpenSession) {
          errors['session'] = 'No hay sesión abierta';
        }
        break;

      case 'rescue_session':
        if (!hasRescueSessions) {
          errors['session'] = 'No hay sesiones de rescate pendientes';
        }
        break;
    }
    return errors;
  }

  const factory CollectionConfig({
    // ============ Identifiers ============
    @OdooId() required int id,

    // ============ Basic Data ============
    @OdooString() required String name,
    @OdooString() required String code,
    @OdooBoolean() @Default(true) bool active,

    // ============ Relations ============
    @OdooMany2One('res.company', odooName: 'company_id') int? companyId,
    @OdooMany2OneName(sourceField: 'company_id') String? companyName,
    @OdooMany2One('account.journal', odooName: 'journal_id') int? journalId,
    @OdooMany2OneName(sourceField: 'journal_id') String? journalName,
    @OdooMany2One('account.journal', odooName: 'cash_journal_id') int? cashJournalId,
    @OdooMany2OneName(sourceField: 'cash_journal_id') String? cashJournalName,
    @OdooMany2Many('account.journal', odooName: 'allowed_journal_ids') List<int>? allowedJournalIds,
    @OdooMany2One('account.account', odooName: 'cash_difference_account_id') int? cashDifferenceAccountId,
    @OdooMany2One('res.currency', odooName: 'currency_id') int? currencyId,
    @OdooMany2OneName(sourceField: 'currency_id') String? currencyName,

    // ============ Configuration Fields ============
    @OdooBoolean(odooName: 'set_maximum_difference') @Default(false) bool setMaximumDifference,
    @OdooFloat(odooName: 'amount_authorized_diff') @Default(0.0) double amountAuthorizedDiff,
    @OdooMany2Many('res.users', odooName: 'user_ids') List<int>? userIds,

    // ============ Session Fields ============
    @OdooMany2One('collection.session', odooName: 'current_session_id') int? currentSessionId,
    @OdooSelection(odooName: 'current_session_state') String? currentSessionState,
    @OdooString(odooName: 'current_session_name') String? currentSessionName,
    @OdooInteger(odooName: 'number_of_opened_session') @Default(0) int numberOfOpenedSession,
    @OdooDateTime(odooName: 'last_session_closing_date') DateTime? lastSessionClosingDate,
    @OdooFloat(odooName: 'last_session_closing_cash') @Default(0.0) double lastSessionClosingCash,

    // ============ Dashboard Display Fields ============
    @OdooString(odooName: 'collection_session_username') String? currentSessionUserName,
    @OdooString(odooName: 'current_session_state_display') String? currentSessionStateDisplay,
    @OdooInteger(odooName: 'number_of_rescue_session') @Default(0) int numberOfRescueSession,
  }) = _CollectionConfig;

  factory CollectionConfig.fromJson(Map<String, dynamic> json) =>
      _$CollectionConfigFromJson(json);

  // ═══════════════════════════════════════════════════════════════════════════
  // COMPUTED FIELDS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Indica si hay una sesion abierta
  bool get hasOpenSession => numberOfOpenedSession > 0;

  /// Indica si hay sesiones de rescate pendientes
  bool get hasRescueSessions => numberOfRescueSession > 0;

  /// Indica si el usuario puede abrir sesion
  bool get canOpenSession => !hasOpenSession;

  /// Indica si tiene diferencia maxima configurada
  bool get hasDifferenceLimit => setMaximumDifference && amountAuthorizedDiff > 0;

}
