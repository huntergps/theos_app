// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pricelist.model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Pricelist {

@OdooId() int get id;@OdooString() String get name;@OdooBoolean() bool get active;@OdooMany2One('res.currency', odooName: 'currency_id') int? get currencyId;@OdooMany2OneName(sourceField: 'currency_id') String? get currencyName;@OdooMany2One('res.company', odooName: 'company_id') int? get companyId;@OdooMany2OneName(sourceField: 'company_id') String? get companyName;@OdooInteger() int get sequence;@OdooLocalOnly() String? get discountPolicy;@OdooDateTime(odooName: 'write_date', writable: false) DateTime? get writeDate;
/// Create a copy of Pricelist
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PricelistCopyWith<Pricelist> get copyWith => _$PricelistCopyWithImpl<Pricelist>(this as Pricelist, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Pricelist&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.active, active) || other.active == active)&&(identical(other.currencyId, currencyId) || other.currencyId == currencyId)&&(identical(other.currencyName, currencyName) || other.currencyName == currencyName)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&(identical(other.companyName, companyName) || other.companyName == companyName)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.discountPolicy, discountPolicy) || other.discountPolicy == discountPolicy)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,active,currencyId,currencyName,companyId,companyName,sequence,discountPolicy,writeDate);

@override
String toString() {
  return 'Pricelist(id: $id, name: $name, active: $active, currencyId: $currencyId, currencyName: $currencyName, companyId: $companyId, companyName: $companyName, sequence: $sequence, discountPolicy: $discountPolicy, writeDate: $writeDate)';
}


}

