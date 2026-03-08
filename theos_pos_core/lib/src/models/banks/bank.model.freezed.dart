// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bank.model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Bank {

@OdooId() int get id;@OdooString() String get name;@OdooString() String? get bic;@OdooMany2One('res.country', odooName: 'country') int? get countryId;@OdooBoolean() bool get active;@OdooDateTime(odooName: 'write_date', writable: false) DateTime? get writeDate;
/// Create a copy of Bank
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BankCopyWith<Bank> get copyWith => _$BankCopyWithImpl<Bank>(this as Bank, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Bank&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.bic, bic) || other.bic == bic)&&(identical(other.countryId, countryId) || other.countryId == countryId)&&(identical(other.active, active) || other.active == active)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,bic,countryId,active,writeDate);

@override
String toString() {
  return 'Bank(id: $id, name: $name, bic: $bic, countryId: $countryId, active: $active, writeDate: $writeDate)';
}


}

/// @nodoc
abstract mixin class $BankCopyWith<$Res>  {
  factory $BankCopyWith(Bank value, $Res Function(Bank) _then) = _$BankCopyWithImpl;
@useResult
$Res call({
@OdooId() int id,@OdooString() String name,@OdooString() String? bic,@OdooMany2One('res.country', odooName: 'country') int? countryId,@OdooBoolean() bool active,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate
});




}
/// @nodoc
class _$BankCopyWithImpl<$Res>
    implements $BankCopyWith<$Res> {
  _$BankCopyWithImpl(this._self, this._then);

  final Bank _self;
  final $Res Function(Bank) _then;

/// Create a copy of Bank
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? bic = freezed,Object? countryId = freezed,Object? active = null,Object? writeDate = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,bic: freezed == bic ? _self.bic : bic // ignore: cast_nullable_to_non_nullable
as String?,countryId: freezed == countryId ? _self.countryId : countryId // ignore: cast_nullable_to_non_nullable
as int?,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Bank].
extension BankPatterns on Bank {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Bank value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Bank() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Bank value)  $default,){
final _that = this;
switch (_that) {
case _Bank():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Bank value)?  $default,){
final _that = this;
switch (_that) {
case _Bank() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooString()  String name, @OdooString()  String? bic, @OdooMany2One('res.country', odooName: 'country')  int? countryId, @OdooBoolean()  bool active, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Bank() when $default != null:
return $default(_that.id,_that.name,_that.bic,_that.countryId,_that.active,_that.writeDate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooString()  String name, @OdooString()  String? bic, @OdooMany2One('res.country', odooName: 'country')  int? countryId, @OdooBoolean()  bool active, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)  $default,) {final _that = this;
switch (_that) {
case _Bank():
return $default(_that.id,_that.name,_that.bic,_that.countryId,_that.active,_that.writeDate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@OdooId()  int id, @OdooString()  String name, @OdooString()  String? bic, @OdooMany2One('res.country', odooName: 'country')  int? countryId, @OdooBoolean()  bool active, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)?  $default,) {final _that = this;
switch (_that) {
case _Bank() when $default != null:
return $default(_that.id,_that.name,_that.bic,_that.countryId,_that.active,_that.writeDate);case _:
  return null;

}
}

}

/// @nodoc


class _Bank extends Bank {
  const _Bank({@OdooId() required this.id, @OdooString() required this.name, @OdooString() this.bic, @OdooMany2One('res.country', odooName: 'country') this.countryId, @OdooBoolean() this.active = true, @OdooDateTime(odooName: 'write_date', writable: false) this.writeDate}): super._();
  

@override@OdooId() final  int id;
@override@OdooString() final  String name;
@override@OdooString() final  String? bic;
@override@OdooMany2One('res.country', odooName: 'country') final  int? countryId;
@override@JsonKey()@OdooBoolean() final  bool active;
@override@OdooDateTime(odooName: 'write_date', writable: false) final  DateTime? writeDate;

/// Create a copy of Bank
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BankCopyWith<_Bank> get copyWith => __$BankCopyWithImpl<_Bank>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Bank&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.bic, bic) || other.bic == bic)&&(identical(other.countryId, countryId) || other.countryId == countryId)&&(identical(other.active, active) || other.active == active)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,bic,countryId,active,writeDate);

