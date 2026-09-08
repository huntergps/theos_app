import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'theme/orbi_theme.dart';

/// Branded startup surface. It intentionally has no session or persistence
/// responsibilities; the app shell decides when it should be shown.
final class OrbiSplashScreen extends StatelessWidget {
  const OrbiSplashScreen({super.key, this.message = 'Preparando Orbi ERP…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      key: const Key('orbi-splash'),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colors.primary, colors.tertiary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final logoHeight = (constraints.maxHeight * .22).clamp(
                80.0,
                180.0,
              );
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(OrbiTheme.space24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Semantics(
                          label: 'Marca Orbi ERP',
                          image: true,
                          child: SvgPicture.asset(
                            'assets/images/orbi_logo.svg',
                            height: logoHeight,
                            colorFilter: ColorFilter.mode(
                              colors.onPrimary,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                        const SizedBox(height: OrbiTheme.space32),
                        Semantics(
                          liveRegion: true,
                          label: message,
                          child: Text(
                            message,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: colors.onPrimary),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: OrbiTheme.space16),
                        CircularProgressIndicator(
                          color: colors.onPrimary,
                          semanticsLabel: 'Cargando',
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
