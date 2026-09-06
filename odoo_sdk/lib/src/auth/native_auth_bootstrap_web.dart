import 'native_auth_bootstrap_types.dart';

/// Cookie bootstrap is intentionally unavailable in browser builds.
class NativeOdooAuthBootstrap {
  NativeOdooAuthBootstrap({Object? httpClient});

  Future<NativeAuthBootstrapResult> authenticateAndCreateApiKey({
    required String baseUrl,
    required String database,
    required String login,
    required String password,
    String apiKeyName = 'Orbi ERP native login',
  }) async {
    throw const NativeAuthBootstrapException(
      NativeAuthBootstrapFailureKind.unsupportedPlatform,
    );
  }
}
