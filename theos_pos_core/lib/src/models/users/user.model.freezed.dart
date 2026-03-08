// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user.model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$User {

@OdooId() int get id;@OdooString() String get name;@OdooString() String get login;@OdooString() String? get email;@OdooString() String? get lang;@OdooString() String? get tz;@OdooString() String? get signature;@OdooMany2One('res.partner', odooName: 'partner_id') int? get partnerId;@OdooMany2OneName(sourceField: 'partner_id') String? get partnerName;@OdooMany2One('res.company', odooName: 'company_id') int? get companyId;@OdooMany2OneName(sourceField: 'company_id') String? get companyName;@OdooMany2One('stock.warehouse', odooName: 'property_warehouse_id') int? get warehouseId;@OdooMany2OneName(sourceField: 'property_warehouse_id') String? get warehouseName;@OdooString(odooName: 'avatar_128') String? get avatar128;@OdooString(odooName: 'notification_type') String? get notificationType;@OdooString(odooName: 'work_email') String? get workEmail;@OdooString(odooName: 'work_phone') String? get workPhone;@OdooString(odooName: 'mobile_phone') String? get mobilePhone;@OdooLocalOnly() List<int> get groupIds;@OdooLocalOnly() List<String> get permissions;@OdooLocalOnly() bool get isCurrentUser;@OdooDateTime(odooName: 'write_date') DateTime? get writeDate;// Out of Office (modulo mail)
@OdooDateTime(odooName: 'out_of_office_from') DateTime? get outOfOfficeFrom;@OdooDateTime(odooName: 'out_of_office_to') DateTime? get outOfOfficeTo;@OdooString(odooName: 'out_of_office_message') String? get outOfOfficeMessage;// Calendar preferences
@OdooString(odooName: 'calendar_default_privacy') String? get calendarDefaultPrivacy;// Work location (modulo hr)
@OdooMany2One('hr.work.location', odooName: 'work_location_id') int? get workLocationId;@OdooMany2OneName(sourceField: 'work_location_id') String? get workLocationName;// Resource calendar / Work schedule
@OdooMany2One('resource.calendar', odooName: 'resource_calendar_id') int? get resourceCalendarId;@OdooMany2OneName(sourceField: 'resource_calendar_id') String? get resourceCalendarName;// PIN for attendance (modulo hr)
@OdooString() String? get pin;// Private information (modulo hr)
@OdooString(odooName: 'private_street') String? get privateStreet;@OdooString(odooName: 'private_street2') String? get privateStreet2;@OdooString(odooName: 'private_city') String? get privateCity;@OdooString(odooName: 'private_zip') String? get privateZip;@OdooMany2One('res.country.state', odooName: 'private_state_id') int? get privateStateId;@OdooMany2OneName(sourceField: 'private_state_id') String? get privateStateName;@OdooMany2One('res.country', odooName: 'private_country_id') int? get privateCountryId;@OdooMany2OneName(sourceField: 'private_country_id') String? get privateCountryName;@OdooString(odooName: 'private_email') String? get privateEmail;@OdooString(odooName: 'private_phone') String? get privatePhone;// Emergency contact (modulo hr)
@OdooString(odooName: 'emergency_contact') String? get emergencyContact;@OdooString(odooName: 'emergency_phone') String? get emergencyPhone;
/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserCopyWith<User> get copyWith => _$UserCopyWithImpl<User>(this as User, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is User&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.login, login) || other.login == login)&&(identical(other.email, email) || other.email == email)&&(identical(other.lang, lang) || other.lang == lang)&&(identical(other.tz, tz) || other.tz == tz)&&(identical(other.signature, signature) || other.signature == signature)&&(identical(other.partnerId, partnerId) || other.partnerId == partnerId)&&(identical(other.partnerName, partnerName) || other.partnerName == partnerName)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&(identical(other.companyName, companyName) || other.companyName == companyName)&&(identical(other.warehouseId, warehouseId) || other.warehouseId == warehouseId)&&(identical(other.warehouseName, warehouseName) || other.warehouseName == warehouseName)&&(identical(other.avatar128, avatar128) || other.avatar128 == avatar128)&&(identical(other.notificationType, notificationType) || other.notificationType == notificationType)&&(identical(other.workEmail, workEmail) || other.workEmail == workEmail)&&(identical(other.workPhone, workPhone) || other.workPhone == workPhone)&&(identical(other.mobilePhone, mobilePhone) || other.mobilePhone == mobilePhone)&&const DeepCollectionEquality().equals(other.groupIds, groupIds)&&const DeepCollectionEquality().equals(other.permissions, permissions)&&(identical(other.isCurrentUser, isCurrentUser) || other.isCurrentUser == isCurrentUser)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate)&&(identical(other.outOfOfficeFrom, outOfOfficeFrom) || other.outOfOfficeFrom == outOfOfficeFrom)&&(identical(other.outOfOfficeTo, outOfOfficeTo) || other.outOfOfficeTo == outOfOfficeTo)&&(identical(other.outOfOfficeMessage, outOfOfficeMessage) || other.outOfOfficeMessage == outOfOfficeMessage)&&(identical(other.calendarDefaultPrivacy, calendarDefaultPrivacy) || other.calendarDefaultPrivacy == calendarDefaultPrivacy)&&(identical(other.workLocationId, workLocationId) || other.workLocationId == workLocationId)&&(identical(other.workLocationName, workLocationName) || other.workLocationName == workLocationName)&&(identical(other.resourceCalendarId, resourceCalendarId) || other.resourceCalendarId == resourceCalendarId)&&(identical(other.resourceCalendarName, resourceCalendarName) || other.resourceCalendarName == resourceCalendarName)&&(identical(other.pin, pin) || other.pin == pin)&&(identical(other.privateStreet, privateStreet) || other.privateStreet == privateStreet)&&(identical(other.privateStreet2, privateStreet2) || other.privateStreet2 == privateStreet2)&&(identical(other.privateCity, privateCity) || other.privateCity == privateCity)&&(identical(other.privateZip, privateZip) || other.privateZip == privateZip)&&(identical(other.privateStateId, privateStateId) || other.privateStateId == privateStateId)&&(identical(other.privateStateName, privateStateName) || other.privateStateName == privateStateName)&&(identical(other.privateCountryId, privateCountryId) || other.privateCountryId == privateCountryId)&&(identical(other.privateCountryName, privateCountryName) || other.privateCountryName == privateCountryName)&&(identical(other.privateEmail, privateEmail) || other.privateEmail == privateEmail)&&(identical(other.privatePhone, privatePhone) || other.privatePhone == privatePhone)&&(identical(other.emergencyContact, emergencyContact) || other.emergencyContact == emergencyContact)&&(identical(other.emergencyPhone, emergencyPhone) || other.emergencyPhone == emergencyPhone));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,name,login,email,lang,tz,signature,partnerId,partnerName,companyId,companyName,warehouseId,warehouseName,avatar128,notificationType,workEmail,workPhone,mobilePhone,const DeepCollectionEquality().hash(groupIds),const DeepCollectionEquality().hash(permissions),isCurrentUser,writeDate,outOfOfficeFrom,outOfOfficeTo,outOfOfficeMessage,calendarDefaultPrivacy,workLocationId,workLocationName,resourceCalendarId,resourceCalendarName,pin,privateStreet,privateStreet2,privateCity,privateZip,privateStateId,privateStateName,privateCountryId,privateCountryName,privateEmail,privatePhone,emergencyContact,emergencyPhone]);

