// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tax.model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Tax {

@OdooId() int get id;@OdooString() String get name;@OdooString() String? get description;@OdooSelection(odooName: 'type_tax_use') TaxTypeUse get typeTaxUse;@OdooSelection(odooName: 'amount_type') TaxAmountType get amountType;@OdooFloat() double get amount;@OdooBoolean() bool get active;@OdooBoolean(odooName: 'price_include') bool get priceInclude;@OdooBoolean(odooName: 'include_base_amount') bool get includeBaseAmount;@OdooInteger() int get sequence;@OdooMany2One('res.company', odooName: 'company_id') int? get companyId;@OdooMany2OneName(sourceField: 'company_id') String? get companyName;@OdooString(odooName: 'tax_group_id') String? get taxGroup;@OdooString(odooName: 'tax_group_l10n_ec_type') String? get taxGroupL10nEcType;@OdooDateTime(odooName: 'write_date', writable: false) DateTime? get writeDate;
/// Create a copy of Tax
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaxCopyWith<Tax> get copyWith => _$TaxCopyWithImpl<Tax>(this as Tax, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Tax&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.typeTaxUse, typeTaxUse) || other.typeTaxUse == typeTaxUse)&&(identical(other.amountType, amountType) || other.amountType == amountType)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.active, active) || other.active == active)&&(identical(other.priceInclude, priceInclude) || other.priceInclude == priceInclude)&&(identical(other.includeBaseAmount, includeBaseAmount) || other.includeBaseAmount == includeBaseAmount)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&(identical(other.companyName, companyName) || other.companyName == companyName)&&(identical(other.taxGroup, taxGroup) || other.taxGroup == taxGroup)&&(identical(other.taxGroupL10nEcType, taxGroupL10nEcType) || other.taxGroupL10nEcType == taxGroupL10nEcType)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,description,typeTaxUse,amountType,amount,active,priceInclude,includeBaseAmount,sequence,companyId,companyName,taxGroup,taxGroupL10nEcType,writeDate);

@override
String toString() {
  return 'Tax(id: $id, name: $name, description: $description, typeTaxUse: $typeTaxUse, amountType: $amountType, amount: $amount, active: $active, priceInclude: $priceInclude, includeBaseAmount: $includeBaseAmount, sequence: $sequence, companyId: $companyId, companyName: $companyName, taxGroup: $taxGroup, taxGroupL10nEcType: $taxGroupL10nEcType, writeDate: $writeDate)';
}


}

