import 'package:flutter/material.dart';

class JayPharmaLogo extends StatelessWidget {
  final double size;
  final bool isDark;
  final bool showText;
  final bool showSubtitle;

  const JayPharmaLogo({
    super.key,
    this.size = 48,
    this.isDark = false,
    this.showText = true,
    this.showSubtitle = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showText) {
      // Just the official shield emblem icon
      return Image.asset(
        isDark
            ? 'assets/images/jay_pharma_shield_white.png'
            : 'assets/images/jay_pharma_shield.png',
        height: size,
        width: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => Icon(
          Icons.local_hospital_rounded,
          size: size,
          color: const Color(0xFF16A34A),
        ),
      );
    }

    // Full official brand logo
    // When isDark is true (AppBar, Login Portal, dark backgrounds),
    // uses the inverted white typography & shield with medical green accents,
    // blending seamlessly and transparently onto dark navy backgrounds without any white box container!
    final assetPath = isDark
        ? 'assets/images/jay_pharma_logo_white.png'
        : 'assets/images/jay_pharma_logo.png';

    return Image.asset(
      assetPath,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => Image.asset(
        isDark
            ? 'assets/images/jay_pharma_shield_white.png'
            : 'assets/images/jay_pharma_shield.png',
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}

