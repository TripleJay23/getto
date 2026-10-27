import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getto/design_system/components/getto_home_area_row.dart';
import 'package:getto/design_system/components/getto_item_row.dart';
import 'package:getto/design_system/components/getto_skeleton_row.dart';
import 'package:getto/design_system/components/getto_count_stepper.dart';
import 'package:getto/design_system/components/getto_empty_state_card.dart';

import '../../../tool/m231_component_preview.dart';

void main() {
  for (final width in <int>[320, 430]) {
    for (final textScale in <int>[1, 2]) {
      testWidgets('$width dp at ${textScale * 100}% text has no overflow', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width.toDouble(), 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(const M231ComponentPreviewApp());

        if (width == 430) {
          await tester.tap(find.widgetWithText(ChoiceChip, '430dp'));
          await tester.pumpAndSettle();
        }
        if (textScale == 2) {
          await tester.tap(find.widgetWithText(ChoiceChip, '200%'));
          await tester.pumpAndSettle();
        }

        expect(
          tester.getSize(find.byKey(const Key('m231-preview-canvas'))).width,
          width.toDouble(),
        );
        expect(find.byType(GettoItemRow), findsNWidgets(2));
        expect(find.byType(GettoHomeAreaRow), findsNWidgets(2));
        expect(find.byType(GettoSkeletonRow), findsNWidgets(2));
        final firstItem = tester.element(find.byType(GettoItemRow).first);
        expect(
          MediaQuery.textScalerOf(firstItem).scale(14),
          closeTo(14.0 * textScale, 0.001),
        );
        await tester.ensureVisible(find.byType(GettoSkeletonRow).last);
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('stepper actions update only preview-local count', (
    tester,
  ) async {
    await tester.pumpWidget(const M231ComponentPreviewApp());
    final increase = find.byTooltip('Increase count');
    final decrease = find.byTooltip('Decrease count');
    await tester.ensureVisible(increase);
    await tester.pump();
    await tester.tap(increase);
    await tester.pump();
    expect(find.bySemanticsLabel('Count: 2'), findsWidgets);
    await tester.tap(decrease);
    await tester.pump();
    expect(find.bySemanticsLabel('Count: 1'), findsWidgets);
  });

  testWidgets('both default and custom areas expose interactive management', (
    tester,
  ) async {
    await tester.pumpWidget(const M231ComponentPreviewApp());
    final actions = find.text('Manage');
    expect(actions, findsNWidgets(2));
    await tester.ensureVisible(actions.first);
    await tester.pump();
    await tester.tap(actions.first);
    await tester.pump();
    expect(
      find.text('Preview only: manage default Kitchen area'),
      findsOneWidget,
    );
    await tester.ensureVisible(actions.last);
    await tester.pump();
    await tester.tap(actions.last);
    await tester.pump();
    expect(find.text('Preview only: manage custom area'), findsOneWidget);
  });

  testWidgets('preview toggle exposes all null-callback states', (
    tester,
  ) async {
    await tester.pumpWidget(const M231ComponentPreviewApp());
    await tester.ensureVisible(find.text('Controls enabled'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Controls enabled'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<GettoCountStepper>(find.byType(GettoCountStepper))
          .onChanged,
      isNull,
    );
    for (final area in tester.widgetList<GettoHomeAreaRow>(
      find.byType(GettoHomeAreaRow),
    )) {
      expect(area.onManage, isNull);
    }
    for (final item in tester.widgetList<GettoItemRow>(
      find.byType(GettoItemRow),
    )) {
      expect(item.onTap, isNull);
    }
    expect(
      tester
          .widget<GettoEmptyStateCard>(find.byType(GettoEmptyStateCard))
          .onAction,
      isNull,
    );
  });

  testWidgets('empty-state preview action gives feedback', (tester) async {
    await tester.pumpWidget(const M231ComponentPreviewApp());
    await tester.ensureVisible(find.text('Clear search'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear search'));
    await tester.pump();
    expect(find.text('Preview only: clear search'), findsOneWidget);
  });
}
