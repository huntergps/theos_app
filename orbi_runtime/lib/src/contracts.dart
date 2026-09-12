library;

import 'dart:convert';

/// Stable, non-secret identity of one app installation and Odoo user scope.
final class AppScope {
  AppScope({
    required String appId,
    required String installationId,
    required String normalizedServerUrl,
    required String database,
    required int userId,
  }) : appId = _required(appId, 'appId'),
       installationId = _required(installationId, 'installationId'),
       normalizedServerUrl = _normalizeServerUrl(normalizedServerUrl),
       database = _required(database, 'database'),
       userId = _positive(userId, 'userId');

  final String appId;
  final String installationId;
  final String normalizedServerUrl;
  final String database;
  final int userId;

  /// Length-prefixed JSON avoids ambiguous delimiter concatenation.
  String get scopeKey => jsonEncode([
    appId,
    installationId,
    normalizedServerUrl,
    database,
    userId,
  ]);

  AppScope copyWith({
    String? appId,
    String? installationId,
    String? normalizedServerUrl,
    String? database,
    int? userId,
  }) => AppScope(
    appId: appId ?? this.appId,
    installationId: installationId ?? this.installationId,
    normalizedServerUrl: normalizedServerUrl ?? this.normalizedServerUrl,
    database: database ?? this.database,
    userId: userId ?? this.userId,
  );

  @override
  bool operator ==(Object other) =>
      other is AppScope &&
      other.appId == appId &&
      other.installationId == installationId &&
      other.normalizedServerUrl == normalizedServerUrl &&
      other.database == database &&
      other.userId == userId;

  @override
  int get hashCode =>
      Object.hash(appId, installationId, normalizedServerUrl, database, userId);

  @override
  String toString() =>
      'AppScope($normalizedServerUrl/$database, user: $userId)';
}

/// Effective company partition inside an [AppScope].
final class CompanyContext {
  CompanyContext({
    required this.companyId,
    required Iterable<int> allowedCompanyIds,
    required String scopeKey,
    required this.capabilityRevision,
  }) : allowedCompanyIds = _companyIds(allowedCompanyIds, companyId),
       scopeKey = _required(scopeKey, 'scopeKey') {
    if (capabilityRevision < 0) {
      throw ArgumentError.value(capabilityRevision, 'capabilityRevision');
    }
  }

  factory CompanyContext.forScope({
    required AppScope scope,
    required int companyId,
    required Iterable<int> allowedCompanyIds,
    required int capabilityRevision,
  }) => CompanyContext(
    companyId: companyId,
    allowedCompanyIds: allowedCompanyIds,
    scopeKey: scope.scopeKey,
    capabilityRevision: capabilityRevision,
  );

  final int companyId;
  final List<int> allowedCompanyIds;
  final String scopeKey;
  final int capabilityRevision;

  @override
  bool operator ==(Object other) =>
      other is CompanyContext &&
      other.companyId == companyId &&
      other.scopeKey == scopeKey &&
      other.capabilityRevision == capabilityRevision &&
      _sameInts(other.allowedCompanyIds, allowedCompanyIds);

  @override
  int get hashCode => Object.hash(
    companyId,
    scopeKey,
    capabilityRevision,
    Object.hashAll(allowedCompanyIds),
  );
}

/// Generation-bound lease used to reject work completing after a scope change.
final class SessionLease {
  SessionLease({required this.scope, required int generation})
    : generation = _positive(generation, 'generation');

  final AppScope scope;
  final int generation;

  bool accepts({required AppScope scope, required int generation}) =>
      this.scope == scope && this.generation == generation;

  @override
  bool operator ==(Object other) =>
      other is SessionLease &&
      other.scope == scope &&
      other.generation == generation;

  @override
  int get hashCode => Object.hash(scope, generation);
}

enum NetworkTransport { none, wifi, mobile, ethernet, vpn, other }

final class NetworkSignal {
  NetworkSignal({
    required Iterable<NetworkTransport> transports,
    DateTime? observedAt,
  }) : transports = List.unmodifiable(_normalizeTransports(transports)),
       observedAt = (observedAt ?? DateTime.now()).toUtc();

  final List<NetworkTransport> transports;
  final DateTime observedAt;

  bool get hasNetwork => !transports.contains(NetworkTransport.none);
}

enum BackendHealthState { unknown, checking, reachable, unreachable }

final class BackendHealth {
  const BackendHealth({
    this.state = BackendHealthState.unknown,
    this.lastCheckedAt,
  });

