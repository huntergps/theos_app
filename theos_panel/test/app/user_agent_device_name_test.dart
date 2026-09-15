import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/app/user_agent_device_name.dart';

/// El valor por omisión del nombre del equipo en la web (encargo del
/// 14-sep-2026): «sale del agente de usuario, por ejemplo "Chrome en
/// macOS"». Pura, sin `dart:js_interop` ni `package:web`, así que corre con
/// `flutter test` normal — a diferencia de `device_name_factory_web.dart`,
/// que sólo puede probarse `--platform chrome` (ver
/// `test/web/web_crypto_unlock_backend_test.dart`).
void main() {
  test('web default comes from user agent: Chrome en macOS', () {
    const chromeOnMac =
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
        'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 '
        'Safari/537.36';
    expect(describeUserAgentDeviceName(chromeOnMac), 'Chrome en macOS');
  });

  test('reconoce Edge como Edge, no como Chrome', () {
    const edgeOnWindows =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36 Edg/128.0.0.0';
    expect(describeUserAgentDeviceName(edgeOnWindows), 'Edge en Windows');
  });

  test('reconoce Safari real (sin "Chrome/") en iOS', () {
    const safariOnIphone =
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 '
        'Mobile/15E148 Safari/604.1';
    expect(describeUserAgentDeviceName(safariOnIphone), 'Safari en iOS');
  });

  test('un user-agent irreconocible cae a una frase genérica, nunca lanza', () {
    expect(describeUserAgentDeviceName(''), 'Este navegador');
    expect(describeUserAgentDeviceName('algo-inventado/1.0'), 'Este navegador');
  });
}
