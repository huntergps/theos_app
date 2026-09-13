import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';

import 'theme/orbi_theme.dart';
import '../ui/components/orbi_brand.dart';

/// Branded startup surface. It intentionally has no session or persistence
/// responsibilities; the app shell decides when it should be shown.
final class OrbiSplashScreen extends StatelessWidget {
  const OrbiSplashScreen({super.key, this.message = 'Preparando Orbi ERP…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      key: const Key('orbi-splash'),
      // ScaffoldPage's own default padding is 24px top, painted with
      // scaffoldBackgroundColor UNDER the content — with a photo backdrop
      // that shows as a solid strip above it. The photo must start at the
      // very top of the screen instead.
      padding: EdgeInsets.zero,
      content: Stack(
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
                          // El símbolo gira y el texto no (ver
                          // `_AnimatedSplashSymbol`), así que el par ya no
                          // puede ser el `OrbiBrand` de una sola pieza. Pero
                          // sigue siendo UNA marca para quien usa lector de
                          // pantalla: envueltos en `Semantics` con
                          // `ExcludeSemantics` por dentro, se anuncia
                          // «Marca Orbi ERP» una sola vez, en vez de que
                          // `OrbiSymbol` y `OrbiWordmark` anuncien cada uno
                          // el suyo por separado.
                          Semantics(
                            label: 'Marca Orbi ERP',
                            image: true,
                            child: ExcludeSemantics(
                              child: Column(
                                children: [
                                  _AnimatedSplashSymbol(
                                    height: logoHeight,
                                    color: orbiPhotoInk,
                                  ),
                                  const SizedBox(height: OrbiTheme.space16),
                                  OrbiWordmark(
                                    height: logoHeight * 0.35,
                                    color: orbiPhotoInk,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: OrbiTheme.space32),
                          Semantics(
                            liveRegion: true,
                            label: message,
                            child: Text(
                              message,
                              style: FluentTheme.of(context).typography.bodyLarge
                                  ?.copyWith(color: orbiPhotoInk),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: OrbiTheme.space16),
                          // ProgressBar (the line), not ProgressRing (the
                          // circle) — orden del dueño, 12-sep-2026: «en
                          // theos_pos... con línea en lugar de círculo de
                          // carga», matching theos_pos's own splash screen
                          // (theos_pos/lib/shared/screens/splash_screen.dart).
                          // No `value`: indeterminate, since boot progress
                          // has no measurable percentage.
                          ProgressBar(
                            activeColor: orbiPhotoInk,
                            semanticLabel: 'Cargando',
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

/// The spinning brand mark theos_pos already shows on its own splash screen
/// (`theos_pos/lib/shared/widgets/theos_logo.dart`'s `TheosLogo`, built with
/// `animate: true`) — orden del dueño, 12-sep-2026: «en theos_pos... el logo
/// estaba animado en el splash». A slow, continuous rotation of the approved
/// mark while the app boots.
///
/// Spins [OrbiSymbol] only, never the "ORBI ERP" lettering — orden del
/// dueño, 13-sep-2026: en theos_pos sólo el símbolo gira, nunca el texto
/// (`TheosLogo` vs. the separate, static `TheosNameSvg`). `OrbiBrand`'s
/// single combined SVG made that impossible before [OrbiSymbol] was split
/// out of it; wrapping the whole mark (as this used to do) rotated the
/// wordmark too.
///
/// Built from the same core Flutter animation primitives theos_pos's
/// `TheosLogo` uses (`AnimationController` + `Transform.rotate`): those are
/// framework mechanics, not a fluent_ui surface/color/shape decision, so
/// they sit outside "el estilo lo determina fluent_ui" — nothing here
/// invents a color, a shape or a shadow, it only spins the already-approved
/// [OrbiSymbol] asset (which still carries the caller's own tint). Unlike
/// theos_pos's version, this one respects the platform's reduce-motion
/// setting: theos_pos's `TheosLogo` has no such check.
class _AnimatedSplashSymbol extends StatefulWidget {
  const _AnimatedSplashSymbol({required this.height, required this.color});

  final double height;
  final Color color;

  @override
  State<_AnimatedSplashSymbol> createState() => _AnimatedSplashSymbolState();
}

class _AnimatedSplashSymbolState extends State<_AnimatedSplashSymbol>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool? _lastDisableAnimations;

  @override
  void initState() {
    super.initState();
    // Mirrors TheosLogo's own 20-second rotation. Starts paused; whether it
    // actually spins is decided in didChangeDependencies below, once
    // MediaQuery is reachable.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Read fresh on every dependency change, not just once at mount, so a
    // reduce-motion setting flipped mid-session is honored too, not only
    // whatever it was when the splash first appeared.
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (disableAnimations == _lastDisableAnimations) return;
    _lastDisableAnimations = disableAnimations;
    if (disableAnimations) {
      _controller
        ..stop()
        ..value = 0;
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.rotate(
        key: const Key('splash-logo-rotation'),
        angle: _controller.value * 2 * math.pi,
        child: child,
      ),
      child: OrbiSymbol(height: widget.height, color: widget.color),
    );
  }
}