@override
String toString() {
  return 'User(id: $id, name: $name, login: $login, email: $email, lang: $lang, tz: $tz, signature: $signature, partnerId: $partnerId, partnerName: $partnerName, companyId: $companyId, companyName: $companyName, warehouseId: $warehouseId, warehouseName: $warehouseName, avatar128: $avatar128, notificationType: $notificationType, workEmail: $workEmail, workPhone: $workPhone, mobilePhone: $mobilePhone, groupIds: $groupIds, permissions: $permissions, isCurrentUser: $isCurrentUser, writeDate: $writeDate, outOfOfficeFrom: $outOfOfficeFrom, outOfOfficeTo: $outOfOfficeTo, outOfOfficeMessage: $outOfOfficeMessage, calendarDefaultPrivacy: $calendarDefaultPrivacy, workLocationId: $workLocationId, workLocationName: $workLocationName, resourceCalendarId: $resourceCalendarId, resourceCalendarName: $resourceCalendarName, pin: $pin, privateStreet: $privateStreet, privateStreet2: $privateStreet2, privateCity: $privateCity, privateZip: $privateZip, privateStateId: $privateStateId, privateStateName: $privateStateName, privateCountryId: $privateCountryId, privateCountryName: $privateCountryName, privateEmail: $privateEmail, privatePhone: $privatePhone, emergencyContact: $emergencyContact, emergencyPhone: $emergencyPhone)';
}


}

