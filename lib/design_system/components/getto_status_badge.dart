import 'package:flutter/material.dart';

import '../tokens/getto_colors.dart';
import '../tokens/getto_radii.dart';
import '../typography/getto_typography.dart';
import 'getto_artwork.dart';

/// Presentation-only states from Figma Getto/Status Badge (87:70).
///
/// These values deliberately do not import or replace domain enums. The
/// owning feature maps committed facts or derived attention into a view state.
enum GettoBadgeState {
  learning,
  earlyEstimate,
  established,
  attention,
  checkNeeded,
  expiring,
  expired,
  acquired,
  readyToRestock,
  upcoming,
  dueToday,
  overdue,
  paid,
  inUse,
  inHome,
}

class _BadgeAppearance {
  const _BadgeAppearance(this.label, this.foreground, this.background);

  final String label;
  final Color foreground;
  final Color background;
}

_BadgeAppearance _appearance(GettoBadgeState state) => switch (state) {
  GettoBadgeState.learning => const _BadgeAppearance(
    'Learning',
    Color(0xFF46514B),
    Color(0xFFECEFEB),
  ),
  GettoBadgeState.earlyEstimate => const _BadgeAppearance(
    'Early estimate',
    GettoColors.attention,
    Color(0xFFFFF8E8),
  ),
  GettoBadgeState.established => const _BadgeAppearance(
    'Established',
    GettoColors.textBrand,
    Color(0xFFF2F8F5),
  ),
  GettoBadgeState.attention => const _BadgeAppearance(
    'Attention',
    GettoColors.attention,
    Color(0xFFFFF8E8),
  ),
  GettoBadgeState.checkNeeded => const _BadgeAppearance(
    'Check needed',
    GettoColors.attention,
    Color(0xFFFFF8E8),
  ),
  GettoBadgeState.expiring => const _BadgeAppearance(
    'Expiring',
    GettoColors.error,
    GettoColors.errorSurface,
  ),
  GettoBadgeState.expired => const _BadgeAppearance(
    'Expired',
    GettoColors.error,
    GettoColors.errorSurface,
  ),
  GettoBadgeState.acquired => const _BadgeAppearance(
    'Acquired',
    Color(0xFF46514B),
    Color(0xFFECEFEB),
  ),
  GettoBadgeState.readyToRestock => const _BadgeAppearance(
    'Ready to restock',
    GettoColors.textBrand,
    Color(0xFFF2F8F5),
  ),
  GettoBadgeState.upcoming => const _BadgeAppearance(
    'Upcoming',
    GettoColors.bills,
    GettoColors.billsSurface,
  ),
  GettoBadgeState.dueToday => const _BadgeAppearance(
    'Due today',
    GettoColors.attention,
    Color(0xFFFFF8E8),
  ),
  GettoBadgeState.overdue => const _BadgeAppearance(
    'Overdue',
    GettoColors.error,
    GettoColors.errorSurface,
  ),
  GettoBadgeState.paid => const _BadgeAppearance(
    'Paid',
    GettoColors.textBrand,
    Color(0xFFF2F8F5),
  ),
  GettoBadgeState.inUse => const _BadgeAppearance(
    'In use',
    GettoColors.textBrand,
    Color(0xFFF2F8F5),
  ),
  GettoBadgeState.inHome => const _BadgeAppearance(
    'In home',
    Color(0xFF46514B),
    Color(0xFFECEFEB),
  ),
};

/// Non-interactive text + icon status indicator.
///
/// Uses the accepted local vector by default. Callers may supply verified
/// context-specific artwork; the icon slot remains 16dp.
class GettoStatusBadge extends StatelessWidget {
  const GettoStatusBadge({required this.state, this.icon, super.key});

  final GettoBadgeState state;
  final Widget? icon;

  GettoArt get _art => switch (state) {
    GettoBadgeState.learning => GettoArt.learning,
    GettoBadgeState.earlyEstimate => GettoArt.earlyEstimate,
    GettoBadgeState.established => GettoArt.established,
    GettoBadgeState.attention ||
    GettoBadgeState.checkNeeded => GettoArt.attention,
    GettoBadgeState.expiring => GettoArt.expiring,
    GettoBadgeState.expired || GettoBadgeState.overdue => GettoArt.expired,
    GettoBadgeState.acquired => GettoArt.acquired,
    GettoBadgeState.readyToRestock => GettoArt.readyToRestock,
    GettoBadgeState.upcoming => GettoArt.upcoming,
    GettoBadgeState.dueToday => GettoArt.dueToday,
    GettoBadgeState.paid => GettoArt.paid,
    GettoBadgeState.inUse => GettoArt.inUse,
    GettoBadgeState.inHome => GettoArt.inHome,
  };

  double get _referenceWidth => switch (state) {
    GettoBadgeState.inUse => 79,
    GettoBadgeState.inHome => 90,
    _ => 120,
  };

  @override
  Widget build(BuildContext context) {
    final appearance = _appearance(state);
    return Semantics(
      label: appearance.label,
      container: true,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: appearance.background,
            borderRadius: BorderRadius.circular(GettoRadii.pill),
          ),
          child: ConstrainedBox(
            // Reference widths are minima: longer labels and enlarged text
            // may expand or wrap, never overlap the icon or pill padding.
            constraints: BoxConstraints(
              minHeight: 32,
              minWidth: _referenceWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: icon ?? GettoArtwork(art: _art),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      appearance.label,
                      softWrap: true,
                      style: GettoTypography.labelSmall.copyWith(
                        color: appearance.foreground,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
