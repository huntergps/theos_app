import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import '../features/auth/auth_controller.dart';
import '../ui/fluent/orbi_fluent_theme.dart';
import 'preferences/app_preferences.dart';
import 'router.dart';
import 'session_composition.dart';

/// El idioma fijo de toda la app — nunca el del sistema operativo. Vive como
/// constante, y no repetido dentro de `build`, para que un test de
/// localización (`orbi_app_locale_test.dart`) pueda comprobar EXACTAMENTE lo
/// que usa `FluentApp.router` más abajo, no una copia que podría divergir.
const Locale orbiAppLocale = Locale('es');

/// La raíz de Orbi.
///
/// Es `FluentApp`, no `MaterialApp`, por decisión del dueño del 11-sep-2026.
/// La aplicación madura de este mismo repositorio lleva 518 ficheros sin una
/// sola importación de Material y con las rejillas de Syncfusion dentro, así
/// que el camino está probado aquí, no supuesto.
class OrbiApp extends ConsumerWidget {
  const OrbiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps `SystemNotificationPresenter.activeScopeKey` following the real
    // session instead of the `'unconfigured'` sentinel it is built with in
    // `bootstrap.dart` (see the 13-sep-2026 real-time audit, §4): applies on
    // login/restore with the session's own scope, and again on logout with
    // `capabilities == null`, which resolves to `unconfiguredScopeKey` and
    // cancels whatever was left shown under the closed scope. Registered
    // here, not in `bootstrap.dart` or `auth_controller.dart`, so it never
    // competes with edits those two files are getting elsewhere right now.
    //
    // `ref.listen` (riverpod 3.4, no `fireImmediately` anymore) only reacts
    // to FUTURE changes, so the current value is applied once directly below
    // — safe to repeat every build because `activateScope` is a no-op when
    // the scope key has not actually changed.
    void syncNotificationScope(CapabilitySnapshot? capabilities) {
      ref
          .read(notificationPresenterProvider)
          ?.activateScope(
            capabilities?.scopeKey ??
                SystemNotificationPresenter.unconfiguredScopeKey,
          );
    }

    ref.listen<CapabilitySnapshot?>(
      capabilitySnapshotProvider,
      (previous, next) => syncNotificationScope(next),
    );
    syncNotificationScope(ref.read(capabilitySnapshotProvider));
    final preferences = ref.watch(
      appPreferencesProvider(ref.watch(preferencesScopeProvider)),
    );
    return AnimatedBuilder(
      animation: preferences,
      builder: (context, _) {
        final snapshot = preferences.snapshot;
        final density = snapshot.density == PreferenceDensity.compact
            ? VisualDensity.compact
            : VisualDensity.standard;
        return FluentApp.router(
          title: 'Orbi ERP',
          debugShowCheckedModeBanner: false,
          // 🔴 Causa raíz de las fechas en inglés («14 September 2026» en
          // Enviar, «day / month / year» en Movimientos), medida el
          // 14-sep-2026: sin `locale:`, `FluentApp` resuelve el idioma del
          // SISTEMA operativo en vez de forzar español, así que en cualquier
          // equipo con el sistema en inglés el `DatePicker` de fluent_ui
          // (que arma los nombres de mes con `DateFormat.MMMM(locale)` de
          // `package:intl`, ver `date_picker.dart` del paquete `fluent_ui`)
          // sale en inglés. `theos_pos/lib/main.dart:235` ya fija
          // `locale: const Locale('es')` en su propio `FluentApp.router` por
          // la misma razón — aquí faltaba ese mismo fijado. No hace falta
          // llamar `initializeDateFormatting`: `FluentApp` siempre incluye
          // `GlobalMaterialLocalizations.delegate` (ver
          // `fluent_app.dart` → `_localizationsDelegates`), y cargar esa
          // localización ya inicializa los símbolos de fecha de `intl` para
          // TODOS los idiomas (`loadDateIntlDataIfNotLoaded` en
          // `flutter_localizations`) — lo único que faltaba era fijar qué
          // idioma usa la app.
          locale: orbiAppLocale,
          theme: OrbiFluentTheme.fromSeed(
            Color(snapshot.accentSeed),
            Brightness.light,
            visualDensity: density,
          ),
          darkTheme: OrbiFluentTheme.fromSeed(
            Color(snapshot.accentSeed),
            Brightness.dark,
            visualDensity: density,
          ),
          themeMode: snapshot.appThemeMode,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(snapshot.textScale),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
          routerConfig: ref.watch(orbiRouterProvider),
        );
      },
    );
  }
}
