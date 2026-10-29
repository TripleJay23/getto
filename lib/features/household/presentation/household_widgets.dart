import 'package:flutter/material.dart';

import '../../../design_system/tokens/getto_colors.dart';
import '../../../design_system/tokens/getto_radii.dart';
import '../../../design_system/typography/getto_typography.dart';

/// Growing R3 actions: 50dp minimum, no fixed-height text clipping.
class HouseholdAction extends StatelessWidget {
  const HouseholdAction(
    this.label, {
    required this.onPressed,
    this.secondary = false,
    this.destructive = false,
    this.minimumHeight,
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool secondary;
  final bool destructive;
  final double? minimumHeight;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      minimumSize: Size(
        double.infinity,
        minimumHeight ?? (secondary ? 52 : 58),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GettoRadii.md),
      ),
      textStyle: GettoTypography.labelLarge,
      backgroundColor: secondary
          ? const Color(0xFFF2F8F5)
          : destructive
          ? GettoColors.error
          : GettoColors.actionPrimary,
      foregroundColor: secondary ? GettoColors.textBrand : GettoColors.surface,
      disabledBackgroundColor: const Color(0xFFE5E8E6),
      disabledForegroundColor: const Color(0xFF6B756F),
      side: secondary
          ? const BorderSide(color: Color(0xFFDDE3DF))
          : BorderSide.none,
    );
    return secondary
        ? OutlinedButton(
            onPressed: onPressed,
            style: style,
            child: Text(label, textAlign: TextAlign.center),
          )
        : FilledButton(
            onPressed: onPressed,
            style: style,
            child: Text(label, textAlign: TextAlign.center),
          );
  }
}

class HouseholdMessage extends StatelessWidget {
  const HouseholdMessage(this.message, {this.error = false, super.key});
  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: error ? GettoColors.errorSurface : GettoColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(GettoRadii.lg),
      ),
      child: Text(
        message,
        style: GettoTypography.bodySmall.copyWith(
          color: error ? GettoColors.error : GettoColors.textBrand,
        ),
      ),
    ),
  );
}
