import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_qweb/flutter_qweb.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:theos_pos/core/database/database_helper.dart';
import 'package:theos_pos/features/reports/repositories/qweb_template_repository.dart';
import 'package:theos_pos/features/sync/repositories/qweb_template_sync_repository.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;

import '../../../mocks/mock_odoo_client.dart';

class _MockDatabaseHelper extends Mock implements DatabaseHelper {}

CachedTemplate _remoteTemplate({
  required String key,
  required int id,
  String model = 'sale.order',
}) {
  return CachedTemplate(
    templateKey: key,
    odooId: id,
    name: key,
    model: model,
    xmlContent: '<t t-name="$key"/>',
    requiredFields: const [],
    dependencies: const [],
    lastSynced: DateTime.utc(2026, 8, 26),
    checksum: 'checksum-$id',
  );
}

void main() {
  late AppDatabase database;
  late QwebTemplateRepository templates;
  late MockOdooClient client;
  late QwebTemplateSyncRepository sync;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    templates = QwebTemplateRepository(database);
    client = MockOdooClient.online();
    sync = QwebTemplateSyncRepository(
      db: _MockDatabaseHelper(),
      odooClient: client,
      appDatabase: database,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'missing exact remote view is tombstoned and no longer served',
    () async {
      await templates.saveTemplate(
        _remoteTemplate(key: 'custom.removed', id: 41),
      );
      when(
        () => client.searchRead(
          model: 'ir.ui.view',
          domain: any(named: 'domain'),
          fields: any(named: 'fields'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          order: any(named: 'order'),
        ),
      ).thenAnswer((_) async => const []);

      expect(await sync.syncTemplate('custom.removed'), isFalse);

      expect(await templates.getTemplate('custom.removed'), isNull);
      expect(await templates.templateExists('custom.removed'), isFalse);
      expect(await templates.getTemplateCount(), 0);
      final row =
          await (database.select(database.qwebReportTemplate)
                ..where((table) => table.templateKey.equals('custom.removed')))
              .getSingle();
      expect(row.active, isFalse);
    },
  );

  test('complete model scope tombstones stale remote rows but keeps dependencies and local drafts', () async {
    await templates.saveTemplates([
      _remoteTemplate(key: 'custom.old_report', id: 51),
      _remoteTemplate(key: 'sale.report_saleorder_document', id: 52),
    ]);
    await database
        .into(database.qwebReportTemplate)
        .insert(
          QwebReportTemplateCompanion.insert(
            odooId: -53,
            templateKey: 'local.unsynced_draft',
            name: 'Local draft',
            model: 'sale.order',
            reportType: 'pdf',
            reportName: 'local.unsynced_draft',
            xmlContent: '<t t-name="local.unsynced_draft"/>',
            active: const drift.Value(true),
          ),
        );

    when(
      () => client.searchRead(
        model: 'ir.actions.report',
        domain: any(named: 'domain'),
        fields: any(named: 'fields'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
        order: any(named: 'order'),
      ),
    ).thenAnswer(
      (_) async => const [
        {
          'report_name': 'custom.current_report',
          'name': 'Current',
          'model': 'sale.order',
        },
      ],
    );
    when(
      () => client.searchRead(
        model: 'ir.ui.view',
        domain: any(named: 'domain'),
        fields: any(named: 'fields'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
        order: any(named: 'order'),
      ),
    ).thenAnswer(
      (_) async => const [
        {
          'id': 54,
          'key': 'custom.current_report',
          'name': 'Current',
          'model': false,
          'arch_db': '<t t-name="custom.current_report"/>',
          'active': true,
        },
      ],
    );

    expect(await sync.syncTemplatesForModel('sale.order'), 1);

    expect(await templates.getTemplate('custom.old_report'), isNull);
    expect(
      await templates.getTemplate('sale.report_saleorder_document'),
      isNotNull,
    );
    expect(await templates.getTemplate('local.unsynced_draft'), isNotNull);
    final current = await templates.getTemplate('custom.current_report');
    expect(current?.model, 'sale.order');

    final rows = await database.select(database.qwebReportTemplate).get();
    final byKey = {for (final row in rows) row.templateKey: row};
    expect(byKey['custom.old_report']?.active, isFalse);
    expect(byKey['sale.report_saleorder_document']?.active, isTrue);
    expect(byKey['local.unsynced_draft']?.active, isTrue);
    expect(byKey['custom.current_report']?.active, isTrue);
  });

  test('transport failure preserves the last usable cached template', () async {
    await templates.saveTemplate(
      _remoteTemplate(key: 'custom.keep_on_error', id: 61),
    );
    when(
      () => client.searchRead(
        model: 'ir.ui.view',
        domain: any(named: 'domain'),
        fields: any(named: 'fields'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
        order: any(named: 'order'),
      ),
    ).thenThrow(StateError('network unavailable'));

    await expectLater(
      sync.syncTemplate('custom.keep_on_error'),
      throwsA(isA<StateError>()),
    );

    expect(await templates.getTemplate('custom.keep_on_error'), isNotNull);
  });
}
