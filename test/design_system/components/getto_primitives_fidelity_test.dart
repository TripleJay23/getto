import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:getto/design_system/components/getto_artwork.dart';
import 'package:getto/design_system/components/getto_count_stepper.dart';
import 'package:getto/design_system/components/getto_empty_state_card.dart';
import 'package:getto/design_system/components/getto_home_area_row.dart';
import 'package:getto/design_system/components/getto_item_row.dart';
import 'package:getto/design_system/components/getto_skeleton_row.dart';
import 'package:getto/design_system/components/getto_status_badge.dart';
import 'package:getto/design_system/theme/getto_theme.dart';

Widget _empty(VoidCallback? action) => GettoEmptyStateCard(
  illustration: const GettoArtwork(art: GettoArt.search),
  title: 'No matches',
  description: 'Try another name or clear the search.',
  actionLabel: 'Clear search',
  onAction: action,
);

Widget _area(VoidCallback? action, {bool isDefault = true}) => GettoHomeAreaRow(
  name: isDefault ? 'Kitchen' : 'Personal study and storage space',
  activeItems: 6,
  isDefault: isDefault,
  onManage: action,
);

Widget _frame(Widget child, {double scale = 1, bool reduced = false}) =>
    MaterialApp(
      theme: GettoTheme.light,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reduced,
            accessibleNavigation: reduced,
          ),
          child: Scaffold(body: child),
        ),
      ),
    );

Future<Uint8List> _pixels(WidgetTester tester, GlobalKey key) async =>
    (await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        return Uint8List.fromList(data!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    }))!;

