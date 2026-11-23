import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Widget logo bulat YALT (`assets/images/logo_bulat.svg`).
class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({
    super.key,
    this.size = 110.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(
        'assets/images/logo_bulat.svg',
        width: size,
        height: size,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => SizedBox(width: size, height: size),
      ),
    );
  }
}