/// @nodoc
abstract mixin class $TaxCopyWith<$Res>  {
  factory $TaxCopyWith(Tax value, $Res Function(Tax) _then) = _$TaxCopyWithImpl;
@useResult
$Res call({
@OdooId() int id,@OdooString() String name,@OdooString() String? description,@OdooSelection(odooName: 'type_tax_use') TaxTypeUse typeTaxUse,@OdooSelection(odooName: 'amount_type') TaxAmountType amountType,@OdooFloat() double amount,@OdooBoolean() bool active,@OdooBoolean(odooName: 'price_include') bool priceInclude,@OdooBoolean(odooName: 'include_base_amount') bool includeBaseAmount,@OdooInteger() int sequence,@OdooMany2One('res.company', odooName: 'company_id') int? companyId,@OdooMany2OneName(sourceField: 'company_id') String? companyName,@OdooString(odooName: 'tax_group_id') String? taxGroup,@OdooString(odooName: 'tax_group_l10n_ec_type') String? taxGroupL10nEcType,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate
});




}
/// @nodoc
class _$TaxCopyWithImpl<$Res>
    implements $TaxCopyWith<$Res> {
  _$TaxCopyWithImpl(this._self, this._then);

  final Tax _self;
  final $Res Function(Tax) _then;

/// Create a copy of Tax
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? description = freezed,Object? typeTaxUse = null,Object? amountType = null,Object? amount = null,Object? active = null,Object? priceInclude = null,Object? includeBaseAmount = null,Object? sequence = null,Object? companyId = freezed,Object? companyName = freezed,Object? taxGroup = freezed,Object? taxGroupL10nEcType = freezed,Object? writeDate = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,typeTaxUse: null == typeTaxUse ? _self.typeTaxUse : typeTaxUse // ignore: cast_nullable_to_non_nullable
as TaxTypeUse,amountType: null == amountType ? _self.amountType : amountType // ignore: cast_nullable_to_non_nullable
as TaxAmountType,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,priceInclude: null == priceInclude ? _self.priceInclude : priceInclude // ignore: cast_nullable_to_non_nullable
as bool,includeBaseAmount: null == includeBaseAmount ? _self.includeBaseAmount : includeBaseAmount // ignore: cast_nullable_to_non_nullable
as bool,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,companyId: freezed == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as int?,companyName: freezed == companyName ? _self.companyName : companyName // ignore: cast_nullable_to_non_nullable
as String?,taxGroup: freezed == taxGroup ? _self.taxGroup : taxGroup // ignore: cast_nullable_to_non_nullable
as String?,taxGroupL10nEcType: freezed == taxGroupL10nEcType ? _self.taxGroupL10nEcType : taxGroupL10nEcType // ignore: cast_nullable_to_non_nullable
as String?,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Tax].
extension TaxPatterns on Tax {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Tax value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Tax() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Tax value)  $default,){
final _that = this;
switch (_that) {
case _Tax():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Tax value)?  $default,){
final _that = this;
switch (_that) {
case _Tax() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooString()  String name, @OdooString()  String? description, @OdooSelection(odooName: 'type_tax_use')  TaxTypeUse typeTaxUse, @OdooSelection(odooName: 'amount_type')  TaxAmountType amountType, @OdooFloat()  double amount, @OdooBoolean()  bool active, @OdooBoolean(odooName: 'price_include')  bool priceInclude, @OdooBoolean(odooName: 'include_base_amount')  bool includeBaseAmount, @OdooInteger()  int sequence, @OdooMany2One('res.company', odooName: 'company_id')  int? companyId, @OdooMany2OneName(sourceField: 'company_id')  String? companyName, @OdooString(odooName: 'tax_group_id')  String? taxGroup, @OdooString(odooName: 'tax_group_l10n_ec_type')  String? taxGroupL10nEcType, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Tax() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.typeTaxUse,_that.amountType,_that.amount,_that.active,_that.priceInclude,_that.includeBaseAmount,_that.sequence,_that.companyId,_that.companyName,_that.taxGroup,_that.taxGroupL10nEcType,_that.writeDate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooString()  String name, @OdooString()  String? description, @OdooSelection(odooName: 'type_tax_use')  TaxTypeUse typeTaxUse, @OdooSelection(odooName: 'amount_type')  TaxAmountType amountType, @OdooFloat()  double amount, @OdooBoolean()  bool active, @OdooBoolean(odooName: 'price_include')  bool priceInclude, @OdooBoolean(odooName: 'include_base_amount')  bool includeBaseAmount, @OdooInteger()  int sequence, @OdooMany2One('res.company', odooName: 'company_id')  int? companyId, @OdooMany2OneName(sourceField: 'company_id')  String? companyName, @OdooString(odooName: 'tax_group_id')  String? taxGroup, @OdooString(odooName: 'tax_group_l10n_ec_type')  String? taxGroupL10nEcType, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)  $default,) {final _that = this;
switch (_that) {
case _Tax():
return $default(_that.id,_that.name,_that.description,_that.typeTaxUse,_that.amountType,_that.amount,_that.active,_that.priceInclude,_that.includeBaseAmount,_that.sequence,_that.companyId,_that.companyName,_that.taxGroup,_that.taxGroupL10nEcType,_that.writeDate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@OdooId()  int id, @OdooString()  String name, @OdooString()  String? description, @OdooSelection(odooName: 'type_tax_use')  TaxTypeUse typeTaxUse, @OdooSelection(odooName: 'amount_type')  TaxAmountType amountType, @OdooFloat()  double amount, @OdooBoolean()  bool active, @OdooBoolean(odooName: 'price_include')  bool priceInclude, @OdooBoolean(odooName: 'include_base_amount')  bool includeBaseAmount, @OdooInteger()  int sequence, @OdooMany2One('res.company', odooName: 'company_id')  int? companyId, @OdooMany2OneName(sourceField: 'company_id')  String? companyName, @OdooString(odooName: 'tax_group_id')  String? taxGroup, @OdooString(odooName: 'tax_group_l10n_ec_type')  String? taxGroupL10nEcType, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)?  $default,) {final _that = this;
switch (_that) {
case _Tax() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.typeTaxUse,_that.amountType,_that.amount,_that.active,_that.priceInclude,_that.includeBaseAmount,_that.sequence,_that.companyId,_that.companyName,_that.taxGroup,_that.taxGroupL10nEcType,_that.writeDate);case _:
  return null;

}
}

}

