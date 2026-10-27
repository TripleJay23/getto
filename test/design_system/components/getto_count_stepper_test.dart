import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getto/design_system/components/getto_count_stepper.dart';
import 'package:getto/design_system/theme/getto_theme.dart';

void main() {
  testWidgets('boundaries disable only the unavailable action', (tester) async {
    var value = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: GettoTheme.light,
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, setState) => GettoCountStepper(
                value: value,
                maximum: 1,
                onChanged: (next) => setState(() => value = next),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(IconButton), findsNWidgets(2));

    // At zero, decrease must be disabled.
    expect(
      tester.widget<IconButton>(find.byType(IconButton).first).onPressed,
      isNull,
    );

    await tester.tap(find.byTooltip('Increase count'));
    await tester.pump();
    expect(value, 1);

    // At maximum, increase must be disabled.
    expect(
      tester.widget<IconButton>(find.byType(IconButton).last).onPressed,
      isNull,
    );

    await tester.tap(find.byTooltip('Decrease count'));
    await tester.pump();
    expect(value, 0);
  });

  testWidgets('count actions meet Android target and label guidelines', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: GettoTheme.light,
        home: Scaffold(
          body: Center(child: GettoCountStepper(value: 3, onChanged: (_) {})),
        ),
      ),
    );
    final minus = tester.getSize(find.byTooltip('Decrease count'));
    final plus = tester.getSize(find.byTooltip('Increase count'));
    expect(minus.width, greaterThanOrEqualTo(48));
    expect(minus.height, greaterThanOrEqualTo(48));
    expect(plus.width, greaterThanOrEqualTo(48));
    expect(plus.height, greaterThanOrEqualTo(48));
    expect(find.bySemanticsLabel('Count: 3'), findsWidgets);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('long count at 200 percent keeps readable controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: GettoTheme.light,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: Scaffold(
              body: Center(
                child: GettoCountStepper(value: 123, onChanged: (_) {}),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('123'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
