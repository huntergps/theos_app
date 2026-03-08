// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'withhold_line.model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WithholdLine {

@OdooId() int get id;@OdooLocalOnly() String get lineUuid;@OdooInteger(odooName: 'tax_id') int get taxId;@OdooString(odooName: 'tax_name') String get taxName;@OdooFloat(odooName: 'tax_percent') double get taxPercent;@OdooSelection() WithholdType get withholdType;@OdooSelection(odooName: 'taxsupport_code') TaxSupportCode? get taxSupportCode;@OdooFloat() double get base;@OdooFloat() double get amount;@OdooString() String? get notes;
/// Create a copy of WithholdLine
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WithholdLineCopyWith<WithholdLine> get copyWith => _$WithholdLineCopyWithImpl<WithholdLine>(this as WithholdLine, _$identity);

  /// Serializes this WithholdLine to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WithholdLine&&(identical(other.id, id) || other.id == id)&&(identical(other.lineUuid, lineUuid) || other.lineUuid == lineUuid)&&(identical(other.taxId, taxId) || other.taxId == taxId)&&(identical(other.taxName, taxName) || other.taxName == taxName)&&(identical(other.taxPercent, taxPercent) || other.taxPercent == taxPercent)&&(identical(other.withholdType, withholdType) || other.withholdType == withholdType)&&(identical(other.taxSupportCode, taxSupportCode) || other.taxSupportCode == taxSupportCode)&&(identical(other.base, base) || other.base == base)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.notes, notes) || other.notes == notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,lineUuid,taxId,taxName,taxPercent,withholdType,taxSupportCode,base,amount,notes);

@override
String toString() {
  return 'WithholdLine(id: $id, lineUuid: $lineUuid, taxId: $taxId, taxName: $taxName, taxPercent: $taxPercent, withholdType: $withholdType, taxSupportCode: $taxSupportCode, base: $base, amount: $amount, notes: $notes)';
}


}

