/// Consolidated providers for Sales feature
///
/// ## Reactive (Stream) vs One-shot (Future) Providers
///
/// This file contains TWO categories of providers:
///
/// **Stream-based (reactive)** - auto-update when local DB changes:
/// - [saleOrderByIdProvider] -> delegates to [saleOrderStreamProvider]
/// - [saleOrderLinesProvider] -> delegates to [saleOrderLinesStreamProvider]
/// - [unsyncedSaleOrdersProvider] -> delegates to [unsyncedSaleOrdersStreamProvider]
///
/// **Future-based (one-shot)** - enriched local reads:
/// - [saleOrderWithLinesProvider] - reads local but enriches with repository logic
/// - [saleOrderSearchProvider] - local search with repository enrichment
///
/// For new UI code, prefer the stream providers from [sale_order_stream_providers.dart].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/repositories/repository_providers.dart';
import '../repositories/sales_repository.dart';

import 'package:theos_pos_core/theos_pos_core.dart';

import 'sale_order_form_notifier.dart';
import 'sale_order_stream_providers.dart';

// Re-export refactored sale order form components
export 'sale_order_form_state.dart';
export 'sale_order_form_notifier.dart';
export 'sale_order_line_manager.dart';
export 'sale_order_field_updater.dart';
export 'sale_order_tabs_provider.dart';

// Re-export unified order cache (single source of truth)
export 'order_cache_provider.dart';

// Re-export stream providers for reactive UI (preferred pattern)
export 'sale_order_stream_providers.dart';

// Re-export service providers (extracted from service files)
export 'service_providers.dart';

// Session guard — checks if there's an active collection session
export 'session_guard_provider.dart';

part 'providers.g.dart';

// ============ Sale Order Providers (Local DB - delegates to Streams) ============
// These providers read from local DB only. They now delegate to the reactive
// stream providers so the UI auto-updates when local DB changes.

/// Single order by ID - reactive via [saleOrderStreamProvider]
///
/// Returns the latest value from the stream. Consumers using `.when()` will
/// auto-update when the order changes in the local DB.
@riverpod
Future<SaleOrder?> saleOrderById(Ref ref, int orderId) async {
  // Delegate to stream provider - this makes the provider reactive
  final asyncValue = ref.watch(saleOrderStreamProvider(orderId));
  return asyncValue.value;
}

/// Order with lines - kept as FutureProvider because it enriches data
/// via repository logic (partner/product lookups) that streams don't do.
///
/// For reactive line-only watching, use [saleOrderLinesStreamProvider].
@riverpod
Future<(SaleOrder?, List<SaleOrderLine>)> saleOrderWithLines(
  Ref ref,
  int orderId,
) async {
  final repo = ref.watch(salesRepositoryProvider);
  if (repo == null) return (null, <SaleOrderLine>[]);
  return repo.getWithLines(orderId, forceRefresh: false);
}

/// Unsynced orders - reactive via [unsyncedSaleOrdersStreamProvider]
@Riverpod(keepAlive: true)
Future<List<SaleOrder>> unsyncedSaleOrders(Ref ref) async {
  final asyncValue = ref.watch(unsyncedSaleOrdersStreamProvider);
  return asyncValue.value ?? [];
}

/// Order lines by orderId - reactive via [saleOrderLinesStreamProvider]
///
/// Auto-updates when lines are added/removed/modified in local DB.
@riverpod
Future<List<SaleOrderLine>> saleOrderLines(Ref ref, int orderId) async {
  final asyncValue = ref.watch(saleOrderLinesStreamProvider(orderId));
  return asyncValue.value ?? [];
}

/// Search orders - kept as FutureProvider (search involves repository logic)
@riverpod
Future<List<SaleOrder>> saleOrderSearch(Ref ref, String query) async {
  final repo = ref.watch(salesRepositoryProvider);
  if (repo == null) return [];
  return repo.search(query);
}

// ============ Sale Order Form Providers ============

@Riverpod(keepAlive: true)
List<SaleOrderLine> saleOrderFormVisibleLines(Ref ref) {
  final lineState = ref.watch(
    saleOrderFormProvider.select(
      (state) => (
        lines: state.lines,
        deletedIds: state.deletedLineIds,
        updated: state.updatedLines,
        added: state.newLines,
      ),
    ),
  );

  final deletedIds = lineState.deletedIds.toSet();
  final updatedById = {for (final line in lineState.updated) line.id: line};
  final visible = <SaleOrderLine>[
    for (final line in lineState.lines)
      if (!deletedIds.contains(line.id)) updatedById[line.id] ?? line,
    ...lineState.added,
  ]..sort((a, b) => a.sequence.compareTo(b.sequence));

  return visible;
}
