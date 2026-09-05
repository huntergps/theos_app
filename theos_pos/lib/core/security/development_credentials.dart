import 'package:flutter/foundation.dart';

// The environment value is evaluated only in the native-debug branch. In Web,
// profile and release compilations the constant is the empty string, so the
// credential value is not retained merely because somebody supplied the define
// manually instead of using the guarded launcher.
const _nativeDebugErp2ApiKey = kDebugMode && !kIsWeb
    ? String.fromEnvironment('THEOS_ERP2_API_KEY')
    : '';

/// Selects a compile-time development credential only for native debug builds.
///
/// Web artifacts and profile/release artifacts must never contain an injected
/// ERP credential. Keeping the policy in a pure function makes that boundary
/// directly testable without relying on the current compiler mode.
String selectDevelopmentCredential({
  required bool isDebugMode,
  required bool isWeb,
  required String injectedValue,
}) {
  if (!isDebugMode || isWeb) return '';
  return injectedValue;
}

String get developmentErp2ApiKey => selectDevelopmentCredential(
  isDebugMode: kDebugMode,
  isWeb: kIsWeb,
  injectedValue: _nativeDebugErp2ApiKey,
);
