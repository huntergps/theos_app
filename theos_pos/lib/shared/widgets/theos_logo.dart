import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Logo SVG de Theos POS desde assets/images/logo.svg.
///
/// Soporta [animate] para rotación sutil (efecto branding).
class TheosLogo extends StatefulWidget {
  const TheosLogo({
    super.key,
    this.size = 80,
    this.animate = false,
    this.color,
  });

  final double size;
  final bool animate;
  final Color? color;

  @override
  State<TheosLogo> createState() => _TheosLogoState();
}

class _TheosLogoState extends State<TheosLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
    if (widget.animate) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = FluentTheme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final color = widget.color ??
        (isDark ? const Color(0xFFE0E0E0) : const Color(0xFF2D2D2D));

    final svg = SvgPicture.asset(
      'assets/images/logo.svg',
      width: widget.size,
      height: widget.size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );

    if (!widget.animate) return svg;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.rotate(
        angle: _controller.value * 2 * 3.14159265,
        child: child,
      ),
      child: svg,
    );
  }
}

/// Logo con nombre: logo_nombre.svg o logo_nombre.png.
/// Usa el SVG cuando quieres mono-color con tinteo, o el PNG para full-color.
class TheosLogoName extends StatelessWidget {
  const TheosLogoName({
    super.key,
    this.height = 48,
    this.color,
    this.usePng = false,
  });

  final double height;
  final Color? color;
  final bool usePng;

  @override
  Widget build(BuildContext context) {
    if (usePng) {
      return Image.asset(
        'assets/images/logo_nombre.png',
        height: height,
        fit: BoxFit.contain,
      );
    }

    final brightness = FluentTheme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final resolvedColor = color ??
        (isDark ? const Color(0xFFE0E0E0) : const Color(0xFF2D2D2D));

    return SvgPicture.asset(
      'assets/images/logo_nombre.svg',
      height: height,
      colorFilter: ColorFilter.mode(resolvedColor, BlendMode.srcIn),
    );
  }
}

/// Logo PNG full-color (sin tinteo). Ideal para splash screens.
class TheosLogoImage extends StatelessWidget {
  const TheosLogoImage({super.key, this.height = 200});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      height: height,
      fit: BoxFit.contain,
    );
  }
}
