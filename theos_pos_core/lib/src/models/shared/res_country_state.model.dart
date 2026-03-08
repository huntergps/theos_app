import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

part 'res_country_state.model.freezed.dart';
part 'res_country_state.model.g.dart';

/// Odoo model: res.country.state
@OdooModel('res.country.state', tableName: 'res_country_state')
@freezed
abstract class ResCountryState with _$ResCountryState {
  const ResCountryState._();

  const factory ResCountryState({
    @OdooId() required int id,
    @OdooString() required String name,
    @OdooString() String? code,
    @OdooMany2One('res.country', odooName: 'country_id') int? countryId,
    @OdooMany2OneName(sourceField: 'country_id') String? countryName,
    @OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,
  }) = _ResCountryState;
}