/// @nodoc
abstract mixin class $UserCopyWith<$Res>  {
  factory $UserCopyWith(User value, $Res Function(User) _then) = _$UserCopyWithImpl;
@useResult
$Res call({
@OdooId() int id,@OdooString() String name,@OdooString() String login,@OdooString() String? email,@OdooString() String? lang,@OdooString() String? tz,@OdooString() String? signature,@OdooMany2One('res.partner', odooName: 'partner_id') int? partnerId,@OdooMany2OneName(sourceField: 'partner_id') String? partnerName,@OdooMany2One('res.company', odooName: 'company_id') int? companyId,@OdooMany2OneName(sourceField: 'company_id') String? companyName,@OdooMany2One('stock.warehouse', odooName: 'property_warehouse_id') int? warehouseId,@OdooMany2OneName(sourceField: 'property_warehouse_id') String? warehouseName,@OdooString(odooName: 'avatar_128') String? avatar128,@OdooString(odooName: 'notification_type') String? notificationType,@OdooString(odooName: 'work_email') String? workEmail,@OdooString(odooName: 'work_phone') String? workPhone,@OdooString(odooName: 'mobile_phone') String? mobilePhone,@OdooLocalOnly() List<int> groupIds,@OdooLocalOnly() List<String> permissions,@OdooLocalOnly() bool isCurrentUser,@OdooDateTime(odooName: 'write_date') DateTime? writeDate,@OdooDateTime(odooName: 'out_of_office_from') DateTime? outOfOfficeFrom,@OdooDateTime(odooName: 'out_of_office_to') DateTime? outOfOfficeTo,@OdooString(odooName: 'out_of_office_message') String? outOfOfficeMessage,@OdooString(odooName: 'calendar_default_privacy') String? calendarDefaultPrivacy,@OdooMany2One('hr.work.location', odooName: 'work_location_id') int? workLocationId,@OdooMany2OneName(sourceField: 'work_location_id') String? workLocationName,@OdooMany2One('resource.calendar', odooName: 'resource_calendar_id') int? resourceCalendarId,@OdooMany2OneName(sourceField: 'resource_calendar_id') String? resourceCalendarName,@OdooString() String? pin,@OdooString(odooName: 'private_street') String? privateStreet,@OdooString(odooName: 'private_street2') String? privateStreet2,@OdooString(odooName: 'private_city') String? privateCity,@OdooString(odooName: 'private_zip') String? privateZip,@OdooMany2One('res.country.state', odooName: 'private_state_id') int? privateStateId,@OdooMany2OneName(sourceField: 'private_state_id') String? privateStateName,@OdooMany2One('res.country', odooName: 'private_country_id') int? privateCountryId,@OdooMany2OneName(sourceField: 'private_country_id') String? privateCountryName,@OdooString(odooName: 'private_email') String? privateEmail,@OdooString(odooName: 'private_phone') String? privatePhone,@OdooString(odooName: 'emergency_contact') String? emergencyContact,@OdooString(odooName: 'emergency_phone') String? emergencyPhone
});




}
/// @nodoc
class _$UserCopyWithImpl<$Res>
    implements $UserCopyWith<$Res> {
  _$UserCopyWithImpl(this._self, this._then);

  final User _self;
  final $Res Function(User) _then;

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? login = null,Object? email = freezed,Object? lang = freezed,Object? tz = freezed,Object? signature = freezed,Object? partnerId = freezed,Object? partnerName = freezed,Object? companyId = freezed,Object? companyName = freezed,Object? warehouseId = freezed,Object? warehouseName = freezed,Object? avatar128 = freezed,Object? notificationType = freezed,Object? workEmail = freezed,Object? workPhone = freezed,Object? mobilePhone = freezed,Object? groupIds = null,Object? permissions = null,Object? isCurrentUser = null,Object? writeDate = freezed,Object? outOfOfficeFrom = freezed,Object? outOfOfficeTo = freezed,Object? outOfOfficeMessage = freezed,Object? calendarDefaultPrivacy = freezed,Object? workLocationId = freezed,Object? workLocationName = freezed,Object? resourceCalendarId = freezed,Object? resourceCalendarName = freezed,Object? pin = freezed,Object? privateStreet = freezed,Object? privateStreet2 = freezed,Object? privateCity = freezed,Object? privateZip = freezed,Object? privateStateId = freezed,Object? privateStateName = freezed,Object? privateCountryId = freezed,Object? privateCountryName = freezed,Object? privateEmail = freezed,Object? privatePhone = freezed,Object? emergencyContact = freezed,Object? emergencyPhone = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,login: null == login ? _self.login : login // ignore: cast_nullable_to_non_nullable
as String,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,lang: freezed == lang ? _self.lang : lang // ignore: cast_nullable_to_non_nullable
as String?,tz: freezed == tz ? _self.tz : tz // ignore: cast_nullable_to_non_nullable
as String?,signature: freezed == signature ? _self.signature : signature // ignore: cast_nullable_to_non_nullable
as String?,partnerId: freezed == partnerId ? _self.partnerId : partnerId // ignore: cast_nullable_to_non_nullable
as int?,partnerName: freezed == partnerName ? _self.partnerName : partnerName // ignore: cast_nullable_to_non_nullable
as String?,companyId: freezed == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as int?,companyName: freezed == companyName ? _self.companyName : companyName // ignore: cast_nullable_to_non_nullable
as String?,warehouseId: freezed == warehouseId ? _self.warehouseId : warehouseId // ignore: cast_nullable_to_non_nullable
as int?,warehouseName: freezed == warehouseName ? _self.warehouseName : warehouseName // ignore: cast_nullable_to_non_nullable
as String?,avatar128: freezed == avatar128 ? _self.avatar128 : avatar128 // ignore: cast_nullable_to_non_nullable
as String?,notificationType: freezed == notificationType ? _self.notificationType : notificationType // ignore: cast_nullable_to_non_nullable
as String?,workEmail: freezed == workEmail ? _self.workEmail : workEmail // ignore: cast_nullable_to_non_nullable
as String?,workPhone: freezed == workPhone ? _self.workPhone : workPhone // ignore: cast_nullable_to_non_nullable
as String?,mobilePhone: freezed == mobilePhone ? _self.mobilePhone : mobilePhone // ignore: cast_nullable_to_non_nullable
as String?,groupIds: null == groupIds ? _self.groupIds : groupIds // ignore: cast_nullable_to_non_nullable
as List<int>,permissions: null == permissions ? _self.permissions : permissions // ignore: cast_nullable_to_non_nullable
as List<String>,isCurrentUser: null == isCurrentUser ? _self.isCurrentUser : isCurrentUser // ignore: cast_nullable_to_non_nullable
as bool,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,outOfOfficeFrom: freezed == outOfOfficeFrom ? _self.outOfOfficeFrom : outOfOfficeFrom // ignore: cast_nullable_to_non_nullable
as DateTime?,outOfOfficeTo: freezed == outOfOfficeTo ? _self.outOfOfficeTo : outOfOfficeTo // ignore: cast_nullable_to_non_nullable
as DateTime?,outOfOfficeMessage: freezed == outOfOfficeMessage ? _self.outOfOfficeMessage : outOfOfficeMessage // ignore: cast_nullable_to_non_nullable
as String?,calendarDefaultPrivacy: freezed == calendarDefaultPrivacy ? _self.calendarDefaultPrivacy : calendarDefaultPrivacy // ignore: cast_nullable_to_non_nullable
as String?,workLocationId: freezed == workLocationId ? _self.workLocationId : workLocationId // ignore: cast_nullable_to_non_nullable
as int?,workLocationName: freezed == workLocationName ? _self.workLocationName : workLocationName // ignore: cast_nullable_to_non_nullable
as String?,resourceCalendarId: freezed == resourceCalendarId ? _self.resourceCalendarId : resourceCalendarId // ignore: cast_nullable_to_non_nullable
as int?,resourceCalendarName: freezed == resourceCalendarName ? _self.resourceCalendarName : resourceCalendarName // ignore: cast_nullable_to_non_nullable
as String?,pin: freezed == pin ? _self.pin : pin // ignore: cast_nullable_to_non_nullable
as String?,privateStreet: freezed == privateStreet ? _self.privateStreet : privateStreet // ignore: cast_nullable_to_non_nullable
as String?,privateStreet2: freezed == privateStreet2 ? _self.privateStreet2 : privateStreet2 // ignore: cast_nullable_to_non_nullable
as String?,privateCity: freezed == privateCity ? _self.privateCity : privateCity // ignore: cast_nullable_to_non_nullable
as String?,privateZip: freezed == privateZip ? _self.privateZip : privateZip // ignore: cast_nullable_to_non_nullable
as String?,privateStateId: freezed == privateStateId ? _self.privateStateId : privateStateId // ignore: cast_nullable_to_non_nullable
as int?,privateStateName: freezed == privateStateName ? _self.privateStateName : privateStateName // ignore: cast_nullable_to_non_nullable
as String?,privateCountryId: freezed == privateCountryId ? _self.privateCountryId : privateCountryId // ignore: cast_nullable_to_non_nullable
as int?,privateCountryName: freezed == privateCountryName ? _self.privateCountryName : privateCountryName // ignore: cast_nullable_to_non_nullable
as String?,privateEmail: freezed == privateEmail ? _self.privateEmail : privateEmail // ignore: cast_nullable_to_non_nullable
as String?,privatePhone: freezed == privatePhone ? _self.privatePhone : privatePhone // ignore: cast_nullable_to_non_nullable
as String?,emergencyContact: freezed == emergencyContact ? _self.emergencyContact : emergencyContact // ignore: cast_nullable_to_non_nullable
as String?,emergencyPhone: freezed == emergencyPhone ? _self.emergencyPhone : emergencyPhone // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [User].
extension UserPatterns on User {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _User value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _User() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _User value)  $default,){
final _that = this;
switch (_that) {
case _User():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _User value)?  $default,){
final _that = this;
switch (_that) {
case _User() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooString()  String name, @OdooString()  String login, @OdooString()  String? email, @OdooString()  String? lang, @OdooString()  String? tz, @OdooString()  String? signature, @OdooMany2One('res.partner', odooName: 'partner_id')  int? partnerId, @OdooMany2OneName(sourceField: 'partner_id')  String? partnerName, @OdooMany2One('res.company', odooName: 'company_id')  int? companyId, @OdooMany2OneName(sourceField: 'company_id')  String? companyName, @OdooMany2One('stock.warehouse', odooName: 'property_warehouse_id')  int? warehouseId, @OdooMany2OneName(sourceField: 'property_warehouse_id')  String? warehouseName, @OdooString(odooName: 'avatar_128')  String? avatar128, @OdooString(odooName: 'notification_type')  String? notificationType, @OdooString(odooName: 'work_email')  String? workEmail, @OdooString(odooName: 'work_phone')  String? workPhone, @OdooString(odooName: 'mobile_phone')  String? mobilePhone, @OdooLocalOnly()  List<int> groupIds, @OdooLocalOnly()  List<String> permissions, @OdooLocalOnly()  bool isCurrentUser, @OdooDateTime(odooName: 'write_date')  DateTime? writeDate, @OdooDateTime(odooName: 'out_of_office_from')  DateTime? outOfOfficeFrom, @OdooDateTime(odooName: 'out_of_office_to')  DateTime? outOfOfficeTo, @OdooString(odooName: 'out_of_office_message')  String? outOfOfficeMessage, @OdooString(odooName: 'calendar_default_privacy')  String? calendarDefaultPrivacy, @OdooMany2One('hr.work.location', odooName: 'work_location_id')  int? workLocationId, @OdooMany2OneName(sourceField: 'work_location_id')  String? workLocationName, @OdooMany2One('resource.calendar', odooName: 'resource_calendar_id')  int? resourceCalendarId, @OdooMany2OneName(sourceField: 'resource_calendar_id')  String? resourceCalendarName, @OdooString()  String? pin, @OdooString(odooName: 'private_street')  String? privateStreet, @OdooString(odooName: 'private_street2')  String? privateStreet2, @OdooString(odooName: 'private_city')  String? privateCity, @OdooString(odooName: 'private_zip')  String? privateZip, @OdooMany2One('res.country.state', odooName: 'private_state_id')  int? privateStateId, @OdooMany2OneName(sourceField: 'private_state_id')  String? privateStateName, @OdooMany2One('res.country', odooName: 'private_country_id')  int? privateCountryId, @OdooMany2OneName(sourceField: 'private_country_id')  String? privateCountryName, @OdooString(odooName: 'private_email')  String? privateEmail, @OdooString(odooName: 'private_phone')  String? privatePhone, @OdooString(odooName: 'emergency_contact')  String? emergencyContact, @OdooString(odooName: 'emergency_phone')  String? emergencyPhone)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _User() when $default != null:
return $default(_that.id,_that.name,_that.login,_that.email,_that.lang,_that.tz,_that.signature,_that.partnerId,_that.partnerName,_that.companyId,_that.companyName,_that.warehouseId,_that.warehouseName,_that.avatar128,_that.notificationType,_that.workEmail,_that.workPhone,_that.mobilePhone,_that.groupIds,_that.permissions,_that.isCurrentUser,_that.writeDate,_that.outOfOfficeFrom,_that.outOfOfficeTo,_that.outOfOfficeMessage,_that.calendarDefaultPrivacy,_that.workLocationId,_that.workLocationName,_that.resourceCalendarId,_that.resourceCalendarName,_that.pin,_that.privateStreet,_that.privateStreet2,_that.privateCity,_that.privateZip,_that.privateStateId,_that.privateStateName,_that.privateCountryId,_that.privateCountryName,_that.privateEmail,_that.privatePhone,_that.emergencyContact,_that.emergencyPhone);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooString()  String name, @OdooString()  String login, @OdooString()  String? email, @OdooString()  String? lang, @OdooString()  String? tz, @OdooString()  String? signature, @OdooMany2One('res.partner', odooName: 'partner_id')  int? partnerId, @OdooMany2OneName(sourceField: 'partner_id')  String? partnerName, @OdooMany2One('res.company', odooName: 'company_id')  int? companyId, @OdooMany2OneName(sourceField: 'company_id')  String? companyName, @OdooMany2One('stock.warehouse', odooName: 'property_warehouse_id')  int? warehouseId, @OdooMany2OneName(sourceField: 'property_warehouse_id')  String? warehouseName, @OdooString(odooName: 'avatar_128')  String? avatar128, @OdooString(odooName: 'notification_type')  String? notificationType, @OdooString(odooName: 'work_email')  String? workEmail, @OdooString(odooName: 'work_phone')  String? workPhone, @OdooString(odooName: 'mobile_phone')  String? mobilePhone, @OdooLocalOnly()  List<int> groupIds, @OdooLocalOnly()  List<String> permissions, @OdooLocalOnly()  bool isCurrentUser, @OdooDateTime(odooName: 'write_date')  DateTime? writeDate, @OdooDateTime(odooName: 'out_of_office_from')  DateTime? outOfOfficeFrom, @OdooDateTime(odooName: 'out_of_office_to')  DateTime? outOfOfficeTo, @OdooString(odooName: 'out_of_office_message')  String? outOfOfficeMessage, @OdooString(odooName: 'calendar_default_privacy')  String? calendarDefaultPrivacy, @OdooMany2One('hr.work.location', odooName: 'work_location_id')  int? workLocationId, @OdooMany2OneName(sourceField: 'work_location_id')  String? workLocationName, @OdooMany2One('resource.calendar', odooName: 'resource_calendar_id')  int? resourceCalendarId, @OdooMany2OneName(sourceField: 'resource_calendar_id')  String? resourceCalendarName, @OdooString()  String? pin, @OdooString(odooName: 'private_street')  String? privateStreet, @OdooString(odooName: 'private_street2')  String? privateStreet2, @OdooString(odooName: 'private_city')  String? privateCity, @OdooString(odooName: 'private_zip')  String? privateZip, @OdooMany2One('res.country.state', odooName: 'private_state_id')  int? privateStateId, @OdooMany2OneName(sourceField: 'private_state_id')  String? privateStateName, @OdooMany2One('res.country', odooName: 'private_country_id')  int? privateCountryId, @OdooMany2OneName(sourceField: 'private_country_id')  String? privateCountryName, @OdooString(odooName: 'private_email')  String? privateEmail, @OdooString(odooName: 'private_phone')  String? privatePhone, @OdooString(odooName: 'emergency_contact')  String? emergencyContact, @OdooString(odooName: 'emergency_phone')  String? emergencyPhone)  $default,) {final _that = this;
switch (_that) {
case _User():
return $default(_that.id,_that.name,_that.login,_that.email,_that.lang,_that.tz,_that.signature,_that.partnerId,_that.partnerName,_that.companyId,_that.companyName,_that.warehouseId,_that.warehouseName,_that.avatar128,_that.notificationType,_that.workEmail,_that.workPhone,_that.mobilePhone,_that.groupIds,_that.permissions,_that.isCurrentUser,_that.writeDate,_that.outOfOfficeFrom,_that.outOfOfficeTo,_that.outOfOfficeMessage,_that.calendarDefaultPrivacy,_that.workLocationId,_that.workLocationName,_that.resourceCalendarId,_that.resourceCalendarName,_that.pin,_that.privateStreet,_that.privateStreet2,_that.privateCity,_that.privateZip,_that.privateStateId,_that.privateStateName,_that.privateCountryId,_that.privateCountryName,_that.privateEmail,_that.privatePhone,_that.emergencyContact,_that.emergencyPhone);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@OdooId()  int id, @OdooString()  String name, @OdooString()  String login, @OdooString()  String? email, @OdooString()  String? lang, @OdooString()  String? tz, @OdooString()  String? signature, @OdooMany2One('res.partner', odooName: 'partner_id')  int? partnerId, @OdooMany2OneName(sourceField: 'partner_id')  String? partnerName, @OdooMany2One('res.company', odooName: 'company_id')  int? companyId, @OdooMany2OneName(sourceField: 'company_id')  String? companyName, @OdooMany2One('stock.warehouse', odooName: 'property_warehouse_id')  int? warehouseId, @OdooMany2OneName(sourceField: 'property_warehouse_id')  String? warehouseName, @OdooString(odooName: 'avatar_128')  String? avatar128, @OdooString(odooName: 'notification_type')  String? notificationType, @OdooString(odooName: 'work_email')  String? workEmail, @OdooString(odooName: 'work_phone')  String? workPhone, @OdooString(odooName: 'mobile_phone')  String? mobilePhone, @OdooLocalOnly()  List<int> groupIds, @OdooLocalOnly()  List<String> permissions, @OdooLocalOnly()  bool isCurrentUser, @OdooDateTime(odooName: 'write_date')  DateTime? writeDate, @OdooDateTime(odooName: 'out_of_office_from')  DateTime? outOfOfficeFrom, @OdooDateTime(odooName: 'out_of_office_to')  DateTime? outOfOfficeTo, @OdooString(odooName: 'out_of_office_message')  String? outOfOfficeMessage, @OdooString(odooName: 'calendar_default_privacy')  String? calendarDefaultPrivacy, @OdooMany2One('hr.work.location', odooName: 'work_location_id')  int? workLocationId, @OdooMany2OneName(sourceField: 'work_location_id')  String? workLocationName, @OdooMany2One('resource.calendar', odooName: 'resource_calendar_id')  int? resourceCalendarId, @OdooMany2OneName(sourceField: 'resource_calendar_id')  String? resourceCalendarName, @OdooString()  String? pin, @OdooString(odooName: 'private_street')  String? privateStreet, @OdooString(odooName: 'private_street2')  String? privateStreet2, @OdooString(odooName: 'private_city')  String? privateCity, @OdooString(odooName: 'private_zip')  String? privateZip, @OdooMany2One('res.country.state', odooName: 'private_state_id')  int? privateStateId, @OdooMany2OneName(sourceField: 'private_state_id')  String? privateStateName, @OdooMany2One('res.country', odooName: 'private_country_id')  int? privateCountryId, @OdooMany2OneName(sourceField: 'private_country_id')  String? privateCountryName, @OdooString(odooName: 'private_email')  String? privateEmail, @OdooString(odooName: 'private_phone')  String? privatePhone, @OdooString(odooName: 'emergency_contact')  String? emergencyContact, @OdooString(odooName: 'emergency_phone')  String? emergencyPhone)?  $default,) {final _that = this;
switch (_that) {
case _User() when $default != null:
return $default(_that.id,_that.name,_that.login,_that.email,_that.lang,_that.tz,_that.signature,_that.partnerId,_that.partnerName,_that.companyId,_that.companyName,_that.warehouseId,_that.warehouseName,_that.avatar128,_that.notificationType,_that.workEmail,_that.workPhone,_that.mobilePhone,_that.groupIds,_that.permissions,_that.isCurrentUser,_that.writeDate,_that.outOfOfficeFrom,_that.outOfOfficeTo,_that.outOfOfficeMessage,_that.calendarDefaultPrivacy,_that.workLocationId,_that.workLocationName,_that.resourceCalendarId,_that.resourceCalendarName,_that.pin,_that.privateStreet,_that.privateStreet2,_that.privateCity,_that.privateZip,_that.privateStateId,_that.privateStateName,_that.privateCountryId,_that.privateCountryName,_that.privateEmail,_that.privatePhone,_that.emergencyContact,_that.emergencyPhone);case _:
  return null;

}
}

}

