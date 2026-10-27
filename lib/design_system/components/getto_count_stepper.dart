import 'package:flutter/material.dart';

import '../tokens/getto_colors.dart';
import '../tokens/getto_radii.dart';
import '../typography/getto_typography.dart';
import 'getto_artwork.dart';

/// Controlled, presentation-only count editor matching Figma 59:76.
///
/// The parent owns the authoritative value and must commit changes through the
/// existing reconciliation use case; this widget does not write or predict.
class GettoCountStepper extends StatelessWidget {
  const GettoCountStepper({
    required this.value,
    required this.onChanged,
    this.minimum = 0,
    this.maximum,
    this.decreaseIcon = const GettoArtwork(
      art: GettoArt.decrease,
      followIconTheme: true,
    ),
    this.increaseIcon = const GettoArtwork(
      art: GettoArt.increase,
      followIconTheme: true,
    ),
    super.key,
  }) : assert(minimum >= 0),
       assert(value >= minimum),
       assert(maximum == null || maximum >= value);

  final int value;
  final int minimum;
  final int? maximum;
  final ValueChanged<int>? onChanged;
  final Widget decreaseIcon;
  final Widget increaseIcon;

  @override
  Widget build(BuildContext context) {
    final canDecrease = onChanged != null && value > minimum;
    final canIncrease =
        onChanged != null && (maximum == null || value < maximum!);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: GettoColors.surface,
        border: Border.all(color: const Color(0xFFDDE3DF)),
        borderRadius: BorderRadius.circular(GettoRadii.md),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 168),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StepAction(
              label: 'Decrease count',
              onPressed: canDecrease ? () => onChanged!(value - 1) : null,
              icon: decreaseIcon,
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 72),
              child: Semantics(
                label: 'Count: $value',
                liveRegion: true,
                child: ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '$value',
                      textAlign: TextAlign.center,
                      style: GettoTypography.titleMedium,
                    ),
                  ),
                ),
              ),
            ),
            _StepAction(
              label: 'Increase count',
              onPressed: canIncrease ? () => onChanged!(value + 1) : null,
              icon: increaseIcon,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepAction extends StatelessWidget {
  const _StepAction({
    required this.label,
    required this.onPressed,
    required this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget icon;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    tooltip: label,
    icon: icon,
    color: GettoColors.textBrand,
    constraints: const BoxConstraints.tightFor(width: 48, height: 48),
    padding: EdgeInsets.zero,
    visualDensity: VisualDensity.standard,
  );
}
