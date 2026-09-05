import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/core/security/transport_security.dart';

void main() {
  group('allowsInsecureLoopbackTransport', () {
    test('allows clear-text transport for canonical loopback hosts', () {
      expect(allowsInsecureLoopbackTransport('http://localhost:8069'), isTrue);
      expect(
        allowsInsecureLoopbackTransport('http://127.0.0.1:8069/json/2'),
        isTrue,
      );
      expect(allowsInsecureLoopbackTransport('http://[::1]:8069'), isTrue);
    });

    test('rejects non-loopback clear-text hosts in every build mode', () {
      expect(
        allowsInsecureLoopbackTransport('http://erp2.tecnosmart.com.ec'),
        isFalse,
      );
      expect(
        allowsInsecureLoopbackTransport('http://192.168.1.10:8069'),
        isFalse,
      );
      expect(
        allowsInsecureLoopbackTransport('http://localhost.example.com'),
        isFalse,
      );
    });

    test('does not mark HTTPS or malformed URLs as insecure exceptions', () {
      expect(
        allowsInsecureLoopbackTransport('https://localhost:8069'),
        isFalse,
      );
      expect(allowsInsecureLoopbackTransport('not a URL'), isFalse);
    });
  });
}
