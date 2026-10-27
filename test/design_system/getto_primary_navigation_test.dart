import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getto/app/app.dart';
import 'package:getto/app/routing/app_router.dart';
import 'package:getto/app/composition/household_providers.dart';
import 'package:getto/design_system/components/getto_primary_navigation.dart';
import 'package:getto/design_system/theme/getto_theme.dart';
import 'package:getto/design_system/tokens/getto_colors.dart';

const _names = <String>['home', 'buy', 'bills'];
const _labels = <String>['Home', 'Buy', 'Bills'];

/// Standalone rail harness. `MediaQuery.disableAnimations` triggers the Getto
/// reduced-motion policy while Flutter's own controllers keep their full
/// duration, which is the worst case for detecting residual animation.
Future<void> _pumpRail(
  WidgetTester tester, {
  required bool reduceMotion,
}) async {
  tester.view.physicalSize = const Size(1024, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  var selected = 0;
  await tester.pumpWidget(
    MaterialApp(
      theme: GettoTheme.light,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reduceMotion),
          child: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: Row(
                children: [
                  GettoRailNavigation(
                    selectedIndex: selected,
                    onSelected: (index) => setState(() => selected = index),
                  ),
                  const Expanded(child: SizedBox.expand()),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpApp(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  final router = createAppRouter(initialLocation: '/home');
  addTearDown(() {
    router.dispose();
    tester.view.reset();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        allAreasStreamProvider.overrideWith((ref) => Stream.value([])),
        allItemsStreamProvider.overrideWith((ref) => Stream.value([])),
      ],
      child: GettoApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _rail() => find.byKey(const ValueKey('getto-navigation-rail'));

Finder _builtInIndicators() => find.descendant(
  of: find.byType(NavigationRail),
  matching: find.byType(NavigationIndicator),
);

Finder _staticIndicator(String name) =>
    find.byKey(ValueKey('getto-rail-static-indicator-$name'));

Color? _staticColor(WidgetTester tester, String name) {
  final ink = find.descendant(
    of: _staticIndicator(name),
    matching: find.byType(Ink),
  );
  final decoration = tester.widget<Ink>(ink).decoration;
  return (decoration! as ShapeDecoration).color;
}

/// Visible coverage of each Material indicator: its selection progress when
/// it paints a non-transparent color, otherwise zero.
List<double> _visibleBuiltInProgress(WidgetTester tester) => tester
    .widgetList<NavigationIndicator>(_builtInIndicators())
    .map((i) => (i.color?.a ?? 1) == 0 ? 0.0 : i.animation.value)
    .toList();

void _expectStaticSelection(WidgetTester tester, int selected, String when) {
  for (var i = 0; i < _names.length; i++) {
    expect(
      _staticColor(tester, _names[i]),
      i == selected ? GettoColors.surfaceSubtle : Colors.transparent,
      reason: '${_names[i]} static indicator $when',
    );
  }
  expect(
    _visibleBuiltInProgress(tester),
    everyElement(0.0),
    reason: 'built-in indicator must not be visible $when',
  );
  expect(
    tester.widget<NavigationRail>(_rail()).selectedIndex,
    selected,
    reason: when,
  );
}

FocusNode _destinationFocus(WidgetTester tester, String label) => Focus.of(
  tester.element(
    find.descendant(
      of: find.byType(NavigationRail),
      matching: find.text(label),
    ),
  ),
);

void main() {
  group('rail reduced motion', () {
    testWidgets('selection is replaced immediately with no visible animation', (
      tester,
    ) async {
      await _pumpRail(tester, reduceMotion: true);
      _expectStaticSelection(tester, 0, 'initially');

      await tester.tap(find.text('Buy'));
      await tester.pump();
      _expectStaticSelection(tester, 1, 'on the first frame');
      for (final step in const <int>[1, 15, 50, 100, 200]) {
        await tester.pump(Duration(milliseconds: step));
        _expectStaticSelection(tester, 1, 'after +${step}ms');
      }
      await tester.pumpAndSettle();
      _expectStaticSelection(tester, 1, 'when settled');
      expect(find.byIcon(Icons.shopping_bag), findsOneWidget);
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    });

    testWidgets('platform reduce-motion path in the real shell is static', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(
            disableAnimations: true,
            reduceMotion: true,
          );
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _pumpApp(tester, const Size(1024, 800));

      await tester.tap(find.text('Bills'));
      await tester.pump();
      _expectStaticSelection(tester, 2, 'on the first frame');
      await tester.pump(const Duration(milliseconds: 1));
      _expectStaticSelection(tester, 2, 'after +1ms');
      await tester.pumpAndSettle();
      _expectStaticSelection(tester, 2, 'when settled');
      expect(find.byKey(const ValueKey('getto-bills-page')), findsOneWidget);
    });
  });

  testWidgets('normal motion keeps the Material indicator animation', (
    tester,
  ) async {
    await _pumpRail(tester, reduceMotion: false);
    expect(_staticIndicator('home'), findsNothing);
    expect(_visibleBuiltInProgress(tester), <double>[1, 0, 0]);
    expect(
      tester.widgetList<NavigationIndicator>(_builtInIndicators()).first.color,
      GettoColors.surfaceSubtle,
    );

    await tester.tap(find.text('Buy'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final mid = _visibleBuiltInProgress(tester);
    expect(mid[0], inExclusiveRange(0, 1), reason: 'Home animates out');
    expect(mid[1], inExclusiveRange(0, 1), reason: 'Buy animates in');

    await tester.pumpAndSettle();
    expect(_visibleBuiltInProgress(tester), <double>[0, 1, 0]);
  });

  testWidgets('reduced and normal rail render identical geometry', (
    tester,
  ) async {
    Future<Map<String, Rect>> measure({required bool reduceMotion}) async {
      await _pumpRail(tester, reduceMotion: reduceMotion);
      final rects = <String, Rect>{
        'rail': tester.getRect(_rail()),
        'indicator': reduceMotion
            ? tester.getRect(_staticIndicator('home'))
            : tester.getRect(_builtInIndicators().first),
      };
      for (final label in _labels) {
        rects['label-$label'] = tester.getRect(find.text(label));
        final icon = find.descendant(
          of: find.byType(NavigationRail),
          matching: find.byType(Icon),
        );
        rects['icons'] = tester.getRect(icon.first);
        rects['target-$label'] = tester.getRect(
          find.ancestor(
            of: find.text(label),
            matching: find.byWidgetPredicate((w) => w is InkResponse),
          ),
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
      return rects;
    }

    final normal = await measure(reduceMotion: false);
    final reduced = await measure(reduceMotion: true);

    expect(reduced, normal);
    expect(normal['rail']!.width, 80);
    expect(normal['indicator']!.size, const Size(56, 32));
    expect(normal['icons']!.size, const Size(24, 24));
    for (final label in _labels) {
      expect(normal['target-$label']!.width, greaterThanOrEqualTo(48));
      expect(normal['target-$label']!.height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('reduced motion keeps rail identity and keyboard focus', (
    tester,
  ) async {
    await _pumpRail(tester, reduceMotion: true);

    final railState = tester.state(find.byType(NavigationRail));
    final railElement = tester.element(_rail());

    for (final (label, index) in <(String, int)>[
      ('Buy', 1),
      ('Bills', 2),
      ('Home', 0),
    ]) {
      final node = _destinationFocus(tester, label);
      node.requestFocus();
      await tester.pump();
      expect(
        node.hasPrimaryFocus,
        isTrue,
        reason: '$label has focus before activation',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      _expectStaticSelection(tester, index, 'after activating $label');
      await tester.pumpAndSettle();

      final current = _destinationFocus(tester, label);
      expect(
        node.hasPrimaryFocus,
        isTrue,
        reason: '$label keeps focus after activation',
      );
      expect(identical(current, node), isTrue);
      expect(
        identical(tester.state(find.byType(NavigationRail)), railState),
        isTrue,
      );
      expect(identical(tester.element(_rail()), railElement), isTrue);
    }
  });

  testWidgets('semantics expose names and one selected state in both modes', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    Future<List<(String, bool)>> snapshot({required bool reduceMotion}) async {
      await _pumpRail(tester, reduceMotion: reduceMotion);
      await tester.tap(find.text('Bills'));
      await tester.pumpAndSettle();
      final result = <(String, bool)>[];
      for (var i = 0; i < _labels.length; i++) {
        final label = _labels[i];
        expect(
          find.bySemanticsLabel(RegExp('^$label\\b')),
          findsOneWidget,
          reason: 'exactly one $label node',
        );
        final node = tester.getSemantics(find.text(label));
        expect(
          node,
          isSemantics(
            isSelected: i == 2,
            hasTapAction: true,
            isFocusable: true,
          ),
        );
        expect(node.label, startsWith(label));
        result.add((
          node.label,
          node.flagsCollection.isSelected.toBoolOrNull() ?? false,
        ));
      }
      await tester.pumpWidget(const SizedBox.shrink());
      return result;
    }

    final normal = await snapshot(reduceMotion: false);
    final reduced = await snapshot(reduceMotion: true);
    expect(reduced, normal);
    expect(reduced.where((entry) => entry.$2), hasLength(1));
    handle.dispose();
  });

  testWidgets('compact selected indicator measures 64x32dp', (tester) async {
    await _pumpApp(tester, const Size(360, 780));
    final indicators = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.byType(NavigationIndicator),
    );
    expect(indicators, findsNWidgets(3));
    expect(tester.getSize(indicators.first), const Size(64, 32));
    expect(
      tester.widget<NavigationIndicator>(indicators.first).animation.value,
      1,
    );
    expect(tester.getSize(find.byType(NavigationBar)).height, 80);
  });
}
