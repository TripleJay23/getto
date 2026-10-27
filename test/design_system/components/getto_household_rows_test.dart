import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getto/design_system/components/getto_home_area_row.dart';
import 'package:getto/design_system/components/getto_item_row.dart';
import 'package:getto/design_system/components/getto_status_badge.dart';
import 'package:getto/design_system/theme/getto_theme.dart';

void main() {
  testWidgets('default areas have a usable Manage action (M2-D10)', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var activated = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: GettoTheme.light,
        home: Scaffold(
          body: GettoHomeAreaRow(
            name: 'Kitchen',
            activeItems: 6,
            isDefault: true,
            onManage: () => activated = true,
          ),
        ),
      ),
    );
    expect(find.text('6 active items · default'), findsOneWidget);
    expect(find.bySemanticsLabel('Manage Kitchen'), findsWidgets);
    await tester.tap(find.text('Manage'));
    expect(activated, isTrue);
    semantics.dispose();
  });

  testWidgets('custom area uses the same action contract', (tester) async {
    var activated = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: GettoTheme.light,
        home: Scaffold(
          body: GettoHomeAreaRow(
            name: 'Studio',
            activeItems: 1,
            isDefault: false,
            onManage: () => activated = true,
          ),
        ),
      ),
    );
    expect(find.text('1 active item · custom'), findsOneWidget);
    await tester.tap(find.text('Manage'));
    expect(activated, isTrue);
  });

  testWidgets('item row retains title, subtitle and semantic badge', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: GettoTheme.light,
        home: Scaffold(
          body: GettoItemRow(
            title: 'Toothpaste',
            subtitle: 'Bathroom · In use',
            status: GettoBadgeState.inUse,
            statusIcon: const Icon(Icons.check, size: 16),
            onTap: () => tapped = true,
          ),
        ),
      ),
    );
    expect(find.text('Toothpaste'), findsOneWidget);
    expect(find.text('In use'), findsOneWidget);
    await tester.tap(find.text('Toothpaste'));
    expect(tapped, isTrue);
  });

  testWidgets('430dp item row meets reference minimum height', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: GettoTheme.light,
        home: const Scaffold(
          body: GettoItemRow(
            title: 'Toothpaste',
            subtitle: 'Bathroom · In use',
            status: GettoBadgeState.inUse,
            statusIcon: Icon(Icons.check, size: 16),
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(GettoItemRow)).height,
      greaterThanOrEqualTo(76),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('rows do not overflow at 320dp and 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
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
                child: Column(
                  children: [
                    const GettoItemRow(
                      title: 'Extra long household item name',
                      subtitle: 'Bathroom · Optional package context',
                      status: GettoBadgeState.readyToRestock,
                      statusIcon: Icon(Icons.check_circle, size: 16),
                    ),
                    GettoHomeAreaRow(
                      name: 'Long personal home area name',
                      activeItems: 12,
                      isDefault: true,
                      onManage: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Extra long household item name'), findsOneWidget);
    expect(find.text('Manage'), findsOneWidget);
  });
}
