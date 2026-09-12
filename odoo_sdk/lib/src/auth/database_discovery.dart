// A single implementation for every platform, deliberately.
//
// This used to be a conditional export with a Flutter-web variant
// (`database_discovery_web.dart`) that refused to even attempt
// `/web/database/list`, on the assumption that a browser build is always
// cross-origin from the target Odoo host and therefore always CORS-blocked.
// That assumption does not hold: CORS only restricts *cross-origin* requests
// — a browser build served from the SAME origin as the Odoo host (the
// deployment this project's own `docs/orbi_panel/decisions/W01-web-auth.md`
// recommends) is not cross-origin at all, and the request succeeds exactly
// like it does from any non-browser client. Measured directly against
// ERP2: a same-origin-equivalent call to `/web/database/list` returns the
// database list with no CORS headers involved on either side, because none
// are needed for a same-origin request.
//
// `Dio()` already resolves to a browser-compatible adapter on web (the same
// unconditional `Dio()` this package's main JSON-2 client,
// `OdooHttpClient`, already uses for real web traffic — see
// `api/client/odoo_http_client.dart`), so there is no platform-specific code
// left to write here. A cross-origin deployment without server-side CORS
// support for this route still fails, but now with the server's own
// unreachable/blocked response surfacing as
// [DatabaseDiscoveryFailureKind.connection] — an honest, measured outcome —
// instead of a canned [DatabaseDiscoveryFailureKind.unsupportedPlatform]
// excuse applied unconditionally regardless of where the build is served
// from.
export 'database_discovery_io.dart';
