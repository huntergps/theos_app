import 'package:dio/dio.dart';

/// No-op on web — browsers manage certificate validation.
void configureCertificatePinning(
  Dio dio,
  List<String> sha256Pins,
  bool allowSystemCertificates,
) {}
