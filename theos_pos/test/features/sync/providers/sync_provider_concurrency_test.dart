import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart' show SyncModelInfo;
import 'package:theos_pos/core/database/repositories/repository_providers.dart';
import 'package:theos_pos/features/sync/providers/sync_provider.dart';
import 'package:theos_pos/features/sync/repositories/catalog_sync_repository.dart';

class _MockCatalogSyncRepository extends Mock
    implements CatalogSyncRepository {}

void main() {
  late _MockCatalogSyncRepository repository;
  late ProviderContainer container;
  late List<SyncItemDef> originalItems;
  late Map<String, SyncModelInfo> metadata;

  setUpAll(() {
    registerFallbackValue(SyncModelInfo(modelName: 'fallback'));
  });

  setUp(() async {
    repository = _MockCatalogSyncRepository();
    metadata = {};
    originalItems = List<SyncItemDef>.of(SyncNotifier.syncItems);

    when(() => repository.isOnline).thenReturn(true);
    when(() => repository.isCancelRequested).thenReturn(false);
    when(() => repository.getAllModelSyncInfo())
        .thenAnswer((_) async => Map<String, SyncModelInfo>.of(metadata));
    when(() => repository.getModelSyncInfo(any())).thenAnswer((invocation) {
      final name = invocation.positionalArguments.single as String;
      return Future.value(metadata[name] ?? SyncModelInfo(modelName: name));
    });
    when(() => repository.saveModelSyncInfo(any()))
        .thenAnswer((invocation) async {
          final info = invocation.positionalArguments.single as SyncModelInfo;
          metadata[info.modelName] = info;
        });
    when(() => repository.getLocalCountForModel(any()))
        .thenAnswer((_) async => 1);
    when(
      () => repository.syncDeletedRecords(
        odooModel: any(named: 'odooModel'),
        localModelName: any(named: 'localModelName'),
        sinceDate: any(named: 'sinceDate'),
      ),
    ).thenAnswer((_) async => 0);

    container = ProviderContainer(
      overrides: [catalogSyncRepositoryProvider.overrideWithValue(repository)],
    );
    container.read(syncProvider);
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() async {
    await container.read(syncProvider.notifier).cancelAndWait();
    container.dispose();
    SyncNotifier.syncItems
      ..clear()
      ..addAll(originalItems);
    SyncNotifier.resetSyncFlag();
  });

  test('recovery and full sync never overlap', () async {
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    var calls = 0;
    var active = 0;
    var maxActive = 0;

    SyncNotifier.syncItems
      ..clear()
      ..add(
        SyncItemDef(
          name: 'categories',
          description: 'Categories',
          odooModel: 'product.category',
          syncFn: (_, _, _) async {
            calls++;
            active++;
            if (active > maxActive) maxActive = active;
            try {
              if (calls == 1) {
                firstStarted.complete();
                await releaseFirst.future;
              }
              return 1;
            } finally {
              active--;
            }
          },
        ),
      );

    final notifier = container.read(syncProvider.notifier);
    final recovery = notifier.syncCriticalData();
    await firstStarted.future;

    final full = notifier.syncAll();
    await Future<void>.delayed(Duration.zero);

    expect(calls, 1);
    expect(maxActive, 1);

    releaseFirst.complete();
    await Future.wait([recovery, full]);

    expect(calls, 2);
    expect(maxActive, 1);
  });

  test('recovery persists and reuses the incremental watermark', () async {
    final sinceDates = <DateTime?>[];

    SyncNotifier.syncItems
      ..clear()
      ..add(
        SyncItemDef(
          name: 'categories',
          description: 'Categories',
          odooModel: 'product.category',
          syncFn: (_, _, sinceDate) async {
            sinceDates.add(sinceDate);
            return 3;
          },
        ),
      );

    final notifier = container.read(syncProvider.notifier);
    await notifier.syncCriticalData();
    final firstWatermark = metadata['categories']!.lastSyncDate;

    await notifier.syncCriticalData();

    expect(sinceDates, hasLength(2));
    expect(sinceDates.first, isNull);
    expect(firstWatermark, isNotNull);
    expect(sinceDates.last, firstWatermark);
    expect(metadata['categories']!.wasIncremental, isTrue);
  });

  test('critical recovery runs tombstones first and preserves watermark on failure', () async {
    final previousWatermark = DateTime.utc(2026, 8, 25, 12);
    metadata['categories'] = SyncModelInfo(
      modelName: 'categories',
      lastSyncDate: previousWatermark,
    );
    var liveFetchCalls = 0;
    when(
      () => repository.syncDeletedRecords(
        odooModel: 'product.category',
        localModelName: 'categories',
        sinceDate: previousWatermark,
      ),
    ).thenThrow(StateError('tombstone failure'));
    SyncNotifier.syncItems
      ..clear()
      ..add(
        SyncItemDef(
          name: 'categories',
          description: 'Categories',
          odooModel: 'product.category',
          syncFn: (_, _, _) async {
            liveFetchCalls++;
            return 1;
          },
        ),
      );

    await container.read(syncProvider.notifier).syncCriticalData();

    expect(liveFetchCalls, 0);
    expect(metadata['categories']!.lastSyncDate, previousWatermark);
    expect(metadata['categories']!.errorMessage, isNotNull);
    verify(
      () => repository.syncDeletedRecords(
        odooModel: 'product.category',
        localModelName: 'categories',
        sinceDate: previousWatermark,
      ),
    ).called(1);
  });

  test('single item preserves watermark when tombstone sync fails', () async {
    final previousWatermark = DateTime.utc(2026, 8, 25, 12);
    metadata['categories'] = SyncModelInfo(
      modelName: 'categories',
      lastSyncDate: previousWatermark,
    );
    var liveFetchCalls = 0;
    when(
      () => repository.syncDeletedRecords(
        odooModel: 'product.category',
        localModelName: 'categories',
        sinceDate: previousWatermark,
      ),
    ).thenThrow(StateError('tombstone failure'));
    SyncNotifier.syncItems
      ..clear()
      ..add(
        SyncItemDef(
          name: 'categories',
          description: 'Categories',
          odooModel: 'product.category',
          syncFn: (_, _, _) async {
            liveFetchCalls++;
            return 1;
          },
        ),
      );

    final notifier = container.read(syncProvider.notifier);
    await notifier.syncItem('categories');

    expect(liveFetchCalls, 0);
    expect(metadata['categories']!.lastSyncDate, previousWatermark);
    expect(
      container.read(syncProvider).getItemState('categories').status,
      SyncStatus.error,
    );
  });

  test(
    'full sync preserves item watermark when tombstone sync fails',
    () async {
      final previousWatermark = DateTime.utc(2026, 8, 25, 12);
      metadata['categories'] = SyncModelInfo(
        modelName: 'categories',
        lastSyncDate: previousWatermark,
      );
      var liveFetchCalls = 0;
      when(
        () => repository.syncDeletedRecords(
          odooModel: 'product.category',
          localModelName: 'categories',
          sinceDate: previousWatermark,
        ),
      ).thenThrow(StateError('tombstone failure'));
      SyncNotifier.syncItems
        ..clear()
        ..add(
          SyncItemDef(
            name: 'categories',
            description: 'Categories',
            odooModel: 'product.category',
            syncFn: (_, _, _) async {
              liveFetchCalls++;
              return 1;
            },
          ),
        );

      await container.read(syncProvider.notifier).syncAll();

      expect(liveFetchCalls, 0);
      expect(metadata['categories']!.lastSyncDate, previousWatermark);
      expect(
        container.read(syncProvider).getItemState('categories').status,
        SyncStatus.error,
      );
    },
  );

  test('metadata commit failure never publishes a newer watermark', () async {
    final previousWatermark = DateTime.utc(2026, 8, 25, 12);
    metadata['categories'] = SyncModelInfo(
      modelName: 'categories',
      lastSyncDate: previousWatermark,
    );
    when(() => repository.saveModelSyncInfo(any()))
        .thenThrow(StateError('metadata storage failure'));
    SyncNotifier.syncItems
      ..clear()
      ..add(
        SyncItemDef(
          name: 'categories',
          description: 'Categories',
          odooModel: 'product.category',
          syncFn: (_, _, _) async => 1,
        ),
      );

    final notifier = container.read(syncProvider.notifier);
    await notifier.syncItem('categories');

    final state = container.read(syncProvider).getItemState('categories');
    expect(state.status, SyncStatus.error);
    expect(state.lastSyncDate, previousWatermark);
    expect(metadata['categories']!.lastSyncDate, previousWatermark);
  });

  test('cancelAndWait does not complete while a writer is active', () async {
    final started = Completer<void>();
    final release = Completer<void>();

    SyncNotifier.syncItems
      ..clear()
      ..add(
        SyncItemDef(
          name: 'categories',
          description: 'Categories',
          odooModel: 'product.category',
          syncFn: (_, _, _) async {
            started.complete();
            await release.future;
            return 1;
          },
        ),
      );

    final notifier = container.read(syncProvider.notifier);
    final recovery = notifier.syncCriticalData();
    await started.future;

    var becameIdle = false;
    final idle = notifier.cancelAndWait().then((_) => becameIdle = true);
    await Future<void>.delayed(Duration.zero);

    expect(becameIdle, isFalse);

    release.complete();
    await Future.wait([recovery, idle]);
    expect(becameIdle, isTrue);
  });
}
