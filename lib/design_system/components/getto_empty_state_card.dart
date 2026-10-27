import 'package:flutter/material.dart';

import '../tokens/getto_colors.dart';
import '../tokens/getto_radii.dart';
import '../typography/getto_typography.dart';

/// Responsive content/action container based on Figma Empty State (61:99).
///
/// Illustration is supplied by the screen so the correct Figma asset is used
/// for each accepted journey; no arbitrary replacement art is embedded here.
class GettoEmptyStateCard extends StatelessWidget {
  const GettoEmptyStateCard({
    required this.illustration,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
    super.key,
  });

  final Widget illustration;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: GettoColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(GettoRadii.lg),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: SizedBox(width: 40, height: 40, child: illustration),
                ),
                const SizedBox(height: 10),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(title, style: GettoTypography.titleMedium),
                        const SizedBox(height: 10),
                        Text(
                          description,
                          style: GettoTypography.bodySmall.copyWith(
                            color: GettoColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: onAction,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            backgroundColor: onAction == null
                                ? const Color(0xFFECEFEB)
                                : const Color(0xFFF2F8F5),
                            foregroundColor: GettoColors.textBrand,
                            textStyle: GettoTypography.labelLarge,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                GettoRadii.md,
                              ),
                              side: const BorderSide(color: Color(0xFFDDE3DF)),
                            ),
                          ),
                          child: Text(actionLabel, textAlign: TextAlign.center),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