@override
String toString() {
  return 'Bank(id: $id, name: $name, bic: $bic, countryId: $countryId, active: $active, writeDate: $writeDate)';
}


}

/// @nodoc
abstract mixin class _$BankCopyWith<$Res> implements $BankCopyWith<$Res> {
  factory _$BankCopyWith(_Bank value, $Res Function(_Bank) _then) = __$BankCopyWithImpl;
@override @useResult
$Res call({
@OdooId() int id,@OdooString() String name,@OdooString() String? bic,@OdooMany2One('res.country', odooName: 'country') int? countryId,@OdooBoolean() bool active,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate
});




}
/// @nodoc
class __$BankCopyWithImpl<$Res>
    implements _$BankCopyWith<$Res> {
  __$BankCopyWithImpl(this._self, this._then);

  final _Bank _self;
  final $Res Function(_Bank) _then;

/// Create a copy of Bank
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? bic = freezed,Object? countryId = freezed,Object? active = null,Object? writeDate = freezed,}) {
  return _then(_Bank(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,bic: freezed == bic ? _self.bic : bic // ignore: cast_nullable_to_non_nullable
as String?,countryId: freezed == countryId ? _self.countryId : countryId // ignore: cast_nullable_to_non_nullable
as int?,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
mixin _$PartnerBank {

@OdooId() int get id;@OdooMany2One('res.partner', odooName: 'partner_id') int get partnerId;@OdooMany2One('res.bank', odooName: 'bank_id') int? get bankId;@OdooString(odooName: 'acc_number') String get accNumber;@OdooDateTime(odooName: 'write_date', writable: false) DateTime? get writeDate;
/// Create a copy of PartnerBank
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PartnerBankCopyWith<PartnerBank> get copyWith => _$PartnerBankCopyWithImpl<PartnerBank>(this as PartnerBank, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PartnerBank&&(identical(other.id, id) || other.id == id)&&(identical(other.partnerId, partnerId) || other.partnerId == partnerId)&&(identical(other.bankId, bankId) || other.bankId == bankId)&&(identical(other.accNumber, accNumber) || other.accNumber == accNumber)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate));
}


@override
int get hashCode => Object.hash(runtimeType,id,partnerId,bankId,accNumber,writeDate);

@override
String toString() {
  return 'PartnerBank(id: $id, partnerId: $partnerId, bankId: $bankId, accNumber: $accNumber, writeDate: $writeDate)';
}


}

/// @nodoc
abstract mixin class $PartnerBankCopyWith<$Res>  {
  factory $PartnerBankCopyWith(PartnerBank value, $Res Function(PartnerBank) _then) = _$PartnerBankCopyWithImpl;
@useResult
$Res call({
@OdooId() int id,@OdooMany2One('res.partner', odooName: 'partner_id') int partnerId,@OdooMany2One('res.bank', odooName: 'bank_id') int? bankId,@OdooString(odooName: 'acc_number') String accNumber,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate
});




}
/// @nodoc
class _$PartnerBankCopyWithImpl<$Res>
    implements $PartnerBankCopyWith<$Res> {
  _$PartnerBankCopyWithImpl(this._self, this._then);

  final PartnerBank _self;
  final $Res Function(PartnerBank) _then;

/// Create a copy of PartnerBank
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? partnerId = null,Object? bankId = freezed,Object? accNumber = null,Object? writeDate = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,partnerId: null == partnerId ? _self.partnerId : partnerId // ignore: cast_nullable_to_non_nullable
as int,bankId: freezed == bankId ? _self.bankId : bankId // ignore: cast_nullable_to_non_nullable
as int?,accNumber: null == accNumber ? _self.accNumber : accNumber // ignore: cast_nullable_to_non_nullable
as String,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [PartnerBank].
extension PartnerBankPatterns on PartnerBank {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PartnerBank value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PartnerBank() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PartnerBank value)  $default,){
final _that = this;
switch (_that) {
case _PartnerBank():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PartnerBank value)?  $default,){
final _that = this;
switch (_that) {
case _PartnerBank() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooMany2One('res.partner', odooName: 'partner_id')  int partnerId, @OdooMany2One('res.bank', odooName: 'bank_id')  int? bankId, @OdooString(odooName: 'acc_number')  String accNumber, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PartnerBank() when $default != null:
return $default(_that.id,_that.partnerId,_that.bankId,_that.accNumber,_that.writeDate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooMany2One('res.partner', odooName: 'partner_id')  int partnerId, @OdooMany2One('res.bank', odooName: 'bank_id')  int? bankId, @OdooString(odooName: 'acc_number')  String accNumber, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)  $default,) {final _that = this;
switch (_that) {
case _PartnerBank():
return $default(_that.id,_that.partnerId,_that.bankId,_that.accNumber,_that.writeDate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@OdooId()  int id, @OdooMany2One('res.partner', odooName: 'partner_id')  int partnerId, @OdooMany2One('res.bank', odooName: 'bank_id')  int? bankId, @OdooString(odooName: 'acc_number')  String accNumber, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)?  $default,) {final _that = this;
switch (_that) {
case _PartnerBank() when $default != null:
return $default(_that.id,_that.partnerId,_that.bankId,_that.accNumber,_that.writeDate);case _:
  return null;

}
}

}

/// @nodoc


class _PartnerBank extends PartnerBank {
  const _PartnerBank({@OdooId() required this.id, @OdooMany2One('res.partner', odooName: 'partner_id') required this.partnerId, @OdooMany2One('res.bank', odooName: 'bank_id') this.bankId, @OdooString(odooName: 'acc_number') required this.accNumber, @OdooDateTime(odooName: 'write_date', writable: false) this.writeDate}): super._();
  

@override@OdooId() final  int id;
@override@OdooMany2One('res.partner', odooName: 'partner_id') final  int partnerId;
@override@OdooMany2One('res.bank', odooName: 'bank_id') final  int? bankId;
@override@OdooString(odooName: 'acc_number') final  String accNumber;
@override@OdooDateTime(odooName: 'write_date', writable: false) final  DateTime? writeDate;

/// Create a copy of PartnerBank
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PartnerBankCopyWith<_PartnerBank> get copyWith => __$PartnerBankCopyWithImpl<_PartnerBank>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PartnerBank&&(identical(other.id, id) || other.id == id)&&(identical(other.partnerId, partnerId) || other.partnerId == partnerId)&&(identical(other.bankId, bankId) || other.bankId == bankId)&&(identical(other.accNumber, accNumber) || other.accNumber == accNumber)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate));
}


