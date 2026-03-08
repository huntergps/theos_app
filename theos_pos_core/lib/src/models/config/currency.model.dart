/// Currency Model for res.currency
///
/// Represents currency information synced from Odoo.
library;

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

part 'currency.model.freezed.dart';
part 'currency.model.g.dart';

@OdooModel('res.currency', tableName: 'res_currency')
@freezed
abstract class Currency with _$Currency {
  const Currency._();

  const factory Currency({
    @OdooId() required int id,
    @OdooLocalOnly() String? uuid,
    @OdooString() required String name,
    @OdooString() required String symbol,
    @OdooInteger(odooName: 'decimal_places') @Default(2) int decimalPlaces,
    @OdooFloat() @Default(0.01) double rounding,
    @OdooBoolean() @Default(true) bool active,
    @OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,
  }) = _Currency;

  bool get isActive => active;
  DateTime? get lastModified => writeDate;
  bool get isBaseCurrency => name == 'USD' || name == 'EUR';
  bool get hasSymbol => symbol.trim().isNotEmpty;

  String formatAmount(double amount) {
    return '${amount.toStringAsFixed(decimalPlaces)} $symbol';
  }
}

@OdooModel('decimal.precision', tableName: 'decimal_precision')
@freezed
abstract class DecimalPrecision with _$DecimalPrecision {
  const DecimalPrecision._();

  const factory DecimalPrecision({
    @OdooId() required int id,
    @OdooLocalOnly() String? uuid,
    @OdooString() required String name,
    @OdooInteger() required int digits,
    @OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,
  }) = _DecimalPrecision;

  bool get isActive => true;
  DateTime? get lastModified => writeDate;
  bool get isValidDigits => digits >= 0 && digits <= 10;
}