/// @nodoc


class _User extends User {
  const _User({@OdooId() required this.id, @OdooString() required this.name, @OdooString() required this.login, @OdooString() this.email, @OdooString() this.lang, @OdooString() this.tz, @OdooString() this.signature, @OdooMany2One('res.partner', odooName: 'partner_id') this.partnerId, @OdooMany2OneName(sourceField: 'partner_id') this.partnerName, @OdooMany2One('res.company', odooName: 'company_id') this.companyId, @OdooMany2OneName(sourceField: 'company_id') this.companyName, @OdooMany2One('stock.warehouse', odooName: 'property_warehouse_id') this.warehouseId, @OdooMany2OneName(sourceField: 'property_warehouse_id') this.warehouseName, @OdooString(odooName: 'avatar_128') this.avatar128, @OdooString(odooName: 'notification_type') this.notificationType, @OdooString(odooName: 'work_email') this.workEmail, @OdooString(odooName: 'work_phone') this.workPhone, @OdooString(odooName: 'mobile_phone') this.mobilePhone, @OdooLocalOnly() final  List<int> groupIds = const [], @OdooLocalOnly() final  List<String> permissions = const [], @OdooLocalOnly() this.isCurrentUser = false, @OdooDateTime(odooName: 'write_date') this.writeDate, @OdooDateTime(odooName: 'out_of_office_from') this.outOfOfficeFrom, @OdooDateTime(odooName: 'out_of_office_to') this.outOfOfficeTo, @OdooString(odooName: 'out_of_office_message') this.outOfOfficeMessage, @OdooString(odooName: 'calendar_default_privacy') this.calendarDefaultPrivacy, @OdooMany2One('hr.work.location', odooName: 'work_location_id') this.workLocationId, @OdooMany2OneName(sourceField: 'work_location_id') this.workLocationName, @OdooMany2One('resource.calendar', odooName: 'resource_calendar_id') this.resourceCalendarId, @OdooMany2OneName(sourceField: 'resource_calendar_id') this.resourceCalendarName, @OdooString() this.pin, @OdooString(odooName: 'private_street') this.privateStreet, @OdooString(odooName: 'private_street2') this.privateStreet2, @OdooString(odooName: 'private_city') this.privateCity, @OdooString(odooName: 'private_zip') this.privateZip, @OdooMany2One('res.country.state', odooName: 'private_state_id') this.privateStateId, @OdooMany2OneName(sourceField: 'private_state_id') this.privateStateName, @OdooMany2One('res.country', odooName: 'private_country_id') this.privateCountryId, @OdooMany2OneName(sourceField: 'private_country_id') this.privateCountryName, @OdooString(odooName: 'private_email') this.privateEmail, @OdooString(odooName: 'private_phone') this.privatePhone, @OdooString(odooName: 'emergency_contact') this.emergencyContact, @OdooString(odooName: 'emergency_phone') this.emergencyPhone}): _groupIds = groupIds,_permissions = permissions,super._();
  

@override@OdooId() final  int id;
@override@OdooString() final  String name;
@override@OdooString() final  String login;
@override@OdooString() final  String? email;
@override@OdooString() final  String? lang;
@override@OdooString() final  String? tz;
@override@OdooString() final  String? signature;
@override@OdooMany2One('res.partner', odooName: 'partner_id') final  int? partnerId;
@override@OdooMany2OneName(sourceField: 'partner_id') final  String? partnerName;
@override@OdooMany2One('res.company', odooName: 'company_id') final  int? companyId;
@override@OdooMany2OneName(sourceField: 'company_id') final  String? companyName;
@override@OdooMany2One('stock.warehouse', odooName: 'property_warehouse_id') final  int? warehouseId;
@override@OdooMany2OneName(sourceField: 'property_warehouse_id') final  String? warehouseName;
@override@OdooString(odooName: 'avatar_128') final  String? avatar128;
@override@OdooString(odooName: 'notification_type') final  String? notificationType;
@override@OdooString(odooName: 'work_email') final  String? workEmail;
@override@OdooString(odooName: 'work_phone') final  String? workPhone;
@override@OdooString(odooName: 'mobile_phone') final  String? mobilePhone;
 final  List<int> _groupIds;
@override@JsonKey()@OdooLocalOnly() List<int> get groupIds {
  if (_groupIds is EqualUnmodifiableListView) return _groupIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_groupIds);
}

 final  List<String> _permissions;