@override
int get hashCode => Object.hash(runtimeType,id,partnerId,bankId,accNumber,writeDate);

@override
String toString() {
  return 'PartnerBank(id: $id, partnerId: $partnerId, bankId: $bankId, accNumber: $accNumber, writeDate: $writeDate)';
}


}

/// @nodoc
abstract mixin class _$PartnerBankCopyWith<$Res> implements $PartnerBankCopyWith<$Res> {
  factory _$PartnerBankCopyWith(_PartnerBank value, $Res Function(_PartnerBank) _then) = __$PartnerBankCopyWithImpl;
@override @useResult
$Res call({
@OdooId() int id,@OdooMany2One('res.partner', odooName: 'partner_id') int partnerId,@OdooMany2One('res.bank', odooName: 'bank_id') int? bankId,@OdooString(odooName: 'acc_number') String accNumber,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate
});




}
/// @nodoc
class __$PartnerBankCopyWithImpl<$Res>
    implements _$PartnerBankCopyWith<$Res> {
  __$PartnerBankCopyWithImpl(this._self, this._then);

  final _PartnerBank _self;
  final $Res Function(_PartnerBank) _then;

/// Create a copy of PartnerBank
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? partnerId = null,Object? bankId = freezed,Object? accNumber = null,Object? writeDate = freezed,}) {
  return _then(_PartnerBank(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,partnerId: null == partnerId ? _self.partnerId : partnerId // ignore: cast_nullable_to_non_nullable
as int,bankId: freezed == bankId ? _self.bankId : bankId // ignore: cast_nullable_to_non_nullable
as int?,accNumber: null == accNumber ? _self.accNumber : accNumber // ignore: cast_nullable_to_non_nullable
as String,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
