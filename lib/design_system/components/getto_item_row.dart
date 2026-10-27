import 'package:flutter/material.dart';

import '../tokens/getto_colors.dart';
import '../tokens/getto_radii.dart';
import '../tokens/getto_spacing.dart';
import '../typography/getto_typography.dart';
import 'getto_status_badge.dart';

/// Responsive, presentation-only item row based on Getto/Item Row (60:6).
///
/// The caller supplies the committed item's visible wording and a visual
/// badge state; no domain state is inferred or mutated inside the component.
class GettoItemRow extends StatelessWidget {
  const GettoItemRow({
    required this.title,
    required this.subtitle,
    this.status,
    this.factualStatus,
    this.statusIcon,
    this.onTap,
    this.grouped = false,
    super.key,
  }) : assert((status == null) != (factualStatus == null));

  final String title;
  final String subtitle;
  final GettoBadgeState? status;

  /// Explicit factual copy for states outside the lifecycle badge vocabulary.
  final String? factualStatus;
  final Widget? statusIcon;
  final VoidCallback? onTap;
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GettoColors.surface,
      shape: RoundedRectangleBorder(
        side: grouped
            ? BorderSide.none
            : const BorderSide(color: Color(0xFFDDE3DF)),
        borderRadius: BorderRadius.circular(grouped ? 0 : GettoRadii.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = grouped
                ? constraints.maxWidth >= 240 &&
                      MediaQuery.textScalerOf(context).scale(16) < 24
                : constraints.maxWidth >= 360 &&
                      MediaQuery.textScalerOf(context).scale(16) < 28;
            final description = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: GettoTypography.titleSmall),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GettoTypography.bodySmall.copyWith(
                    color: GettoColors.textSecondary,
                  ),
                ),
              ],
            );
            final badge = status == null
                ? Text(factualStatus!, style: GettoTypography.labelSmall)
                : GettoStatusBadge(state: status!, icon: statusIcon);
            return ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 76),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: grouped ? 18 : GettoSpacing.md,
                  vertical: grouped ? 16 : GettoSpacing.sm,
                ),
                child: wide
                    ? Row(
                        crossAxisAlignment: grouped
                            ? CrossAxisAlignment.start
                            : CrossAxisAlignment.center,
                        children: [
                          Expanded(child: description),
                          const SizedBox(width: GettoSpacing.sm),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: grouped
                                  ? constraints.maxWidth * .42
                                  : 200,
                            ),
                            child: badge,
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          description,
                          const SizedBox(height: GettoSpacing.xs),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: badge,
                          ),
                        ],
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}
