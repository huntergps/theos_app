import 'dart:convert' show base64;
import 'dart:io' show HttpClient;

import 'package:crypto/crypto.dart' show sha256;
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

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
