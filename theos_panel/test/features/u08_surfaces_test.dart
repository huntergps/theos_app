import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/features/home/home_center.dart';
import 'package:theos_panel/features/activities/activity_center.dart';
import 'package:theos_panel/features/reports/document_view.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

void main() {
  test('home resumes authorized real work and exposes empty/error states', () {
    const item = HomeResumeItem(
      id: 'orders',
      title: 'Ventas pendientes',
      subtitle: '2 locales',
      actionLabel: 'Continuar',
      route: '/sales',
    );
    const snapshot = HomeResumeSnapshot(HomeResumeState.data, items: [item]);
    expect(snapshot.items.single.id, 'orders');
    expect(const HomeResumeSnapshot(HomeResumeState.empty).items, isEmpty);
    expect(
      const HomeResumeSnapshot(
        HomeResumeState.error,
        message: 'offline',
      ).message,
      'offline',
    );
  });

  testWidgets('home resume invokes authorized navigation callback', (
    tester,
  ) async {
    const item = HomeResumeItem(
      id: 'orders',
      title: 'Ventas pendientes',
      subtitle: '2 locales',
      actionLabel: 'Continuar',
      route: '/sales',
    );
    var resumed = false;
    await tester.pumpWidget(
      ProviderScope(
        child: FluentApp(
          theme: OrbiFluentTheme.light,
          home: ScaffoldPage(
            content: HomeCenterView(
              port: _HomePort(item),
              onResume: (value) async => resumed = value.route == '/sales',
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Continuar'));
    expect(resumed, isTrue);
    // Fluent's `HoverButton` (under `FilledButton`) schedules a 100ms timer
    // on tap-up to reset its pressed state; flush it before teardown.
    await tester.pump(const Duration(milliseconds: 150));
  });

  test('activity operation is gated by port permission and status remains explicit', () async {
    final item = const ActivityItem(
      id: 'a',
      title: 'Llamar cliente',
      status: ActivityStatus.today,
    );
    final port = _Activities([item], allowed: false);
    expect(await port.complete(item), isFalse);
    expect(port.calls, 1);
    expect(
      const ActivityItem(
        id: 'done',
        title: 'Listo',
        status: ActivityStatus.done,
      ).canComplete,
      isFalse,
    );
  });

  test(
    'cached document reopens after serialization with fiscal and sync separate',
    () async {
      final document = const CachedDocument(
        title: 'Factura local',
        bytes: [1, 2],
        mimeType: 'application/pdf',
        fiscalState: DocumentFiscalState.localDraft,
        syncState: DocumentSyncState.queued,
      );
      final persisted = CachedDocumentCodec.encode(document);
      final reopened = CachedDocumentCodec.decode(persisted, documentId: 'doc');
      final port = _Documents(reopened);
      expect((await port.loadCached('doc')).bytes, [1, 2]);
      expect(reopened.fiscalState, DocumentFiscalState.localDraft);
      expect(reopened.syncState, DocumentSyncState.queued);
    },
  );

  test('invalid cached document bytes fail closed', () {
    expect(
      () => CachedDocumentCodec.decode(
        '{"title":"Factura","mimeType":"application/pdf",'
        '"bytes":"not-base64","fiscalState":"authorized",'
        '"syncState":"synced"}',
        documentId: 'doc',
      ),
      throwsFormatException,
    );
  });
}

final class _Activities implements ActivityPort {
  _Activities(this.snapshot, {required this.allowed});
  @override
  final List<ActivityItem> snapshot;
  final bool allowed;
  var calls = 0;
  @override
  Stream<List<ActivityItem>> get changes => const Stream.empty();
  @override
  Future<bool> complete(ActivityItem item) async {
    calls++;
    return allowed && item.canComplete;
  }
}

final class _HomePort implements HomeResumePort {
  const _HomePort(this.item);
  final HomeResumeItem item;
  @override
  HomeResumeSnapshot get snapshot =>
      HomeResumeSnapshot(HomeResumeState.data, items: [item]);
  @override
  Stream<HomeResumeSnapshot> get changes => const Stream.empty();
  @override
  Future<void> resume(HomeResumeItem item) async {}
}

final class _Documents implements DocumentRenderPort {
  _Documents(this.document);
  final CachedDocument document;
  @override
  Future<CachedDocument> loadCached(String documentId) async => document;
}