@override@JsonKey()@OdooLocalOnly() List<String> get permissions {
  if (_permissions is EqualUnmodifiableListView) return _permissions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_permissions);
}

@override@JsonKey()@OdooLocalOnly() final  bool isCurrentUser;
@override@OdooDateTime(odooName: 'write_date') final  DateTime? writeDate;
// Out of Office (modulo mail)
@override@OdooDateTime(odooName: 'out_of_office_from') final  DateTime? outOfOfficeFrom;
@override@OdooDateTime(odooName: 'out_of_office_to') final  DateTime? outOfOfficeTo;
@override@OdooString(odooName: 'out_of_office_message') final  String? outOfOfficeMessage;
// Calendar preferences
@override@OdooString(odooName: 'calendar_default_privacy') final  String? calendarDefaultPrivacy;
// Work location (modulo hr)
@override@OdooMany2One('hr.work.location', odooName: 'work_location_id') final  int? workLocationId;
@override@OdooMany2OneName(sourceField: 'work_location_id') final  String? workLocationName;
// Resource calendar / Work schedule
@override@OdooMany2One('resource.calendar', odooName: 'resource_calendar_id') final  int? resourceCalendarId;
@override@OdooMany2OneName(sourceField: 'resource_calendar_id') final  String? resourceCalendarName;
// PIN for attendance (modulo hr)
@override@OdooString() final  String? pin;
// Private information (modulo hr)
@override@OdooString(odooName: 'private_street') final  String? privateStreet;
@override@OdooString(odooName: 'private_street2') final  String? privateStreet2;
@override@OdooString(odooName: 'private_city') final  String? privateCity;
@override@OdooString(odooName: 'private_zip') final  String? privateZip;
@override@OdooMany2One('res.country.state', odooName: 'private_state_id') final  int? privateStateId;
@override@OdooMany2OneName(sourceField: 'private_state_id') final  String? privateStateName;
@override@OdooMany2One('res.country', odooName: 'private_country_id') final  int? privateCountryId;
@override@OdooMany2OneName(sourceField: 'private_country_id') final  String? privateCountryName;
@override@OdooString(odooName: 'private_email') final  String? privateEmail;
@override@OdooString(odooName: 'private_phone') final  String? privatePhone;
// Emergency contact (modulo hr)
@override@OdooString(odooName: 'emergency_contact') final  String? emergencyContact;
@override@OdooString(odooName: 'emergency_phone') final  String? emergencyPhone;

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserCopyWith<_User> get copyWith => __$UserCopyWithImpl<_User>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _User&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.login, login) || other.login == login)&&(identical(other.email, email) || other.email == email)&&(identical(other.lang, lang) || other.lang == lang)&&(identical(other.tz, tz) || other.tz == tz)&&(identical(other.signature, signature) || other.signature == signature)&&(identical(other.partnerId, partnerId) || other.partnerId == partnerId)&&(identical(other.partnerName, partnerName) || other.partnerName == partnerName)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&(identical(other.companyName, companyName) || other.companyName == companyName)&&(identical(other.warehouseId, warehouseId) || other.warehouseId == warehouseId)&&(identical(other.warehouseName, warehouseName) || other.warehouseName == warehouseName)&&(identical(other.avatar128, avatar128) || other.avatar128 == avatar128)&&(identical(other.notificationType, notificationType) || other.notificationType == notificationType)&&(identical(other.workEmail, workEmail) || other.workEmail == workEmail)&&(identical(other.workPhone, workPhone) || other.workPhone == workPhone)&&(identical(other.mobilePhone, mobilePhone) || other.mobilePhone == mobilePhone)&&const DeepCollectionEquality().equals(other._groupIds, _groupIds)&&const DeepCollectionEquality().equals(other._permissions, _permissions)&&(identical(other.isCurrentUser, isCurrentUser) || other.isCurrentUser == isCurrentUser)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate)&&(identical(other.outOfOfficeFrom, outOfOfficeFrom) || other.outOfOfficeFrom == outOfOfficeFrom)&&(identical(other.outOfOfficeTo, outOfOfficeTo) || other.outOfOfficeTo == outOfOfficeTo)&&(identical(other.outOfOfficeMessage, outOfOfficeMessage) || other.outOfOfficeMessage == outOfOfficeMessage)&&(identical(other.calendarDefaultPrivacy, calendarDefaultPrivacy) || other.calendarDefaultPrivacy == calendarDefaultPrivacy)&&(identical(other.workLocationId, workLocationId) || other.workLocationId == workLocationId)&&(identical(other.workLocationName, workLocationName) || other.workLocationName == workLocationName)&&(identical(other.resourceCalendarId, resourceCalendarId) || other.resourceCalendarId == resourceCalendarId)&&(identical(other.resourceCalendarName, resourceCalendarName) || other.resourceCalendarName == resourceCalendarName)&&(identical(other.pin, pin) || other.pin == pin)&&(identical(other.privateStreet, privateStreet) || other.privateStreet == privateStreet)&&(identical(other.privateStreet2, privateStreet2) || other.privateStreet2 == privateStreet2)&&(identical(other.privateCity, privateCity) || other.privateCity == privateCity)&&(identical(other.privateZip, privateZip) || other.privateZip == privateZip)&&(identical(other.privateStateId, privateStateId) || other.privateStateId == privateStateId)&&(identical(other.privateStateName, privateStateName) || other.privateStateName == privateStateName)&&(identical(other.privateCountryId, privateCountryId) || other.privateCountryId == privateCountryId)&&(identical(other.privateCountryName, privateCountryName) || other.privateCountryName == privateCountryName)&&(identical(other.privateEmail, privateEmail) || other.privateEmail == privateEmail)&&(identical(other.privatePhone, privatePhone) || other.privatePhone == privatePhone)&&(identical(other.emergencyContact, emergencyContact) || other.emergencyContact == emergencyContact)&&(identical(other.emergencyPhone, emergencyPhone) || other.emergencyPhone == emergencyPhone));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,name,login,email,lang,tz,signature,partnerId,partnerName,companyId,companyName,warehouseId,warehouseName,avatar128,notificationType,workEmail,workPhone,mobilePhone,const DeepCollectionEquality().hash(_groupIds),const DeepCollectionEquality().hash(_permissions),isCurrentUser,writeDate,outOfOfficeFrom,outOfOfficeTo,outOfOfficeMessage,calendarDefaultPrivacy,workLocationId,workLocationName,resourceCalendarId,resourceCalendarName,pin,privateStreet,privateStreet2,privateCity,privateZip,privateStateId,privateStateName,privateCountryId,privateCountryName,privateEmail,privatePhone,emergencyContact,emergencyPhone]);

