import 'dart:io' show gzip;

/// Compress bytes using gzip (native platforms).
List<int> gzipEncode(List<int> bytes) => gzip.encode(bytes);