/// @nodoc
abstract mixin class $WithholdLineCopyWith<$Res>  {
  factory $WithholdLineCopyWith(WithholdLine value, $Res Function(WithholdLine) _then) = _$WithholdLineCopyWithImpl;
@useResult
$Res call({
@OdooId() int id,@OdooLocalOnly() String lineUuid,@OdooInteger(odooName: 'tax_id') int taxId,@OdooString(odooName: 'tax_name') String taxName,@OdooFloat(odooName: 'tax_percent') double taxPercent,@OdooSelection() WithholdType withholdType,@OdooSelection(odooName: 'taxsupport_code') TaxSupportCode? taxSupportCode,@OdooFloat() double base,@OdooFloat() double amount,@OdooString() String? notes
});




}
/// @nodoc
class _$WithholdLineCopyWithImpl<$Res>
    implements $WithholdLineCopyWith<$Res> {
  _$WithholdLineCopyWithImpl(this._self, this._then);

  final WithholdLine _self;
  final $Res Function(WithholdLine) _then;

/// Create a copy of WithholdLine
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? lineUuid = null,Object? taxId = null,Object? taxName = null,Object? taxPercent = null,Object? withholdType = null,Object? taxSupportCode = freezed,Object? base = null,Object? amount = null,Object? notes = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,lineUuid: null == lineUuid ? _self.lineUuid : lineUuid // ignore: cast_nullable_to_non_nullable
as String,taxId: null == taxId ? _self.taxId : taxId // ignore: cast_nullable_to_non_nullable
as int,taxName: null == taxName ? _self.taxName : taxName // ignore: cast_nullable_to_non_nullable
as String,taxPercent: null == taxPercent ? _self.taxPercent : taxPercent // ignore: cast_nullable_to_non_nullable
as double,withholdType: null == withholdType ? _self.withholdType : withholdType // ignore: cast_nullable_to_non_nullable
as WithholdType,taxSupportCode: freezed == taxSupportCode ? _self.taxSupportCode : taxSupportCode // ignore: cast_nullable_to_non_nullable
as TaxSupportCode?,base: null == base ? _self.base : base // ignore: cast_nullable_to_non_nullable
as double,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [WithholdLine].
extension WithholdLinePatterns on WithholdLine {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WithholdLine value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WithholdLine() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WithholdLine value)  $default,){
final _that = this;
switch (_that) {
case _WithholdLine():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WithholdLine value)?  $default,){
final _that = this;
switch (_that) {
case _WithholdLine() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooLocalOnly()  String lineUuid, @OdooInteger(odooName: 'tax_id')  int taxId, @OdooString(odooName: 'tax_name')  String taxName, @OdooFloat(odooName: 'tax_percent')  double taxPercent, @OdooSelection()  WithholdType withholdType, @OdooSelection(odooName: 'taxsupport_code')  TaxSupportCode? taxSupportCode, @OdooFloat()  double base, @OdooFloat()  double amount, @OdooString()  String? notes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WithholdLine() when $default != null:
return $default(_that.id,_that.lineUuid,_that.taxId,_that.taxName,_that.taxPercent,_that.withholdType,_that.taxSupportCode,_that.base,_that.amount,_that.notes);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooLocalOnly()  String lineUuid, @OdooInteger(odooName: 'tax_id')  int taxId, @OdooString(odooName: 'tax_name')  String taxName, @OdooFloat(odooName: 'tax_percent')  double taxPercent, @OdooSelection()  WithholdType withholdType, @OdooSelection(odooName: 'taxsupport_code')  TaxSupportCode? taxSupportCode, @OdooFloat()  double base, @OdooFloat()  double amount, @OdooString()  String? notes)  $default,) {final _that = this;
switch (_that) {
case _WithholdLine():
return $default(_that.id,_that.lineUuid,_that.taxId,_that.taxName,_that.taxPercent,_that.withholdType,_that.taxSupportCode,_that.base,_that.amount,_that.notes);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@OdooId()  int id, @OdooLocalOnly()  String lineUuid, @OdooInteger(odooName: 'tax_id')  int taxId, @OdooString(odooName: 'tax_name')  String taxName, @OdooFloat(odooName: 'tax_percent')  double taxPercent, @OdooSelection()  WithholdType withholdType, @OdooSelection(odooName: 'taxsupport_code')  TaxSupportCode? taxSupportCode, @OdooFloat()  double base, @OdooFloat()  double amount, @OdooString()  String? notes)?  $default,) {final _that = this;
switch (_that) {
case _WithholdLine() when $default != null:
return $default(_that.id,_that.lineUuid,_that.taxId,_that.taxName,_that.taxPercent,_that.withholdType,_that.taxSupportCode,_that.base,_that.amount,_that.notes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WithholdLine extends WithholdLine {
  const _WithholdLine({@OdooId() this.id = 0, @OdooLocalOnly() required this.lineUuid, @OdooInteger(odooName: 'tax_id') required this.taxId, @OdooString(odooName: 'tax_name') required this.taxName, @OdooFloat(odooName: 'tax_percent') required this.taxPercent, @OdooSelection() required this.withholdType, @OdooSelection(odooName: 'taxsupport_code') this.taxSupportCode, @OdooFloat() required this.base, @OdooFloat() required this.amount, @OdooString() this.notes}): super._();
  factory _WithholdLine.fromJson(Map<String, dynamic> json) => _$WithholdLineFromJson(json);

@override@JsonKey()@OdooId() final  int id;
@override@OdooLocalOnly() final  String lineUuid;
@override@OdooInteger(odooName: 'tax_id') final  int taxId;
@override@OdooString(odooName: 'tax_name') final  String taxName;
@override@OdooFloat(odooName: 'tax_percent') final  double taxPercent;
@override@OdooSelection() final  WithholdType withholdType;
@override@OdooSelection(odooName: 'taxsupport_code') final  TaxSupportCode? taxSupportCode;
@override@OdooFloat() final  double base;
@override@OdooFloat() final  double amount;
@override@OdooString() final  String? notes;

/// Create a copy of WithholdLine
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WithholdLineCopyWith<_WithholdLine> get copyWith => __$WithholdLineCopyWithImpl<_WithholdLine>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WithholdLineToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WithholdLine&&(identical(other.id, id) || other.id == id)&&(identical(other.lineUuid, lineUuid) || other.lineUuid == lineUuid)&&(identical(other.taxId, taxId) || other.taxId == taxId)&&(identical(other.taxName, taxName) || other.taxName == taxName)&&(identical(other.taxPercent, taxPercent) || other.taxPercent == taxPercent)&&(identical(other.withholdType, withholdType) || other.withholdType == withholdType)&&(identical(other.taxSupportCode, taxSupportCode) || other.taxSupportCode == taxSupportCode)&&(identical(other.base, base) || other.base == base)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.notes, notes) || other.notes == notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,lineUuid,taxId,taxName,taxPercent,withholdType,taxSupportCode,base,amount,notes);

@override
String toString() {
  return 'WithholdLine(id: $id, lineUuid: $lineUuid, taxId: $taxId, taxName: $taxName, taxPercent: $taxPercent, withholdType: $withholdType, taxSupportCode: $taxSupportCode, base: $base, amount: $amount, notes: $notes)';
}


}

/// @nodoc
abstract mixin class _$WithholdLineCopyWith<$Res> implements $WithholdLineCopyWith<$Res> {
  factory _$WithholdLineCopyWith(_WithholdLine value, $Res Function(_WithholdLine) _then) = __$WithholdLineCopyWithImpl;
@override @useResult
$Res call({
@OdooId() int id,@OdooLocalOnly() String lineUuid,@OdooInteger(odooName: 'tax_id') int taxId,@OdooString(odooName: 'tax_name') String taxName,@OdooFloat(odooName: 'tax_percent') double taxPercent,@OdooSelection() WithholdType withholdType,@OdooSelection(odooName: 'taxsupport_code') TaxSupportCode? taxSupportCode,@OdooFloat() double base,@OdooFloat() double amount,@OdooString() String? notes
});




}
/// @nodoc
class __$WithholdLineCopyWithImpl<$Res>
    implements _$WithholdLineCopyWith<$Res> {
  __$WithholdLineCopyWithImpl(this._self, this._then);

  final _WithholdLine _self;
  final $Res Function(_WithholdLine) _then;

/// Create a copy of WithholdLine
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? lineUuid = null,Object? taxId = null,Object? taxName = null,Object? taxPercent = null,Object? withholdType = null,Object? taxSupportCode = freezed,Object? base = null,Object? amount = null,Object? notes = freezed,}) {
  return _then(_WithholdLine(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,lineUuid: null == lineUuid ? _self.lineUuid : lineUuid // ignore: cast_nullable_to_non_nullable
as String,taxId: null == taxId ? _self.taxId : taxId // ignore: cast_nullable_to_non_nullable
as int,taxName: null == taxName ? _self.taxName : taxName // ignore: cast_nullable_to_non_nullable
as String,taxPercent: null == taxPercent ? _self.taxPercent : taxPercent // ignore: cast_nullable_to_non_nullable
as double,withholdType: null == withholdType ? _self.withholdType : withholdType // ignore: cast_nullable_to_non_nullable
as WithholdType,taxSupportCode: freezed == taxSupportCode ? _self.taxSupportCode : taxSupportCode // ignore: cast_nullable_to_non_nullable
as TaxSupportCode?,base: null == base ? _self.base : base // ignore: cast_nullable_to_non_nullable
as double,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$AvailableWithholdTax {

 int get id; String get name; String? get spanishName; double get amount; WithholdType get withholdType;
/// Create a copy of AvailableWithholdTax
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AvailableWithholdTaxCopyWith<AvailableWithholdTax> get copyWith => _$AvailableWithholdTaxCopyWithImpl<AvailableWithholdTax>(this as AvailableWithholdTax, _$identity);

  /// Serializes this AvailableWithholdTax to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AvailableWithholdTax&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.spanishName, spanishName) || other.spanishName == spanishName)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.withholdType, withholdType) || other.withholdType == withholdType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,spanishName,amount,withholdType);

@override
String toString() {
  return 'AvailableWithholdTax(id: $id, name: $name, spanishName: $spanishName, amount: $amount, withholdType: $withholdType)';
}


}

/// @nodoc
abstract mixin class $AvailableWithholdTaxCopyWith<$Res>  {
  factory $AvailableWithholdTaxCopyWith(AvailableWithholdTax value, $Res Function(AvailableWithholdTax) _then) = _$AvailableWithholdTaxCopyWithImpl;
@useResult
$Res call({
 int id, String name, String? spanishName, double amount, WithholdType withholdType
});




}
/// @nodoc
class _$AvailableWithholdTaxCopyWithImpl<$Res>
    implements $AvailableWithholdTaxCopyWith<$Res> {
  _$AvailableWithholdTaxCopyWithImpl(this._self, this._then);

  final AvailableWithholdTax _self;
  final $Res Function(AvailableWithholdTax) _then;

/// Create a copy of AvailableWithholdTax
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? spanishName = freezed,Object? amount = null,Object? withholdType = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,spanishName: freezed == spanishName ? _self.spanishName : spanishName // ignore: cast_nullable_to_non_nullable
as String?,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,withholdType: null == withholdType ? _self.withholdType : withholdType // ignore: cast_nullable_to_non_nullable
as WithholdType,
  ));
}

}


