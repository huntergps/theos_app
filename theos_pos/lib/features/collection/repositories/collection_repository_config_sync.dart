part of 'collection_repository.dart';

/// Configuration synchronization operations kept separate from the session
/// and payment workflows in [CollectionRepository].
extension CollectionRepositoryConfigSync on CollectionRepository {
  /// Observe only the current point, using the repository's captured database.
  /// Invalid identities are errors, never a fallback granting visibility.
  Stream<PosAppCapabilities?> watchPosCapabilities(int configId) {
    final manager = CollectionConfigManager()..initDb(_appDb);
    return manager
        .watchLocalSearch(
          domain: [
            ['id', '=', configId],
          ],
        )
        .map((rows) {
          if (rows.isEmpty) return null;
          final config = rows.single;
          final encoded = config.posAppCapabilitiesJson;
          if (encoded == null) return null;
          final capabilities = PosAppCapabilities.fromJson(
            jsonDecode(encoded) as Map<String, dynamic>,
          );
          if (capabilities.configId != config.id ||
              capabilities.companyId != config.companyId) {
            throw const FormatException(
              'POS capability point/company mismatch',
            );
          }
          return capabilities;
        });
  }

  /// Sync collection configs and return them.
  ///
  /// When offline, the local cache is returned unchanged. A successful online
  /// response also refreshes open sessions so callers retain the existing
  /// repository contract.
  Future<List<CollectionConfig>> syncCollectionConfigs() async {
    final client = odooClient;
    final database = _appDb;
    final manager = CollectionConfigManager()..initDb(database);
    if (!isOnline || client == null) {
      return manager.searchLocal();
    }

    try {
      final currentUser = await _userRepository.getCurrentUser();
      if (currentUser == null) {
        return await manager.searchLocal();
      }

      final data = await client.searchRead(
        model: 'collection.config',
        fields: manager.odooFields,
        domain: [
          [
            'user_ids',
            'in',
            [currentUser.id],
          ],
        ],
      );

      final configs = await loadPosAppCapabilities(
        client,
        data.map(manager.fromOdoo).toList(),
      );

      await database.transaction(() async {
        await _deleteConfigsNotIn(configs.map((c) => c.id).toList(), manager);
        if (configs.isNotEmpty) await manager.upsertLocalBatch(configs);
      });
      if (configs.isNotEmpty) await syncCollectionSessions();
    } catch (_) {
      // Keep the cache available when the remote service is unavailable.
    }
    return manager.searchLocal();
  }

  Future<void> _deleteConfigsNotIn(
    List<int> keepIds,
    CollectionConfigManager manager,
  ) async {
    if (keepIds.isEmpty) {
      await manager.deleteAllLocal();
      return;
    }
    final keep = keepIds.toSet();
    final allConfigs = await manager.searchLocal();
    for (final config in allConfigs) {
      if (!keep.contains(config.id)) {
        await manager.deleteLocal(config.id);
      }
    }
  }
}
