import 'package:flutter/material.dart';

import '../motion/getto_motion.dart';
import '../responsive/getto_responsive.dart';
import '../tokens/getto_colors.dart';
import 'getto_screen_artwork.dart';

/// Shared destination contract across compact and rail layouts.
enum GettoDestination {
  home('Home', Icons.home_outlined, Icons.home),
  buy('Buy', Icons.shopping_bag_outlined, Icons.shopping_bag),
  bills('Bills', Icons.receipt_long_outlined, Icons.receipt_long);

  const GettoDestination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class GettoBottomNavigation extends StatelessWidget {
  const GettoBottomNavigation({
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      key: const ValueKey('getto-bottom-navigation'),
      height: GettoResponsive.bottomNavigationHeight,
      backgroundColor: GettoColors.surface,
      indicatorColor: const Color(0xFFF2F8F5),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      animationDuration: GettoMotion.effective(context, GettoMotion.standard),
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      destinations: [
        for (final destination in GettoDestination.values)
          NavigationDestination(
            key: ValueKey('getto-nav-${destination.name}'),
            icon: SizedBox(
              width: 24,
              height: 24,
              child: GettoScreenArtwork(
                destination.name,
                color: GettoColors.textPrimary,
              ),
            ),
            selectedIcon: SizedBox(
              width: 24,
              height: 24,
              child: GettoScreenArtwork(
                destination.name,
                color: GettoColors.actionPrimary,
              ),
            ),
            label: destination.label,
            tooltip: destination.label,
          ),
      ],
    );
  }
}

class GettoRailNavigation extends StatelessWidget {
  const GettoRailNavigation({
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    // NavigationRail animates its indicator with internal controllers whose
    // duration is fixed and not configurable. Under reduced motion the rail,
    // its key and its indicator layout stay unchanged (preserving focus, ink
    // clipping and semantics); only the animated indicator is made transparent
    // and a static indicator is painted with each destination icon instead.
    final reduceMotion = GettoMotion.shouldReduce(context);
    return NavigationRail(
      key: const ValueKey('getto-navigation-rail'),
      minWidth: GettoResponsive.railWidth,
      backgroundColor: GettoColors.surface,
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      labelType: NavigationRailLabelType.all,
      useIndicator: true,
      indicatorColor: reduceMotion ? Colors.transparent : null,
      scrollable: true,
      destinations: [
        for (final destination in GettoDestination.values)
          NavigationRailDestination(
            icon: _railIcon(
              destination,
              Icon(destination.icon, size: 24),
              selected: false,
              reduceMotion: reduceMotion,
            ),
            selectedIcon: _railIcon(
              destination,
              Icon(
                destination.selectedIcon,
                size: 24,
                color: GettoColors.actionPrimary,
              ),
              selected: true,
              reduceMotion: reduceMotion,
            ),
            label: Text(destination.label),
            padding: const EdgeInsets.symmetric(vertical: 4),
          ),
      ],
    );
  }

  static Widget _railIcon(
    GettoDestination destination,
    Icon icon, {
    required bool selected,
    required bool reduceMotion,
  }) {
    if (!reduceMotion) return icon;
    return _StaticRailIndicator(
      // Same key and type for both icon states so the slot (and its ink
      // feature) is updated in place rather than recreated on selection.
      key: ValueKey('getto-rail-static-indicator-${destination.name}'),
      selected: selected,
      child: icon,
    );
  }
}

/// Immediate selected-state indicator for the rail when motion is reduced.
///
/// Uses the rail theme's indicator color and shape. It is painted as [Ink] on
/// the destination's Material, exactly like the built-in indicator, so focus,
/// hover and splash highlights continue to draw above it.
class _StaticRailIndicator extends StatelessWidget {
  const _StaticRailIndicator({
    required this.selected,
    required this.child,
    super.key,
  });

  /// Matches the Material 3 NavigationRail indicator rendered in normal motion.
  /// Widget tests assert both motion modes produce identical geometry.
  static const Size size = Size(56, 32);

  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final railTheme = NavigationRailTheme.of(context);
    return Ink(
      width: size.width,
      height: size.height,
      decoration: ShapeDecoration(
        shape: railTheme.indicatorShape ?? const StadiumBorder(),
        color: selected
            ? railTheme.indicatorColor ??
                  Theme.of(context).colorScheme.secondaryContainer
            : Colors.transparent,
      ),
      child: Center(child: child),
    );
  }
}
