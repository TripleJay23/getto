import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getto/app/app.dart';
import 'package:getto/app/routing/app_router.dart';
import 'package:getto/app/composition/household_providers.dart';
import 'package:getto/design_system/responsive/getto_responsive.dart';

Future<void> pumpGetto(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  final router = createAppRouter(initialLocation: '/home');
  addTearDown(() {
    router.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
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

void main() {
  testWidgets('compact navigation switches three real branches', (
    tester,
  ) async {
    await pumpGetto(tester, const Size(430, 900));
    expect(
      find.byKey(const ValueKey('getto-bottom-navigation')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('getto-home-page')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('getto-nav-buy')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('getto-buy-page')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('getto-nav-bills')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('getto-bills-page')), findsOneWidget);
  });

  testWidgets('responsive nav switches at exact accepted boundaries', (
    tester,
  ) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    for (final width in <double>[320, 599, 600, 839, 840, 1024]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      final router = createAppRouter(initialLocation: '/home');
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
      final compact = width < GettoResponsive.railStart;
      expect(
        find.byType(NavigationBar),
        compact ? findsOneWidget : findsNothing,
      );
      expect(
        find.byType(NavigationRail),
        compact ? findsNothing : findsOneWidget,
      );
      expect(tester.takeException(), isNull, reason: 'width $width');
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    }
  });

  testWidgets('compact nav has 80dp height and >=48dp destinations', (
    tester,
  ) async {
    await pumpGetto(tester, const Size(320, 780));
    expect(tester.getSize(find.byType(NavigationBar)).height, 80);
    for (final name in <String>['home', 'buy', 'bills']) {
      final size = tester.getSize(find.byKey(ValueKey('getto-nav-$name')));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  testWidgets('200% scale keeps all compact destinations tappable at 320dp', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpGetto(tester, const Size(320, 780));

    final navigation = find.byType(NavigationBar);
    final navigationRect = tester.getRect(navigation);
    expect(navigationRect.height, 80);
    expect(find.byKey(const ValueKey('getto-home-page')), findsOneWidget);

    for (final (name, label, selectedIndex) in <(String, String, int)>[
      ('buy', 'Buy', 1),
      ('bills', 'Bills', 2),
      ('home', 'Home', 0),
    ]) {
      final destination = find.byKey(ValueKey('getto-nav-$name'));
      expect(tester.widget<NavigationDestination>(destination).label, label);
      final bounds = tester.getRect(destination);
      expect(bounds.width, greaterThanOrEqualTo(48));
      expect(bounds.height, greaterThanOrEqualTo(48));
      expect(bounds.left, greaterThanOrEqualTo(navigationRect.left - 1));
      expect(bounds.right, lessThanOrEqualTo(navigationRect.right + 1));
      await tester.tap(destination);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('getto-$name-page')), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(navigation).selectedIndex,
        selectedIndex,
      );
      expect(tester.takeException(), isNull, reason: 'destination $name');
    }
  });
}
