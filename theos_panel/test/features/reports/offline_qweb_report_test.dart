import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_qweb/flutter_qweb.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos_core/theos_pos_core.dart';
import 'package:theos_panel/features/reports/document_view.dart';
import 'package:theos_panel/features/reports/offline_qweb_report.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('renders a cached QWeb template to PDF without a network', () async {
    final generator = OfflineQwebReportGenerator(
      _Templates(
        CachedTemplate(
          templateKey: 'test.offline',
          odooId: 1,
          name: 'Offline test',
          model: 'sale.order',
          xmlContent: '''
          <t t-name="test.offline">
            <div><h1><t t-out="doc.name"/></h1></div>
          </t>
        ''',
          requiredFields: const [],
          dependencies: const [],
          lastSynced: DateTime.utc(2026),
          checksum: 'test-checksum',
        ),
      ),
    );

    final bytes = await generator.render(
      templateName: 'test.offline',
      records: const [
        {'name': 'Pedido offline'},
      ],
      options: const RenderOptions(includeHeader: false, includeFooter: false),
    );

    expect(bytes, isA<Uint8List>());
    expect(bytes, isNotEmpty);
    expect(utf8.decode(bytes.take(5).toList(), allowMalformed: true), '%PDF-');
    expect(generator.templatesLoaded, isTrue);
    expect(generator.templateCount, 1);
  });

  test('reopened PDF keeps independent fiscal and sync states', () async {
    final generator = OfflineQwebReportGenerator(
      _Templates(
        CachedTemplate(
          templateKey: 'test.offline',
          odooId: 1,
          name: 'Offline test',
          model: 'sale.order',
          xmlContent: '<div><t t-out="doc.name"/></div>',
          requiredFields: const [],
          dependencies: const [],
          lastSynced: DateTime.utc(2026),
          checksum: 'test-checksum',
        ),
      ),
    );
    final bytes = await generator.render(
      templateName: 'test.offline',
      records: const [
        {'name': 'Pedido offline'},
      ],
      options: const RenderOptions(includeHeader: false, includeFooter: false),
    );
    final document = CachedDocument(
      title: 'Pedido offline.pdf',
      bytes: bytes,
      mimeType: 'application/pdf',
      fiscalState: DocumentFiscalState.localDraft,
      syncState: DocumentSyncState.queued,
    );
    final reopened = CachedDocumentCodec.decode(
      CachedDocumentCodec.encode(document),
      documentId: 'order-1',
    );
    expect(reopened.bytes, bytes);
    expect(reopened.fiscalState, DocumentFiscalState.localDraft);
    expect(reopened.syncState, DocumentSyncState.queued);
  });

  test('does not claim offline generation when template is absent', () async {
    final generator = OfflineQwebReportGenerator(_Templates(null));
    await expectLater(
      generator.render(templateName: 'missing.template', records: const []),
      throwsA(isA<StateError>()),
    );
  });

  test('reads the existing QWeb cache after a database reopen', () async {
    final file = File(
      '${Directory.systemTemp.path}/orbi-qweb-${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final first = AppDatabase(NativeDatabase(file));
    await first
        .into(first.qwebReportTemplate)
        .insert(
          QwebReportTemplateCompanion.insert(
            odooId: 17,
            templateKey: 'test.reopen',
            name: 'Reopen',
            model: 'sale.order',
            reportType: 'pdf',
            reportName: 'test.reopen',
            xmlContent: '<div>cached</div>',
            lastSynced: drift.Value(DateTime.utc(2026)),
            checksum: const drift.Value('cache-v1'),
          ),
        );
    await first.close();
    final reopened = AppDatabase(NativeDatabase(file));
    final cached = await DatabaseQwebTemplateProvider(reopened)
        .getAllTemplates();
    expect(cached.single.templateKey, 'test.reopen');
    expect(cached.single.checksum, 'cache-v1');
    await reopened.close();
    await file.delete();
  });
}

final class _Templates implements QwebTemplateProvider {
  const _Templates(this.template);
  final CachedTemplate? template;

  @override
  Future<List<CachedTemplate>> getAllTemplates() async => [?template];

  @override
  Future<Map<String, PaperFormat>> getAllPaperFormats() async => const {};
}
