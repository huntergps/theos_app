import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

part 'res_country.model.freezed.dart';
part 'res_country.model.g.dart';

/// Odoo model: res.country
@OdooModel('res.country', tableName: 'res_country')
@freezed
abstract class ResCountry with _$ResCountry {
  const ResCountry._();

  const factory ResCountry({
    @OdooId() required int id,
    @OdooString() required String name,
    @OdooString() String? code,
    @OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,
  }) = _ResCountry;
}
