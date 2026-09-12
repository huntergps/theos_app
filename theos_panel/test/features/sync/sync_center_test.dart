import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/features/sync/sync_center.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

final class _SyncPort implements SyncCenterPort {
  _SyncPort(this._snapshot);
  final SyncCenterSnapshot _snapshot;
  final changes = StreamController<SyncCenterSnapshot>.broadcast();
  var retries = 0;

  @override
  SyncCenterSnapshot get snapshot => _snapshot;
  @override
  Stream<SyncCenterSnapshot> get snapshots => changes.stream;
  @override
  Future<void> retry() async => retries++;
}

void main() {
  testWidgets('shows real catalog progress and invokes coordinated retry', (
    tester,
  ) async {
    final port = _SyncPort(
      SyncCenterSnapshot(
        sync: SyncSnapshot(
          queuedCount: 1,
          failures: [
            SyncFailure(
              jobId: 'catalog:uom',
              message: "Invalid field 'rounding' on 'uom.uom'",
            ),
          ],
        ),
        catalogs: const [
          SyncCatalogStatus(
            id: 'orders',
            label: 'Órdenes',
            state: SyncCatalogState.failed,
            completed: 3,
            total: 10,
            message: 'Cursor no confirmado',
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [syncCenterPortProvider.overrideWithValue(port)],
        child: FluentApp(
          theme: OrbiFluentTheme.light,
          home: const ScaffoldPage(content: SyncCenterView()),
        ),
      ),
    );
    expect(find.text('Cursor no confirmado'), findsOneWidget);
    expect(find.text('En cola: 1'), findsOneWidget);
    await tester.tap(find.text('Reintentar sincronización'));
    // Fluent's `FilledButton` runs through `HoverButton`, which schedules a
    // 100ms timer on tap-up to reset its pressed state; flush it before
    // teardown.
    await tester.pump(const Duration(milliseconds: 150));
    expect(port.retries, 1);
    await port.changes.close();
  });

  testWidgets('offline state preserves work and disables retry', (
    tester,
  ) async {
    final port = _SyncPort(
      SyncCenterSnapshot(sync: SyncSnapshot(queuedCount: 2), offline: true),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [syncCenterPortProvider.overrideWithValue(port)],
        child: FluentApp(
          theme: OrbiFluentTheme.light,
          home: const ScaffoldPage(content: SyncCenterView()),
        ),
      ),
    );
    expect(
      find.text('Sin conexión; se conserva el trabajo local.'),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Reintentar sincronización'),
    );
    expect(button.onPressed, isNull);
    await port.changes.close();
  });
}
