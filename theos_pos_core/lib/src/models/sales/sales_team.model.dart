import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

part 'sales_team.model.freezed.dart';
part 'sales_team.model.g.dart';

/// Sales Team model representing crm.team in Odoo
///
/// Sales teams organize salespeople and can be used to filter sales orders.
///
/// **Computed getters:**
/// - [displayName] - formatted team name
/// - [hasLeader] - whether team has a leader assigned
/// - [leaderName] - leader display name or default
@OdooModel('crm.team', tableName: 'crm_team')
@freezed
abstract class SalesTeam with _$SalesTeam {
  const SalesTeam._();

  const factory SalesTeam({
    @OdooId() required int id,
    @OdooString() required String name,
    @OdooBoolean() @Default(true) bool active,
    @OdooMany2One('res.company', odooName: 'company_id') int? companyId,
    @OdooMany2OneName(sourceField: 'company_id') String? companyName,
    @OdooMany2One('res.users', odooName: 'user_id') int? userId,
    @OdooMany2OneName(sourceField: 'user_id') String? userName,
    @OdooInteger() @Default(10) int sequence,
    @OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,
  }) = _SalesTeam;

  // ═══════════════════════════════════════════════════════════════════════════
  // Computed Getters
  // ═══════════════════════════════════════════════════════════════════════════

  /// Display name (just the name for now)
  String get displayName => name;

  /// Check if team has a leader assigned
  bool get hasLeader => userId != null && userId! > 0;

  /// Get leader display name or default
  String get leaderName => userName ?? 'Sin líder';
}
