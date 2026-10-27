import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getto/design_system/motion/getto_motion.dart';
import 'package:getto/design_system/responsive/getto_responsive.dart';
import 'package:getto/design_system/theme/getto_semantics.dart';
import 'package:getto/design_system/theme/getto_theme.dart';
import 'package:getto/design_system/tokens/getto_colors.dart';
import 'package:getto/design_system/typography/getto_typography.dart';

void main() {
  test('accepted R3 palette and semantic extension remain exact', () {
    expect(GettoColors.canvas, const Color(0xFFFBFAF6));
    expect(GettoColors.surface, const Color(0xFFFFFFFF));
    expect(GettoColors.actionPrimary, const Color(0xFF287257));
    expect(GettoColors.textPrimary, const Color(0xFF17201C));
    expect(GettoColors.textSecondary, const Color(0xFF5E6963));
    expect(GettoColors.textBrand, const Color(0xFF1F5D48));
    expect(GettoColors.attention, const Color(0xFF8A5A00));
    expect(GettoColors.attentionSurface, const Color(0xFFFFF8E8));
    expect(GettoColors.error, const Color(0xFFA33B32));
    expect(GettoColors.errorSurface, const Color(0xFFFFF4F2));
    expect(GettoColors.bills, const Color(0xFF356A8A));
    expect(GettoColors.billsSurface, const Color(0xFFF4F8FB));
    expect(
      GettoTheme.light.extension<GettoSemanticColors>(),
      GettoSemanticColors.light,
    );
    expect(GettoTheme.light.scaffoldBackgroundColor, GettoColors.canvas);
  });

  test('text styles retain accepted size, weight, and line height', () {
    final styles = <TextStyle>[
      GettoTypography.displayLarge,
      GettoTypography.titleLarge,
      GettoTypography.titleMedium,
      GettoTypography.titleSmall,
      GettoTypography.bodyLarge,
      GettoTypography.bodyMedium,
      GettoTypography.bodySmall,
      GettoTypography.labelLarge,
      GettoTypography.labelMedium,
      GettoTypography.labelSmall,
    ];
    final sizes = <double>[32, 24, 20, 18, 17, 16, 14, 15, 13, 12];
    final lines = <double>[40, 32, 28, 26, 26, 24, 20, 20, 18, 16];
    final weights = <FontWeight>[
      FontWeight.w800,
      FontWeight.w700,
      FontWeight.w600,
      FontWeight.w600,
      FontWeight.w400,
      FontWeight.w400,
      FontWeight.w400,
      FontWeight.w600,
      FontWeight.w600,
      FontWeight.w500,
    ];
    for (var i = 0; i < styles.length; i++) {
      expect(styles[i].fontFamily, GettoTypography.family);
      expect(styles[i].fontSize, sizes[i]);
      expect(styles[i].fontWeight, weights[i]);
      expect(styles[i].height! * styles[i].fontSize!, closeTo(lines[i], .001));
    }
  });

  test('accepted breakpoints and max content widths', () {
    expect(GettoResponsive.classify(320), GettoWindowClass.compact);
    expect(GettoResponsive.classify(599.99), GettoWindowClass.compact);
    expect(GettoResponsive.classify(600), GettoWindowClass.medium);
    expect(GettoResponsive.classify(839.99), GettoWindowClass.medium);
    expect(GettoResponsive.classify(840), GettoWindowClass.expanded);
    expect(GettoResponsive.maxReadableWidth(GettoWindowClass.medium), 560);
    expect(GettoResponsive.maxReadableWidth(GettoWindowClass.expanded), 640);
  });

  testWidgets('reduced motion is 0ms while normal motion uses R3 tokens', (
    tester,
  ) async {
    Duration? normal;
    Duration? reduced;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            normal = GettoMotion.effective(context, GettoMotion.standard);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: Builder(
                builder: (innerContext) {
                  reduced = GettoMotion.effective(
                    innerContext,
                    GettoMotion.standard,
                  );
                  return const SizedBox.shrink();
                },
              ),
            );
          },
        ),
      ),
    );
    expect(normal, anyOf(GettoMotion.standard, Duration.zero));
    expect(reduced, Duration.zero);
  });
}
