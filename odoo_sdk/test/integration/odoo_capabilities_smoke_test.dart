/// Read-only capability smoke tests for explicitly configured Odoo 19/20
/// instances.
///
/// Configure either slot exclusively through environment variables:
///
/// - `ODOO19_BASE_URL`, `ODOO19_API_KEY`, `ODOO19_DATABASE`
/// - `ODOO20_BASE_URL`, `ODOO20_API_KEY`, `ODOO20_DATABASE`
/// - `NEWERP_BASE_URL`, `NEWERP_API_KEY`, `NEWERP_DATABASE` (19.5 contract)
/// - `EPR2_BASE_URL`, `EPR2_API_KEY`, `EPR2_DATABASE` (19.5 contract)
/// - `ERP2_BASE_URL`, `ERP2_API_KEY`, `ERP2_DATABASE` (19.5 contract)
/// - `PVISION_BASE_URL`, `PVISION_API_KEY`, `PVISION_DATABASE` (19.5 contract)
/// - `JB_BASE_URL`, `JB_API_KEY`, `JB_DATABASE` (19.5 contract)
/// - `DEJAVU_BASE_URL`, `DEJAVU_API_KEY`, `DEJAVU_DATABASE` (19.5 contract)
///
/// A slot is skipped unless all three values are present. The test never logs
/// configuration values and only reads versions, models, and field metadata.
library;

import 'dart:io';

import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:test/test.dart';

void main() {
  for (final slot in const [
    _OdooSlot(prefix: 'ODOO19', expectedMajor: 19),
    _OdooSlot(prefix: 'ODOO20', expectedMajor: 20),
  ]) {
    final config = _SmokeConfig.fromEnvironment(slot.prefix);

    test(
      '${slot.prefix} read-only version and capabilities smoke',
      () async {
        final client = OdooClient(
          config: OdooClientConfig(
            baseUrl: config!.baseUrl,
            apiKey: config.apiKey,
            database: config.database,
            enableRetry: false,
            allowInsecure: _isLoopbackHttp(config.baseUrl),
          ),
        );

        late ({
          OdooVersion version,
          Set<String> models,
          Map<String, Set<String>> fieldsByModel,
        })
        snapshot;
        try {
          snapshot = await _readOnlySnapshot(client);
        } catch (error) {
          fail(
            '${slot.prefix} read-only smoke failed '
            '(${error.runtimeType}); configuration values were suppressed',
          );
        }

        expect(
          snapshot.version.major,
          slot.expectedMajor,
          reason: '${slot.prefix} must point to Odoo ${slot.expectedMajor}.x',
        );
        expect(snapshot.version.isSupported, isTrue);
        expect(snapshot.models, contains('ir.model'));
        expect(
          snapshot.fieldsByModel['ir.model'],
          containsAll(const ['model', 'name']),
        );

        final capabilities = const OdooCapabilitiesDetector().detect(
          version: snapshot.version,
          evidence: OdooCapabilityEvidence(
            models: snapshot.models,
            fieldsByModel: snapshot.fieldsByModel,
          ),
        );

        expect(capabilities.version.major, slot.expectedMajor);
        expect(
          capabilities.matrix.keys.toSet(),
          OdooCapabilityArea.values.toSet(),
        );
      },
      skip: config == null
          ? 'Set ${slot.prefix}_BASE_URL/API_KEY/DATABASE to enable'
          : false,
    );
  }

  for (final slot in const [
    _ContractSlot(prefix: 'NEWERP'),
    _ContractSlot(prefix: 'EPR2'),
    _ContractSlot(prefix: 'ERP2'),
    _ContractSlot(prefix: 'PVISION'),
    _ContractSlot(prefix: 'JB'),
    _ContractSlot(prefix: 'DEJAVU'),
  ]) {
    final config = _SmokeConfig.fromEnvironment(slot.prefix);
    test(
      '${slot.prefix} read-only Odoo 19.5 schema contract',
      () async {
        final client = OdooClient(
          config: OdooClientConfig(
            baseUrl: config!.baseUrl,
            apiKey: config.apiKey,
            database: config.database,
            enableRetry: false,
            allowInsecure: _isLoopbackHttp(config.baseUrl),
          ),
        );

        // Do not certify the minor version from ir.module.module.latest_version:
        // that is an installed module version, not authoritative server release
        // metadata. This probe certifies the deployed schema contract only.
        for (final entry in _required195Fields.entries) {
          final fields = await client.getModelFields(entry.key);
          expect(
            fields.keys,
            containsAll(entry.value),
            reason: '${entry.key} is missing required 19.5 fields',
          );
        }
        final wizardLineFields = await client.getModelFields(_wizardLineModel);
        // This field is intentionally informational: deployed 19.5 databases
        // differ here. Keep the hasField result observable without making it
        // a required contract.
        print(
          '${slot.prefix} wizard.line line_type: '
          '${wizardLineFields.containsKey('line_type')}',
        );
      },
      skip: config == null
          ? 'Set ${slot.prefix}_BASE_URL/API_KEY/DATABASE to enable'
          : false,
    );
  }
}