@override
String toString() {
  return 'User(id: $id, name: $name, login: $login, email: $email, lang: $lang, tz: $tz, signature: $signature, partnerId: $partnerId, partnerName: $partnerName, companyId: $companyId, companyName: $companyName, warehouseId: $warehouseId, warehouseName: $warehouseName, avatar128: $avatar128, notificationType: $notificationType, workEmail: $workEmail, workPhone: $workPhone, mobilePhone: $mobilePhone, groupIds: $groupIds, permissions: $permissions, isCurrentUser: $isCurrentUser, writeDate: $writeDate, outOfOfficeFrom: $outOfOfficeFrom, outOfOfficeTo: $outOfOfficeTo, outOfOfficeMessage: $outOfOfficeMessage, calendarDefaultPrivacy: $calendarDefaultPrivacy, workLocationId: $workLocationId, workLocationName: $workLocationName, resourceCalendarId: $resourceCalendarId, resourceCalendarName: $resourceCalendarName, pin: $pin, privateStreet: $privateStreet, privateStreet2: $privateStreet2, privateCity: $privateCity, privateZip: $privateZip, privateStateId: $privateStateId, privateStateName: $privateStateName, privateCountryId: $privateCountryId, privateCountryName: $privateCountryName, privateEmail: $privateEmail, privatePhone: $privatePhone, emergencyContact: $emergencyContact, emergencyPhone: $emergencyPhone)';
}


}

