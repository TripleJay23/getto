import 'package:flutter/material.dart';

import '../tokens/getto_colors.dart';

/// R3 typography roles. Height is a line-height/font-size multiplier.
abstract final class GettoTypography {
  static const family = 'Manrope';

  static TextStyle _style(double size, double lineHeight, FontWeight weight) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      color: GettoColors.textPrimary,
    );
  }

  static final displayLarge = _style(32, 40, FontWeight.w800);
  static final titleLarge = _style(24, 32, FontWeight.w700);
  static final titleMedium = _style(20, 28, FontWeight.w600);
  static final titleSmall = _style(18, 26, FontWeight.w600);
  static final bodyLarge = _style(17, 26, FontWeight.w400);
  static final bodyMedium = _style(16, 24, FontWeight.w400);
  static final bodySmall = _style(14, 20, FontWeight.w400);
  static final labelLarge = _style(15, 20, FontWeight.w600);
  static final labelMedium = _style(13, 18, FontWeight.w600);
  static final labelSmall = _style(12, 16, FontWeight.w500);

  static TextTheme get textTheme => TextTheme(
    displayLarge: displayLarge,
    headlineMedium: titleLarge,
    titleLarge: titleLarge,
    titleMedium: titleMedium,
    titleSmall: titleSmall,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    bodySmall: bodySmall,
    labelLarge: labelLarge,
    labelMedium: labelMedium,
    labelSmall: labelSmall,
  );
}
