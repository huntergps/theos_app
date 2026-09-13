import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

/// El diálogo de «Confirmar cierre», por sí solo.
///
/// Va aparte de [DesktopCloseGuard] a propósito: probarlo así no necesita un
/// canal de plataforma real de `window_manager` —que no existe dentro de
/// `flutter test`— sólo `showDialog`. Texto y botones son literalmente los
/// de `theos_pos` (`theos_pos/lib/shared/screens/main_screen.dart`,
/// `onWindowClose`): el dueño pidió mirar qué hace `theos_pos` y iguala
/// siempre, sin condicionarlo a que haya operaciones pendientes en la cola.
Future<bool?> showConfirmCloseDialog(BuildContext context) => showDialog<bool>(
  context: context,
  builder: (dialogContext) => ContentDialog(
    title: const Text('Confirmar cierre'),
    content: const Text('¿Estás seguro de que deseas cerrar la aplicación?'),
    actions: [
      Button(
        child: const Text('No'),
        onPressed: () => Navigator.of(dialogContext).pop(false),
      ),
      FilledButton(
        key: const Key('confirm-close-yes'),
        child: const Text('Sí'),
        onPressed: () => Navigator.of(dialogContext).pop(true),
      ),
    ],
  ),
);

/// Envuelve el árbol operativo para preguntar antes de cerrar la ventana en
/// escritorio — nunca en web ni en móvil, donde no hay ventana que cerrar.
///
/// 🔴 Separado de `OperationalShell` a propósito. `window_manager` habla por
/// canal de plataforma, y ese canal no existe dentro de `flutter test`:
/// meter `WindowListener` dentro del marco que las pruebas de
/// `operational_shell_test.dart` instancian en cada prueba habría roto las
/// cuarenta y una de un tirón. Aquí, en cambio, sólo se paga ese costo quien
/// lo use de verdad (`router.dart`, envolviendo `OperationalShell`).
///
/// [onBeforeClose] es el hueco para un cierre limpio de sesión, equivalente
/// al que hace `theos_pos` en su propio `onWindowClose`
/// (`runBestEffortSessionCleanup` + `AppInitializer.deactivateSessionScope`).
/// Ese vaciado vive en código de sesión que no toca este encargo —queda
/// como una conexión pendiente para quien integre esto en `router.dart`.
class DesktopCloseGuard extends StatefulWidget {
  const DesktopCloseGuard({super.key, required this.child, this.onBeforeClose});

  final Widget child;
  final Future<void> Function()? onBeforeClose;

  @override
  State<DesktopCloseGuard> createState() => _DesktopCloseGuardState();
}

class _DesktopCloseGuardState extends State<DesktopCloseGuard>
    with WindowListener {
  bool get _isDesktop {
    if (kIsWeb) return false;
    return const [
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.macOS,
    ].contains(defaultTargetPlatform);
  }

  @override
  void initState() {
    super.initState();
    if (_isDesktop) {
      windowManager.addListener(this);
      // La prevención vive con la guarda: si se activara al arrancar y la
      // guarda no estuviera montada, el botón de cerrar no haría nada.
      unawaited(windowManager.setPreventClose(true));
    }
  }

  @override
  void dispose() {
    if (_isDesktop) {
      windowManager.removeListener(this);
      unawaited(windowManager.setPreventClose(false));
    }
    super.dispose();
  }

  @override
  void onWindowClose() async {
    if (!_isDesktop) return;
    final isPreventClose = await windowManager.isPreventClose();
    if (!isPreventClose || !mounted) return;

    final confirmed = await showConfirmCloseDialog(context);
    if (confirmed != true) return;

    await widget.onBeforeClose?.call();
    await windowManager.destroy();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