/// Adds pattern-matching-related methods to [AvailableWithholdTax].
extension AvailableWithholdTaxPatterns on AvailableWithholdTax {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AvailableWithholdTax value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AvailableWithholdTax() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AvailableWithholdTax value)  $default,){
final _that = this;
switch (_that) {
case _AvailableWithholdTax():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AvailableWithholdTax value)?  $default,){
final _that = this;
switch (_that) {
case _AvailableWithholdTax() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name,  String? spanishName,  double amount,  WithholdType withholdType)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AvailableWithholdTax() when $default != null:
return $default(_that.id,_that.name,_that.spanishName,_that.amount,_that.withholdType);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name,  String? spanishName,  double amount,  WithholdType withholdType)  $default,) {final _that = this;
switch (_that) {
case _AvailableWithholdTax():
return $default(_that.id,_that.name,_that.spanishName,_that.amount,_that.withholdType);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name,  String? spanishName,  double amount,  WithholdType withholdType)?  $default,) {final _that = this;
switch (_that) {
case _AvailableWithholdTax() when $default != null:
return $default(_that.id,_that.name,_that.spanishName,_that.amount,_that.withholdType);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AvailableWithholdTax extends AvailableWithholdTax {
  const _AvailableWithholdTax({required this.id, required this.name, this.spanishName, required this.amount, required this.withholdType}): super._();
  factory _AvailableWithholdTax.fromJson(Map<String, dynamic> json) => _$AvailableWithholdTaxFromJson(json);

@override final  int id;
@override final  String name;
@override final  String? spanishName;
@override final  double amount;
@override final  WithholdType withholdType;

/// Create a copy of AvailableWithholdTax
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AvailableWithholdTaxCopyWith<_AvailableWithholdTax> get copyWith => __$AvailableWithholdTaxCopyWithImpl<_AvailableWithholdTax>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AvailableWithholdTaxToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AvailableWithholdTax&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.spanishName, spanishName) || other.spanishName == spanishName)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.withholdType, withholdType) || other.withholdType == withholdType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,spanishName,amount,withholdType);

