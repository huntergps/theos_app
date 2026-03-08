// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'collection_config.model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CollectionConfig {

// ============ Identifiers ============
@OdooId() int get id;// ============ Basic Data ============
@OdooString() String get name;@OdooString() String get code;@OdooBoolean() bool get active;// ============ Relations ============
@OdooMany2One('res.company', odooName: 'company_id') int? get companyId;@OdooMany2OneName(sourceField: 'company_id') String? get companyName;@OdooMany2One('account.journal', odooName: 'journal_id') int? get journalId;@OdooMany2OneName(sourceField: 'journal_id') String? get journalName;@OdooMany2One('account.journal', odooName: 'cash_journal_id') int? get cashJournalId;@OdooMany2OneName(sourceField: 'cash_journal_id') String? get cashJournalName;@OdooMany2Many('account.journal', odooName: 'allowed_journal_ids') List<int>? get allowedJournalIds;@OdooMany2One('account.account', odooName: 'cash_difference_account_id') int? get cashDifferenceAccountId;@OdooMany2One('res.currency', odooName: 'currency_id') int? get currencyId;@OdooMany2OneName(sourceField: 'currency_id') String? get currencyName;// ============ Configuration Fields ============
@OdooBoolean(odooName: 'set_maximum_difference') bool get setMaximumDifference;@OdooFloat(odooName: 'amount_authorized_diff') double get amountAuthorizedDiff;@OdooMany2Many('res.users', odooName: 'user_ids') List<int>? get userIds;// ============ Session Fields ============
@OdooMany2One('collection.session', odooName: 'current_session_id') int? get currentSessionId;@OdooSelection(odooName: 'current_session_state') String? get currentSessionState;@OdooString(odooName: 'current_session_name') String? get currentSessionName;@OdooInteger(odooName: 'number_of_opened_session') int get numberOfOpenedSession;@OdooDateTime(odooName: 'last_session_closing_date') DateTime? get lastSessionClosingDate;@OdooFloat(odooName: 'last_session_closing_cash') double get lastSessionClosingCash;// ============ Dashboard Display Fields ============
@OdooString(odooName: 'collection_session_username') String? get currentSessionUserName;@OdooString(odooName: 'current_session_state_display') String? get currentSessionStateDisplay;@OdooInteger(odooName: 'number_of_rescue_session') int get numberOfRescueSession;
/// Create a copy of CollectionConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CollectionConfigCopyWith<CollectionConfig> get copyWith => _$CollectionConfigCopyWithImpl<CollectionConfig>(this as CollectionConfig, _$identity);

  /// Serializes this CollectionConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CollectionConfig&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.code, code) || other.code == code)&&(identical(other.active, active) || other.active == active)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&(identical(other.companyName, companyName) || other.companyName == companyName)&&(identical(other.journalId, journalId) || other.journalId == journalId)&&(identical(other.journalName, journalName) || other.journalName == journalName)&&(identical(other.cashJournalId, cashJournalId) || other.cashJournalId == cashJournalId)&&(identical(other.cashJournalName, cashJournalName) || other.cashJournalName == cashJournalName)&&const DeepCollectionEquality().equals(other.allowedJournalIds, allowedJournalIds)&&(identical(other.cashDifferenceAccountId, cashDifferenceAccountId) || other.cashDifferenceAccountId == cashDifferenceAccountId)&&(identical(other.currencyId, currencyId) || other.currencyId == currencyId)&&(identical(other.currencyName, currencyName) || other.currencyName == currencyName)&&(identical(other.setMaximumDifference, setMaximumDifference) || other.setMaximumDifference == setMaximumDifference)&&(identical(other.amountAuthorizedDiff, amountAuthorizedDiff) || other.amountAuthorizedDiff == amountAuthorizedDiff)&&const DeepCollectionEquality().equals(other.userIds, userIds)&&(identical(other.currentSessionId, currentSessionId) || other.currentSessionId == currentSessionId)&&(identical(other.currentSessionState, currentSessionState) || other.currentSessionState == currentSessionState)&&(identical(other.currentSessionName, currentSessionName) || other.currentSessionName == currentSessionName)&&(identical(other.numberOfOpenedSession, numberOfOpenedSession) || other.numberOfOpenedSession == numberOfOpenedSession)&&(identical(other.lastSessionClosingDate, lastSessionClosingDate) || other.lastSessionClosingDate == lastSessionClosingDate)&&(identical(other.lastSessionClosingCash, lastSessionClosingCash) || other.lastSessionClosingCash == lastSessionClosingCash)&&(identical(other.currentSessionUserName, currentSessionUserName) || other.currentSessionUserName == currentSessionUserName)&&(identical(other.currentSessionStateDisplay, currentSessionStateDisplay) || other.currentSessionStateDisplay == currentSessionStateDisplay)&&(identical(other.numberOfRescueSession, numberOfRescueSession) || other.numberOfRescueSession == numberOfRescueSession));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,name,code,active,companyId,companyName,journalId,journalName,cashJournalId,cashJournalName,const DeepCollectionEquality().hash(allowedJournalIds),cashDifferenceAccountId,currencyId,currencyName,setMaximumDifference,amountAuthorizedDiff,const DeepCollectionEquality().hash(userIds),currentSessionId,currentSessionState,currentSessionName,numberOfOpenedSession,lastSessionClosingDate,lastSessionClosingCash,currentSessionUserName,currentSessionStateDisplay,numberOfRescueSession]);

