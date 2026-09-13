import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Approved photographic backdrop shared by login and startup. Keep the logo
/// separate so responsive cropping never distorts or cuts the corporate mark.
const orbiAuthBackgroundAsset = 'assets/images/orbi_lake_sunrise.png';

/// Photo foreground is intentionally independent of the form's theme. The
/// approved photograph stays equally lit across sizes and light/dark themes.
const orbiPhotoInk = Color(0xFF12383C);

class OrbiAuthBackdrop extends StatelessWidget {
  const OrbiAuthBackdrop({super.key});

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Image.asset(orbiAuthBackgroundAsset, fit: BoxFit.cover),
      // One uniform veil: no breakpoint-specific or theme-specific gradients.
      const ColoredBox(color: Color(0x52FFFFFF)),
    ],
  );
}

/// Shared Orbi mark used by startup and authentication surfaces.
class OrbiBrand extends StatelessWidget {
  const OrbiBrand({super.key, this.height = 84, this.color});

  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? FluentTheme.of(context).accentColor;
    return Semantics(
      label: 'Marca Orbi ERP',
      image: true,
      child: SvgPicture.asset(
        'assets/images/orbi_logo.svg',
        height: height,
        colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
        // The wrapper exposes one accessible image, not two nested labels.
        excludeFromSemantics: true,
      ),
    );
  }
}

/// Only the orbit ring + center dot, split out of the same artwork
/// [OrbiBrand] draws whole. `orbi_logo.svg`'s single path combines the ring
/// and the "ORBI ERP" letters, so a caller that animates the whole mark (as
/// the startup screen used to) ends up spinning the wordmark too — orden del
/// dueño, 13-sep-2026: en theos_pos sólo gira el símbolo
/// (`theos_pos/lib/shared/widgets/theos_logo.dart`'s `TheosLogo`), nunca el
/// texto. `orbi_symbol.svg` and [OrbiWordmark]'s `orbi_wordmark.svg` were cut
/// from `orbi_logo.svg`'s original path data by subpath (no new geometry),
/// and verified pixel-identical to the source when rendered together.
class OrbiSymbol extends StatelessWidget {
  const OrbiSymbol({super.key, this.height = 84, this.color});

  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? FluentTheme.of(context).accentColor;
    return Semantics(
      label: 'Símbolo Orbi ERP',
      image: true,
      child: SvgPicture.asset(
        'assets/images/orbi_symbol.svg',
        height: height,
        colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
        excludeFromSemantics: true,
      ),
    );
  }
}

/// The "ORBI ERP" lettering only, split out of the same artwork [OrbiBrand]
/// draws whole. See [OrbiSymbol] for why this split exists.
class OrbiWordmark extends StatelessWidget {
  const OrbiWordmark({super.key, this.height = 40, this.color});

  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? FluentTheme.of(context).accentColor;
    return Semantics(
      label: 'Orbi ERP',
      image: true,
      child: SvgPicture.asset(
        'assets/images/orbi_wordmark.svg',
        height: height,
        colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
        excludeFromSemantics: true,
      ),
    );
  }
}
