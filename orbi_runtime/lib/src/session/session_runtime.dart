// The optional private factory is intentionally selected in the initializer.
// ignore_for_file: prefer_initializing_formals
import '../contracts.dart';
import '../storage/runtime_database_owner.dart';

import 'package:odoo_sdk/odoo_sdk.dart';

typedef RuntimeClientFactory = OdooClient Function(
  AppScope scope,
  String apiKey,
);

/// Coordinates activation and teardown without owning credentials or UI state.
final class SessionRuntime {
  SessionRuntime({
    RuntimeDatabaseOwner? databaseOwner,
    RuntimeClientFactory? clientFactory,
  }) : _databaseOwner = databaseOwner ?? RuntimeDatabaseOwner(),
       _clientFactory = clientFactory;

  final RuntimeDatabaseOwner _databaseOwner;
  final RuntimeClientFactory? _clientFactory;
  SessionActivation? _active;
  int _activationEpoch = 0;

  SessionActivation? get active => _active;

  /// Exposes the already-owned database boundary to composition adapters.
  /// Callers must not construct another owner from this value.
  RuntimeDatabaseOwner get databaseOwner => _databaseOwner;

  Future<SessionActivation> activate(
    AppScope scope, {
    String? apiKey,
    bool webSession = false,
    String? csrfToken,
  }) async {
    final requestEpoch = ++_activationEpoch;
    final database = await _databaseOwner.open(scope);
    if (requestEpoch != _activationEpoch) {
      throw StateError('Session activation superseded by a newer request');
    }
    final client = apiKey == null && !webSession
        ? null
        : webSession
            ? _webSessionClient(scope, csrfToken)
            : (_clientFactory ?? _defaultClient)(scope, apiKey!);
    final activation = SessionActivation(database: database, client: client);
    _active = activation;
    return activation;
  }

  Future<void> close() async {
    ++_activationEpoch;
    _active = null;
    await _databaseOwner.close();
  }

  bool accepts(SessionLease lease) => _active?.database.lease == lease;

  static OdooClient _defaultClient(AppScope scope, String apiKey) => OdooClient(
    config: OdooClientConfig(
      baseUrl: scope.normalizedServerUrl,
      apiKey: apiKey,
      database: scope.database,
    ),
  );

  static OdooClient _webSessionClient(AppScope scope, String? csrfToken) =>
      OdooClient(
        config: OdooClientConfig(
          baseUrl: scope.normalizedServerUrl,
          apiKey: '',
          database: scope.database,
          csrfToken: csrfToken,
          transportMode: OdooTransportMode.webSession,
        ),
      );
}

final class SessionActivation {
  const SessionActivation({required this.database, this.client});

  final RuntimeDatabase database;
  final OdooClient? client;

  AppScope get scope => database.scope;
  SessionLease get lease => database.lease;
}
