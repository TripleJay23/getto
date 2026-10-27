import 'package:flutter/material.dart';

import '../tokens/getto_colors.dart';

/// Presentation-only semantic tone pairs. No feature/domain state lives here.
@immutable
class GettoSemanticColors extends ThemeExtension<GettoSemanticColors> {
  const GettoSemanticColors({
    required this.attention,
    required this.attentionSurface,
    required this.error,
    required this.errorSurface,
    required this.bills,
    required this.billsSurface,
  });

  static const light = GettoSemanticColors(
    attention: GettoColors.attention,
    attentionSurface: GettoColors.attentionSurface,
    error: GettoColors.error,
    errorSurface: GettoColors.errorSurface,
    bills: GettoColors.bills,
    billsSurface: GettoColors.billsSurface,
  );

  final Color attention;
  final Color attentionSurface;
  final Color error;
  final Color errorSurface;
  final Color bills;
  final Color billsSurface;

  @override
  GettoSemanticColors copyWith({
    Color? attention,
    Color? attentionSurface,
    Color? error,
    Color? errorSurface,
    Color? bills,
    Color? billsSurface,
  }) {
    return GettoSemanticColors(
      attention: attention ?? this.attention,
      attentionSurface: attentionSurface ?? this.attentionSurface,
      error: error ?? this.error,
      errorSurface: errorSurface ?? this.errorSurface,
      bills: bills ?? this.bills,
      billsSurface: billsSurface ?? this.billsSurface,
    );
  }

  @override
  GettoSemanticColors lerp(
    ThemeExtension<GettoSemanticColors>? other,
    double t,
  ) {
    if (other is! GettoSemanticColors) return this;
    return GettoSemanticColors(
      attention: Color.lerp(attention, other.attention, t)!,
      attentionSurface: Color.lerp(
        attentionSurface,
        other.attentionSurface,
        t,
      )!,
      error: Color.lerp(error, other.error, t)!,
      errorSurface: Color.lerp(errorSurface, other.errorSurface, t)!,
      bills: Color.lerp(bills, other.bills, t)!,
      billsSurface: Color.lerp(billsSurface, other.billsSurface, t)!,
    );
  }
}
