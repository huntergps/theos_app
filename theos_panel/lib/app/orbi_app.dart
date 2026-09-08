import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme/orbi_theme.dart';
import 'preferences/app_preferences.dart';

class OrbiApp extends ConsumerWidget {
  const OrbiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(
      appPreferencesProvider(ref.watch(preferencesScopeProvider)),
    );
    return AnimatedBuilder(
      animation: preferences,
      builder: (context, _) => MaterialApp.router(
        title: 'Orbi ERP',
        theme: OrbiTheme.fromSeed(
          Color(preferences.snapshot.accentSeed),
          Brightness.light,
          visualDensity:
              preferences.snapshot.density == PreferenceDensity.compact
              ? VisualDensity.compact
              : VisualDensity.standard,
        ),
        darkTheme: OrbiTheme.fromSeed(
          Color(preferences.snapshot.accentSeed),
          Brightness.dark,
          visualDensity:
              preferences.snapshot.density == PreferenceDensity.compact
              ? VisualDensity.compact
              : VisualDensity.standard,
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(preferences.snapshot.textScale),
          ),
          child: child ?? const SizedBox.shrink(),
        ),
        themeMode: preferences.snapshot.materialThemeMode,
        routerConfig: ref.watch(orbiRouterProvider),
      ),
    );
  }
}