@override
String toString() {
  return 'AvailableWithholdTax(id: $id, name: $name, spanishName: $spanishName, amount: $amount, withholdType: $withholdType)';
}


}

/// @nodoc
abstract mixin class _$AvailableWithholdTaxCopyWith<$Res> implements $AvailableWithholdTaxCopyWith<$Res> {
  factory _$AvailableWithholdTaxCopyWith(_AvailableWithholdTax value, $Res Function(_AvailableWithholdTax) _then) = __$AvailableWithholdTaxCopyWithImpl;
@override @useResult
$Res call({
 int id, String name, String? spanishName, double amount, WithholdType withholdType
});




}
/// @nodoc
class __$AvailableWithholdTaxCopyWithImpl<$Res>
    implements _$AvailableWithholdTaxCopyWith<$Res> {
  __$AvailableWithholdTaxCopyWithImpl(this._self, this._then);

  final _AvailableWithholdTax _self;
  final $Res Function(_AvailableWithholdTax) _then;

/// Create a copy of AvailableWithholdTax
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? spanishName = freezed,Object? amount = null,Object? withholdType = null,}) {
  return _then(_AvailableWithholdTax(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,spanishName: freezed == spanishName ? _self.spanishName : spanishName // ignore: cast_nullable_to_non_nullable
as String?,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,withholdType: null == withholdType ? _self.withholdType : withholdType // ignore: cast_nullable_to_non_nullable
as WithholdType,
  ));
}


}

// dart format on
