import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import '../features/notifications/notification_inbox.dart';
import '../features/notifications/notification_navigator.dart';
import '../features/auth/auth_controller.dart';

final runtimeSessionProvider = Provider<SessionRuntime?>((ref) => null);

/// Bridges the runtime's active lease to the UI inbox contract.
final class SessionNotificationInboxPort implements NotificationInboxPort {
  SessionNotificationInboxPort(this.runtime, {this.capabilities});
  final RuntimeNotificationInbox runtime;
  final CapabilitySnapshot? capabilities;

  void _validate(NotificationScope scope) {
    final active = runtime.sessions.active;
    if (active == null || scope.scopeKey != active.scope.scopeKey) {
      throw StateError('notification scope does not match session');
    }
    final partition = scope.partitionKey;
    if (!_validPartition(partition, companyId: scope.companyId)) {
      throw StateError('notification partition does not match session');
    }
  }

  bool _validPartition(String partition, {int? companyId}) {
    if (partition == 'global') return true;
    final companyPartition = partition.startsWith('company:')
        ? int.tryParse(partition.substring('company:'.length))
        : null;
    return companyPartition != null &&
        companyPartition > 0 &&
        companyId != null &&
        companyPartition == companyId &&
        capabilities?.companyId == companyId;
  }

  @override
  Stream<NotificationInboxSnapshot> watch(NotificationQuery query) async* {
    final active = runtime.sessions.active;
    if (active == null || query.scopeKey != active.scope.scopeKey) {
      yield* Stream<NotificationInboxSnapshot>.error(
        StateError('notification scope does not match session'),
      );
      return;
    }
    // 🔴 Antes se llamaba sin `companyId`, y el parámetro nombrado por
    // omisión es `null`. Para cualquier partición `company:<id>` (que es la
    // que arma el router para toda sesión con compañía activa, la normal) la
    // condición de `_validPartition` exige `companyId != null` y nunca podía
    // cumplirse: el `StateError` salía ANTES de tocar `runtime.watch`, sin
    // una sola petición de red, y la UI lo mostraba como «No se pudo cargar
    // avisos» — un mensaje de fallo de carga para lo que en realidad era un
    // rechazo de permisos que ni llegaba a intentar la lectura.
    if (!_validPartition(query.partitionKey, companyId: capabilities?.companyId)) {
      yield* Stream<NotificationInboxSnapshot>.error(
        StateError('notification partition does not match session'),
      );
      return;
    }
    // `runtime.watch` emite la página COMPLETA y vigente en cada cambio (no
    // una fila nueva por emisión) — se REEMPLAZA el snapshot, no se acumula;
    // acumular volvería a agregar la misma fila en cada re-emisión.
    await for (final entries in runtime.watch(query)) {
      yield NotificationInboxSnapshot(
        entries: entries,
        unreadCount: entries.where((item) => item.readAt == null).length,
      );
    }
  }

  @override
  Future<NotificationIngestResult> ingest(
    NotificationEvent event, {
    bool baseline = false,
  }) async {
    _validate(event.scope);
    await runtime.ingest(event, baseline: baseline);
    return baseline
        ? NotificationIngestResult.baseline
        : NotificationIngestResult.inserted;
  }

  @override
  Future<int> markRead(String id, NotificationScope scope) {
    _validate(scope);
    return runtime.markRead(id, scope);
  }

  @override
  Future<int> markUnread(String id, NotificationScope scope) {
    _validate(scope);
    return runtime.markUnread(id, scope);
  }

  @override
  Future<int> archive(String id, NotificationScope scope) {
    _validate(scope);
    return runtime.archive(id, scope);
  }
}

final sessionNotificationInboxPortProvider = Provider<NotificationInboxPort?>((
  ref,
) {
  final runtime = ref.watch(runtimeSessionProvider);
  final allocator = ref.watch(notificationSystemIdAllocatorProvider);
  final capabilities = ref.watch(capabilitySnapshotProvider);
  if (runtime == null || allocator == null) return null;
  return SessionNotificationInboxPort(
    RuntimeNotificationInbox(runtime, allocator: allocator),
    capabilities: capabilities,
  );
});

final notificationSystemIdAllocatorProvider =
    Provider<NotificationSystemIdAllocator?>((ref) => null);

NotificationNavigator sessionNotificationNavigator({
  required SessionRuntime runtime,
  required CapabilitySnapshot? capabilities,
  required NotificationTargetOpener opener,
}) => NotificationNavigator(
  validation: _SessionNotificationValidation(runtime, capabilities),
  opener: opener,
  allowedTargetTypes: const {'activity', 'document', 'order'},
);

final class _SessionNotificationValidation
    implements NotificationNavigationValidation {
  _SessionNotificationValidation(this.runtime, this.capabilities);
  final SessionRuntime runtime;
  final CapabilitySnapshot? capabilities;

  @override
  Future<bool> sessionIsActive(NotificationScope scope) async =>
      runtime.active?.scope.scopeKey == scope.scopeKey;

  @override
  Future<bool> companyIsAllowed(NotificationScope scope) async =>
      scope.companyId == null || capabilities?.companyId == scope.companyId;

  @override
  Future<bool> targetExists(
    NotificationTarget target,
    NotificationScope scope,
  ) async => target.reference.trim().isNotEmpty;

  @override
  Future<bool> canOpen(
    NotificationTarget target,
    NotificationScope scope,
  ) async {
    final permission = switch (target.type) {
      'activity' => 'activities',
      'document' => 'reports',
      'order' => 'seller',
      _ => '',
    };
    return permission.isNotEmpty &&
        capabilities?.permissions.contains(permission) == true;
  }
}
