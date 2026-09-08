import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/erp2_harness.dart';

/// V01 is an explicitly opt-in integration stage. With no run sentinel the
/// normal suite is skipped and cannot contact any Odoo host. When enabled,
/// every fixture, actor, method contract and cleanup capability is read before
/// the first mutation.
void main() {
  final runEnabled =
      Platform.environment['ORBI_ERP2_RUN_WRITES'] ==
      'I_UNDERSTAND_ORBI_E2E_WRITES';

  test('V01 ERP2 four-flow harness (opt-in)', () async {
    final config = Erp2HarnessConfig.fromEnvironment(Platform.environment);
    config.requireWritePreflight();
    final auditKey = Platform.environment['ORBI_ERP2_AUDIT_API_KEY'] ?? '';
    if (auditKey.isEmpty) {
      fail('ORBI_ERP2_AUDIT_API_KEY is required for V01 preflight.');
    }
    final auditClient = OdooClient(
      config: OdooClientConfig(
        baseUrl: config.serverUrl,
        database: config.database,
        apiKey: auditKey,
      ),
    );
    final readiness = await Erp2ServerPreflight(client: auditClient)
        .check(config, forWrites: true);
    if (!readiness.ok) {
      fail(
        'V01 server preflight blocked before mutation: '
        '${readiness.errors.join('; ')}',
      );
    }

    final actorClients = <Erp2Actor, OdooClient>{};
    for (final actor in Erp2Actor.values) {
      final key =
          Platform
              .environment['ORBI_ERP2_${actor.name.toUpperCase()}_API_KEY'] ??
          '';
      if (key.isEmpty) fail('${actor.name} API key is required.');
      actorClients[actor] = OdooClient(
        config: OdooClientConfig(
          baseUrl: config.serverUrl,
          database: config.database,
          apiKey: key,
        ),
      );
    }

    final harness = Erp2WriteHarness(
      config: config,
      auditClient: auditClient,
      actorClients: actorClients,
    );
    Map<String, Object?>? evidence;
    try {
      evidence = await harness.run();
    } finally {
      // ERP2 V01 fixtures are retained for audit. No archive/unlink/write is
      // attempted in cleanup, including when the write stage fails.
      await harness.retainPrefixedFixtures();
    }
    await File(config.evidenceFile)
        .writeAsString(const JsonEncoder.withIndent('  ').convert(evidence));
  }, skip: runEnabled ? null : 'V01 remote stage disabled; set run sentinel');
}