/// @nodoc
abstract mixin class $PricelistCopyWith<$Res>  {
  factory $PricelistCopyWith(Pricelist value, $Res Function(Pricelist) _then) = _$PricelistCopyWithImpl;
@useResult
$Res call({
@OdooId() int id,@OdooString() String name,@OdooBoolean() bool active,@OdooMany2One('res.currency', odooName: 'currency_id') int? currencyId,@OdooMany2OneName(sourceField: 'currency_id') String? currencyName,@OdooMany2One('res.company', odooName: 'company_id') int? companyId,@OdooMany2OneName(sourceField: 'company_id') String? companyName,@OdooInteger() int sequence,@OdooLocalOnly() String? discountPolicy,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate
});




}
/// @nodoc
class _$PricelistCopyWithImpl<$Res>
    implements $PricelistCopyWith<$Res> {
  _$PricelistCopyWithImpl(this._self, this._then);

  final Pricelist _self;
  final $Res Function(Pricelist) _then;

/// Create a copy of Pricelist
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? active = null,Object? currencyId = freezed,Object? currencyName = freezed,Object? companyId = freezed,Object? companyName = freezed,Object? sequence = null,Object? discountPolicy = freezed,Object? writeDate = freezed,}) {
  return _then(Pricelist(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,currencyId: freezed == currencyId ? _self.currencyId : currencyId // ignore: cast_nullable_to_non_nullable
as int?,currencyName: freezed == currencyName ? _self.currencyName : currencyName // ignore: cast_nullable_to_non_nullable
as String?,companyId: freezed == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as int?,companyName: freezed == companyName ? _self.companyName : companyName // ignore: cast_nullable_to_non_nullable
as String?,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,discountPolicy: freezed == discountPolicy ? _self.discountPolicy : discountPolicy // ignore: cast_nullable_to_non_nullable
as String?,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Pricelist].
extension PricelistPatterns on Pricelist {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Pricelist value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Pricelist() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Pricelist value)  $default,){
final _that = this;
switch (_that) {
case _Pricelist():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Pricelist value)?  $default,){
final _that = this;
switch (_that) {
case _Pricelist() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooString()  String name, @OdooBoolean()  bool active, @OdooMany2One('res.currency', odooName: 'currency_id')  int? currencyId, @OdooMany2OneName(sourceField: 'currency_id')  String? currencyName, @OdooMany2One('res.company', odooName: 'company_id')  int? companyId, @OdooMany2OneName(sourceField: 'company_id')  String? companyName, @OdooInteger()  int sequence, @OdooLocalOnly()  String? discountPolicy, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Pricelist() when $default != null:
return $default(_that.id,_that.name,_that.active,_that.currencyId,_that.currencyName,_that.companyId,_that.companyName,_that.sequence,_that.discountPolicy,_that.writeDate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooString()  String name, @OdooBoolean()  bool active, @OdooMany2One('res.currency', odooName: 'currency_id')  int? currencyId, @OdooMany2OneName(sourceField: 'currency_id')  String? currencyName, @OdooMany2One('res.company', odooName: 'company_id')  int? companyId, @OdooMany2OneName(sourceField: 'company_id')  String? companyName, @OdooInteger()  int sequence, @OdooLocalOnly()  String? discountPolicy, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)  $default,) {final _that = this;
switch (_that) {
case _Pricelist():
return $default(_that.id,_that.name,_that.active,_that.currencyId,_that.currencyName,_that.companyId,_that.companyName,_that.sequence,_that.discountPolicy,_that.writeDate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@OdooId()  int id, @OdooString()  String name, @OdooBoolean()  bool active, @OdooMany2One('res.currency', odooName: 'currency_id')  int? currencyId, @OdooMany2OneName(sourceField: 'currency_id')  String? currencyName, @OdooMany2One('res.company', odooName: 'company_id')  int? companyId, @OdooMany2OneName(sourceField: 'company_id')  String? companyName, @OdooInteger()  int sequence, @OdooLocalOnly()  String? discountPolicy, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)?  $default,) {final _that = this;
switch (_that) {
case _Pricelist() when $default != null:
return $default(_that.id,_that.name,_that.active,_that.currencyId,_that.currencyName,_that.companyId,_that.companyName,_that.sequence,_that.discountPolicy,_that.writeDate);case _:
  return null;

}
}

}

/// @nodoc


class _Pricelist extends Pricelist {
  const _Pricelist({@OdooId() required this.id, @OdooString() required this.name, @OdooBoolean() this.active = true, @OdooMany2One('res.currency', odooName: 'currency_id') this.currencyId, @OdooMany2OneName(sourceField: 'currency_id') this.currencyName, @OdooMany2One('res.company', odooName: 'company_id') this.companyId, @OdooMany2OneName(sourceField: 'company_id') this.companyName, @OdooInteger() this.sequence = 16, @OdooLocalOnly() this.discountPolicy, @OdooDateTime(odooName: 'write_date', writable: false) this.writeDate}): super._();
  

@override@OdooId() final  int id;
@override@OdooString() final  String name;
@override@JsonKey()@OdooBoolean() final  bool active;
@override@OdooMany2One('res.currency', odooName: 'currency_id') final  int? currencyId;
@override@OdooMany2OneName(sourceField: 'currency_id') final  String? currencyName;
@override@OdooMany2One('res.company', odooName: 'company_id') final  int? companyId;
@override@OdooMany2OneName(sourceField: 'company_id') final  String? companyName;
@override@JsonKey()@OdooInteger() final  int sequence;
@override@OdooLocalOnly() final  String? discountPolicy;
@override@OdooDateTime(odooName: 'write_date', writable: false) final  DateTime? writeDate;

/// Create a copy of Pricelist
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PricelistCopyWith<_Pricelist> get copyWith => __$PricelistCopyWithImpl<_Pricelist>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Pricelist&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.active, active) || other.active == active)&&(identical(other.currencyId, currencyId) || other.currencyId == currencyId)&&(identical(other.currencyName, currencyName) || other.currencyName == currencyName)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&(identical(other.companyName, companyName) || other.companyName == companyName)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.discountPolicy, discountPolicy) || other.discountPolicy == discountPolicy)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,active,currencyId,currencyName,companyId,companyName,sequence,discountPolicy,writeDate);

@override
String toString() {
  return 'Pricelist(id: $id, name: $name, active: $active, currencyId: $currencyId, currencyName: $currencyName, companyId: $companyId, companyName: $companyName, sequence: $sequence, discountPolicy: $discountPolicy, writeDate: $writeDate)';
}


}

