import 'package:theos_pos_core/theos_pos_core.dart';

import '../contracts.dart';
import '../storage/runtime_database_owner.dart';
import 'native_auth_service.dart';

abstract interface class CapabilityReader {
  Future<CapabilitySnapshot> fetch(AppScope scope, int companyId);
}

final class RuntimeCapabilityService {
  final RuntimeDatabaseOwner owner;
  final CapabilityReader reader;
  const RuntimeCapabilityService({required this.owner, required this.reader});

  Future<CapabilitySnapshot> refresh({
    required AppScope scope,
    required SessionLease lease,
    required int companyId,
  }) async {
    if (!owner.accepts(lease)) throw StateError('Capability lease is stale');
    final snapshot = await reader.fetch(scope, companyId);
    if (!owner.accepts(lease) ||
        snapshot.scopeKey != scope.scopeKey ||
        snapshot.companyId != companyId) {
      throw StateError('Capability response belongs to a stale scope');
    }
    await CapabilitySnapshotStore(owner.active!.database)
        .save(scope.scopeKey, snapshot);
    return snapshot;
  }

  Future<CapabilitySnapshot?> offline({
    required AppScope scope,
    required int companyId,
  }) async {
    final active = owner.active;
    if (active == null || active.scope != scope) return null;
    return CapabilitySnapshotStore(active.database)
        .read(scope.scopeKey, companyId: companyId);
  }
}

final class RuntimeCapabilitySnapshotPort implements CapabilitySnapshotPort {
  final RuntimeCapabilityService service;
  const RuntimeCapabilitySnapshotPort(this.service);
  @override
  Future<CapabilitySnapshot?> refresh(AppScope scope, int companyId) {
    final lease = service.owner.active?.lease;
    if (lease == null) return Future.value(null);
    return service.refresh(scope: scope, lease: lease, companyId: companyId);
  }

  @override
  Future<CapabilitySnapshot?> offline(AppScope scope, int companyId) =>
      service.offline(scope: scope, companyId: companyId);
}
