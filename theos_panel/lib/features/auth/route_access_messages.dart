/// What to say when someone reaches a screen their permissions do not cover.
///
/// 🔴 The tone is the whole point, and it is not decoration.
///
/// A seller who has no Caja permission is **not** looking at an error. That is
/// simply the job they have. Measured on ERP2 with the real accounts: the
/// seller (uid 9) carries 19 groups and none of them is `Caja de Cobros /
/// Cajero`, while the cashier (uid 23) carries the same 19 plus that one.
/// Neither of those is a failure — they are two roles.
///
/// So these messages never say "no tienes acceso" as if something broke, and
/// they carry [OrbiMessageSeverity.info], not `error`. Telling a seller that
/// something failed when nothing failed sends them to ask for help they do
/// not need, and quietly teaches them that the app is unreliable.
///
/// The one that IS styled as attention is [_loadingPermissions], because that
/// one really is temporary and really does mean "try again in a moment".
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbi_runtime/orbi_runtime.dart' show CapabilitySnapshot;

import '../../ui/components/copyable_message.dart';



/// Still waiting for the server to say what this person may do.
///
/// A genuinely different situation from a permission that is absent: nothing
/// has been decided yet. `RouteAccessPolicy.allows` treats a null snapshot as
/// "everything gated stays closed", which is the right call, but it must not
/// be reported with the same words as a refusal.
const CopyableMessage _loadingPermissions = CopyableMessage(
  title: 'Todavía estamos cargando tus permisos',
  body:
      'Aún no sabemos qué partes te corresponden, así que por ahora sólo se '
      'puede entrar al inicio y a la configuración. Espera unos segundos y '
      'vuelve a intentarlo.',
  severity: OrbiMessageSeverity.warning,
);

/// One entry per gated area of `RouteAccessPolicy`, in the same order, so the
/// two can be read side by side.
const Map<String, String> _areaNames = {
  '/collection': 'Caja',
  '/warehouse': 'Bodega',
  '/envases': 'Envases',
  '/sales': 'Ventas',
  '/clients': 'Clientes',
  '/products': 'Productos',
  '/approvals': 'Aprobaciones',
  '/sync': 'Sincronización',
  '/activities': 'Actividades',
  '/notifications': 'Avisos',
  '/reports': 'Reportes',
};

/// Who to ask, per area. Naming the right person is the difference between a
/// message that closes a door and one that opens a path.
const Map<String, String> _whoToAsk = {
  '/collection': 'Si necesitas cobrar, pídele a tu supervisor el permiso de '
      'cajero.',
  '/warehouse': 'Si necesitas mover existencias, pídele a tu supervisor el '
      'permiso de bodega.',
  '/envases': 'Si necesitas ver o mover envases, pídeselo a tu supervisor.',
  '/approvals': 'Aprobar es cosa de quien tiene ese encargo. Si crees que te '
      'toca a ti, pídeselo a tu supervisor.',
  '/sync': 'La sincronización la maneja quien administra el sistema.',
};

/// The message for [path], or null when the person may actually be there.
///
/// Returns [_loadingPermissions] when [capabilities] has not arrived yet: not
/// knowing is not the same as being refused.
CopyableMessage? routeAccessDeniedMessage(
  String path, {
  required CapabilitySnapshot? capabilities,
}) {
  if (path == '/' || path == '/settings' || path == '/login') return null;
  if (capabilities == null) return _loadingPermissions;
  final area = _areaFor(path);
  if (area == null) return _unknownArea;
  return CopyableMessage(
    title: '${_areaNames[area]} no está entre tus permisos',
    body:
        'Esto no es un fallo: tu usuario no tiene ese permiso, así que esa '
        'parte no te corresponde. '
        '${_whoToAsk[area] ?? 'Si crees que deberías entrar, pídeselo a tu supervisor.'}',
    severity: OrbiMessageSeverity.info,
  );
}

/// A gated path with no area of its own. Says the honest vague thing rather
/// than naming an area it cannot identify.
const CopyableMessage _unknownArea = CopyableMessage(
  title: 'Esa parte no está entre tus permisos',
  body:
      'Esto no es un fallo: tu usuario no tiene el permiso que hace falta '
      'para esa pantalla. Si crees que deberías entrar, pídeselo a tu '
      'supervisor.',
  severity: OrbiMessageSeverity.info,
);

String? _areaFor(String path) {
  for (final area in _areaNames.keys) {
    if (path == area || path.startsWith('$area/')) return area;
  }
  return null;
}

/// Every area this module can name, for the test that keeps it aligned with
/// `RouteAccessPolicy`.
Iterable<String> get knownGatedAreas => _areaNames.keys;

/// Carries the refusal from the redirect to whatever screen ends up on
/// screen, because the two happen in different places.
///
/// `GoRouter`'s `redirect` can only return a destination — it has no way to
/// say anything on the way out, which is precisely why the refusal has been
/// silent. So the redirect deposits the message here and the shell picks it
/// up once, on the screen the person actually lands on.
///
/// [take] is deliberately a one-shot read: a refusal explains ONE navigation
/// that did not happen. Leaving it around would make it reappear later,
/// attached to a move that had nothing to do with it.
final class RouteAccessDenialNotifier extends Notifier<CopyableMessage?> {
  @override
  CopyableMessage? build() => null;

  /// Records why [path] was refused. Returns whether anything was recorded,
  /// so a caller can tell a real refusal from a path that was always open.
  bool report(String path, {required CapabilitySnapshot? capabilities}) {
    final message = routeAccessDeniedMessage(path, capabilities: capabilities);
    if (message == null) return false;
    state = message;
    return true;
  }

  /// Reads and clears in one step.
  CopyableMessage? take() {
    final message = state;
    state = null;
    return message;
  }
}

final routeAccessDenialProvider =
    NotifierProvider<RouteAccessDenialNotifier, CopyableMessage?>(
      RouteAccessDenialNotifier.new,
    );
