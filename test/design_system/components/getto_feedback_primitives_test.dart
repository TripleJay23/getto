import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getto/design_system/components/getto_empty_state_card.dart';
import 'package:getto/design_system/components/getto_skeleton_row.dart';
import 'package:getto/design_system/theme/getto_theme.dart';

void main() {
  testWidgets('empty state offers a real, labeled next step', (tester) async {
    var cleared = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: GettoTheme.light,
        home: Scaffold(
          body: GettoEmptyStateCard(
            illustration: const Icon(Icons.search),
            title: 'No matches',
            description: 'Try another name or clear the search.',
            actionLabel: 'Clear search',
            onAction: () => cleared = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Clear search'));
    expect(cleared, isTrue);
    expect(find.text('No matches'), findsOneWidget);
  });

  testWidgets('item and bill skeletons are noninteractive', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GettoTheme.light,
        home: const Scaffold(
          body: Column(
            children: [
              GettoSkeletonRow(kind: GettoSkeletonKind.item),
              GettoSkeletonRow(kind: GettoSkeletonKind.bill),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(GettoSkeletonRow), findsNWidgets(2));
    expect(find.byType(InkWell), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty state scales and scrolls at 320dp/200 percent', (
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
              body: SingleChildScrollView(
                child: GettoEmptyStateCard(
                  illustration: const Icon(Icons.home_outlined),
                  title: 'Nothing to track yet',
                  description: 'Your home is ready. Start with one item whenever you like.',
                  actionLabel: 'Add first item',
                  onAction: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