Future<
  ({
    OdooVersion version,
    Set<String> models,
    Map<String, Set<String>> fieldsByModel,
  })
>
_readOnlySnapshot(OdooClient client) async {
  final version = await client.fetchVersion(maxAttempts: 1);
  final records = await client.searchRead(
    model: 'ir.model',
    fields: const ['model'],
    domain: [
      ['model', 'in', _probedModels],
    ],
    limit: _probedModels.length,
  );
  final models = records
      .map((record) => record['model'])
      .whereType<String>()
      .toSet();
  final fieldsByModel = <String, Set<String>>{};

  for (final entry in _probedFields.entries) {
    if (!models.contains(entry.key)) continue;
    final fields = await client.fieldsGet(
      model: entry.key,
      fields: entry.value,
      attributes: const ['type', 'relation'],
    );
    fieldsByModel[entry.key] = fields.keys.toSet();
  }

  return (version: version, models: models, fieldsByModel: fieldsByModel);
}

bool _isLoopbackHttp(String baseUrl) {
  final uri = Uri.tryParse(baseUrl);
  if (uri?.scheme != 'http') return false;
  return const {'localhost', '127.0.0.1', '::1'}.contains(uri?.host);
}

final class _SmokeConfig {
  final String baseUrl;
  final String apiKey;
  final String database;

  const _SmokeConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.database,
  });

  static _SmokeConfig? fromEnvironment(String prefix) {
    final baseUrl = Platform.environment['${prefix}_BASE_URL']?.trim();
    final apiKey = Platform.environment['${prefix}_API_KEY']?.trim();
    final database = Platform.environment['${prefix}_DATABASE']?.trim();
    if (baseUrl == null ||
        baseUrl.isEmpty ||
        apiKey == null ||
        apiKey.isEmpty ||
        database == null ||
        database.isEmpty) {
      return null;
    }
    return _SmokeConfig(baseUrl: baseUrl, apiKey: apiKey, database: database);
  }
}

final class _OdooSlot {
  final String prefix;
  final int expectedMajor;

  const _OdooSlot({required this.prefix, required this.expectedMajor});
}

final class _ContractSlot {
  final String prefix;

  const _ContractSlot({required this.prefix});
}

const _probedModels = <String>[
  'ir.model',
  'res.bank',
  'l10n.ec.bank',
  'res.partner.bank',
  'uom.uom',
  'sale.order.line',
  'stock.move',
  'stock.quant',
  'stock.scrap',
  'product.template',
  'collection.session',
  'l10n_ec_collection_box.sale.order.payment.wizard',
  'account.move',
  'ir.actions.report',
  'res.users',
];

const _probedFields = <String, List<String>>{
  'ir.model': ['model', 'name'],
  'sale.order.line': ['product_uom', 'product_uom_id'],
  'stock.move': ['product_uom', 'uom_id', 'is_scrap'],
  'ir.actions.report': ['report_name', 'report_type'],
};

/// Required schema for the deployed Odoo 19.5 collection/sales contract.
/// Keep this read-only: fields_get does not create or mutate records.
const _required195Fields = <String, List<String>>{
  'l10n.ec.bank': ['name', 'code', 'tipo', 'active'],
  'l10n_ec_collection_box.sale.order.payment': [
    'l10n_ec_bank_id',
    'bank_name_ec',
  ],
  'l10n_ec_collection_box.sale.order.payment.wizard.line': [
    'l10n_ec_bank_id',
    'bank_name_ec',
  ],
  'sale.order.line': ['product_uom_id'],
  'res.partner.bank': ['account_number', 'bank_name'],
  'l10n_ec.cash.out': ['cash_out_uuid'],
  'account.advance': ['external_id', 'advance_line_ids'],
  'account.advance.line': ['journal_id', 'amount', 'advance_method_line_id'],
};

const _wizardLineModel =
    'l10n_ec_collection_box.sale.order.payment.wizard.line';
