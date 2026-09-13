import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;

/// Traduce el ciclo de vida real de la app (`AppLifecycleListener`) a un
/// `Stream<bool>` de «está en primer plano» — la única forma en que
/// `SyncAutoResyncTrigger` (en `orbi_runtime`, agnóstico de Flutter) puede
/// escucharlo sin depender de `package:flutter`.
///
/// En la web, Flutter ya deriva `resumed`/`hidden` de
/// `document.visibilityState`: volver a la pestaña visible es exactamente
/// `onShow`/`onResume`, no hace falta un puente aparte para el navegador.
final class AppForegroundSignal {
  AppForegroundSignal() {
    _listener = AppLifecycleListener(
      onResume: () => _emit(true),
      onShow: () => _emit(true),
      onHide: () => _emit(false),
      onPause: () => _emit(false),
      onInactive: () => _emit(false),
      onDetach: () => _emit(false),
    );
  }

  final _controller = StreamController<bool>.broadcast();
  late final AppLifecycleListener _listener;

  Stream<bool> get stream => _controller.stream;

  void _emit(bool value) {
    if (!_controller.isClosed) _controller.add(value);
  }

  void dispose() {
    _listener.dispose();
    unawaited(_controller.close());
  }
}
