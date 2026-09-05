import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:test/test.dart';

void main() {
  const testApiKey = 'retry-test-secret-api-key';

  OdooClient clientFor(HttpServer server, {void Function(Object)? onRetry}) {
    return OdooClient(
      config: OdooClientConfig(
        baseUrl: 'http://${server.address.host}:${server.port}',
        apiKey: testApiKey,
        database: 'retry_test',
        allowInsecure: true,
        retryConfig: RetryConfig(
          maxRetries: 1,
          initialDelay: Duration.zero,
          maxDelay: Duration.zero,
          useJitter: false,
          onRetry: onRetry == null ? null : (_, _, error) => onRetry(error),
        ),
      ),
    );
  }

  test('safe JSON-2 read retries once after a transient response', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));

    var attempts = 0;
    final served = Completer<void>();
    final subscription = server.listen((request) async {
      attempts++;
      expect(request.method, 'POST');
      expect(request.uri.path, '/json/2/res.partner/search_read');
      await utf8.decoder.bind(request).join();

      if (attempts == 1) {
        request.response
          ..statusCode = HttpStatus.serviceUnavailable
          ..headers.contentType = ContentType.json
          ..write('{"error":"temporarily unavailable"}');
      } else {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write('[{"id":1,"name":"Retry succeeded"}]');
        served.complete();
      }
      await request.response.close();
    });
    addTearDown(subscription.cancel);

    final records = await clientFor(server)
        .searchRead(model: 'res.partner', fields: const ['name']);
    await served.future.timeout(const Duration(seconds: 2));

    expect(attempts, 2);
    expect(records.single['name'], 'Retry succeeded');
  });

  test('JSON-2 mutation is never resent after a transient response', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));

    var attempts = 0;
    final firstRequest = Completer<void>();
    final subscription = server.listen((request) async {
      attempts++;
      expect(request.method, 'POST');
      expect(request.uri.path, '/json/2/res.partner/create');
      await utf8.decoder.bind(request).join();
      request.response
        ..statusCode = HttpStatus.serviceUnavailable
        ..headers.contentType = ContentType.json
        ..write('{"error":"ambiguous create"}');
      await request.response.close();
      firstRequest.complete();
    });
    addTearDown(subscription.cancel);

    await expectLater(
      clientFor(server).create(
        model: 'res.partner',
        values: const {'name': 'Must not be duplicated'},
      ),
      throwsA(isA<OdooException>()),
    );
    await firstRequest.future.timeout(const Duration(seconds: 2));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(attempts, 1);
  });

  test(
    'retry errors and final failures do not expose bearer secrets',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      final retryErrors = <String>[];
      var attempts = 0;
      final subscription = server.listen((request) async {
        attempts++;
        await utf8.decoder.bind(request).join();
        request.response
          ..statusCode = HttpStatus.serviceUnavailable
          ..headers.contentType = ContentType.json
          ..write('{"error":"still unavailable"}');
        await request.response.close();
      });
      addTearDown(subscription.cancel);

      Object? failure;
      try {
        await clientFor(
          server,
          onRetry: (error) => retryErrors.add(error.toString()),
        ).searchCount(model: 'res.users', domain: const []);
      } catch (error) {
        failure = error;
      }

      expect(attempts, 2);
      expect(failure, isA<OdooException>());
      expect(retryErrors, isNotEmpty);
      expect(retryErrors.join('\n'), isNot(contains(testApiKey)));
      expect(failure.toString(), isNot(contains(testApiKey)));
    },
  );
}