void main() {
  setUpAll(() async {
    // Reference metrics need the bundled font, rather than the test Ahem font.
    final loader = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope[wght].ttf'));
    await loader.load();
  });

  testWidgets('every original SVG loads at its source dimensions', (
    tester,
  ) async {
    for (final art in GettoArt.values) {
      final svg = await rootBundle.loadString(art.assetPath);
      expect(svg, contains('width="${art.dimension.toInt()}"'));
      expect(svg, contains('height="${art.dimension.toInt()}"'));
      await tester.pumpWidget(_frame(Center(child: GettoArtwork(art: art))));
      await tester.pumpAndSettle();
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(
        tester.getSize(find.byType(GettoArtwork)),
        Size.square(art.dimension),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('normal reference geometry and canonical artwork', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _frame(
        Column(
          children: [
            const GettoStatusBadge(state: GettoBadgeState.learning),
            const GettoStatusBadge(state: GettoBadgeState.inUse),
            const GettoStatusBadge(state: GettoBadgeState.inHome),
            GettoCountStepper(value: 1, onChanged: (_) {}),
            _area(() {}),
            _empty(() {}),
            const GettoSkeletonRow(kind: GettoSkeletonKind.item),
            const GettoSkeletonRow(kind: GettoSkeletonKind.bill),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final badges = find.byType(GettoStatusBadge);
    expect(tester.getSize(badges.at(0)), const Size(120, 32));
    expect(tester.getSize(badges.at(1)), const Size(79, 32));
    expect(tester.getSize(badges.at(2)), const Size(90, 32));
    expect(tester.getSize(find.byType(GettoCountStepper)), const Size(168, 48));
    expect(tester.getSize(find.byType(GettoHomeAreaRow)), const Size(390, 70));
    final manage = find.ancestor(
      of: find.text('Manage'),
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(manage), const Size(72, 48));
    final emptyBox = find
        .descendant(
          of: find.byType(GettoEmptyStateCard),
          matching: find.byType(DecoratedBox),
        )
        .first;
    expect(tester.getSize(emptyBox), const Size(360, 202));
    expect(tester.getSize(find.byType(TextButton)), const Size(300, 48));
    expect(tester.getSize(find.text('No matches')).width, 300);
    expect(
      tester.getSize(find.byType(GettoSkeletonRow).first),
      const Size(390, 76),
    );
    expect(
      tester.getSize(find.byType(GettoSkeletonRow).last),
      const Size(390, 96),
    );
    final reservations = find.descendant(
      of: find.byType(GettoSkeletonRow),
      matching: find.byWidgetPredicate(
        (w) =>
            w is SizedBox &&
            ((w.width == 84 && w.height == 48) ||
                (w.width == 92 && w.height == 52)),
      ),
    );
    expect(reservations, findsNWidgets(2));
    expect(find.byType(Icon), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final enabled in [true, false]) {
        testWidgets(
          'real $width dp viewport, ${scale * 100}% text, enabled=$enabled',
          (tester) async {
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final VoidCallback? action = enabled ? () {} : null;
            await tester.pumpWidget(
              _frame(
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final state in GettoBadgeState.values)
                            GettoStatusBadge(state: state),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GettoCountStepper(
                          value: 1,
                          maximum: 3,
                          onChanged: enabled ? (_) {} : null,
                        ),
                      ),
                      GettoItemRow(
                        title: 'Extra long household item name',
                        subtitle: 'Bathroom · Optional package context',
                        status: GettoBadgeState.readyToRestock,
                        onTap: action,
                      ),
                      _area(action),
                      _area(action, isDefault: false),
                      _empty(action),
                      const GettoSkeletonRow(kind: GettoSkeletonKind.item),
                      const GettoSkeletonRow(kind: GettoSkeletonKind.bill),
                    ],
                  ),
                ),
                scale: scale,
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.getSize(find.byType(SingleChildScrollView)).width,
              width,
            );
            expect(tester.getSize(find.byType(GettoItemRow)).width, width);
            expect(tester.takeException(), isNull);
            await tester.ensureVisible(find.byType(TextButton));
            await tester.pumpAndSettle();
            expect(
              tester.getSize(find.byType(TextButton)).height,
              greaterThanOrEqualTo(48),
            );
            await tester.ensureVisible(find.byType(GettoSkeletonRow).last);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('all enabled controls meet Android touch and label guidelines', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _frame(
        Column(
          children: [
            GettoCountStepper(value: 1, onChanged: (_) {}),
            _area(() {}),
            _empty(() {}),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets(
    'null callbacks disable actions and retain informative semantics',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _frame(
          Column(
            children: [
              const GettoCountStepper(value: 1, onChanged: null),
              _area(null),
              _area(null, isDefault: false),
              _empty(null),
              const GettoItemRow(
                title: 'Toothpaste',
                subtitle: 'Bathroom · In use',
                status: GettoBadgeState.inUse,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in [
        'Decrease count',
        'Increase count',
        'Manage Kitchen',
        'Manage Personal study and storage space',
        'Clear search',
      ]) {
        final action = label.endsWith('count')
            ? find.byTooltip(label)
            : find.bySemanticsLabel(label);
        expect(action, findsWidgets, reason: label);
        final data = tester.getSemantics(action.first).getSemanticsData();
        expect(data.label.isEmpty ? data.tooltip : data.label, label);
        expect(
          data.flagsCollection.isEnabled,
          ui.Tristate.isFalse,
          reason: label,
        );
        expect(data.hasAction(ui.SemanticsAction.tap), isFalse, reason: label);
      }
      expect(find.bySemanticsLabel('Count: 1'), findsWidgets);
      for (final ink in tester.widgetList<InkWell>(find.byType(InkWell))) {
        expect(ink.onTap, isNull);
      }
      semantics.dispose();
    },
  );

  for (final reduced in [false, true]) {
    testWidgets(
      'pressed feedback and activation remain useful, reduced=$reduced',
      (tester) async {
        var taps = 0;
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          _frame(
            Center(
              child: RepaintBoundary(
                key: boundaryKey,
                child: SizedBox(width: 390, child: _area(() => taps++)),
              ),
            ),
            reduced: reduced,
          ),
        );
        await tester.pumpAndSettle();
        final idle = await _pixels(tester, boundaryKey);
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Manage')),
        );
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 100));
        final pressed = await _pixels(tester, boundaryKey);
        expect(
          listEquals(idle, pressed),
          isFalse,
          reason: 'Pressed feedback must remain visible',
        );
        await gesture.up();
        await tester.pumpAndSettle();
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('stepper keyboard focus survives update, reduced=$reduced', (
      tester,
    ) async {
      var value = 1;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _frame(
          Center(
            child: StatefulBuilder(
              builder: (context, setState) => GettoCountStepper(
                value: value,
                maximum: 3,
                onChanged: (next) => setState(() => value = next),
              ),
            ),
          ),
          reduced: reduced,
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      final focus = FocusManager.instance.primaryFocus;
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(value, 2);
      expect(FocusManager.instance.primaryFocus, same(focus));
      expect(find.bySemanticsLabel('Count: 2'), findsWidgets);
      semantics.dispose();
    });
  }
}
