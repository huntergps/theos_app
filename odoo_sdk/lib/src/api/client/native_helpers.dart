import 'dart:convert' show base64;
import 'dart:io' show HttpClient;

import 'package:crypto/crypto.dart' show sha256;
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';

/// Add cookie manager interceptor (native only).
void addCookieManager(Dio dio, Object cookieJar) {
  dio.interceptors.add(CookieManager(cookieJar as CookieJar));
}

/// Create a CookieJar instance.
Object createCookieJar() => CookieJar();

/// Load cookies for a URL from the CookieJar.
Future<List<dynamic>> loadCookies(Object cookieJar, Uri uri) async {
  return (cookieJar as CookieJar).loadForRequest(uri);
}

/// Configure certificate pinning on Dio (native only).
void configureCertificatePinning(
  Dio dio,
  List<String> sha256Pins,
  bool allowSystemCertificates,
) {
  final adapter = dio.httpClientAdapter;
  if (adapter is IOHttpClientAdapter) {
    adapter.createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) {
        if (sha256Pins.isEmpty) return true;

        final certBytes = cert.der;
        final digest = sha256.convert(certBytes);
        final certPin = base64.encode(digest.bytes);

        final pinMatches = sha256Pins.contains(certPin);
        if (pinMatches) return true;
        if (allowSystemCertificates) return false;
        return false;
      };
      return client;
    };
  }
}
