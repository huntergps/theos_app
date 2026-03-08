// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sales_team.model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SalesTeam {

@OdooId() int get id;@OdooString() String get name;@OdooBoolean() bool get active;@OdooMany2One('res.company', odooName: 'company_id') int? get companyId;@OdooMany2OneName(sourceField: 'company_id') String? get companyName;@OdooMany2One('res.users', odooName: 'user_id') int? get userId;@OdooMany2OneName(sourceField: 'user_id') String? get userName;@OdooInteger() int get sequence;@OdooDateTime(odooName: 'write_date', writable: false) DateTime? get writeDate;
/// Create a copy of SalesTeam
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SalesTeamCopyWith<SalesTeam> get copyWith => _$SalesTeamCopyWithImpl<SalesTeam>(this as SalesTeam, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SalesTeam&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.active, active) || other.active == active)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&(identical(other.companyName, companyName) || other.companyName == companyName)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.userName, userName) || other.userName == userName)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,active,companyId,companyName,userId,userName,sequence,writeDate);

@override
String toString() {
  return 'SalesTeam(id: $id, name: $name, active: $active, companyId: $companyId, companyName: $companyName, userId: $userId, userName: $userName, sequence: $sequence, writeDate: $writeDate)';
}


}

/// @nodoc
abstract mixin class $SalesTeamCopyWith<$Res>  {
  factory $SalesTeamCopyWith(SalesTeam value, $Res Function(SalesTeam) _then) = _$SalesTeamCopyWithImpl;
@useResult
$Res call({
@OdooId() int id,@OdooString() String name,@OdooBoolean() bool active,@OdooMany2One('res.company', odooName: 'company_id') int? companyId,@OdooMany2OneName(sourceField: 'company_id') String? companyName,@OdooMany2One('res.users', odooName: 'user_id') int? userId,@OdooMany2OneName(sourceField: 'user_id') String? userName,@OdooInteger() int sequence,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate
});




}
/// @nodoc
class _$SalesTeamCopyWithImpl<$Res>
    implements $SalesTeamCopyWith<$Res> {
  _$SalesTeamCopyWithImpl(this._self, this._then);

  final SalesTeam _self;
  final $Res Function(SalesTeam) _then;

/// Create a copy of SalesTeam
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? active = null,Object? companyId = freezed,Object? companyName = freezed,Object? userId = freezed,Object? userName = freezed,Object? sequence = null,Object? writeDate = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,companyId: freezed == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as int?,companyName: freezed == companyName ? _self.companyName : companyName // ignore: cast_nullable_to_non_nullable
as String?,userId: freezed == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int?,userName: freezed == userName ? _self.userName : userName // ignore: cast_nullable_to_non_nullable
as String?,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [SalesTeam].
extension SalesTeamPatterns on SalesTeam {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SalesTeam value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SalesTeam() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SalesTeam value)  $default,){
final _that = this;
switch (_that) {
case _SalesTeam():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SalesTeam value)?  $default,){
final _that = this;
switch (_that) {
case _SalesTeam() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooString()  String name, @OdooBoolean()  bool active, @OdooMany2One('res.company', odooName: 'company_id')  int? companyId, @OdooMany2OneName(sourceField: 'company_id')  String? companyName, @OdooMany2One('res.users', odooName: 'user_id')  int? userId, @OdooMany2OneName(sourceField: 'user_id')  String? userName, @OdooInteger()  int sequence, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SalesTeam() when $default != null:
return $default(_that.id,_that.name,_that.active,_that.companyId,_that.companyName,_that.userId,_that.userName,_that.sequence,_that.writeDate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooString()  String name, @OdooBoolean()  bool active, @OdooMany2One('res.company', odooName: 'company_id')  int? companyId, @OdooMany2OneName(sourceField: 'company_id')  String? companyName, @OdooMany2One('res.users', odooName: 'user_id')  int? userId, @OdooMany2OneName(sourceField: 'user_id')  String? userName, @OdooInteger()  int sequence, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)  $default,) {final _that = this;
switch (_that) {
case _SalesTeam():
return $default(_that.id,_that.name,_that.active,_that.companyId,_that.companyName,_that.userId,_that.userName,_that.sequence,_that.writeDate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@OdooId()  int id, @OdooString()  String name, @OdooBoolean()  bool active, @OdooMany2One('res.company', odooName: 'company_id')  int? companyId, @OdooMany2OneName(sourceField: 'company_id')  String? companyName, @OdooMany2One('res.users', odooName: 'user_id')  int? userId, @OdooMany2OneName(sourceField: 'user_id')  String? userName, @OdooInteger()  int sequence, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)?  $default,) {final _that = this;
switch (_that) {
case _SalesTeam() when $default != null:
return $default(_that.id,_that.name,_that.active,_that.companyId,_that.companyName,_that.userId,_that.userName,_that.sequence,_that.writeDate);case _:
  return null;

}
}

}

/// @nodoc


class _SalesTeam extends SalesTeam {
  const _SalesTeam({@OdooId() required this.id, @OdooString() required this.name, @OdooBoolean() this.active = true, @OdooMany2One('res.company', odooName: 'company_id') this.companyId, @OdooMany2OneName(sourceField: 'company_id') this.companyName, @OdooMany2One('res.users', odooName: 'user_id') this.userId, @OdooMany2OneName(sourceField: 'user_id') this.userName, @OdooInteger() this.sequence = 10, @OdooDateTime(odooName: 'write_date', writable: false) this.writeDate}): super._();
  

@override@OdooId() final  int id;
@override@OdooString() final  String name;
@override@JsonKey()@OdooBoolean() final  bool active;
@override@OdooMany2One('res.company', odooName: 'company_id') final  int? companyId;
@override@OdooMany2OneName(sourceField: 'company_id') final  String? companyName;
@override@OdooMany2One('res.users', odooName: 'user_id') final  int? userId;
@override@OdooMany2OneName(sourceField: 'user_id') final  String? userName;
@override@JsonKey()@OdooInteger() final  int sequence;
@override@OdooDateTime(odooName: 'write_date', writable: false) final  DateTime? writeDate;

/// Create a copy of SalesTeam
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SalesTeamCopyWith<_SalesTeam> get copyWith => __$SalesTeamCopyWithImpl<_SalesTeam>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SalesTeam&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.active, active) || other.active == active)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&(identical(other.companyName, companyName) || other.companyName == companyName)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.userName, userName) || other.userName == userName)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,active,companyId,companyName,userId,userName,sequence,writeDate);

