import 'package:flutter/foundation.dart';

import 'environment_reader.dart';

/// Opt-in configuration for the live, read-only integration journey.
///
/// Secrets are accepted only from compile-time dart-defines or the native
/// process environment. They are never serialized and [toString] is redacted.
final class E2eConfiguration {
  const E2eConfiguration._({
    required this.enabled,
    required this.readOnly,
    required this.allowWrites,
    required this.serverUrl,
    required this.database,
    required this.apiKey,
    required this.expectedUserId,
    required this.skipReason,
  });

  static const _defaultServerUrl = 'https://erp2.tecnosmart.com.ec';
  static const _defaultDatabase = 'erp2_tecnosmart_com_ec';

  static const _defineEnabled = String.fromEnvironment('THEOS_E2E_ENABLED');
  static const _defineReadOnly = String.fromEnvironment('THEOS_E2E_READ_ONLY');
  static const _defineAllowWrites = String.fromEnvironment(
    'THEOS_E2E_ALLOW_WRITES',
  );
  static const _defineServerUrl = String.fromEnvironment(
    'THEOS_E2E_SERVER_URL',
  );
  static const _defineDatabase = String.fromEnvironment('THEOS_E2E_DATABASE');
  static const _defineApiKey = String.fromEnvironment('THEOS_E2E_API_KEY');
  static const _defineExpectedUid = String.fromEnvironment(
    'THEOS_E2E_EXPECTED_UID',
  );

  final bool enabled;
  final bool readOnly;
  final bool allowWrites;
  final String serverUrl;
  final String database;
  final String apiKey;
  final int? expectedUserId;
  final String? skipReason;

  bool get canRun => skipReason == null;

  factory E2eConfiguration.fromEnvironment({bool businessJourney = false}) =>
      E2eConfiguration.resolve(
        dartDefines: const <String, String>{
          'THEOS_E2E_ENABLED': _defineEnabled,
          'THEOS_E2E_READ_ONLY': _defineReadOnly,
          'THEOS_E2E_ALLOW_WRITES': _defineAllowWrites,
          'THEOS_E2E_SERVER_URL': _defineServerUrl,
          'THEOS_E2E_DATABASE': _defineDatabase,
          'THEOS_E2E_API_KEY': _defineApiKey,
          'THEOS_E2E_EXPECTED_UID': _defineExpectedUid,
        },
        processEnvironment: _readProcessEnvironment(),
        isWeb: kIsWeb,
        isRelease: kReleaseMode,
        businessJourney: businessJourney,
      );

  static Map<String, String> _readProcessEnvironment() {
    final values = <String, String>{};
    for (final name in const <String>[
      'THEOS_E2E_ENABLED',
      'THEOS_E2E_READ_ONLY',
      'THEOS_E2E_ALLOW_WRITES',
      'THEOS_E2E_SERVER_URL',
      'THEOS_E2E_DATABASE',
      'THEOS_E2E_API_KEY',
      'THEOS_E2E_EXPECTED_UID',
    ]) {
      final value = readProcessEnvironment(name);
      if (value != null) values[name] = value;
    }
    return values;
  }