  final BackendHealthState state;
  final DateTime? lastCheckedAt;
}

enum AuthStatus { authenticated, expired, required, unknown }

/// Un trabajo de sincronización que no terminó, con lo suficiente para poder
/// decírselo a alguien.
///
/// Existe porque el coordinador contaba los fallos y tiraba el error: la
/// pantalla podía decir «5 con error» y nada más, ni siquiera cuáles. El
/// trabajo ya devolvía el error tipado —modelo y campo incluidos— y se
/// descartaba al convertirlo en un entero.
final class SyncFailure {
  SyncFailure({required String jobId, required String message})
    : jobId = _required(jobId, 'jobId'),
      message = _required(message, 'message');

  /// El identificador del trabajo, tal cual lo declara él mismo.
  final String jobId;

  /// Lo que dijo el servidor, sin interpretar. La traducción a algo legible es
  /// de la capa de presentación, no de aquí.
  final String message;
}

final class SyncSnapshot {
  SyncSnapshot({
    this.active = false,
    int queuedCount = 0,
    int conflictCount = 0,
    List<SyncFailure> failures = const [],
    this.lastCompletedAt,
  }) : queuedCount = _nonNegative(queuedCount, 'queuedCount'),
       conflictCount = _nonNegative(conflictCount, 'conflictCount'),
       failures = List.unmodifiable(failures);

  final bool active;
  final int queuedCount;
  final int conflictCount;

  /// Qué falló, no sólo cuánto. Vacía cuando no falló nada.
  final List<SyncFailure> failures;

  final DateTime? lastCompletedAt;

  /// Derivado a propósito: mientras el número y el detalle fueran dos campos
  /// independientes, podían contradecirse, que es como se llegó a un contador
  /// sin nada detrás.
  int get failedCount => failures.length;
}

final class SyncReason {
  SyncReason(String code) : code = _required(code, 'code');
  final String code;
}

final class PauseReason {
  PauseReason(String code) : code = _required(code, 'code');
  final String code;
}

/// Single owner of sync lifecycle and all sync triggers for an active scope.
abstract interface class SyncCoordinator {
  Future<void> start(AppScope scope);

  Future<void> requestSync(SyncReason reason);

  Future<void> pause(PauseReason reason);

  Future<void> stop(AppScope scope);
}

String _required(String value, String name) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be empty');
  }
  return trimmed;
}

int _positive(int value, String name) {
  if (value <= 0) throw ArgumentError.value(value, name, 'Must be positive');
  return value;
}

int _nonNegative(int value, String name) {
  if (value < 0) throw ArgumentError.value(value, name, 'Must not be negative');
  return value;
}

List<int> _companyIds(Iterable<int> values, int selected) {
  _positive(selected, 'companyId');
  final ids = values.toSet().toList(growable: false)..sort();
  if (!ids.contains(selected) || ids.any((id) => id <= 0)) {
    throw ArgumentError.value(
      values,
      'allowedCompanyIds',
      'Must contain positive selected company',
    );
  }
  return List.unmodifiable(ids);
}

List<NetworkTransport> _normalizeTransports(Iterable<NetworkTransport> values) {
  final realTransports =
      values
          .where((transport) => transport != NetworkTransport.none)
          .toSet()
          .toList()
        ..sort((first, second) => first.index.compareTo(second.index));
  return realTransports.isEmpty
      ? const [NetworkTransport.none]
      : realTransports;
}

bool _sameInts(List<int> first, List<int> second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}

String _normalizeServerUrl(String value) {
  final raw = _required(value, 'normalizedServerUrl');
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      !uri.hasAuthority ||
      !{'http', 'https'}.contains(uri.scheme.toLowerCase())) {
    throw ArgumentError.value(
      value,
      'normalizedServerUrl',
      'Must be an HTTP(S) URL',
    );
  }
  if (uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) {
    throw ArgumentError.value(
      value,
      'normalizedServerUrl',
      'Must not contain credentials, query or fragment',
    );
  }
  var path = uri.path;
  while (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  final scheme = uri.scheme.toLowerCase();
  final defaultPort =
      (scheme == 'http' && uri.port == 80) ||
      (scheme == 'https' && uri.port == 443);
  return Uri(
    scheme: scheme,
    host: uri.host.toLowerCase(),
    port: uri.hasPort && !defaultPort ? uri.port : null,
    path: path == '/' ? '' : path,
  ).toString();
}