@override
String toString() {
  return 'CollectionConfig(id: $id, name: $name, code: $code, active: $active, companyId: $companyId, companyName: $companyName, journalId: $journalId, journalName: $journalName, cashJournalId: $cashJournalId, cashJournalName: $cashJournalName, allowedJournalIds: $allowedJournalIds, cashDifferenceAccountId: $cashDifferenceAccountId, currencyId: $currencyId, currencyName: $currencyName, setMaximumDifference: $setMaximumDifference, amountAuthorizedDiff: $amountAuthorizedDiff, userIds: $userIds, currentSessionId: $currentSessionId, currentSessionState: $currentSessionState, currentSessionName: $currentSessionName, numberOfOpenedSession: $numberOfOpenedSession, lastSessionClosingDate: $lastSessionClosingDate, lastSessionClosingCash: $lastSessionClosingCash, currentSessionUserName: $currentSessionUserName, currentSessionStateDisplay: $currentSessionStateDisplay, numberOfRescueSession: $numberOfRescueSession)';
}


}

/// @nodoc
abstract mixin class $CollectionConfigCopyWith<$Res>  {
  factory $CollectionConfigCopyWith(CollectionConfig value, $Res Function(CollectionConfig) _then) = _$CollectionConfigCopyWithImpl;
@useResult
$Res call({
@OdooId() int id,@OdooString() String name,@OdooString() String code,@OdooBoolean() bool active,@OdooMany2One('res.company', odooName: 'company_id') int? companyId,@OdooMany2OneName(sourceField: 'company_id') String? companyName,@OdooMany2One('account.journal', odooName: 'journal_id') int? journalId,@OdooMany2OneName(sourceField: 'journal_id') String? journalName,@OdooMany2One('account.journal', odooName: 'cash_journal_id') int? cashJournalId,@OdooMany2OneName(sourceField: 'cash_journal_id') String? cashJournalName,@OdooMany2Many('account.journal', odooName: 'allowed_journal_ids') List<int>? allowedJournalIds,@OdooMany2One('account.account', odooName: 'cash_difference_account_id') int? cashDifferenceAccountId,@OdooMany2One('res.currency', odooName: 'currency_id') int? currencyId,@OdooMany2OneName(sourceField: 'currency_id') String? currencyName,@OdooBoolean(odooName: 'set_maximum_difference') bool setMaximumDifference,@OdooFloat(odooName: 'amount_authorized_diff') double amountAuthorizedDiff,@OdooMany2Many('res.users', odooName: 'user_ids') List<int>? userIds,@OdooMany2One('collection.session', odooName: 'current_session_id') int? currentSessionId,@OdooSelection(odooName: 'current_session_state') String? currentSessionState,@OdooString(odooName: 'current_session_name') String? currentSessionName,@OdooInteger(odooName: 'number_of_opened_session') int numberOfOpenedSession,@OdooDateTime(odooName: 'last_session_closing_date') DateTime? lastSessionClosingDate,@OdooFloat(odooName: 'last_session_closing_cash') double lastSessionClosingCash,@OdooString(odooName: 'collection_session_username') String? currentSessionUserName,@OdooString(odooName: 'current_session_state_display') String? currentSessionStateDisplay,@OdooInteger(odooName: 'number_of_rescue_session') int numberOfRescueSession
});




}
/// @nodoc
class _$CollectionConfigCopyWithImpl<$Res>
    implements $CollectionConfigCopyWith<$Res> {
  _$CollectionConfigCopyWithImpl(this._self, this._then);

  final CollectionConfig _self;
  final $Res Function(CollectionConfig) _then;

/// Create a copy of CollectionConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? code = null,Object? active = null,Object? companyId = freezed,Object? companyName = freezed,Object? journalId = freezed,Object? journalName = freezed,Object? cashJournalId = freezed,Object? cashJournalName = freezed,Object? allowedJournalIds = freezed,Object? cashDifferenceAccountId = freezed,Object? currencyId = freezed,Object? currencyName = freezed,Object? setMaximumDifference = null,Object? amountAuthorizedDiff = null,Object? userIds = freezed,Object? currentSessionId = freezed,Object? currentSessionState = freezed,Object? currentSessionName = freezed,Object? numberOfOpenedSession = null,Object? lastSessionClosingDate = freezed,Object? lastSessionClosingCash = null,Object? currentSessionUserName = freezed,Object? currentSessionStateDisplay = freezed,Object? numberOfRescueSession = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,companyId: freezed == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as int?,companyName: freezed == companyName ? _self.companyName : companyName // ignore: cast_nullable_to_non_nullable
as String?,journalId: freezed == journalId ? _self.journalId : journalId // ignore: cast_nullable_to_non_nullable
as int?,journalName: freezed == journalName ? _self.journalName : journalName // ignore: cast_nullable_to_non_nullable
as String?,cashJournalId: freezed == cashJournalId ? _self.cashJournalId : cashJournalId // ignore: cast_nullable_to_non_nullable
as int?,cashJournalName: freezed == cashJournalName ? _self.cashJournalName : cashJournalName // ignore: cast_nullable_to_non_nullable
as String?,allowedJournalIds: freezed == allowedJournalIds ? _self.allowedJournalIds : allowedJournalIds // ignore: cast_nullable_to_non_nullable
as List<int>?,cashDifferenceAccountId: freezed == cashDifferenceAccountId ? _self.cashDifferenceAccountId : cashDifferenceAccountId // ignore: cast_nullable_to_non_nullable
as int?,currencyId: freezed == currencyId ? _self.currencyId : currencyId // ignore: cast_nullable_to_non_nullable
as int?,currencyName: freezed == currencyName ? _self.currencyName : currencyName // ignore: cast_nullable_to_non_nullable
as String?,setMaximumDifference: null == setMaximumDifference ? _self.setMaximumDifference : setMaximumDifference // ignore: cast_nullable_to_non_nullable
as bool,amountAuthorizedDiff: null == amountAuthorizedDiff ? _self.amountAuthorizedDiff : amountAuthorizedDiff // ignore: cast_nullable_to_non_nullable
as double,userIds: freezed == userIds ? _self.userIds : userIds // ignore: cast_nullable_to_non_nullable
as List<int>?,currentSessionId: freezed == currentSessionId ? _self.currentSessionId : currentSessionId // ignore: cast_nullable_to_non_nullable
as int?,currentSessionState: freezed == currentSessionState ? _self.currentSessionState : currentSessionState // ignore: cast_nullable_to_non_nullable
as String?,currentSessionName: freezed == currentSessionName ? _self.currentSessionName : currentSessionName // ignore: cast_nullable_to_non_nullable
as String?,numberOfOpenedSession: null == numberOfOpenedSession ? _self.numberOfOpenedSession : numberOfOpenedSession // ignore: cast_nullable_to_non_nullable
as int,lastSessionClosingDate: freezed == lastSessionClosingDate ? _self.lastSessionClosingDate : lastSessionClosingDate // ignore: cast_nullable_to_non_nullable
as DateTime?,lastSessionClosingCash: null == lastSessionClosingCash ? _self.lastSessionClosingCash : lastSessionClosingCash // ignore: cast_nullable_to_non_nullable
as double,currentSessionUserName: freezed == currentSessionUserName ? _self.currentSessionUserName : currentSessionUserName // ignore: cast_nullable_to_non_nullable
as String?,currentSessionStateDisplay: freezed == currentSessionStateDisplay ? _self.currentSessionStateDisplay : currentSessionStateDisplay // ignore: cast_nullable_to_non_nullable
as String?,numberOfRescueSession: null == numberOfRescueSession ? _self.numberOfRescueSession : numberOfRescueSession // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CollectionConfig].
extension CollectionConfigPatterns on CollectionConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CollectionConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CollectionConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CollectionConfig value)  $default,){
final _that = this;
switch (_that) {
case _CollectionConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CollectionConfig value)?  $default,){
final _that = this;
switch (_that) {
case _CollectionConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooString()  String name, @OdooString()  String code, @OdooBoolean()  bool active, @OdooMany2One('res.company', odooName: 'company_id')  int? companyId, @OdooMany2OneName(sourceField: 'company_id')  String? companyName, @OdooMany2One('account.journal', odooName: 'journal_id')  int? journalId, @OdooMany2OneName(sourceField: 'journal_id')  String? journalName, @OdooMany2One('account.journal', odooName: 'cash_journal_id')  int? cashJournalId, @OdooMany2OneName(sourceField: 'cash_journal_id')  String? cashJournalName, @OdooMany2Many('account.journal', odooName: 'allowed_journal_ids')  List<int>? allowedJournalIds, @OdooMany2One('account.account', odooName: 'cash_difference_account_id')  int? cashDifferenceAccountId, @OdooMany2One('res.currency', odooName: 'currency_id')  int? currencyId, @OdooMany2OneName(sourceField: 'currency_id')  String? currencyName, @OdooBoolean(odooName: 'set_maximum_difference')  bool setMaximumDifference, @OdooFloat(odooName: 'amount_authorized_diff')  double amountAuthorizedDiff, @OdooMany2Many('res.users', odooName: 'user_ids')  List<int>? userIds, @OdooMany2One('collection.session', odooName: 'current_session_id')  int? currentSessionId, @OdooSelection(odooName: 'current_session_state')  String? currentSessionState, @OdooString(odooName: 'current_session_name')  String? currentSessionName, @OdooInteger(odooName: 'number_of_opened_session')  int numberOfOpenedSession, @OdooDateTime(odooName: 'last_session_closing_date')  DateTime? lastSessionClosingDate, @OdooFloat(odooName: 'last_session_closing_cash')  double lastSessionClosingCash, @OdooString(odooName: 'collection_session_username')  String? currentSessionUserName, @OdooString(odooName: 'current_session_state_display')  String? currentSessionStateDisplay, @OdooInteger(odooName: 'number_of_rescue_session')  int numberOfRescueSession)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CollectionConfig() when $default != null:
return $default(_that.id,_that.name,_that.code,_that.active,_that.companyId,_that.companyName,_that.journalId,_that.journalName,_that.cashJournalId,_that.cashJournalName,_that.allowedJournalIds,_that.cashDifferenceAccountId,_that.currencyId,_that.currencyName,_that.setMaximumDifference,_that.amountAuthorizedDiff,_that.userIds,_that.currentSessionId,_that.currentSessionState,_that.currentSessionName,_that.numberOfOpenedSession,_that.lastSessionClosingDate,_that.lastSessionClosingCash,_that.currentSessionUserName,_that.currentSessionStateDisplay,_that.numberOfRescueSession);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooString()  String name, @OdooString()  String code, @OdooBoolean()  bool active, @OdooMany2One('res.company', odooName: 'company_id')  int? companyId, @OdooMany2OneName(sourceField: 'company_id')  String? companyName, @OdooMany2One('account.journal', odooName: 'journal_id')  int? journalId, @OdooMany2OneName(sourceField: 'journal_id')  String? journalName, @OdooMany2One('account.journal', odooName: 'cash_journal_id')  int? cashJournalId, @OdooMany2OneName(sourceField: 'cash_journal_id')  String? cashJournalName, @OdooMany2Many('account.journal', odooName: 'allowed_journal_ids')  List<int>? allowedJournalIds, @OdooMany2One('account.account', odooName: 'cash_difference_account_id')  int? cashDifferenceAccountId, @OdooMany2One('res.currency', odooName: 'currency_id')  int? currencyId, @OdooMany2OneName(sourceField: 'currency_id')  String? currencyName, @OdooBoolean(odooName: 'set_maximum_difference')  bool setMaximumDifference, @OdooFloat(odooName: 'amount_authorized_diff')  double amountAuthorizedDiff, @OdooMany2Many('res.users', odooName: 'user_ids')  List<int>? userIds, @OdooMany2One('collection.session', odooName: 'current_session_id')  int? currentSessionId, @OdooSelection(odooName: 'current_session_state')  String? currentSessionState, @OdooString(odooName: 'current_session_name')  String? currentSessionName, @OdooInteger(odooName: 'number_of_opened_session')  int numberOfOpenedSession, @OdooDateTime(odooName: 'last_session_closing_date')  DateTime? lastSessionClosingDate, @OdooFloat(odooName: 'last_session_closing_cash')  double lastSessionClosingCash, @OdooString(odooName: 'collection_session_username')  String? currentSessionUserName, @OdooString(odooName: 'current_session_state_display')  String? currentSessionStateDisplay, @OdooInteger(odooName: 'number_of_rescue_session')  int numberOfRescueSession)  $default,) {final _that = this;
switch (_that) {
case _CollectionConfig():
return $default(_that.id,_that.name,_that.code,_that.active,_that.companyId,_that.companyName,_that.journalId,_that.journalName,_that.cashJournalId,_that.cashJournalName,_that.allowedJournalIds,_that.cashDifferenceAccountId,_that.currencyId,_that.currencyName,_that.setMaximumDifference,_that.amountAuthorizedDiff,_that.userIds,_that.currentSessionId,_that.currentSessionState,_that.currentSessionName,_that.numberOfOpenedSession,_that.lastSessionClosingDate,_that.lastSessionClosingCash,_that.currentSessionUserName,_that.currentSessionStateDisplay,_that.numberOfRescueSession);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@OdooId()  int id, @OdooString()  String name, @OdooString()  String code, @OdooBoolean()  bool active, @OdooMany2One('res.company', odooName: 'company_id')  int? companyId, @OdooMany2OneName(sourceField: 'company_id')  String? companyName, @OdooMany2One('account.journal', odooName: 'journal_id')  int? journalId, @OdooMany2OneName(sourceField: 'journal_id')  String? journalName, @OdooMany2One('account.journal', odooName: 'cash_journal_id')  int? cashJournalId, @OdooMany2OneName(sourceField: 'cash_journal_id')  String? cashJournalName, @OdooMany2Many('account.journal', odooName: 'allowed_journal_ids')  List<int>? allowedJournalIds, @OdooMany2One('account.account', odooName: 'cash_difference_account_id')  int? cashDifferenceAccountId, @OdooMany2One('res.currency', odooName: 'currency_id')  int? currencyId, @OdooMany2OneName(sourceField: 'currency_id')  String? currencyName, @OdooBoolean(odooName: 'set_maximum_difference')  bool setMaximumDifference, @OdooFloat(odooName: 'amount_authorized_diff')  double amountAuthorizedDiff, @OdooMany2Many('res.users', odooName: 'user_ids')  List<int>? userIds, @OdooMany2One('collection.session', odooName: 'current_session_id')  int? currentSessionId, @OdooSelection(odooName: 'current_session_state')  String? currentSessionState, @OdooString(odooName: 'current_session_name')  String? currentSessionName, @OdooInteger(odooName: 'number_of_opened_session')  int numberOfOpenedSession, @OdooDateTime(odooName: 'last_session_closing_date')  DateTime? lastSessionClosingDate, @OdooFloat(odooName: 'last_session_closing_cash')  double lastSessionClosingCash, @OdooString(odooName: 'collection_session_username')  String? currentSessionUserName, @OdooString(odooName: 'current_session_state_display')  String? currentSessionStateDisplay, @OdooInteger(odooName: 'number_of_rescue_session')  int numberOfRescueSession)?  $default,) {final _that = this;
switch (_that) {
case _CollectionConfig() when $default != null:
return $default(_that.id,_that.name,_that.code,_that.active,_that.companyId,_that.companyName,_that.journalId,_that.journalName,_that.cashJournalId,_that.cashJournalName,_that.allowedJournalIds,_that.cashDifferenceAccountId,_that.currencyId,_that.currencyName,_that.setMaximumDifference,_that.amountAuthorizedDiff,_that.userIds,_that.currentSessionId,_that.currentSessionState,_that.currentSessionName,_that.numberOfOpenedSession,_that.lastSessionClosingDate,_that.lastSessionClosingCash,_that.currentSessionUserName,_that.currentSessionStateDisplay,_that.numberOfRescueSession);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CollectionConfig extends CollectionConfig {
  const _CollectionConfig({@OdooId() required this.id, @OdooString() required this.name, @OdooString() required this.code, @OdooBoolean() this.active = true, @OdooMany2One('res.company', odooName: 'company_id') this.companyId, @OdooMany2OneName(sourceField: 'company_id') this.companyName, @OdooMany2One('account.journal', odooName: 'journal_id') this.journalId, @OdooMany2OneName(sourceField: 'journal_id') this.journalName, @OdooMany2One('account.journal', odooName: 'cash_journal_id') this.cashJournalId, @OdooMany2OneName(sourceField: 'cash_journal_id') this.cashJournalName, @OdooMany2Many('account.journal', odooName: 'allowed_journal_ids') final  List<int>? allowedJournalIds, @OdooMany2One('account.account', odooName: 'cash_difference_account_id') this.cashDifferenceAccountId, @OdooMany2One('res.currency', odooName: 'currency_id') this.currencyId, @OdooMany2OneName(sourceField: 'currency_id') this.currencyName, @OdooBoolean(odooName: 'set_maximum_difference') this.setMaximumDifference = false, @OdooFloat(odooName: 'amount_authorized_diff') this.amountAuthorizedDiff = 0.0, @OdooMany2Many('res.users', odooName: 'user_ids') final  List<int>? userIds, @OdooMany2One('collection.session', odooName: 'current_session_id') this.currentSessionId, @OdooSelection(odooName: 'current_session_state') this.currentSessionState, @OdooString(odooName: 'current_session_name') this.currentSessionName, @OdooInteger(odooName: 'number_of_opened_session') this.numberOfOpenedSession = 0, @OdooDateTime(odooName: 'last_session_closing_date') this.lastSessionClosingDate, @OdooFloat(odooName: 'last_session_closing_cash') this.lastSessionClosingCash = 0.0, @OdooString(odooName: 'collection_session_username') this.currentSessionUserName, @OdooString(odooName: 'current_session_state_display') this.currentSessionStateDisplay, @OdooInteger(odooName: 'number_of_rescue_session') this.numberOfRescueSession = 0}): _allowedJournalIds = allowedJournalIds,_userIds = userIds,super._();
  factory _CollectionConfig.fromJson(Map<String, dynamic> json) => _$CollectionConfigFromJson(json);

// ============ Identifiers ============
@override@OdooId() final  int id;
// ============ Basic Data ============
@override@OdooString() final  String name;
@override@OdooString() final  String code;
@override@JsonKey()@OdooBoolean() final  bool active;
// ============ Relations ============
@override@OdooMany2One('res.company', odooName: 'company_id') final  int? companyId;
@override@OdooMany2OneName(sourceField: 'company_id') final  String? companyName;
@override@OdooMany2One('account.journal', odooName: 'journal_id') final  int? journalId;
@override@OdooMany2OneName(sourceField: 'journal_id') final  String? journalName;
@override@OdooMany2One('account.journal', odooName: 'cash_journal_id') final  int? cashJournalId;
@override@OdooMany2OneName(sourceField: 'cash_journal_id') final  String? cashJournalName;
 final  List<int>? _allowedJournalIds;
@override@OdooMany2Many('account.journal', odooName: 'allowed_journal_ids') List<int>? get allowedJournalIds {
  final value = _allowedJournalIds;
  if (value == null) return null;
  if (_allowedJournalIds is EqualUnmodifiableListView) return _allowedJournalIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override@OdooMany2One('account.account', odooName: 'cash_difference_account_id') final  int? cashDifferenceAccountId;
@override@OdooMany2One('res.currency', odooName: 'currency_id') final  int? currencyId;
@override@OdooMany2OneName(sourceField: 'currency_id') final  String? currencyName;
// ============ Configuration Fields ============
@override@JsonKey()@OdooBoolean(odooName: 'set_maximum_difference') final  bool setMaximumDifference;
@override@JsonKey()@OdooFloat(odooName: 'amount_authorized_diff') final  double amountAuthorizedDiff;
 final  List<int>? _userIds;
@override@OdooMany2Many('res.users', odooName: 'user_ids') List<int>? get userIds {
  final value = _userIds;
  if (value == null) return null;
  if (_userIds is EqualUnmodifiableListView) return _userIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

// ============ Session Fields ============
@override@OdooMany2One('collection.session', odooName: 'current_session_id') final  int? currentSessionId;
@override@OdooSelection(odooName: 'current_session_state') final  String? currentSessionState;
@override@OdooString(odooName: 'current_session_name') final  String? currentSessionName;
@override@JsonKey()@OdooInteger(odooName: 'number_of_opened_session') final  int numberOfOpenedSession;
@override@OdooDateTime(odooName: 'last_session_closing_date') final  DateTime? lastSessionClosingDate;
@override@JsonKey()@OdooFloat(odooName: 'last_session_closing_cash') final  double lastSessionClosingCash;
// ============ Dashboard Display Fields ============
@override@OdooString(odooName: 'collection_session_username') final  String? currentSessionUserName;
@override@OdooString(odooName: 'current_session_state_display') final  String? currentSessionStateDisplay;
@override@JsonKey()@OdooInteger(odooName: 'number_of_rescue_session') final  int numberOfRescueSession;

/// Create a copy of CollectionConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CollectionConfigCopyWith<_CollectionConfig> get copyWith => __$CollectionConfigCopyWithImpl<_CollectionConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CollectionConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CollectionConfig&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.code, code) || other.code == code)&&(identical(other.active, active) || other.active == active)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&(identical(other.companyName, companyName) || other.companyName == companyName)&&(identical(other.journalId, journalId) || other.journalId == journalId)&&(identical(other.journalName, journalName) || other.journalName == journalName)&&(identical(other.cashJournalId, cashJournalId) || other.cashJournalId == cashJournalId)&&(identical(other.cashJournalName, cashJournalName) || other.cashJournalName == cashJournalName)&&const DeepCollectionEquality().equals(other._allowedJournalIds, _allowedJournalIds)&&(identical(other.cashDifferenceAccountId, cashDifferenceAccountId) || other.cashDifferenceAccountId == cashDifferenceAccountId)&&(identical(other.currencyId, currencyId) || other.currencyId == currencyId)&&(identical(other.currencyName, currencyName) || other.currencyName == currencyName)&&(identical(other.setMaximumDifference, setMaximumDifference) || other.setMaximumDifference == setMaximumDifference)&&(identical(other.amountAuthorizedDiff, amountAuthorizedDiff) || other.amountAuthorizedDiff == amountAuthorizedDiff)&&const DeepCollectionEquality().equals(other._userIds, _userIds)&&(identical(other.currentSessionId, currentSessionId) || other.currentSessionId == currentSessionId)&&(identical(other.currentSessionState, currentSessionState) || other.currentSessionState == currentSessionState)&&(identical(other.currentSessionName, currentSessionName) || other.currentSessionName == currentSessionName)&&(identical(other.numberOfOpenedSession, numberOfOpenedSession) || other.numberOfOpenedSession == numberOfOpenedSession)&&(identical(other.lastSessionClosingDate, lastSessionClosingDate) || other.lastSessionClosingDate == lastSessionClosingDate)&&(identical(other.lastSessionClosingCash, lastSessionClosingCash) || other.lastSessionClosingCash == lastSessionClosingCash)&&(identical(other.currentSessionUserName, currentSessionUserName) || other.currentSessionUserName == currentSessionUserName)&&(identical(other.currentSessionStateDisplay, currentSessionStateDisplay) || other.currentSessionStateDisplay == currentSessionStateDisplay)&&(identical(other.numberOfRescueSession, numberOfRescueSession) || other.numberOfRescueSession == numberOfRescueSession));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,name,code,active,companyId,companyName,journalId,journalName,cashJournalId,cashJournalName,const DeepCollectionEquality().hash(_allowedJournalIds),cashDifferenceAccountId,currencyId,currencyName,setMaximumDifference,amountAuthorizedDiff,const DeepCollectionEquality().hash(_userIds),currentSessionId,currentSessionState,currentSessionName,numberOfOpenedSession,lastSessionClosingDate,lastSessionClosingCash,currentSessionUserName,currentSessionStateDisplay,numberOfRescueSession]);

@override
String toString() {
  return 'CollectionConfig(id: $id, name: $name, code: $code, active: $active, companyId: $companyId, companyName: $companyName, journalId: $journalId, journalName: $journalName, cashJournalId: $cashJournalId, cashJournalName: $cashJournalName, allowedJournalIds: $allowedJournalIds, cashDifferenceAccountId: $cashDifferenceAccountId, currencyId: $currencyId, currencyName: $currencyName, setMaximumDifference: $setMaximumDifference, amountAuthorizedDiff: $amountAuthorizedDiff, userIds: $userIds, currentSessionId: $currentSessionId, currentSessionState: $currentSessionState, currentSessionName: $currentSessionName, numberOfOpenedSession: $numberOfOpenedSession, lastSessionClosingDate: $lastSessionClosingDate, lastSessionClosingCash: $lastSessionClosingCash, currentSessionUserName: $currentSessionUserName, currentSessionStateDisplay: $currentSessionStateDisplay, numberOfRescueSession: $numberOfRescueSession)';
}


}

/// @nodoc
abstract mixin class _$CollectionConfigCopyWith<$Res> implements $CollectionConfigCopyWith<$Res> {
  factory _$CollectionConfigCopyWith(_CollectionConfig value, $Res Function(_CollectionConfig) _then) = __$CollectionConfigCopyWithImpl;
@override @useResult
$Res call({
@OdooId() int id,@OdooString() String name,@OdooString() String code,@OdooBoolean() bool active,@OdooMany2One('res.company', odooName: 'company_id') int? companyId,@OdooMany2OneName(sourceField: 'company_id') String? companyName,@OdooMany2One('account.journal', odooName: 'journal_id') int? journalId,@OdooMany2OneName(sourceField: 'journal_id') String? journalName,@OdooMany2One('account.journal', odooName: 'cash_journal_id') int? cashJournalId,@OdooMany2OneName(sourceField: 'cash_journal_id') String? cashJournalName,@OdooMany2Many('account.journal', odooName: 'allowed_journal_ids') List<int>? allowedJournalIds,@OdooMany2One('account.account', odooName: 'cash_difference_account_id') int? cashDifferenceAccountId,@OdooMany2One('res.currency', odooName: 'currency_id') int? currencyId,@OdooMany2OneName(sourceField: 'currency_id') String? currencyName,@OdooBoolean(odooName: 'set_maximum_difference') bool setMaximumDifference,@OdooFloat(odooName: 'amount_authorized_diff') double amountAuthorizedDiff,@OdooMany2Many('res.users', odooName: 'user_ids') List<int>? userIds,@OdooMany2One('collection.session', odooName: 'current_session_id') int? currentSessionId,@OdooSelection(odooName: 'current_session_state') String? currentSessionState,@OdooString(odooName: 'current_session_name') String? currentSessionName,@OdooInteger(odooName: 'number_of_opened_session') int numberOfOpenedSession,@OdooDateTime(odooName: 'last_session_closing_date') DateTime? lastSessionClosingDate,@OdooFloat(odooName: 'last_session_closing_cash') double lastSessionClosingCash,@OdooString(odooName: 'collection_session_username') String? currentSessionUserName,@OdooString(odooName: 'current_session_state_display') String? currentSessionStateDisplay,@OdooInteger(odooName: 'number_of_rescue_session') int numberOfRescueSession
});




}
/// @nodoc
class __$CollectionConfigCopyWithImpl<$Res>
    implements _$CollectionConfigCopyWith<$Res> {
  __$CollectionConfigCopyWithImpl(this._self, this._then);

  final _CollectionConfig _self;
  final $Res Function(_CollectionConfig) _then;

/// Create a copy of CollectionConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? code = null,Object? active = null,Object? companyId = freezed,Object? companyName = freezed,Object? journalId = freezed,Object? journalName = freezed,Object? cashJournalId = freezed,Object? cashJournalName = freezed,Object? allowedJournalIds = freezed,Object? cashDifferenceAccountId = freezed,Object? currencyId = freezed,Object? currencyName = freezed,Object? setMaximumDifference = null,Object? amountAuthorizedDiff = null,Object? userIds = freezed,Object? currentSessionId = freezed,Object? currentSessionState = freezed,Object? currentSessionName = freezed,Object? numberOfOpenedSession = null,Object? lastSessionClosingDate = freezed,Object? lastSessionClosingCash = null,Object? currentSessionUserName = freezed,Object? currentSessionStateDisplay = freezed,Object? numberOfRescueSession = null,}) {
  return _then(_CollectionConfig(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,companyId: freezed == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as int?,companyName: freezed == companyName ? _self.companyName : companyName // ignore: cast_nullable_to_non_nullable
as String?,journalId: freezed == journalId ? _self.journalId : journalId // ignore: cast_nullable_to_non_nullable
as int?,journalName: freezed == journalName ? _self.journalName : journalName // ignore: cast_nullable_to_non_nullable
as String?,cashJournalId: freezed == cashJournalId ? _self.cashJournalId : cashJournalId // ignore: cast_nullable_to_non_nullable
as int?,cashJournalName: freezed == cashJournalName ? _self.cashJournalName : cashJournalName // ignore: cast_nullable_to_non_nullable
as String?,allowedJournalIds: freezed == allowedJournalIds ? _self._allowedJournalIds : allowedJournalIds // ignore: cast_nullable_to_non_nullable
as List<int>?,cashDifferenceAccountId: freezed == cashDifferenceAccountId ? _self.cashDifferenceAccountId : cashDifferenceAccountId // ignore: cast_nullable_to_non_nullable
as int?,currencyId: freezed == currencyId ? _self.currencyId : currencyId // ignore: cast_nullable_to_non_nullable
as int?,currencyName: freezed == currencyName ? _self.currencyName : currencyName // ignore: cast_nullable_to_non_nullable
as String?,setMaximumDifference: null == setMaximumDifference ? _self.setMaximumDifference : setMaximumDifference // ignore: cast_nullable_to_non_nullable
as bool,amountAuthorizedDiff: null == amountAuthorizedDiff ? _self.amountAuthorizedDiff : amountAuthorizedDiff // ignore: cast_nullable_to_non_nullable
as double,userIds: freezed == userIds ? _self._userIds : userIds // ignore: cast_nullable_to_non_nullable
as List<int>?,currentSessionId: freezed == currentSessionId ? _self.currentSessionId : currentSessionId // ignore: cast_nullable_to_non_nullable
as int?,currentSessionState: freezed == currentSessionState ? _self.currentSessionState : currentSessionState // ignore: cast_nullable_to_non_nullable
as String?,currentSessionName: freezed == currentSessionName ? _self.currentSessionName : currentSessionName // ignore: cast_nullable_to_non_nullable
as String?,numberOfOpenedSession: null == numberOfOpenedSession ? _self.numberOfOpenedSession : numberOfOpenedSession // ignore: cast_nullable_to_non_nullable
as int,lastSessionClosingDate: freezed == lastSessionClosingDate ? _self.lastSessionClosingDate : lastSessionClosingDate // ignore: cast_nullable_to_non_nullable
as DateTime?,lastSessionClosingCash: null == lastSessionClosingCash ? _self.lastSessionClosingCash : lastSessionClosingCash // ignore: cast_nullable_to_non_nullable
as double,currentSessionUserName: freezed == currentSessionUserName ? _self.currentSessionUserName : currentSessionUserName // ignore: cast_nullable_to_non_nullable
as String?,currentSessionStateDisplay: freezed == currentSessionStateDisplay ? _self.currentSessionStateDisplay : currentSessionStateDisplay // ignore: cast_nullable_to_non_nullable
as String?,numberOfRescueSession: null == numberOfRescueSession ? _self.numberOfRescueSession : numberOfRescueSession // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
