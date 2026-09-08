import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/erp2_harness.dart';

/// Server-side V01 runner. It is deliberately skipped unless the same two
/// explicit write sentinels used by the integration runner are present. This
/// makes it runnable with `flutter test` (without a GUI/device) while keeping
/// the business flow implementation in [Erp2WriteHarness].
void main() {
  final runEnabled =
      Platform.environment['ORBI_ERP2_RUN_WRITES'] ==
      'I_UNDERSTAND_ORBI_E2E_WRITES';

  test('V01 ERP2 four-flow server harness (opt-in)', () async {
    final config = Erp2HarnessConfig.fromEnvironment(Platform.environment);
    // This validates the exact ERP2 host, rejects newerp/admin, and requires
    // all four actors, prefixed fixtures, cleanup mode and evidence path.
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
        sendTimeout: Erp2HarnessTiming.serverCallTimeout,
        receiveTimeout: Erp2HarnessTiming.serverCallTimeout,
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
          sendTimeout: Erp2HarnessTiming.serverCallTimeout,
          receiveTimeout: Erp2HarnessTiming.serverCallTimeout,
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
      // V01 retains prefixed fixtures for audit; it does not archive/unlink.
      await harness.retainPrefixedFixtures();
    }
    await File(config.evidenceFile)
        .writeAsString(const JsonEncoder.withIndent('  ').convert(evidence));
  },
    skip: runEnabled ? null : 'V01 remote stage disabled; set run sentinel',
    timeout: Timeout(Erp2HarnessTiming.suiteTimeout),
  );
}
