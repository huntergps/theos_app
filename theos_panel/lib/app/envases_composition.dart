import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import '../features/auth/auth_controller.dart';
import '../features/envases/envases_dashboard_screen.dart';
import 'notification_scope_adapter.dart';
import 'session_composition.dart';

final envasesDashboardControllerProvider =
    Provider.autoDispose<EnvasesDashboardController?>((ref) {
      final runtime = ref.watch(runtimeSessionProvider);
      final capabilities = ref.watch(capabilitySnapshotProvider);
      final active = runtime?.active;
      if (runtime == null ||
          active == null ||
          capabilities == null ||
          capabilities.scopeKey != active.scope.scopeKey ||
          capabilities.companyId <= 0 ||
          !capabilities.permissions.contains('envases_read')) {
        return null;
      }
      final company = CompanyContext.forScope(
        scope: active.scope,
        companyId: capabilities.companyId,
        allowedCompanyIds: [capabilities.companyId],
        capabilityRevision: capabilities.revision,
      );
      final client = active.client;
      final reader = client == null
          ? null
          : EnvasesDashboardReader.fromClient(client: client, company: company);
      final controller = EnvasesDashboardController(
        cache: EnvasesDashboardCache(
          owner: runtime.databaseOwner,
          lease: active.lease,
          company: company,
        ),
        reader: reader,
      );
      ref.onDispose(controller.dispose);
      return controller;
    });

final class EnvasesDashboardController {
  EnvasesDashboardController({required this.cache, required this.reader});

  final EnvasesDashboardCache cache;
  final EnvasesDashboardReader? reader;
  final _refreshErrors = StreamController<(Object, StackTrace)>.broadcast();
  late final Stream<EnvasesDashboardSnapshot?> _snapshots = Stream.multi((
    controller,
  ) {
    if (_disposed) {
      controller.close();
      return;
    }
    final cacheSubscription = cache.watch().listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    final errorSubscription = _refreshErrors.stream.listen(
      (error) => controller.addError(error.$1, error.$2),
    );
    controller.onCancel = () async {
      await cacheSubscription.cancel();
      await errorSubscription.cancel();
    };
  });
  bool _disposed = false;
  bool _refreshing = false;

  Stream<EnvasesDashboardSnapshot?> get snapshots => _snapshots;
  bool get canRefresh => !_disposed && reader != null;
  bool get refreshing => _refreshing;

  Future<void> refresh() async {
    if (!canRefresh || _refreshing) return;
    _refreshing = true;
    try {
      await cache.refresh(reader!);
    } catch (error, stack) {
      if (!_disposed) {
        // The error itself is retained for each active subscriber; cache.watch
        // remains authoritative for the last good snapshot.
        _refreshErrors.add((error, stack));
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _refreshErrors.close();
  }
}

/// Composition route: capability/session absence is explicit, while the
/// dashboard itself remains a read-only cached screen.
final class EnvasesDashboardRoute extends ConsumerWidget {
  const EnvasesDashboardRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(envasesDashboardControllerProvider);
    if (controller == null) {
      return const NotConfiguredPage(
        title: 'Envases',
        detail: 'No tienes permiso para consultar el dashboard de envases.',
      );
    }
    final active = ref.watch(runtimeSessionProvider)?.active;
    return EnvasesDashboardScreen(
      key: ValueKey(
        '${active?.scope.scopeKey}:${active?.lease.generation}:${ref.read(capabilitySnapshotProvider)?.companyId}',
      ),
      snapshots: controller.snapshots,
      onRefresh: controller.canRefresh ? controller.refresh : null,
    );
  }
}