/// @nodoc
abstract mixin class _$UserCopyWith<$Res> implements $UserCopyWith<$Res> {
  factory _$UserCopyWith(_User value, $Res Function(_User) _then) = __$UserCopyWithImpl;
@override @useResult
$Res call({
@OdooId() int id,@OdooString() String name,@OdooString() String login,@OdooString() String? email,@OdooString() String? lang,@OdooString() String? tz,@OdooString() String? signature,@OdooMany2One('res.partner', odooName: 'partner_id') int? partnerId,@OdooMany2OneName(sourceField: 'partner_id') String? partnerName,@OdooMany2One('res.company', odooName: 'company_id') int? companyId,@OdooMany2OneName(sourceField: 'company_id') String? companyName,@OdooMany2One('stock.warehouse', odooName: 'property_warehouse_id') int? warehouseId,@OdooMany2OneName(sourceField: 'property_warehouse_id') String? warehouseName,@OdooString(odooName: 'avatar_128') String? avatar128,@OdooString(odooName: 'notification_type') String? notificationType,@OdooString(odooName: 'work_email') String? workEmail,@OdooString(odooName: 'work_phone') String? workPhone,@OdooString(odooName: 'mobile_phone') String? mobilePhone,@OdooLocalOnly() List<int> groupIds,@OdooLocalOnly() List<String> permissions,@OdooLocalOnly() bool isCurrentUser,@OdooDateTime(odooName: 'write_date') DateTime? writeDate,@OdooDateTime(odooName: 'out_of_office_from') DateTime? outOfOfficeFrom,@OdooDateTime(odooName: 'out_of_office_to') DateTime? outOfOfficeTo,@OdooString(odooName: 'out_of_office_message') String? outOfOfficeMessage,@OdooString(odooName: 'calendar_default_privacy') String? calendarDefaultPrivacy,@OdooMany2One('hr.work.location', odooName: 'work_location_id') int? workLocationId,@OdooMany2OneName(sourceField: 'work_location_id') String? workLocationName,@OdooMany2One('resource.calendar', odooName: 'resource_calendar_id') int? resourceCalendarId,@OdooMany2OneName(sourceField: 'resource_calendar_id') String? resourceCalendarName,@OdooString() String? pin,@OdooString(odooName: 'private_street') String? privateStreet,@OdooString(odooName: 'private_street2') String? privateStreet2,@OdooString(odooName: 'private_city') String? privateCity,@OdooString(odooName: 'private_zip') String? privateZip,@OdooMany2One('res.country.state', odooName: 'private_state_id') int? privateStateId,@OdooMany2OneName(sourceField: 'private_state_id') String? privateStateName,@OdooMany2One('res.country', odooName: 'private_country_id') int? privateCountryId,@OdooMany2OneName(sourceField: 'private_country_id') String? privateCountryName,@OdooString(odooName: 'private_email') String? privateEmail,@OdooString(odooName: 'private_phone') String? privatePhone,@OdooString(odooName: 'emergency_contact') String? emergencyContact,@OdooString(odooName: 'emergency_phone') String? emergencyPhone
});




}
/// @nodoc
class __$UserCopyWithImpl<$Res>
    implements _$UserCopyWith<$Res> {
  __$UserCopyWithImpl(this._self, this._then);

  final _User _self;
  final $Res Function(_User) _then;

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? login = null,Object? email = freezed,Object? lang = freezed,Object? tz = freezed,Object? signature = freezed,Object? partnerId = freezed,Object? partnerName = freezed,Object? companyId = freezed,Object? companyName = freezed,Object? warehouseId = freezed,Object? warehouseName = freezed,Object? avatar128 = freezed,Object? notificationType = freezed,Object? workEmail = freezed,Object? workPhone = freezed,Object? mobilePhone = freezed,Object? groupIds = null,Object? permissions = null,Object? isCurrentUser = null,Object? writeDate = freezed,Object? outOfOfficeFrom = freezed,Object? outOfOfficeTo = freezed,Object? outOfOfficeMessage = freezed,Object? calendarDefaultPrivacy = freezed,Object? workLocationId = freezed,Object? workLocationName = freezed,Object? resourceCalendarId = freezed,Object? resourceCalendarName = freezed,Object? pin = freezed,Object? privateStreet = freezed,Object? privateStreet2 = freezed,Object? privateCity = freezed,Object? privateZip = freezed,Object? privateStateId = freezed,Object? privateStateName = freezed,Object? privateCountryId = freezed,Object? privateCountryName = freezed,Object? privateEmail = freezed,Object? privatePhone = freezed,Object? emergencyContact = freezed,Object? emergencyPhone = freezed,}) {
  return _then(_User(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,login: null == login ? _self.login : login // ignore: cast_nullable_to_non_nullable
as String,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,lang: freezed == lang ? _self.lang : lang // ignore: cast_nullable_to_non_nullable
as String?,tz: freezed == tz ? _self.tz : tz // ignore: cast_nullable_to_non_nullable
as String?,signature: freezed == signature ? _self.signature : signature // ignore: cast_nullable_to_non_nullable
as String?,partnerId: freezed == partnerId ? _self.partnerId : partnerId // ignore: cast_nullable_to_non_nullable
as int?,partnerName: freezed == partnerName ? _self.partnerName : partnerName // ignore: cast_nullable_to_non_nullable
as String?,companyId: freezed == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as int?,companyName: freezed == companyName ? _self.companyName : companyName // ignore: cast_nullable_to_non_nullable
as String?,warehouseId: freezed == warehouseId ? _self.warehouseId : warehouseId // ignore: cast_nullable_to_non_nullable
as int?,warehouseName: freezed == warehouseName ? _self.warehouseName : warehouseName // ignore: cast_nullable_to_non_nullable
as String?,avatar128: freezed == avatar128 ? _self.avatar128 : avatar128 // ignore: cast_nullable_to_non_nullable
as String?,notificationType: freezed == notificationType ? _self.notificationType : notificationType // ignore: cast_nullable_to_non_nullable
as String?,workEmail: freezed == workEmail ? _self.workEmail : workEmail // ignore: cast_nullable_to_non_nullable
as String?,workPhone: freezed == workPhone ? _self.workPhone : workPhone // ignore: cast_nullable_to_non_nullable
as String?,mobilePhone: freezed == mobilePhone ? _self.mobilePhone : mobilePhone // ignore: cast_nullable_to_non_nullable
as String?,groupIds: null == groupIds ? _self._groupIds : groupIds // ignore: cast_nullable_to_non_nullable
as List<int>,permissions: null == permissions ? _self._permissions : permissions // ignore: cast_nullable_to_non_nullable
as List<String>,isCurrentUser: null == isCurrentUser ? _self.isCurrentUser : isCurrentUser // ignore: cast_nullable_to_non_nullable
as bool,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,outOfOfficeFrom: freezed == outOfOfficeFrom ? _self.outOfOfficeFrom : outOfOfficeFrom // ignore: cast_nullable_to_non_nullable
as DateTime?,outOfOfficeTo: freezed == outOfOfficeTo ? _self.outOfOfficeTo : outOfOfficeTo // ignore: cast_nullable_to_non_nullable
as DateTime?,outOfOfficeMessage: freezed == outOfOfficeMessage ? _self.outOfOfficeMessage : outOfOfficeMessage // ignore: cast_nullable_to_non_nullable
as String?,calendarDefaultPrivacy: freezed == calendarDefaultPrivacy ? _self.calendarDefaultPrivacy : calendarDefaultPrivacy // ignore: cast_nullable_to_non_nullable
as String?,workLocationId: freezed == workLocationId ? _self.workLocationId : workLocationId // ignore: cast_nullable_to_non_nullable
as int?,workLocationName: freezed == workLocationName ? _self.workLocationName : workLocationName // ignore: cast_nullable_to_non_nullable
as String?,resourceCalendarId: freezed == resourceCalendarId ? _self.resourceCalendarId : resourceCalendarId // ignore: cast_nullable_to_non_nullable
as int?,resourceCalendarName: freezed == resourceCalendarName ? _self.resourceCalendarName : resourceCalendarName // ignore: cast_nullable_to_non_nullable
as String?,pin: freezed == pin ? _self.pin : pin // ignore: cast_nullable_to_non_nullable
as String?,privateStreet: freezed == privateStreet ? _self.privateStreet : privateStreet // ignore: cast_nullable_to_non_nullable
as String?,privateStreet2: freezed == privateStreet2 ? _self.privateStreet2 : privateStreet2 // ignore: cast_nullable_to_non_nullable
as String?,privateCity: freezed == privateCity ? _self.privateCity : privateCity // ignore: cast_nullable_to_non_nullable
as String?,privateZip: freezed == privateZip ? _self.privateZip : privateZip // ignore: cast_nullable_to_non_nullable
as String?,privateStateId: freezed == privateStateId ? _self.privateStateId : privateStateId // ignore: cast_nullable_to_non_nullable
as int?,privateStateName: freezed == privateStateName ? _self.privateStateName : privateStateName // ignore: cast_nullable_to_non_nullable
as String?,privateCountryId: freezed == privateCountryId ? _self.privateCountryId : privateCountryId // ignore: cast_nullable_to_non_nullable
as int?,privateCountryName: freezed == privateCountryName ? _self.privateCountryName : privateCountryName // ignore: cast_nullable_to_non_nullable
as String?,privateEmail: freezed == privateEmail ? _self.privateEmail : privateEmail // ignore: cast_nullable_to_non_nullable
as String?,privatePhone: freezed == privatePhone ? _self.privatePhone : privatePhone // ignore: cast_nullable_to_non_nullable
as String?,emergencyContact: freezed == emergencyContact ? _self.emergencyContact : emergencyContact // ignore: cast_nullable_to_non_nullable
as String?,emergencyPhone: freezed == emergencyPhone ? _self.emergencyPhone : emergencyPhone // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
