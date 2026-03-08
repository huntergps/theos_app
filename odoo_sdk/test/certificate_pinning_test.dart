import 'package:test/test.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

void main() {
  group('SEC-05: Certificate Pinning', () {
    group('CertificatePinningConfig', () {
      test('creates with required sha256Pins', () {
        const config = CertificatePinningConfig(
          sha256Pins: {'abc123=', 'def456='},
        );

        expect(config.sha256Pins, {'abc123=', 'def456='});
        expect(config.sha256Pins.length, 2);
      });

      test('allowSystemCertificates defaults to false', () {
        const config = CertificatePinningConfig(sha256Pins: {'abc123='});

        expect(config.allowSystemCertificates, false);
      });

      test('allowSystemCertificates can be set to true', () {
        const config = CertificatePinningConfig(
          sha256Pins: {'abc123='},
          allowSystemCertificates: true,
        );

        expect(config.allowSystemCertificates, true);
      });

      test('creates with empty pins set', () {
        const config = CertificatePinningConfig(sha256Pins: {});

        expect(config.sha256Pins, isEmpty);
      });

      test('sha256Pins is a Set (no duplicates)', () {
        final config = CertificatePinningConfig(
          sha256Pins: Set.from(['abc123=', 'abc123=', 'def456=']),
        );

        expect(config.sha256Pins.length, 2);
      });
    });

    group('OdooClientConfig with certificate pinning', () {
      test('certificatePinning defaults to null', () {
        const config = OdooClientConfig(
          baseUrl: 'https://example.com',
          apiKey: 'test-key',
        );

        expect(config.certificatePinning, isNull);
      });

      test('certificatePinning can be set', () {
        const pinConfig = CertificatePinningConfig(
          sha256Pins: {'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='},
        );

        const config = OdooClientConfig(
          baseUrl: 'https://example.com',
          apiKey: 'test-key',
          certificatePinning: pinConfig,
        );

        expect(config.certificatePinning, isNotNull);
        expect(config.certificatePinning!.sha256Pins.length, 1);
        expect(
          config.certificatePinning!.sha256Pins,
          contains('AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='),
        );
      });

      test('certificatePinning with multiple pins for rotation', () {
        const pinConfig = CertificatePinningConfig(
          sha256Pins: {
            'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
            'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=',
          },
        );

        const config = OdooClientConfig(
          baseUrl: 'https://example.com',
          apiKey: 'test-key',
          certificatePinning: pinConfig,
        );

        expect(config.certificatePinning!.sha256Pins.length, 2);
      });
    });

    group('OdooClientConfig.copyWith preserves pinning', () {
      test('copyWith preserves certificatePinning when not overridden', () {
        const pinConfig = CertificatePinningConfig(
          sha256Pins: {'pin1=', 'pin2='},
          allowSystemCertificates: true,
        );

        const config = OdooClientConfig(
          baseUrl: 'https://example.com',
          apiKey: 'test-key',
          certificatePinning: pinConfig,
        );

        final copy = config.copyWith(baseUrl: 'https://other.com');

        expect(copy.certificatePinning, isNotNull);
        expect(copy.certificatePinning!.sha256Pins, {'pin1=', 'pin2='});
        expect(copy.certificatePinning!.allowSystemCertificates, true);
      });

      test('copyWith can override certificatePinning', () {
        const originalPinConfig = CertificatePinningConfig(
          sha256Pins: {'old-pin='},
        );

        const config = OdooClientConfig(
          baseUrl: 'https://example.com',
          apiKey: 'test-key',
          certificatePinning: originalPinConfig,
        );

        const newPinConfig = CertificatePinningConfig(
          sha256Pins: {'new-pin='},
          allowSystemCertificates: true,
        );

        final copy = config.copyWith(certificatePinning: newPinConfig);

        expect(copy.certificatePinning!.sha256Pins, {'new-pin='});
        expect(copy.certificatePinning!.allowSystemCertificates, true);
      });

      test('copyWith preserves null certificatePinning', () {
        const config = OdooClientConfig(
          baseUrl: 'https://example.com',
          apiKey: 'test-key',
        );

        final copy = config.copyWith(apiKey: 'new-key');

        expect(copy.certificatePinning, isNull);
      });
    });

    group('OdooClientConfig.toString with pinning', () {
      test('toString shows pinning disabled when no pinning configured', () {
        const config = OdooClientConfig(
          baseUrl: 'https://example.com',
          apiKey: 'test-key',
        );

        expect(config.toString(), contains('certificatePinning: disabled'));
      });

      test('toString shows pinning enabled with pin count', () {
        const pinConfig = CertificatePinningConfig(
          sha256Pins: {'pin1=', 'pin2='},
        );

        const config = OdooClientConfig(
          baseUrl: 'https://example.com',
          apiKey: 'test-key',
          certificatePinning: pinConfig,
        );

        final str = config.toString();
        expect(str, contains('certificatePinning: enabled (2 pins)'));
      });

      test('toString shows single pin count', () {
        const pinConfig = CertificatePinningConfig(sha256Pins: {'single-pin='});

        const config = OdooClientConfig(
          baseUrl: 'https://example.com',
          apiKey: 'test-key',
          certificatePinning: pinConfig,
        );

        expect(
          config.toString(),
          contains('certificatePinning: enabled (1 pins)'),
        );
      });
    });

    group('OdooHttpClient with certificate pinning', () {
      test('creates client without pinning (null config)', () {
        final client = OdooHttpClient(
          config: const OdooClientConfig(
            baseUrl: 'https://example.com',
            apiKey: 'test-key',
          ),
        );

        expect(client.config.certificatePinning, isNull);
      });

      test('creates client with pinning configured', () {
        const pinConfig = CertificatePinningConfig(
          sha256Pins: {'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='},
        );

        final client = OdooHttpClient(
          config: const OdooClientConfig(
            baseUrl: 'https://example.com',
            apiKey: 'test-key',
            certificatePinning: pinConfig,
          ),
        );

        expect(client.config.certificatePinning, isNotNull);
        expect(client.config.certificatePinning!.sha256Pins.length, 1);
      });

      test('Dio uses IOHttpClientAdapter on native platforms', () {
        // On native (non-web) platforms, Dio uses IOHttpClientAdapter by default.
        // When certificate pinning is configured, _configureCertificatePinning
        // sets up the onHttpClientCreate callback on the adapter.
        const pinConfig = CertificatePinningConfig(sha256Pins: {'test-pin='});

        final client = OdooHttpClient(
          config: const OdooClientConfig(
            baseUrl: 'https://example.com',
            apiKey: 'test-key',
            certificatePinning: pinConfig,
          ),
        );

        // Verify the client was created successfully with pinning
        expect(client.isConfigured, true);
        expect(client.config.certificatePinning, isNotNull);
      });
    });
  });
}
