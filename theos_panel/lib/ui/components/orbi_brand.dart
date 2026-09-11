import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Shared Orbi mark used by startup and authentication surfaces.
class OrbiBrand extends StatelessWidget {
  const OrbiBrand({super.key, this.height = 84, this.color});

  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      label: 'Marca Orbi ERP',
      image: true,
      child: SvgPicture.asset(
        'assets/images/orbi_logo.svg',
        height: height,
        colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
        semanticsLabel: 'ORBI ERP',
      ),
    );
  }
}