/// @nodoc


class _Tax extends Tax {
  const _Tax({@OdooId() required this.id, @OdooString() required this.name, @OdooString() this.description, @OdooSelection(odooName: 'type_tax_use') this.typeTaxUse = TaxTypeUse.sale, @OdooSelection(odooName: 'amount_type') this.amountType = TaxAmountType.percent, @OdooFloat() this.amount = 0.0, @OdooBoolean() this.active = true, @OdooBoolean(odooName: 'price_include') this.priceInclude = false, @OdooBoolean(odooName: 'include_base_amount') this.includeBaseAmount = false, @OdooInteger() this.sequence = 1, @OdooMany2One('res.company', odooName: 'company_id') this.companyId, @OdooMany2OneName(sourceField: 'company_id') this.companyName, @OdooString(odooName: 'tax_group_id') this.taxGroup, @OdooString(odooName: 'tax_group_l10n_ec_type') this.taxGroupL10nEcType, @OdooDateTime(odooName: 'write_date', writable: false) this.writeDate}): super._();
  

@override@OdooId() final  int id;
@override@OdooString() final  String name;
@override@OdooString() final  String? description;
@override@JsonKey()@OdooSelection(odooName: 'type_tax_use') final  TaxTypeUse typeTaxUse;
@override@JsonKey()@OdooSelection(odooName: 'amount_type') final  TaxAmountType amountType;
@override@JsonKey()@OdooFloat() final  double amount;
@override@JsonKey()@OdooBoolean() final  bool active;
@override@JsonKey()@OdooBoolean(odooName: 'price_include') final  bool priceInclude;
@override@JsonKey()@OdooBoolean(odooName: 'include_base_amount') final  bool includeBaseAmount;
@override@JsonKey()@OdooInteger() final  int sequence;
@override@OdooMany2One('res.company', odooName: 'company_id') final  int? companyId;
@override@OdooMany2OneName(sourceField: 'company_id') final  String? companyName;
@override@OdooString(odooName: 'tax_group_id') final  String? taxGroup;
@override@OdooString(odooName: 'tax_group_l10n_ec_type') final  String? taxGroupL10nEcType;
@override@OdooDateTime(odooName: 'write_date', writable: false) final  DateTime? writeDate;

/// Create a copy of Tax
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaxCopyWith<_Tax> get copyWith => __$TaxCopyWithImpl<_Tax>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Tax&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.typeTaxUse, typeTaxUse) || other.typeTaxUse == typeTaxUse)&&(identical(other.amountType, amountType) || other.amountType == amountType)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.active, active) || other.active == active)&&(identical(other.priceInclude, priceInclude) || other.priceInclude == priceInclude)&&(identical(other.includeBaseAmount, includeBaseAmount) || other.includeBaseAmount == includeBaseAmount)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&(identical(other.companyName, companyName) || other.companyName == companyName)&&(identical(other.taxGroup, taxGroup) || other.taxGroup == taxGroup)&&(identical(other.taxGroupL10nEcType, taxGroupL10nEcType) || other.taxGroupL10nEcType == taxGroupL10nEcType)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,description,typeTaxUse,amountType,amount,active,priceInclude,includeBaseAmount,sequence,companyId,companyName,taxGroup,taxGroupL10nEcType,writeDate);

