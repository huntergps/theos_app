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
