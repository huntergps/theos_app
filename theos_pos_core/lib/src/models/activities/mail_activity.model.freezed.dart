// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mail_activity.model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MailActivity {

@OdooId() int get id;@OdooInteger(odooName: 'res_id') int get resId;@OdooString(odooName: 'res_model') String get resModel;@OdooString(odooName: 'res_name') String? get resName;@OdooString() String? get summary;@OdooString() String? get note;@OdooMany2One('mail.activity.type', odooName: 'activity_type_id') int? get activityTypeId;@OdooMany2OneName(sourceField: 'activity_type_id') String? get activityTypeName;@OdooMany2One('res.users', odooName: 'user_id') int? get userId;@OdooMany2OneName(sourceField: 'user_id') String? get userName;@OdooDate(odooName: 'date_deadline') DateTime get dateDeadline;@OdooString() String get state;@OdooString() String? get icon;@OdooBoolean(odooName: 'can_write') bool get canWrite;@OdooDateTime(odooName: 'create_date', writable: false) DateTime? get createDate;@OdooDateTime(odooName: 'write_date', writable: false) DateTime? get writeDate;
/// Create a copy of MailActivity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MailActivityCopyWith<MailActivity> get copyWith => _$MailActivityCopyWithImpl<MailActivity>(this as MailActivity, _$identity);

  /// Serializes this MailActivity to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MailActivity&&(identical(other.id, id) || other.id == id)&&(identical(other.resId, resId) || other.resId == resId)&&(identical(other.resModel, resModel) || other.resModel == resModel)&&(identical(other.resName, resName) || other.resName == resName)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.note, note) || other.note == note)&&(identical(other.activityTypeId, activityTypeId) || other.activityTypeId == activityTypeId)&&(identical(other.activityTypeName, activityTypeName) || other.activityTypeName == activityTypeName)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.userName, userName) || other.userName == userName)&&(identical(other.dateDeadline, dateDeadline) || other.dateDeadline == dateDeadline)&&(identical(other.state, state) || other.state == state)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.canWrite, canWrite) || other.canWrite == canWrite)&&(identical(other.createDate, createDate) || other.createDate == createDate)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,resId,resModel,resName,summary,note,activityTypeId,activityTypeName,userId,userName,dateDeadline,state,icon,canWrite,createDate,writeDate);

@override
String toString() {
  return 'MailActivity(id: $id, resId: $resId, resModel: $resModel, resName: $resName, summary: $summary, note: $note, activityTypeId: $activityTypeId, activityTypeName: $activityTypeName, userId: $userId, userName: $userName, dateDeadline: $dateDeadline, state: $state, icon: $icon, canWrite: $canWrite, createDate: $createDate, writeDate: $writeDate)';
}


}

