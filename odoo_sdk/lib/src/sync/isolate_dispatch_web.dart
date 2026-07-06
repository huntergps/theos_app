/// Web implementation: no isolates.
///
/// `dart:isolate`'s `Isolate.run()` (and `Isolate.spawn()`) throw
/// `UnsupportedError` on Flutter Web **at runtime** (this is NOT a
/// compile-time error, so it would ship silently and only fail in
/// production if not guarded). Flutter's own `compute()` handles this the
/// same way: on Web it just runs the function synchronously on the calling
/// (only) isolate instead of spawning a new one. We mirror that behavior
/// here so `parseInIsolate` has identical semantics on every platform from
/// the caller's point of view — it just won't get the isolate offload on
/// Web (there's no isolate to offload to).
Future<List<T>> parseInIsolate<T>(
  List<Map<String, dynamic>> pages,
  T Function(Map<String, dynamic>) parser,
) async {
  return pages.map(parser).toList();
}
