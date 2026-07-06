/// Stub for isolate-based page parsing (should never be called).
///
/// Selected by the conditional export in `isolate_dispatch.dart` only if
/// neither `dart.library.io` nor `dart.library.js_interop` is available —
/// no real Flutter/Dart compile target hits this today (it's either native,
/// which has `dart:io`, or Web, which has `js_interop`). Mirrors the same
/// stub pattern already used in
/// `odoo_sdk/lib/src/websocket/platform/websocket_connect_stub.dart`.
Future<List<T>> parseInIsolate<T>(
  List<Map<String, dynamic>> pages,
  T Function(Map<String, dynamic>) parser,
) async {
  throw UnimplementedError(
    'parseInIsolate not supported on this platform (neither dart:io nor '
    'Web js_interop available)',
  );
}