  @visibleForTesting
  factory E2eConfiguration.resolve({
    Map<String, String> dartDefines = const <String, String>{},
    Map<String, String> processEnvironment = const <String, String>{},
    bool isWeb = false,
    bool isRelease = false,
    bool businessJourney = false,
  }) {
    String value(String name, [String fallback = '']) {
      final environmentValue = processEnvironment[name]?.trim();
      if (environmentValue != null && environmentValue.isNotEmpty) {
        return environmentValue;
      }
      final defineValue = dartDefines[name]?.trim();
      return defineValue == null || defineValue.isEmpty
          ? fallback
          : defineValue;
    }

    bool flag(String name) => value(name).toLowerCase() == 'true';

    final enabled = flag('THEOS_E2E_ENABLED');
    final readOnly = flag('THEOS_E2E_READ_ONLY');
    final allowWrites = businessJourney && flag('THEOS_E2E_ALLOW_WRITES');
    final serverUrl = value('THEOS_E2E_SERVER_URL', _defaultServerUrl);
    final database = value('THEOS_E2E_DATABASE', _defaultDatabase);
    final apiKey = value('THEOS_E2E_API_KEY');
    final expectedUidRaw = value('THEOS_E2E_EXPECTED_UID');
    final parsedExpectedUserId = expectedUidRaw.isEmpty
        ? null
        : int.tryParse(expectedUidRaw);
    final expectedUidIsInvalid =
        expectedUidRaw.isNotEmpty &&
        (parsedExpectedUserId == null || parsedExpectedUserId <= 0);
    final uri = Uri.tryParse(serverUrl);

    String? skipReason;
    if (!enabled) {
      skipReason = 'Set THEOS_E2E_ENABLED=true to run the live journey.';
    } else if (businessJourney && !allowWrites) {
      skipReason =
          'THEOS_E2E_ALLOW_WRITES=true is mandatory for the business journey.';
    } else if (businessJourney && readOnly) {
      skipReason =
          'THEOS_E2E_READ_ONLY=false is mandatory for the business journey.';
    } else if (uri?.host.toLowerCase().replaceFirst(RegExp(r'\.$'), '') ==
        'newerp.tecnosmart.com.ec') {
      skipReason = 'Production newerp is prohibited for E2E, including reads.';
    } else if (isRelease) {
      skipReason = 'The credentialed E2E journey is disabled in release mode.';
    } else if (isWeb) {
      skipReason = 'Run credentialed E2E on a native debug target, not Web.';
    } else if (!businessJourney && !readOnly) {
      skipReason = 'THEOS_E2E_READ_ONLY=true is mandatory.';
    } else if (apiKey.isEmpty) {
      skipReason = 'Provide THEOS_E2E_API_KEY through the environment.';
    } else if (database.isEmpty) {
      skipReason = 'THEOS_E2E_DATABASE cannot be empty.';
    } else if (expectedUidIsInvalid) {
      skipReason = 'THEOS_E2E_EXPECTED_UID must be a positive integer.';
    } else if (businessJourney && expectedUidRaw.isEmpty) {
      skipReason =
          'THEOS_E2E_EXPECTED_UID is mandatory for the business journey.';
    } else if (businessJourney &&
        (uri == null ||
            uri.scheme != 'https' ||
            uri.host != 'erp2.tecnosmart.com.ec' ||
            uri.userInfo.isNotEmpty ||
            uri.hasPort ||
            uri.query.isNotEmpty ||
            uri.fragment.isNotEmpty ||
            (uri.path.isNotEmpty && uri.path != '/'))) {
      skipReason = 'Business journey requires the exact ERP2 HTTPS server URL.';
    } else if (businessJourney && database != _defaultDatabase) {
      skipReason = 'Business journey requires the exact ERP2 database.';
    } else if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'https' && !_isLoopbackHost(uri.host))) {
      skipReason = 'THEOS_E2E_SERVER_URL must use HTTPS or loopback HTTP.';
    }

    return E2eConfiguration._(
      enabled: enabled,
      readOnly: readOnly,
      allowWrites: allowWrites,
      serverUrl: serverUrl,
      database: database,
      apiKey: apiKey,
      expectedUserId: parsedExpectedUserId,
      skipReason: skipReason,
    );
  }

  static bool _isLoopbackHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '::1';
  }

  @override
  String toString() =>
      'E2eConfiguration(enabled: $enabled, readOnly: $readOnly, '
      'allowWrites: $allowWrites, '
      'serverUrl: $serverUrl, database: $database, apiKey: [REDACTED], '
      'expectedUserId: $expectedUserId, '
      'canRun: $canRun)';
}
