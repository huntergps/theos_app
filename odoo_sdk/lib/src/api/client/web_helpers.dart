import 'package:dio/dio.dart';

/// No-op on web — browsers handle cookies natively.
void addCookieManager(Dio dio, Object cookieJar) {}

/// Returns a dummy object on web (CookieJar is not available).
Object createCookieJar() => Object();

/// No-op on web — browsers handle cookies natively.
Future<List<dynamic>> loadCookies(Object cookieJar, Uri uri) async => [];

/// No-op on web — browsers manage certificate validation.
void configureCertificatePinning(
  Dio dio,
  List<String> sha256Pins,
  bool allowSystemCertificates,
) {}