/// @nodoc
abstract mixin class $MailActivityCopyWith<$Res>  {
  factory $MailActivityCopyWith(MailActivity value, $Res Function(MailActivity) _then) = _$MailActivityCopyWithImpl;
@useResult
$Res call({
@OdooId() int id,@OdooInteger(odooName: 'res_id') int resId,@OdooString(odooName: 'res_model') String resModel,@OdooString(odooName: 'res_name') String? resName,@OdooString() String? summary,@OdooString() String? note,@OdooMany2One('mail.activity.type', odooName: 'activity_type_id') int? activityTypeId,@OdooMany2OneName(sourceField: 'activity_type_id') String? activityTypeName,@OdooMany2One('res.users', odooName: 'user_id') int? userId,@OdooMany2OneName(sourceField: 'user_id') String? userName,@OdooDate(odooName: 'date_deadline') DateTime dateDeadline,@OdooString() String state,@OdooString() String? icon,@OdooBoolean(odooName: 'can_write') bool canWrite,@OdooDateTime(odooName: 'create_date', writable: false) DateTime? createDate,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate
});




}
/// @nodoc
class _$MailActivityCopyWithImpl<$Res>
    implements $MailActivityCopyWith<$Res> {
  _$MailActivityCopyWithImpl(this._self, this._then);

  final MailActivity _self;
  final $Res Function(MailActivity) _then;

/// Create a copy of MailActivity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? resId = null,Object? resModel = null,Object? resName = freezed,Object? summary = freezed,Object? note = freezed,Object? activityTypeId = freezed,Object? activityTypeName = freezed,Object? userId = freezed,Object? userName = freezed,Object? dateDeadline = null,Object? state = null,Object? icon = freezed,Object? canWrite = null,Object? createDate = freezed,Object? writeDate = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,resId: null == resId ? _self.resId : resId // ignore: cast_nullable_to_non_nullable
as int,resModel: null == resModel ? _self.resModel : resModel // ignore: cast_nullable_to_non_nullable
as String,resName: freezed == resName ? _self.resName : resName // ignore: cast_nullable_to_non_nullable
as String?,summary: freezed == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,activityTypeId: freezed == activityTypeId ? _self.activityTypeId : activityTypeId // ignore: cast_nullable_to_non_nullable
as int?,activityTypeName: freezed == activityTypeName ? _self.activityTypeName : activityTypeName // ignore: cast_nullable_to_non_nullable
as String?,userId: freezed == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int?,userName: freezed == userName ? _self.userName : userName // ignore: cast_nullable_to_non_nullable
as String?,dateDeadline: null == dateDeadline ? _self.dateDeadline : dateDeadline // ignore: cast_nullable_to_non_nullable
as DateTime,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,icon: freezed == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String?,canWrite: null == canWrite ? _self.canWrite : canWrite // ignore: cast_nullable_to_non_nullable
as bool,createDate: freezed == createDate ? _self.createDate : createDate // ignore: cast_nullable_to_non_nullable
as DateTime?,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [MailActivity].
extension MailActivityPatterns on MailActivity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MailActivity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MailActivity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MailActivity value)  $default,){
final _that = this;
switch (_that) {
case _MailActivity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MailActivity value)?  $default,){
final _that = this;
switch (_that) {
case _MailActivity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooInteger(odooName: 'res_id')  int resId, @OdooString(odooName: 'res_model')  String resModel, @OdooString(odooName: 'res_name')  String? resName, @OdooString()  String? summary, @OdooString()  String? note, @OdooMany2One('mail.activity.type', odooName: 'activity_type_id')  int? activityTypeId, @OdooMany2OneName(sourceField: 'activity_type_id')  String? activityTypeName, @OdooMany2One('res.users', odooName: 'user_id')  int? userId, @OdooMany2OneName(sourceField: 'user_id')  String? userName, @OdooDate(odooName: 'date_deadline')  DateTime dateDeadline, @OdooString()  String state, @OdooString()  String? icon, @OdooBoolean(odooName: 'can_write')  bool canWrite, @OdooDateTime(odooName: 'create_date', writable: false)  DateTime? createDate, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MailActivity() when $default != null:
return $default(_that.id,_that.resId,_that.resModel,_that.resName,_that.summary,_that.note,_that.activityTypeId,_that.activityTypeName,_that.userId,_that.userName,_that.dateDeadline,_that.state,_that.icon,_that.canWrite,_that.createDate,_that.writeDate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooInteger(odooName: 'res_id')  int resId, @OdooString(odooName: 'res_model')  String resModel, @OdooString(odooName: 'res_name')  String? resName, @OdooString()  String? summary, @OdooString()  String? note, @OdooMany2One('mail.activity.type', odooName: 'activity_type_id')  int? activityTypeId, @OdooMany2OneName(sourceField: 'activity_type_id')  String? activityTypeName, @OdooMany2One('res.users', odooName: 'user_id')  int? userId, @OdooMany2OneName(sourceField: 'user_id')  String? userName, @OdooDate(odooName: 'date_deadline')  DateTime dateDeadline, @OdooString()  String state, @OdooString()  String? icon, @OdooBoolean(odooName: 'can_write')  bool canWrite, @OdooDateTime(odooName: 'create_date', writable: false)  DateTime? createDate, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)  $default,) {final _that = this;
switch (_that) {
case _MailActivity():
return $default(_that.id,_that.resId,_that.resModel,_that.resName,_that.summary,_that.note,_that.activityTypeId,_that.activityTypeName,_that.userId,_that.userName,_that.dateDeadline,_that.state,_that.icon,_that.canWrite,_that.createDate,_that.writeDate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@OdooId()  int id, @OdooInteger(odooName: 'res_id')  int resId, @OdooString(odooName: 'res_model')  String resModel, @OdooString(odooName: 'res_name')  String? resName, @OdooString()  String? summary, @OdooString()  String? note, @OdooMany2One('mail.activity.type', odooName: 'activity_type_id')  int? activityTypeId, @OdooMany2OneName(sourceField: 'activity_type_id')  String? activityTypeName, @OdooMany2One('res.users', odooName: 'user_id')  int? userId, @OdooMany2OneName(sourceField: 'user_id')  String? userName, @OdooDate(odooName: 'date_deadline')  DateTime dateDeadline, @OdooString()  String state, @OdooString()  String? icon, @OdooBoolean(odooName: 'can_write')  bool canWrite, @OdooDateTime(odooName: 'create_date', writable: false)  DateTime? createDate, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)?  $default,) {final _that = this;
switch (_that) {
case _MailActivity() when $default != null:
return $default(_that.id,_that.resId,_that.resModel,_that.resName,_that.summary,_that.note,_that.activityTypeId,_that.activityTypeName,_that.userId,_that.userName,_that.dateDeadline,_that.state,_that.icon,_that.canWrite,_that.createDate,_that.writeDate);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MailActivity extends MailActivity {
  const _MailActivity({@OdooId() required this.id, @OdooInteger(odooName: 'res_id') required this.resId, @OdooString(odooName: 'res_model') required this.resModel, @OdooString(odooName: 'res_name') this.resName, @OdooString() this.summary, @OdooString() this.note, @OdooMany2One('mail.activity.type', odooName: 'activity_type_id') this.activityTypeId, @OdooMany2OneName(sourceField: 'activity_type_id') this.activityTypeName, @OdooMany2One('res.users', odooName: 'user_id') this.userId, @OdooMany2OneName(sourceField: 'user_id') this.userName, @OdooDate(odooName: 'date_deadline') required this.dateDeadline, @OdooString() required this.state, @OdooString() this.icon, @OdooBoolean(odooName: 'can_write') this.canWrite = true, @OdooDateTime(odooName: 'create_date', writable: false) this.createDate, @OdooDateTime(odooName: 'write_date', writable: false) this.writeDate}): super._();
  factory _MailActivity.fromJson(Map<String, dynamic> json) => _$MailActivityFromJson(json);

@override@OdooId() final  int id;
@override@OdooInteger(odooName: 'res_id') final  int resId;
@override@OdooString(odooName: 'res_model') final  String resModel;
@override@OdooString(odooName: 'res_name') final  String? resName;
@override@OdooString() final  String? summary;
@override@OdooString() final  String? note;
@override@OdooMany2One('mail.activity.type', odooName: 'activity_type_id') final  int? activityTypeId;
@override@OdooMany2OneName(sourceField: 'activity_type_id') final  String? activityTypeName;
@override@OdooMany2One('res.users', odooName: 'user_id') final  int? userId;
@override@OdooMany2OneName(sourceField: 'user_id') final  String? userName;
@override@OdooDate(odooName: 'date_deadline') final  DateTime dateDeadline;
@override@OdooString() final  String state;
@override@OdooString() final  String? icon;
@override@JsonKey()@OdooBoolean(odooName: 'can_write') final  bool canWrite;
@override@OdooDateTime(odooName: 'create_date', writable: false) final  DateTime? createDate;
@override@OdooDateTime(odooName: 'write_date', writable: false) final  DateTime? writeDate;

/// Create a copy of MailActivity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MailActivityCopyWith<_MailActivity> get copyWith => __$MailActivityCopyWithImpl<_MailActivity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MailActivityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MailActivity&&(identical(other.id, id) || other.id == id)&&(identical(other.resId, resId) || other.resId == resId)&&(identical(other.resModel, resModel) || other.resModel == resModel)&&(identical(other.resName, resName) || other.resName == resName)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.note, note) || other.note == note)&&(identical(other.activityTypeId, activityTypeId) || other.activityTypeId == activityTypeId)&&(identical(other.activityTypeName, activityTypeName) || other.activityTypeName == activityTypeName)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.userName, userName) || other.userName == userName)&&(identical(other.dateDeadline, dateDeadline) || other.dateDeadline == dateDeadline)&&(identical(other.state, state) || other.state == state)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.canWrite, canWrite) || other.canWrite == canWrite)&&(identical(other.createDate, createDate) || other.createDate == createDate)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,resId,resModel,resName,summary,note,activityTypeId,activityTypeName,userId,userName,dateDeadline,state,icon,canWrite,createDate,writeDate);

@override
String toString() {
  return 'MailActivity(id: $id, resId: $resId, resModel: $resModel, resName: $resName, summary: $summary, note: $note, activityTypeId: $activityTypeId, activityTypeName: $activityTypeName, userId: $userId, userName: $userName, dateDeadline: $dateDeadline, state: $state, icon: $icon, canWrite: $canWrite, createDate: $createDate, writeDate: $writeDate)';
}


}

/// @nodoc
abstract mixin class _$MailActivityCopyWith<$Res> implements $MailActivityCopyWith<$Res> {
  factory _$MailActivityCopyWith(_MailActivity value, $Res Function(_MailActivity) _then) = __$MailActivityCopyWithImpl;
@override @useResult
$Res call({
@OdooId() int id,@OdooInteger(odooName: 'res_id') int resId,@OdooString(odooName: 'res_model') String resModel,@OdooString(odooName: 'res_name') String? resName,@OdooString() String? summary,@OdooString() String? note,@OdooMany2One('mail.activity.type', odooName: 'activity_type_id') int? activityTypeId,@OdooMany2OneName(sourceField: 'activity_type_id') String? activityTypeName,@OdooMany2One('res.users', odooName: 'user_id') int? userId,@OdooMany2OneName(sourceField: 'user_id') String? userName,@OdooDate(odooName: 'date_deadline') DateTime dateDeadline,@OdooString() String state,@OdooString() String? icon,@OdooBoolean(odooName: 'can_write') bool canWrite,@OdooDateTime(odooName: 'create_date', writable: false) DateTime? createDate,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate
});




}
/// @nodoc
class __$MailActivityCopyWithImpl<$Res>
    implements _$MailActivityCopyWith<$Res> {
  __$MailActivityCopyWithImpl(this._self, this._then);

  final _MailActivity _self;
  final $Res Function(_MailActivity) _then;

/// Create a copy of MailActivity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? resId = null,Object? resModel = null,Object? resName = freezed,Object? summary = freezed,Object? note = freezed,Object? activityTypeId = freezed,Object? activityTypeName = freezed,Object? userId = freezed,Object? userName = freezed,Object? dateDeadline = null,Object? state = null,Object? icon = freezed,Object? canWrite = null,Object? createDate = freezed,Object? writeDate = freezed,}) {
  return _then(_MailActivity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,resId: null == resId ? _self.resId : resId // ignore: cast_nullable_to_non_nullable
as int,resModel: null == resModel ? _self.resModel : resModel // ignore: cast_nullable_to_non_nullable
as String,resName: freezed == resName ? _self.resName : resName // ignore: cast_nullable_to_non_nullable
as String?,summary: freezed == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,activityTypeId: freezed == activityTypeId ? _self.activityTypeId : activityTypeId // ignore: cast_nullable_to_non_nullable
as int?,activityTypeName: freezed == activityTypeName ? _self.activityTypeName : activityTypeName // ignore: cast_nullable_to_non_nullable
as String?,userId: freezed == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int?,userName: freezed == userName ? _self.userName : userName // ignore: cast_nullable_to_non_nullable
as String?,dateDeadline: null == dateDeadline ? _self.dateDeadline : dateDeadline // ignore: cast_nullable_to_non_nullable
as DateTime,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,icon: freezed == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String?,canWrite: null == canWrite ? _self.canWrite : canWrite // ignore: cast_nullable_to_non_nullable
as bool,createDate: freezed == createDate ? _self.createDate : createDate // ignore: cast_nullable_to_non_nullable
as DateTime?,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
