import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/fluent/orbi_fluent_theme.dart';
import 'preferences/app_preferences.dart';
import 'router.dart';

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
