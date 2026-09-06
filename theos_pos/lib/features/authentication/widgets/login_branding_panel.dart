import 'dart:typed_data';

import 'package:fluent_ui/fluent_ui.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/theos_logo.dart';
import '../services/branding_service.dart';

class LoginBrandingPanel extends StatelessWidget {
  const LoginBrandingPanel({
    required this.branding,
    required this.child,
    super.key,
  });

  final AppBranding branding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? branding.darkBackgroundBytes ?? branding.backgroundBytes
        : branding.backgroundBytes;
    final brandColor = branding.theme.brandColor ?? AppColors.loginBackground;
    final safeLightTint = Color.fromARGB(
      0xff,
      (brandColor.r * 255 * .32).round(),
      (brandColor.g * 255 * .32).round(),
      (brandColor.b * 255 * .32).round(),
    );
    final tint = isDark
        ? branding.theme.darkSurfaceColor ?? const Color(0xff1c1c20)
        : safeLightTint;
    final veil = Color.fromARGB(
      isDark ? 0xb8 : 0xa6,
      (tint.r * 255).round(),
      (tint.g * 255).round(),
      (tint.b * 255).round(),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.loginBackground),
        if (background case final bytes?)
          DecoratedBox(
            key: const Key('login-branding-background'),
            decoration: BoxDecoration(
              image: DecorationImage(
                image: MemoryImage(bytes),
                fit: BoxFit.cover,
                onError: (_, _) {},
              ),
            ),
          ),
        ColoredBox(key: const Key('login-branding-veil'), color: veil),
        child,
      ],
    );
  }
}

class LoginBrandLogo extends StatelessWidget {
  const LoginBrandLogo({
    required this.logoBytes,
    required this.height,
    super.key,
  });

  final List<int>? logoBytes;
  final double height;

  @override
  Widget build(BuildContext context) {
    final logo = logoBytes;
    if (logo == null) {
      return TheosLogoName(height: height, color: Colors.white);
    }
    return Image.memory(
      Uint8List.fromList(logo),
      key: const Key('login-company-logo'),
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) =>
          TheosLogoName(height: height, color: Colors.white),
    );
  }
}
