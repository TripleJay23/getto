import 'package:flutter/widgets.dart';

/// Durations accepted at R3. Interaction completion never waits for animation.
abstract final class GettoMotion {
  static const instant = Duration(milliseconds: 80);
  static const fast = Duration(milliseconds: 140);
  static const standard = Duration(milliseconds: 220);
  static const emphasis = Duration(milliseconds: 320);
  static const reduced = Duration.zero;

  /// R3's exact Figma cubic-bezier coordinates remain to be verified.
  /// This policy only centralizes timing and platform accessibility behavior.
  static bool shouldReduce(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context) ||
      WidgetsBinding
          .instance
          .platformDispatcher
          .accessibilityFeatures
          .reduceMotion;

  static Duration effective(BuildContext context, Duration normal) =>
      shouldReduce(context) ? reduced : normal;
}