/// @nodoc
abstract mixin class _$PricelistCopyWith<$Res> implements $PricelistCopyWith<$Res> {
  factory _$PricelistCopyWith(_Pricelist value, $Res Function(_Pricelist) _then) = __$PricelistCopyWithImpl;
@override @useResult
$Res call({
@OdooId() int id,@OdooString() String name,@OdooBoolean() bool active,@OdooMany2One('res.currency', odooName: 'currency_id') int? currencyId,@OdooMany2OneName(sourceField: 'currency_id') String? currencyName,@OdooMany2One('res.company', odooName: 'company_id') int? companyId,@OdooMany2OneName(sourceField: 'company_id') String? companyName,@OdooInteger() int sequence,@OdooLocalOnly() String? discountPolicy,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate
});




}
/// @nodoc
class __$PricelistCopyWithImpl<$Res>
    implements _$PricelistCopyWith<$Res> {
  __$PricelistCopyWithImpl(this._self, this._then);

  final _Pricelist _self;
  final $Res Function(_Pricelist) _then;

/// Create a copy of Pricelist
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? active = null,Object? currencyId = freezed,Object? currencyName = freezed,Object? companyId = freezed,Object? companyName = freezed,Object? sequence = null,Object? discountPolicy = freezed,Object? writeDate = freezed,}) {
  return _then(_Pricelist(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,currencyId: freezed == currencyId ? _self.currencyId : currencyId // ignore: cast_nullable_to_non_nullable
as int?,currencyName: freezed == currencyName ? _self.currencyName : currencyName // ignore: cast_nullable_to_non_nullable
as String?,companyId: freezed == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as int?,companyName: freezed == companyName ? _self.companyName : companyName // ignore: cast_nullable_to_non_nullable
as String?,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,discountPolicy: freezed == discountPolicy ? _self.discountPolicy : discountPolicy // ignore: cast_nullable_to_non_nullable
as String?,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
mixin _$PricelistItem {

@OdooId() int get id;@OdooMany2One('product.pricelist', odooName: 'pricelist_id') int get pricelistId;@OdooMany2One('product.template', odooName: 'product_tmpl_id') int? get productTmplId;@OdooMany2One('product.product', odooName: 'product_id') int? get productId;@OdooMany2One('product.category', odooName: 'categ_id') int? get categId;@OdooSelection() String get appliedOn;@OdooFloat() double get minQuantity;@OdooDateTime() DateTime? get dateStart;@OdooDateTime() DateTime? get dateEnd;@OdooSelection() String get computePrice;@OdooFloat() double get fixedPrice;@OdooFloat() double get percentPrice; int get sequence;@OdooLocalOnly() int? get uomId;@OdooSelection() String get base;@OdooMany2One('product.pricelist', odooName: 'base_pricelist_id') int? get basePricelistId;@OdooFloat() double get priceDiscount;@OdooFloat() double get priceSurcharge;@OdooFloat() double get priceRound;@OdooFloat() double get priceMinMargin;@OdooFloat() double get priceMaxMargin;@OdooDateTime(odooName: 'write_date', writable: false) DateTime? get writeDate;
/// Create a copy of PricelistItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PricelistItemCopyWith<PricelistItem> get copyWith => _$PricelistItemCopyWithImpl<PricelistItem>(this as PricelistItem, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PricelistItem&&(identical(other.id, id) || other.id == id)&&(identical(other.pricelistId, pricelistId) || other.pricelistId == pricelistId)&&(identical(other.productTmplId, productTmplId) || other.productTmplId == productTmplId)&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.categId, categId) || other.categId == categId)&&(identical(other.appliedOn, appliedOn) || other.appliedOn == appliedOn)&&(identical(other.minQuantity, minQuantity) || other.minQuantity == minQuantity)&&(identical(other.dateStart, dateStart) || other.dateStart == dateStart)&&(identical(other.dateEnd, dateEnd) || other.dateEnd == dateEnd)&&(identical(other.computePrice, computePrice) || other.computePrice == computePrice)&&(identical(other.fixedPrice, fixedPrice) || other.fixedPrice == fixedPrice)&&(identical(other.percentPrice, percentPrice) || other.percentPrice == percentPrice)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.uomId, uomId) || other.uomId == uomId)&&(identical(other.base, base) || other.base == base)&&(identical(other.basePricelistId, basePricelistId) || other.basePricelistId == basePricelistId)&&(identical(other.priceDiscount, priceDiscount) || other.priceDiscount == priceDiscount)&&(identical(other.priceSurcharge, priceSurcharge) || other.priceSurcharge == priceSurcharge)&&(identical(other.priceRound, priceRound) || other.priceRound == priceRound)&&(identical(other.priceMinMargin, priceMinMargin) || other.priceMinMargin == priceMinMargin)&&(identical(other.priceMaxMargin, priceMaxMargin) || other.priceMaxMargin == priceMaxMargin)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,pricelistId,productTmplId,productId,categId,appliedOn,minQuantity,dateStart,dateEnd,computePrice,fixedPrice,percentPrice,sequence,uomId,base,basePricelistId,priceDiscount,priceSurcharge,priceRound,priceMinMargin,priceMaxMargin,writeDate]);

@override
String toString() {
  return 'PricelistItem(id: $id, pricelistId: $pricelistId, productTmplId: $productTmplId, productId: $productId, categId: $categId, appliedOn: $appliedOn, minQuantity: $minQuantity, dateStart: $dateStart, dateEnd: $dateEnd, computePrice: $computePrice, fixedPrice: $fixedPrice, percentPrice: $percentPrice, sequence: $sequence, uomId: $uomId, base: $base, basePricelistId: $basePricelistId, priceDiscount: $priceDiscount, priceSurcharge: $priceSurcharge, priceRound: $priceRound, priceMinMargin: $priceMinMargin, priceMaxMargin: $priceMaxMargin, writeDate: $writeDate)';
}


}

/// @nodoc
abstract mixin class $PricelistItemCopyWith<$Res>  {
  factory $PricelistItemCopyWith(PricelistItem value, $Res Function(PricelistItem) _then) = _$PricelistItemCopyWithImpl;
@useResult
$Res call({
@OdooId() int id,@OdooMany2One('product.pricelist', odooName: 'pricelist_id') int pricelistId,@OdooMany2One('product.template', odooName: 'product_tmpl_id') int? productTmplId,@OdooMany2One('product.product', odooName: 'product_id') int? productId,@OdooMany2One('product.category', odooName: 'categ_id') int? categId,@OdooSelection() String appliedOn,@OdooFloat() double minQuantity,@OdooDateTime() DateTime? dateStart,@OdooDateTime() DateTime? dateEnd,@OdooSelection() String computePrice,@OdooFloat() double fixedPrice,@OdooFloat() double percentPrice, int sequence,@OdooLocalOnly() int? uomId,@OdooSelection() String base,@OdooMany2One('product.pricelist', odooName: 'base_pricelist_id') int? basePricelistId,@OdooFloat() double priceDiscount,@OdooFloat() double priceSurcharge,@OdooFloat() double priceRound,@OdooFloat() double priceMinMargin,@OdooFloat() double priceMaxMargin,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate
});




}
/// @nodoc
class _$PricelistItemCopyWithImpl<$Res>
    implements $PricelistItemCopyWith<$Res> {
  _$PricelistItemCopyWithImpl(this._self, this._then);

  final PricelistItem _self;
  final $Res Function(PricelistItem) _then;

/// Create a copy of PricelistItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? pricelistId = null,Object? productTmplId = freezed,Object? productId = freezed,Object? categId = freezed,Object? appliedOn = null,Object? minQuantity = null,Object? dateStart = freezed,Object? dateEnd = freezed,Object? computePrice = null,Object? fixedPrice = null,Object? percentPrice = null,Object? sequence = null,Object? uomId = freezed,Object? base = null,Object? basePricelistId = freezed,Object? priceDiscount = null,Object? priceSurcharge = null,Object? priceRound = null,Object? priceMinMargin = null,Object? priceMaxMargin = null,Object? writeDate = freezed,}) {
  return _then(PricelistItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,pricelistId: null == pricelistId ? _self.pricelistId : pricelistId // ignore: cast_nullable_to_non_nullable
as int,productTmplId: freezed == productTmplId ? _self.productTmplId : productTmplId // ignore: cast_nullable_to_non_nullable
as int?,productId: freezed == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as int?,categId: freezed == categId ? _self.categId : categId // ignore: cast_nullable_to_non_nullable
as int?,appliedOn: null == appliedOn ? _self.appliedOn : appliedOn // ignore: cast_nullable_to_non_nullable
as String,minQuantity: null == minQuantity ? _self.minQuantity : minQuantity // ignore: cast_nullable_to_non_nullable
as double,dateStart: freezed == dateStart ? _self.dateStart : dateStart // ignore: cast_nullable_to_non_nullable
as DateTime?,dateEnd: freezed == dateEnd ? _self.dateEnd : dateEnd // ignore: cast_nullable_to_non_nullable
as DateTime?,computePrice: null == computePrice ? _self.computePrice : computePrice // ignore: cast_nullable_to_non_nullable
as String,fixedPrice: null == fixedPrice ? _self.fixedPrice : fixedPrice // ignore: cast_nullable_to_non_nullable
as double,percentPrice: null == percentPrice ? _self.percentPrice : percentPrice // ignore: cast_nullable_to_non_nullable
as double,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,uomId: freezed == uomId ? _self.uomId : uomId // ignore: cast_nullable_to_non_nullable
as int?,base: null == base ? _self.base : base // ignore: cast_nullable_to_non_nullable
as String,basePricelistId: freezed == basePricelistId ? _self.basePricelistId : basePricelistId // ignore: cast_nullable_to_non_nullable
as int?,priceDiscount: null == priceDiscount ? _self.priceDiscount : priceDiscount // ignore: cast_nullable_to_non_nullable
as double,priceSurcharge: null == priceSurcharge ? _self.priceSurcharge : priceSurcharge // ignore: cast_nullable_to_non_nullable
as double,priceRound: null == priceRound ? _self.priceRound : priceRound // ignore: cast_nullable_to_non_nullable
as double,priceMinMargin: null == priceMinMargin ? _self.priceMinMargin : priceMinMargin // ignore: cast_nullable_to_non_nullable
as double,priceMaxMargin: null == priceMaxMargin ? _self.priceMaxMargin : priceMaxMargin // ignore: cast_nullable_to_non_nullable
as double,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [PricelistItem].
extension PricelistItemPatterns on PricelistItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PricelistItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PricelistItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PricelistItem value)  $default,){
final _that = this;
switch (_that) {
case _PricelistItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PricelistItem value)?  $default,){
final _that = this;
switch (_that) {
case _PricelistItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooMany2One('product.pricelist', odooName: 'pricelist_id')  int pricelistId, @OdooMany2One('product.template', odooName: 'product_tmpl_id')  int? productTmplId, @OdooMany2One('product.product', odooName: 'product_id')  int? productId, @OdooMany2One('product.category', odooName: 'categ_id')  int? categId, @OdooSelection()  String appliedOn, @OdooFloat()  double minQuantity, @OdooDateTime()  DateTime? dateStart, @OdooDateTime()  DateTime? dateEnd, @OdooSelection()  String computePrice, @OdooFloat()  double fixedPrice, @OdooFloat()  double percentPrice,  int sequence, @OdooLocalOnly()  int? uomId, @OdooSelection()  String base, @OdooMany2One('product.pricelist', odooName: 'base_pricelist_id')  int? basePricelistId, @OdooFloat()  double priceDiscount, @OdooFloat()  double priceSurcharge, @OdooFloat()  double priceRound, @OdooFloat()  double priceMinMargin, @OdooFloat()  double priceMaxMargin, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PricelistItem() when $default != null:
return $default(_that.id,_that.pricelistId,_that.productTmplId,_that.productId,_that.categId,_that.appliedOn,_that.minQuantity,_that.dateStart,_that.dateEnd,_that.computePrice,_that.fixedPrice,_that.percentPrice,_that.sequence,_that.uomId,_that.base,_that.basePricelistId,_that.priceDiscount,_that.priceSurcharge,_that.priceRound,_that.priceMinMargin,_that.priceMaxMargin,_that.writeDate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooMany2One('product.pricelist', odooName: 'pricelist_id')  int pricelistId, @OdooMany2One('product.template', odooName: 'product_tmpl_id')  int? productTmplId, @OdooMany2One('product.product', odooName: 'product_id')  int? productId, @OdooMany2One('product.category', odooName: 'categ_id')  int? categId, @OdooSelection()  String appliedOn, @OdooFloat()  double minQuantity, @OdooDateTime()  DateTime? dateStart, @OdooDateTime()  DateTime? dateEnd, @OdooSelection()  String computePrice, @OdooFloat()  double fixedPrice, @OdooFloat()  double percentPrice,  int sequence, @OdooLocalOnly()  int? uomId, @OdooSelection()  String base, @OdooMany2One('product.pricelist', odooName: 'base_pricelist_id')  int? basePricelistId, @OdooFloat()  double priceDiscount, @OdooFloat()  double priceSurcharge, @OdooFloat()  double priceRound, @OdooFloat()  double priceMinMargin, @OdooFloat()  double priceMaxMargin, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)  $default,) {final _that = this;
switch (_that) {
case _PricelistItem():
return $default(_that.id,_that.pricelistId,_that.productTmplId,_that.productId,_that.categId,_that.appliedOn,_that.minQuantity,_that.dateStart,_that.dateEnd,_that.computePrice,_that.fixedPrice,_that.percentPrice,_that.sequence,_that.uomId,_that.base,_that.basePricelistId,_that.priceDiscount,_that.priceSurcharge,_that.priceRound,_that.priceMinMargin,_that.priceMaxMargin,_that.writeDate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@OdooId()  int id, @OdooMany2One('product.pricelist', odooName: 'pricelist_id')  int pricelistId, @OdooMany2One('product.template', odooName: 'product_tmpl_id')  int? productTmplId, @OdooMany2One('product.product', odooName: 'product_id')  int? productId, @OdooMany2One('product.category', odooName: 'categ_id')  int? categId, @OdooSelection()  String appliedOn, @OdooFloat()  double minQuantity, @OdooDateTime()  DateTime? dateStart, @OdooDateTime()  DateTime? dateEnd, @OdooSelection()  String computePrice, @OdooFloat()  double fixedPrice, @OdooFloat()  double percentPrice,  int sequence, @OdooLocalOnly()  int? uomId, @OdooSelection()  String base, @OdooMany2One('product.pricelist', odooName: 'base_pricelist_id')  int? basePricelistId, @OdooFloat()  double priceDiscount, @OdooFloat()  double priceSurcharge, @OdooFloat()  double priceRound, @OdooFloat()  double priceMinMargin, @OdooFloat()  double priceMaxMargin, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)?  $default,) {final _that = this;
switch (_that) {
case _PricelistItem() when $default != null:
return $default(_that.id,_that.pricelistId,_that.productTmplId,_that.productId,_that.categId,_that.appliedOn,_that.minQuantity,_that.dateStart,_that.dateEnd,_that.computePrice,_that.fixedPrice,_that.percentPrice,_that.sequence,_that.uomId,_that.base,_that.basePricelistId,_that.priceDiscount,_that.priceSurcharge,_that.priceRound,_that.priceMinMargin,_that.priceMaxMargin,_that.writeDate);case _:
  return null;

}
}

}

/// @nodoc


class _PricelistItem extends PricelistItem {
  const _PricelistItem({@OdooId() required this.id, @OdooMany2One('product.pricelist', odooName: 'pricelist_id') required this.pricelistId, @OdooMany2One('product.template', odooName: 'product_tmpl_id') this.productTmplId, @OdooMany2One('product.product', odooName: 'product_id') this.productId, @OdooMany2One('product.category', odooName: 'categ_id') this.categId, @OdooSelection() this.appliedOn = '3_global', @OdooFloat() this.minQuantity = 0.0, @OdooDateTime() this.dateStart, @OdooDateTime() this.dateEnd, @OdooSelection() this.computePrice = 'fixed', @OdooFloat() this.fixedPrice = 0.0, @OdooFloat() this.percentPrice = 0.0, this.sequence = 5, @OdooLocalOnly() this.uomId, @OdooSelection() this.base = 'list_price', @OdooMany2One('product.pricelist', odooName: 'base_pricelist_id') this.basePricelistId, @OdooFloat() this.priceDiscount = 0.0, @OdooFloat() this.priceSurcharge = 0.0, @OdooFloat() this.priceRound = 0.0, @OdooFloat() this.priceMinMargin = 0.0, @OdooFloat() this.priceMaxMargin = 0.0, @OdooDateTime(odooName: 'write_date', writable: false) this.writeDate}): super._();
  

@override@OdooId() final  int id;
@override@OdooMany2One('product.pricelist', odooName: 'pricelist_id') final  int pricelistId;
@override@OdooMany2One('product.template', odooName: 'product_tmpl_id') final  int? productTmplId;
@override@OdooMany2One('product.product', odooName: 'product_id') final  int? productId;
@override@OdooMany2One('product.category', odooName: 'categ_id') final  int? categId;
@override@JsonKey()@OdooSelection() final  String appliedOn;
@override@JsonKey()@OdooFloat() final  double minQuantity;
@override@OdooDateTime() final  DateTime? dateStart;
@override@OdooDateTime() final  DateTime? dateEnd;
@override@JsonKey()@OdooSelection() final  String computePrice;
@override@JsonKey()@OdooFloat() final  double fixedPrice;
@override@JsonKey()@OdooFloat() final  double percentPrice;
@override@JsonKey() final  int sequence;
@override@OdooLocalOnly() final  int? uomId;
@override@JsonKey()@OdooSelection() final  String base;
@override@OdooMany2One('product.pricelist', odooName: 'base_pricelist_id') final  int? basePricelistId;
@override@JsonKey()@OdooFloat() final  double priceDiscount;
@override@JsonKey()@OdooFloat() final  double priceSurcharge;
@override@JsonKey()@OdooFloat() final  double priceRound;
@override@JsonKey()@OdooFloat() final  double priceMinMargin;
@override@JsonKey()@OdooFloat() final  double priceMaxMargin;
@override@OdooDateTime(odooName: 'write_date', writable: false) final  DateTime? writeDate;

/// Create a copy of PricelistItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PricelistItemCopyWith<_PricelistItem> get copyWith => __$PricelistItemCopyWithImpl<_PricelistItem>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PricelistItem&&(identical(other.id, id) || other.id == id)&&(identical(other.pricelistId, pricelistId) || other.pricelistId == pricelistId)&&(identical(other.productTmplId, productTmplId) || other.productTmplId == productTmplId)&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.categId, categId) || other.categId == categId)&&(identical(other.appliedOn, appliedOn) || other.appliedOn == appliedOn)&&(identical(other.minQuantity, minQuantity) || other.minQuantity == minQuantity)&&(identical(other.dateStart, dateStart) || other.dateStart == dateStart)&&(identical(other.dateEnd, dateEnd) || other.dateEnd == dateEnd)&&(identical(other.computePrice, computePrice) || other.computePrice == computePrice)&&(identical(other.fixedPrice, fixedPrice) || other.fixedPrice == fixedPrice)&&(identical(other.percentPrice, percentPrice) || other.percentPrice == percentPrice)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.uomId, uomId) || other.uomId == uomId)&&(identical(other.base, base) || other.base == base)&&(identical(other.basePricelistId, basePricelistId) || other.basePricelistId == basePricelistId)&&(identical(other.priceDiscount, priceDiscount) || other.priceDiscount == priceDiscount)&&(identical(other.priceSurcharge, priceSurcharge) || other.priceSurcharge == priceSurcharge)&&(identical(other.priceRound, priceRound) || other.priceRound == priceRound)&&(identical(other.priceMinMargin, priceMinMargin) || other.priceMinMargin == priceMinMargin)&&(identical(other.priceMaxMargin, priceMaxMargin) || other.priceMaxMargin == priceMaxMargin)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,pricelistId,productTmplId,productId,categId,appliedOn,minQuantity,dateStart,dateEnd,computePrice,fixedPrice,percentPrice,sequence,uomId,base,basePricelistId,priceDiscount,priceSurcharge,priceRound,priceMinMargin,priceMaxMargin,writeDate]);

@override
String toString() {
  return 'PricelistItem(id: $id, pricelistId: $pricelistId, productTmplId: $productTmplId, productId: $productId, categId: $categId, appliedOn: $appliedOn, minQuantity: $minQuantity, dateStart: $dateStart, dateEnd: $dateEnd, computePrice: $computePrice, fixedPrice: $fixedPrice, percentPrice: $percentPrice, sequence: $sequence, uomId: $uomId, base: $base, basePricelistId: $basePricelistId, priceDiscount: $priceDiscount, priceSurcharge: $priceSurcharge, priceRound: $priceRound, priceMinMargin: $priceMinMargin, priceMaxMargin: $priceMaxMargin, writeDate: $writeDate)';
}


}

/// @nodoc
abstract mixin class _$PricelistItemCopyWith<$Res> implements $PricelistItemCopyWith<$Res> {
  factory _$PricelistItemCopyWith(_PricelistItem value, $Res Function(_PricelistItem) _then) = __$PricelistItemCopyWithImpl;
@override @useResult
$Res call({
@OdooId() int id,@OdooMany2One('product.pricelist', odooName: 'pricelist_id') int pricelistId,@OdooMany2One('product.template', odooName: 'product_tmpl_id') int? productTmplId,@OdooMany2One('product.product', odooName: 'product_id') int? productId,@OdooMany2One('product.category', odooName: 'categ_id') int? categId,@OdooSelection() String appliedOn,@OdooFloat() double minQuantity,@OdooDateTime() DateTime? dateStart,@OdooDateTime() DateTime? dateEnd,@OdooSelection() String computePrice,@OdooFloat() double fixedPrice,@OdooFloat() double percentPrice, int sequence,@OdooLocalOnly() int? uomId,@OdooSelection() String base,@OdooMany2One('product.pricelist', odooName: 'base_pricelist_id') int? basePricelistId,@OdooFloat() double priceDiscount,@OdooFloat() double priceSurcharge,@OdooFloat() double priceRound,@OdooFloat() double priceMinMargin,@OdooFloat() double priceMaxMargin,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate
});




}
/// @nodoc
class __$PricelistItemCopyWithImpl<$Res>
    implements _$PricelistItemCopyWith<$Res> {
  __$PricelistItemCopyWithImpl(this._self, this._then);

  final _PricelistItem _self;
  final $Res Function(_PricelistItem) _then;

/// Create a copy of PricelistItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? pricelistId = null,Object? productTmplId = freezed,Object? productId = freezed,Object? categId = freezed,Object? appliedOn = null,Object? minQuantity = null,Object? dateStart = freezed,Object? dateEnd = freezed,Object? computePrice = null,Object? fixedPrice = null,Object? percentPrice = null,Object? sequence = null,Object? uomId = freezed,Object? base = null,Object? basePricelistId = freezed,Object? priceDiscount = null,Object? priceSurcharge = null,Object? priceRound = null,Object? priceMinMargin = null,Object? priceMaxMargin = null,Object? writeDate = freezed,}) {
  return _then(_PricelistItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,pricelistId: null == pricelistId ? _self.pricelistId : pricelistId // ignore: cast_nullable_to_non_nullable
as int,productTmplId: freezed == productTmplId ? _self.productTmplId : productTmplId // ignore: cast_nullable_to_non_nullable
as int?,productId: freezed == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as int?,categId: freezed == categId ? _self.categId : categId // ignore: cast_nullable_to_non_nullable
as int?,appliedOn: null == appliedOn ? _self.appliedOn : appliedOn // ignore: cast_nullable_to_non_nullable
as String,minQuantity: null == minQuantity ? _self.minQuantity : minQuantity // ignore: cast_nullable_to_non_nullable
as double,dateStart: freezed == dateStart ? _self.dateStart : dateStart // ignore: cast_nullable_to_non_nullable
as DateTime?,dateEnd: freezed == dateEnd ? _self.dateEnd : dateEnd // ignore: cast_nullable_to_non_nullable
as DateTime?,computePrice: null == computePrice ? _self.computePrice : computePrice // ignore: cast_nullable_to_non_nullable
as String,fixedPrice: null == fixedPrice ? _self.fixedPrice : fixedPrice // ignore: cast_nullable_to_non_nullable
as double,percentPrice: null == percentPrice ? _self.percentPrice : percentPrice // ignore: cast_nullable_to_non_nullable
as double,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,uomId: freezed == uomId ? _self.uomId : uomId // ignore: cast_nullable_to_non_nullable
as int?,base: null == base ? _self.base : base // ignore: cast_nullable_to_non_nullable
as String,basePricelistId: freezed == basePricelistId ? _self.basePricelistId : basePricelistId // ignore: cast_nullable_to_non_nullable
as int?,priceDiscount: null == priceDiscount ? _self.priceDiscount : priceDiscount // ignore: cast_nullable_to_non_nullable
as double,priceSurcharge: null == priceSurcharge ? _self.priceSurcharge : priceSurcharge // ignore: cast_nullable_to_non_nullable
as double,priceRound: null == priceRound ? _self.priceRound : priceRound // ignore: cast_nullable_to_non_nullable
as double,priceMinMargin: null == priceMinMargin ? _self.priceMinMargin : priceMinMargin // ignore: cast_nullable_to_non_nullable
as double,priceMaxMargin: null == priceMaxMargin ? _self.priceMaxMargin : priceMaxMargin // ignore: cast_nullable_to_non_nullable
as double,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
