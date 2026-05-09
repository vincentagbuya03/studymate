import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 100, this.isSquare = false});

  final double size;
  final bool isSquare;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(
        'assets/iskolar_icon_only.svg',
        width: size,
        height: size,
        fit: BoxFit.contain,
        placeholderBuilder: (context) => Icon(
          Icons.school_rounded,
          color: const Color(0xFF2563EB),
          size: size * 0.8,
        ),
      ),
    );
  }
}
