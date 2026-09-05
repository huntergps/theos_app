import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

import '../../../core/database/providers.dart';
import '../../../core/database/repositories/repository_providers.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/constants/user_groups.dart';
import '../repositories/collection_repository.dart';

final hasCollectionPermissionsProvider = Provider<bool>((ref) {
  final user = ref.watch(userProvider);
  return user != null &&
      [
        ...kAdministratorGroups,
        ...kCashierGroups,
      ].any(user.permissions.contains);
});

/// Presentation policies for the cashier's own point, not sales-mode rules.
/// A stream is used because the SQLite configuration is live and read-only.
final counterCapabilitiesProvider = StreamProvider<PosAppCapabilities?>((ref) {
  final user = ref.watch(userProvider);
  final canCollect = ref.watch(hasCollectionPermissionsProvider);
  final session = ref.watch(currentSessionProvider);
  final repository = ref.watch(collectionRepositoryProvider);
  if (!canCollect ||
      user == null ||
      session?.userId != user.id ||
      session?.configId == null ||
      repository == null) {
    return Stream.value(null);
  }
  return repository.watchPosCapabilities(session!.configId!).map((
    capabilities,
  ) {
    if (capabilities != null &&
        session.companyId != null &&
        capabilities.companyId != session.companyId) {
      throw const FormatException('POS capability session company mismatch');
    }
    return capabilities;
  });
});

/// Missing extension preserves the native app; loading/errors do not expose
/// configured actions before the actual policy is known. Never grants ACLs.
bool counterActionVisible(
  AsyncValue<PosAppCapabilities?> capabilities,
  String policy,
) => capabilities.when(
  skipLoadingOnRefresh: false,
  skipLoadingOnReload: false,
  data: (value) => value?.counterPolicies?[policy] ?? true,
  loading: () => false,
  error: (_, _) => false,
);
