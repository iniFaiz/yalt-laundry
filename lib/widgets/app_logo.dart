import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Reusable widget for displaying the YALT circular logo (`logo_bulat`).
/// Uses `assets/images/logo_bulat.svg` with high resolution raster fallback.
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
        placeholderBuilder: (BuildContext context) => Image.asset(
          'assets/images/logo_bulat.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