@override
String toString() {
  return 'SalesTeam(id: $id, name: $name, active: $active, companyId: $companyId, companyName: $companyName, userId: $userId, userName: $userName, sequence: $sequence, writeDate: $writeDate)';
}


}

/// @nodoc
abstract mixin class _$SalesTeamCopyWith<$Res> implements $SalesTeamCopyWith<$Res> {
  factory _$SalesTeamCopyWith(_SalesTeam value, $Res Function(_SalesTeam) _then) = __$SalesTeamCopyWithImpl;
@override @useResult
$Res call({
@OdooId() int id,@OdooString() String name,@OdooBoolean() bool active,@OdooMany2One('res.company', odooName: 'company_id') int? companyId,@OdooMany2OneName(sourceField: 'company_id') String? companyName,@OdooMany2One('res.users', odooName: 'user_id') int? userId,@OdooMany2OneName(sourceField: 'user_id') String? userName,@OdooInteger() int sequence,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate
});




}
/// @nodoc
class __$SalesTeamCopyWithImpl<$Res>
    implements _$SalesTeamCopyWith<$Res> {
  __$SalesTeamCopyWithImpl(this._self, this._then);

  final _SalesTeam _self;
  final $Res Function(_SalesTeam) _then;

/// Create a copy of SalesTeam
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? active = null,Object? companyId = freezed,Object? companyName = freezed,Object? userId = freezed,Object? userName = freezed,Object? sequence = null,Object? writeDate = freezed,}) {
  return _then(_SalesTeam(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,companyId: freezed == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as int?,companyName: freezed == companyName ? _self.companyName : companyName // ignore: cast_nullable_to_non_nullable
as String?,userId: freezed == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int?,userName: freezed == userName ? _self.userName : userName // ignore: cast_nullable_to_non_nullable
as String?,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