@override
String toString() {
  return 'Tax(id: $id, name: $name, description: $description, typeTaxUse: $typeTaxUse, amountType: $amountType, amount: $amount, active: $active, priceInclude: $priceInclude, includeBaseAmount: $includeBaseAmount, sequence: $sequence, companyId: $companyId, companyName: $companyName, taxGroup: $taxGroup, taxGroupL10nEcType: $taxGroupL10nEcType, writeDate: $writeDate)';
}


}

/// @nodoc
abstract mixin class _$TaxCopyWith<$Res> implements $TaxCopyWith<$Res> {
  factory _$TaxCopyWith(_Tax value, $Res Function(_Tax) _then) = __$TaxCopyWithImpl;
@override @useResult
$Res call({
@OdooId() int id,@OdooString() String name,@OdooString() String? description,@OdooSelection(odooName: 'type_tax_use') TaxTypeUse typeTaxUse,@OdooSelection(odooName: 'amount_type') TaxAmountType amountType,@OdooFloat() double amount,@OdooBoolean() bool active,@OdooBoolean(odooName: 'price_include') bool priceInclude,@OdooBoolean(odooName: 'include_base_amount') bool includeBaseAmount,@OdooInteger() int sequence,@OdooMany2One('res.company', odooName: 'company_id') int? companyId,@OdooMany2OneName(sourceField: 'company_id') String? companyName,@OdooString(odooName: 'tax_group_id') String? taxGroup,@OdooString(odooName: 'tax_group_l10n_ec_type') String? taxGroupL10nEcType,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate
});




}
/// @nodoc
class __$TaxCopyWithImpl<$Res>
    implements _$TaxCopyWith<$Res> {
  __$TaxCopyWithImpl(this._self, this._then);

  final _Tax _self;
  final $Res Function(_Tax) _then;

/// Create a copy of Tax
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? description = freezed,Object? typeTaxUse = null,Object? amountType = null,Object? amount = null,Object? active = null,Object? priceInclude = null,Object? includeBaseAmount = null,Object? sequence = null,Object? companyId = freezed,Object? companyName = freezed,Object? taxGroup = freezed,Object? taxGroupL10nEcType = freezed,Object? writeDate = freezed,}) {
  return _then(_Tax(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,typeTaxUse: null == typeTaxUse ? _self.typeTaxUse : typeTaxUse // ignore: cast_nullable_to_non_nullable
as TaxTypeUse,amountType: null == amountType ? _self.amountType : amountType // ignore: cast_nullable_to_non_nullable
as TaxAmountType,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,priceInclude: null == priceInclude ? _self.priceInclude : priceInclude // ignore: cast_nullable_to_non_nullable
as bool,includeBaseAmount: null == includeBaseAmount ? _self.includeBaseAmount : includeBaseAmount // ignore: cast_nullable_to_non_nullable
as bool,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,companyId: freezed == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as int?,companyName: freezed == companyName ? _self.companyName : companyName // ignore: cast_nullable_to_non_nullable
as String?,taxGroup: freezed == taxGroup ? _self.taxGroup : taxGroup // ignore: cast_nullable_to_non_nullable
as String?,taxGroupL10nEcType: freezed == taxGroupL10nEcType ? _self.taxGroupL10nEcType : taxGroupL10nEcType // ignore: cast_nullable_to_non_nullable
as String?,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
