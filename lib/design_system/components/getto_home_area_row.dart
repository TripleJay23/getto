import 'package:flutter/material.dart';

import '../tokens/getto_colors.dart';
import '../tokens/getto_radii.dart';
import '../typography/getto_typography.dart';
import 'getto_artwork.dart';

/// Figma Getto/Home Area Row (119:154), corrected W37 contract (928:2119).
///
/// Seeded/default origin is only a label. Both kinds of areas expose the
/// same management action under accepted decision M2-D10.
class GettoHomeAreaRow extends StatelessWidget {
  const GettoHomeAreaRow({
    required this.name,
    required this.activeItems,
    required this.isDefault,
    required this.onManage,
    this.manageIcon = const GettoArtwork(
      art: GettoArt.chevron,
      followIconTheme: true,
    ),
    super.key,
  }) : assert(activeItems >= 0);

  final String name;
  final int activeItems;
  final bool isDefault;
  final VoidCallback? onManage;
  final Widget manageIcon;

  @override
  Widget build(BuildContext context) {
    final kind = isDefault ? 'default' : 'custom';
    final quantity = activeItems == 1 ? 'item' : 'items';
    final summary = '$activeItems active $quantity · $kind';
    final details = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: GettoTypography.titleSmall),
        const SizedBox(height: 2),
        Text(
          summary,
          style: GettoTypography.bodySmall.copyWith(
            color: GettoColors.textSecondary,
          ),
        ),
      ],
    );
    final normalLabel = MediaQuery.textScalerOf(context).scale(12) <= 12;
    final actionColor = onManage == null
        ? GettoColors.textSecondary.withValues(alpha: 0.38)
        : GettoColors.textBrand;
    final actionLabel = Text(
      'Manage',
      style: GettoTypography.labelSmall.copyWith(
        color: actionColor,
        letterSpacing: 0.2,
      ),
    );
    final action = Semantics(
      button: true,
      enabled: onManage != null,
      label: 'Manage $name',
      onTap: onManage,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onManage,
          borderRadius: BorderRadius.circular(GettoRadii.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: IconTheme(
                data: IconThemeData(color: actionColor),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (normalLabel)
                      SizedBox(width: 50, child: actionLabel)
                    else
                      actionLabel,
                    SizedBox(width: 18, height: 18, child: manageIcon),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Material(
      color: GettoColors.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFDDE3DF)),
        borderRadius: BorderRadius.circular(GettoRadii.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth < 360 ||
              MediaQuery.textScalerOf(context).scale(12) > 20;
          return ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 70),
            child: Padding(
              // Includes the 1dp border inset of the 70dp Figma master.
              padding: const EdgeInsets.fromLTRB(15, 11, 11, 11),
              child: stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [details, const SizedBox(height: 8), action],
                    )
                  : Row(
                      children: [
                        Expanded(child: details),
                        action,
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}
