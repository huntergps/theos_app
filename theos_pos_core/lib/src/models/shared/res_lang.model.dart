import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

part 'res_lang.model.freezed.dart';
part 'res_lang.model.g.dart';

/// Odoo model: res.lang
@OdooModel('res.lang', tableName: 'res_lang')
@freezed
abstract class ResLang with _$ResLang {
  const ResLang._();

  const factory ResLang({
    @OdooId() required int id,
    @OdooString() required String name,
    @OdooString() required String code,
    @OdooBoolean() @Default(true) bool active,
    @OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,
  }) = _ResLang;
}
