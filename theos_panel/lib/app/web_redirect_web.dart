import 'package:web/web.dart' as web;

void redirectToOdooLogin() {
  final current = web.window.location.href;
  final redirect = Uri.encodeComponent(current);
  web.window.location.replace('/web/login?redirect=$redirect');
}
