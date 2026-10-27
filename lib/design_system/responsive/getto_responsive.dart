import 'package:flutter/material.dart';

import '../tokens/getto_spacing.dart';

enum GettoWindowClass { compact, medium, expanded }

abstract final class GettoResponsive {
  static const double railStart = 600;
  static const double expandedStart = 840;
  static const double bottomNavigationHeight = 80;
  static const double railWidth = 80;
  static const double mediumMaxContent = 560;
  static const double expandedMaxContent = 640;

  static GettoWindowClass classify(double width) {
    if (width < railStart) return GettoWindowClass.compact;
    if (width < expandedStart) return GettoWindowClass.medium;
    return GettoWindowClass.expanded;
  }

  static double horizontalGutter(GettoWindowClass windowClass) =>
      windowClass == GettoWindowClass.compact
      ? GettoSpacing.md
      : GettoSpacing.xl;

  static double maxReadableWidth(GettoWindowClass windowClass) =>
      windowClass == GettoWindowClass.expanded
      ? expandedMaxContent
      : mediumMaxContent;
}

/// Centers a single readable flow column without introducing new panes.
class GettoReadableContent extends StatelessWidget {
  const GettoReadableContent({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final windowClass = GettoResponsive.classify(
          MediaQuery.sizeOf(context).width,
        );
        final gutter = GettoResponsive.horizontalGutter(windowClass);
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: GettoResponsive.maxReadableWidth(windowClass),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: SizedBox(width: double.infinity, child: child),
            ),
          ),
        );
      },
    );
  }
}
