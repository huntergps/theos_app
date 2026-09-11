import 'package:flutter/material.dart';

import 'theme/orbi_theme.dart';
import '../ui/components/orbi_brand.dart';

/// Branded startup surface. It intentionally has no session or persistence
/// responsibilities; the app shell decides when it should be shown.
final class OrbiSplashScreen extends StatelessWidget {
  const OrbiSplashScreen({super.key, this.message = 'Preparando Orbi ERP…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('orbi-splash'),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const OrbiAuthBackdrop(),
          SafeArea(
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
                          OrbiBrand(height: logoHeight, color: orbiPhotoInk),
                          const SizedBox(height: OrbiTheme.space32),
                          Semantics(
                            liveRegion: true,
                            label: message,
                            child: Text(
                              message,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: orbiPhotoInk),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: OrbiTheme.space16),
                          CircularProgressIndicator(
                            color: orbiPhotoInk,
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
        ],
      ),
    );
  }
}
