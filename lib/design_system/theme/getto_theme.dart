import 'package:flutter/material.dart';

import '../motion/getto_motion.dart';
import '../tokens/getto_colors.dart';
import '../tokens/getto_radii.dart';
import '../typography/getto_typography.dart';
import 'getto_semantics.dart';

/// The accepted R3 light-only presentation theme. Dark mode is not invented.
abstract final class GettoTheme {
  static final ThemeData light = _buildLight();

  static ThemeData _buildLight() {
    const scheme = ColorScheme.light(
      primary: GettoColors.actionPrimary,
      onPrimary: GettoColors.surface,
      surface: GettoColors.surface,
      onSurface: GettoColors.textPrimary,
      error: GettoColors.error,
      onError: GettoColors.surface,
      outline: GettoColors.textSecondary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: GettoTypography.family,
      colorScheme: scheme,
      scaffoldBackgroundColor: GettoColors.canvas,
      canvasColor: GettoColors.canvas,
      cardColor: GettoColors.surface,
      textTheme: GettoTypography.textTheme,
      extensions: const <ThemeExtension<dynamic>>[GettoSemanticColors.light],
      appBarTheme: AppBarThemeData(
        backgroundColor: GettoColors.canvas,
        foregroundColor: GettoColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: GettoTypography.titleMedium,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        backgroundColor: GettoColors.surface,
        elevation: 0,
        indicatorColor: GettoColors.surfaceSubtle,
        indicatorShape: const StadiumBorder(),
        iconTheme: const WidgetStatePropertyAll(
          IconThemeData(size: 24, color: GettoColors.textPrimary),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return GettoTypography.labelMedium.copyWith(
            color: states.contains(WidgetState.selected)
                ? GettoColors.textBrand
                : GettoColors.textSecondary,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: GettoColors.surface,
        indicatorColor: GettoColors.surfaceSubtle,
        indicatorShape: const StadiumBorder(),
        minWidth: 80,
        labelType: NavigationRailLabelType.all,
        selectedIconTheme: const IconThemeData(
          size: 24,
          color: GettoColors.actionPrimary,
        ),
        unselectedIconTheme: const IconThemeData(
          size: 24,
          color: GettoColors.textSecondary,
        ),
        selectedLabelTextStyle: GettoTypography.labelMedium.copyWith(
          color: GettoColors.textBrand,
        ),
        unselectedLabelTextStyle: GettoTypography.labelMedium.copyWith(
          color: GettoColors.textSecondary,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GettoRadii.lg),
          ),
          textStyle: GettoTypography.labelLarge,
        ),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size(48, 48)),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _GettoPageTransitionBuilder(),
          TargetPlatform.iOS: _GettoPageTransitionBuilder(),
        },
      ),
    );
  }
}

/// Future child routes have an immediate alternative when motion is reduced.
/// There are intentionally no child product routes in M1.
class _GettoPageTransitionBuilder extends PageTransitionsBuilder {
  const _GettoPageTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (GettoMotion.shouldReduce(context)) return child;
    return FadeTransition(opacity: animation, child: child);
  }
}
