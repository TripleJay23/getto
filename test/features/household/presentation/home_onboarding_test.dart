import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:getto/app/app.dart';
import 'package:getto/app/composition/database_providers.dart';
import 'package:getto/app/composition/household_providers.dart';
import 'package:getto/app/composition/onboarding_providers.dart';
import 'package:getto/app/routing/app_router.dart';
import 'package:getto/core/database/app_database.dart';
import 'package:getto/core/domain/result/failure.dart';
import 'package:getto/core/domain/result/result.dart';
import 'package:getto/design_system/components/getto_skeleton_row.dart';
import 'package:getto/design_system/components/getto_item_row.dart';
import 'package:getto/design_system/components/getto_status_badge.dart';
import 'package:getto/features/household/data/drift_area_repository.dart';
import 'package:getto/features/household/data/drift_item_repository.dart';
import 'package:getto/features/household/domain/area.dart';
import 'package:getto/features/household/domain/behavior_profile.dart';
import 'package:getto/features/household/domain/item.dart';
import 'package:getto/features/household/domain/stock_status.dart';
import 'package:getto/features/onboarding/application/onboarding_store.dart';
import 'package:go_router/go_router.dart';

import '../../../support/delayed_item_repository.dart';

class TestSetupStore implements OnboardingStore {
  bool completed = false;
  bool failRead = false;
  bool failWrite = false;
  @override
  Future<Result<bool, DataFailure>> readCompleted() async => failRead
      ? const Result.failure(StorageIoFailure('injected'))
      : Result.success(completed);
  @override
  Future<Result<void, DataFailure>> complete() async {
    if (failWrite) return const Result.failure(StorageIoFailure('injected'));
    completed = true;
    return const Result.success(null);
  }
}

Future<void> settleDatabase(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> tapLabel(WidgetTester tester, String label) async {
  final buttons = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  );
  final finder =
      find.byType(DropdownMenuItem<int>).evaluate().isNotEmpty ||
          buttons.evaluate().isEmpty
      ? find.text(label).last
      : buttons.last;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await settleDatabase(tester);
}

void main() {
  late AppDatabase db;
  late TestSetupStore setup;
  late GoRouter router;
  setUpAll(() async {
    final font = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope[wght].ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await DriftAreaRepository(db).getAreas();
    setup = TestSetupStore();
  });
  void screenTest(
    String description,
    Future<void> Function(WidgetTester) body,
  ) {
    testWidgets(description, (tester) async {
      final shadows = debugDisableShadows;
      debugDisableShadows = false;
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        final closing = db.close();
        await tester.pumpAndSettle();
        await closing;
        router.dispose();
        debugDisableShadows = shadows;
      }
    });
  }

  Future<void> pump(
    WidgetTester tester, {
    String location = '/start',
    double width = 430,
    double height = 900,
    double scale = 1,
    EdgeInsets padding = EdgeInsets.zero,
    bool reduceMotion = false,
    List<Override> extra = const [],
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(
      top: padding.top,
      bottom: padding.bottom,
      left: padding.left,
      right: padding.right,
    );
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
    });
    router = createAppRouter(initialLocation: location);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: reduceMotion);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('screen-capture'),
        child: ProviderScope(
          key: UniqueKey(),
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            onboardingStoreProvider.overrideWithValue(setup),
            ...extra,
          ],
          child: MediaQuery(
            data: MediaQueryData(
              size: Size(width, height),
              padding: padding,
              textScaler: TextScaler.linear(scale),
              disableAnimations: reduceMotion,
            ),
            child: GettoApp(router: router),
          ),
        ),
      ),
    );
    // MaterialApp supplies view metrics; apply text scaling through platform too.
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await settleDatabase(tester);
  }

  Future<void> identity(
    WidgetTester tester, {
    String name = 'Household test',
  }) async {
    await tester.enterText(find.byKey(const Key('item-name')), name);
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tapLabel(tester, 'Kitchen');
    await tapLabel(tester, 'Continue');
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('screen-capture')),
      );
      final picture = await boundary.toImage(pixelRatio: 1);
      try {
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/m232/screens').create(recursive: true);
        await File('build/m232/screens/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
      } finally {
        picture.dispose();
      }
    });
  }

  screenTest(
    'first launch, Explore failure/retry, empty Home and restart routing',
    (tester) async {
      await pump(tester);
      expect(find.text('Run your home with less to remember.'), findsOneWidget);
      await tapLabel(tester, 'Set up my home');
      expect(find.textContaining('Bedroom'), findsWidgets);
      setup.failWrite = true;
      await tapLabel(tester, 'Explore my home');
      expect(setup.completed, isFalse);
      expect(
        find.textContaining("Couldn't save setup progress"),
        findsOneWidget,
      );
      setup.failWrite = false;
      await tapLabel(tester, 'Explore my home');
      expect(find.text('Nothing to track yet'), findsOneWidget);
      expect(
        (await tester.runAsync(() => DriftItemRepository(db).getAllItems()))!
            .valueOrNull,
        isEmpty,
      );
      final oldRouter = router;
      await tester.pumpWidget(const SizedBox());
      oldRouter.dispose();
      await pump(tester);
      expect(find.byKey(const ValueKey('getto-home-page')), findsOneWidget);
      expect(find.text('Run your home with less to remember.'), findsNothing);
    },
  );

  screenTest(
    'read failure remains recoverable without silently resetting onboarding',
    (tester) async {
      setup.failRead = true;
      await pump(tester);
      expect(
        find.textContaining("Couldn't read setup progress"),
        findsOneWidget,
      );
      setup.failRead = false;
      await tapLabel(tester, 'Retry');
      expect(find.text('Set up my home'), findsOneWidget);
    },
  );

  screenTest(
    'first item uses both steps, committed value and completion before Home',
    (tester) async {
      await pump(tester);
      await tapLabel(tester, 'Set up my home');
      await tapLabel(tester, 'Add first item');
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
            .onPressed,
        isNull,
      );
      await identity(tester, name: 'Reading lamp');
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Add item'))
            .onPressed,
        isNull,
      );
      await tapLabel(tester, 'Keep it around');
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Add item'))
            .onPressed,
        isNull,
      );
      await tapLabel(tester, 'Not at home');
      await tapLabel(tester, 'Add item');
      expect(find.text('Added to your home'), findsOneWidget);
      expect(
        (await tester.runAsync(() => DriftItemRepository(db).getAllItems()))!
            .valueOrNull,
        hasLength(1),
      );
      await tapLabel(tester, 'Done for now');
      setup.failWrite = true;
      await tapLabel(tester, 'Go to Home');
      expect(
        find.textContaining('Your item is saved. Setup progress'),
        findsOneWidget,
      );
      setup.failWrite = false;
      await tapLabel(tester, 'Retry');
      expect(find.text('Reading lamp'), findsOneWidget);
      expect(find.text('Not at home'), findsOneWidget);
      expect(find.text('1 item in your home'), findsOneWidget);
    },
  );

  screenTest(
    'custom area Cancel, failed area creation, draft Back/Cancel and item Retry',
    (tester) async {
      await pump(tester, location: '/home');
      await tapLabel(tester, 'Add first item');
      await tester.enterText(find.byKey(const Key('item-name')), 'Draft soap');
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tapLabel(tester, 'Custom · Create a home area');
      await tester.enterText(
        find.byKey(const Key('custom-area-name')),
        'Utility',
      );
      await tapLabel(tester, 'Cancel');
      expect(find.text('Draft soap'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tapLabel(tester, 'Custom · Create a home area');
      await tester.enterText(
        find.byKey(const Key('custom-area-name')),
        'Kitchen',
      );
      await tapLabel(tester, 'Create area');
      expect(find.textContaining('already has this name'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('custom-area-name')),
        'Utility',
      );
      await tapLabel(tester, 'Create area');
      expect(find.text('Your new area is saved and selected.'), findsOneWidget);
      await tapLabel(tester, 'Continue');
      await tapLabel(tester, 'Use it up');
      await tapLabel(tester, 'Yes, at home');
      await tapLabel(tester, 'Back');
      expect(find.text('Draft soap'), findsOneWidget);
      await tapLabel(tester, 'Continue');
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tapLabel(tester, 'Add first item');
      expect(find.text('Finish adding this item'), findsOneWidget);
      await tester.runAsync(
        () => db.customStatement(
          "CREATE TRIGGER reject_widget BEFORE INSERT ON items BEGIN SELECT RAISE(FAIL, 'injected'); END",
        ),
      );
      await tapLabel(tester, 'Add item');
      expect(find.textContaining('new area is already saved'), findsOneWidget);
      await tapLabel(tester, 'Keep editing');
      await tapLabel(tester, 'Back');
      expect(find.text('Draft soap'), findsOneWidget);
      await tapLabel(tester, 'Continue');
      await tester.runAsync(
        () => db.customStatement('DROP TRIGGER reject_widget'),
      );
      await tapLabel(tester, 'Add item');
      expect(find.text('Draft soap'), findsOneWidget);
      expect(find.text('1 item in your home'), findsOneWidget);
    },
  );

  screenTest(
    'reactive items, archived exclusion, contextual area and branch retention',
    (tester) async {
      await pump(tester, location: '/home');
      final repo = DriftItemRepository(db);
      final mutation = (() async {
        await repo.createItem(
          areaId: 1,
          name: 'Kitchen item',
          behaviorProfile: BehaviorProfile.durable,
          stockStatus: StockStatus.inStock,
        );
        final hidden = (await repo.createItem(
          areaId: 1,
          name: 'Archived item',
          behaviorProfile: BehaviorProfile.durable,
          stockStatus: StockStatus.inStock,
        )).valueOrNull!;
        await repo.archiveItem(hidden.id);
        await repo.createItem(
          areaId: 2,
          name: 'Bathroom item',
          behaviorProfile: BehaviorProfile.replenishable,
          stockStatus: StockStatus.outOfStock,
        );
      })();
      await settleDatabase(tester);
      await mutation;
      expect(find.text('2 items in your home'), findsOneWidget);
      expect(find.text('Browse all areas'), findsNothing);
      await tester.tap(find.byTooltip('More home options'));
      await tester.pumpAndSettle();
      expect(find.text('Browse all areas'), findsNothing);
      expect(find.text('Home areas'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Archived item'), findsNothing);
      await tapLabel(tester, 'Kitchen');
      expect(router.routeInformationProvider.value.uri.path, '/home/areas/1');
      expect(find.text('Kitchen item'), findsOneWidget);
      expect(find.text('Bathroom item'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('getto-nav-buy')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('getto-nav-bills')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('getto-nav-home')));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/home/areas/1');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/home');
    },
  );

  screenTest(
    'Android Back, scrim dismissal and busy-write lock preserve draft and commit once',
    (tester) async {
      final delayed = DelayedItems(db);
      await pump(
        tester,
        location: '/home',
        extra: [itemRepositoryProvider.overrideWithValue(delayed)],
      );
      await tapLabel(tester, 'Add first item');
      await identity(tester, name: 'Pending lamp');
      await tapLabel(tester, 'Keep it around');
      await tapLabel(tester, 'Yes, at home');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Pending lamp'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);
      await tapLabel(tester, 'Add first item');
      expect(find.text('Pending lamp'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);
      await tapLabel(tester, 'Add first item');
      expect(find.text('Pending lamp'), findsOneWidget);
      await tapLabel(tester, 'Continue');
      await tester.ensureVisible(find.text('Add item'));
      await tester.tap(find.text('Add item'));
      await tester.pump();
      await tester.ensureVisible(find.text('Back'));
      expect(
        tester
            .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Back'))
            .onPressed,
        isNull,
      );
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      await tester.drag(
        find.byKey(const Key('item-sheet-handle')),
        const Offset(0, 400),
      );
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Finish adding this item'), findsOneWidget);
      delayed.gate.complete();
      await settleDatabase(tester);
      expect(delayed.calls, 1);
      expect(find.text('Pending lamp'), findsOneWidget);
      expect(find.text('1 item in your home'), findsOneWidget);
    },
  );

  screenTest('local-read loading, error and Retry recover actual Home', (
    tester,
  ) async {
    final pending = StreamController<List<Item>>();
    addTearDown(pending.close);
    var attempts = 0;
    await pump(
      tester,
      location: '/home',
      extra: [
        allAreasStreamProvider.overrideWith((ref) => Stream.value(<Area>[])),
        allItemsStreamProvider.overrideWith(
          (ref) => ++attempts == 1 ? pending.stream : Stream.value([]),
        ),
      ],
    );
    expect(find.byType(GettoSkeletonRow), findsNWidgets(3));
    pending.addError(StateError('private error detail'));
    await tester.pumpAndSettle();
    expect(find.textContaining("Couldn't load your home"), findsOneWidget);
    expect(find.textContaining('private error detail'), findsNothing);
    await tapLabel(tester, 'Retry');
    expect(find.text('Nothing to track yet'), findsOneWidget);
  });

  screenTest(
    'basic search composes area, retains across branches and never changes data',
    (tester) async {
      final repo = DriftItemRepository(db);
      await tester.runAsync(() async {
        for (final entry in [
          (1, 'Kitchen soap'),
          (2, 'Bathroom soap'),
          (1, 'Reading lamp'),
        ]) {
          await repo.createItem(
            areaId: entry.$1,
            name: entry.$2,
            behaviorProfile: BehaviorProfile.durable,
            stockStatus: StockStatus.inStock,
          );
        }
      });
      await pump(tester, location: '/home');
      await tester.enterText(find.byKey(const Key('home-search')), 'SOAP');
      await settleDatabase(tester);
      expect(find.text('Kitchen soap'), findsOneWidget);
      expect(find.text('Bathroom soap'), findsOneWidget);
      expect(find.text('Reading lamp'), findsNothing);
      await tapLabel(tester, 'Kitchen');
      expect(find.text('Kitchen soap'), findsOneWidget);
      expect(find.text('Bathroom soap'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('getto-nav-buy')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('getto-nav-home')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('home-search')))
            .controller!
            .text,
        'SOAP',
      );
      await tester.enterText(find.byKey(const Key('home-search')), 'no match');
      await settleDatabase(tester);
      expect(find.text('No matching items'), findsOneWidget);
      await tapLabel(tester, 'Clear search');
      expect(find.text('Reading lamp'), findsOneWidget);
      expect(
        (await tester.runAsync(repo.getAllItems))!.valueOrNull,
        hasLength(3),
      );
    },
  );

  screenTest(
    'ready opens the item sheet directly and dismissal returns to ready',
    (tester) async {
      await pump(tester);
      await tapLabel(tester, 'Set up my home');
      await tapLabel(tester, 'Add first item');
      expect(find.byKey(const Key('item-name')), findsOneWidget);
      expect(find.text('Add your first item'), findsNothing);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Your home is ready'), findsOneWidget);
      expect(find.text('Explore my home'), findsOneWidget);
      expect(setup.completed, isFalse);
    },
  );

  screenTest(
    'Home search unfocuses on outside touch, keyboard hide and submission',
    (tester) async {
      await pump(tester, location: '/home');
      final field = find.byKey(const Key('home-search'));
      FocusNode focus() => tester.widget<TextField>(field).focusNode!;
      await tester.tap(field);
      await tester.pump();
      expect(focus().hasFocus, isTrue);
      await tester.tapAt(tester.getCenter(find.text('Home').first));
      await tester.pumpAndSettle();
      expect(focus().hasFocus, isFalse);

      await tester.tap(field);
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pumpAndSettle();
      expect(focus().hasFocus, isFalse);
      addTearDown(tester.view.resetViewInsets);

      await tester.enterText(field, 'soap');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(focus().hasFocus, isFalse);
      expect(tester.widget<TextField>(field).controller!.text, 'soap');
    },
  );

  screenTest(
    'keyboard Continue does not leave focus on the replacement save action',
    (tester) async {
      await pump(tester, location: '/home');
      await tapLabel(tester, 'Add first item');
      await identity(tester, name: 'Keyboard draft');
      await tapLabel(tester, 'Use it up');
      await tapLabel(tester, 'Yes, at home');
      await tapLabel(tester, 'Back');
      Focus.of(tester.element(find.text('Continue'))).requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Finish adding this item'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleDatabase(tester);
      expect(
        (await tester.runAsync(() => DriftItemRepository(db).getAllItems()))!
            .valueOrNull,
        isEmpty,
      );
      expect(find.text('Finish adding this item'), findsOneWidget);
    },
  );

  screenTest('idle sheet drag dismisses and reopening preserves identity', (
    tester,
  ) async {
    await pump(tester, location: '/home');
    await tapLabel(tester, 'Add first item');
    await tester.enterText(
      find.byKey(const Key('item-name')),
      'Retained draft',
    );
    await tester.drag(
      find.byKey(const Key('item-sheet-handle')),
      const Offset(0, 600),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('item-name')), findsNothing);
    await tapLabel(tester, 'Add first item');
    expect(find.text('Retained draft'), findsOneWidget);
  });

  for (final (width, height, scale, padding) in [
    (352.65, 764.08, 1.15, const EdgeInsets.only(top: 44.4, bottom: 24.2)),
    (320.0, 640.0, 1.0, const EdgeInsets.only(top: 24, bottom: 24)),
  ]) {
    screenTest(
      '$width x $height setup fits the initial viewport with safe areas',
      (tester) async {
        await pump(
          tester,
          width: width,
          height: height,
          scale: scale,
          padding: padding,
        );
        expect(find.text('GETTO'), findsNothing);
        for (final (step, action, name) in [
          (0, 'Set up my home', 'orientation'),
          (1, 'Add first item', 'ready'),
        ]) {
          final button = find.widgetWithText(FilledButton, action).last;
          final rect = tester.getRect(button);
          expect(rect.top, greaterThanOrEqualTo(padding.top));
          expect(rect.bottom, lessThanOrEqualTo(height - padding.bottom));
          expect(button.hitTestable(), findsOneWidget);
          final scroll = tester.state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(ValueKey('onboarding-content-$step')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(
            scroll.position.maxScrollExtent,
            closeTo(0, .1),
            reason: 'Normal-size $name content should fit without scrolling.',
          );
          await capture(tester, 'fit-$name-$width-$height');
          if (step < 1) await tapLabel(tester, action);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final width in [320.0, 352.65, 430.0]) {
    screenTest(
      '$width dp search is compact and presence badge trails the item title',
      (tester) async {
        await tester.runAsync(
          () => DriftItemRepository(db).createItem(
            areaId: 1,
            name: 'Soap',
            behaviorProfile: BehaviorProfile.replenishable,
            stockStatus: StockStatus.inStock,
          ),
        );
        await pump(
          tester,
          location: '/home',
          width: width,
          height: 764.08,
          scale: 1.15,
          padding: const EdgeInsets.only(top: 44.4, bottom: 24.2),
        );
        final search = tester.getRect(find.byKey(const Key('home-search')));
        expect(search.left, closeTo(24, .1));
        expect(search.right, closeTo(width - 24, .1));
        expect(search.height, inInclusiveRange(48, 50));
        final row = find.byType(GettoItemRow);
        final title = tester.getRect(
          find.descendant(of: row, matching: find.text('Soap')),
        );
        final badge = tester.getRect(
          find.descendant(of: row, matching: find.byType(GettoStatusBadge)),
        );
        expect(badge.left, greaterThan(title.right));
        expect(badge.top, closeTo(title.top, .1));
        await capture(tester, 'fit-home-$width');
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final width in [320.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      screenTest(
        '$width dp / $scale filters stay in one horizontal row and reach last area',
        (tester) async {
          await pump(tester, location: '/home', width: width, scale: scale);
          await capture(tester, 'empty-home-$width-$scale');
          final filter = find.byKey(const ValueKey('home-area-filters'));
          final all = find.descendant(of: filter, matching: find.text('All'));
          final kitchen = find.descendant(
            of: filter,
            matching: find.text('Kitchen'),
          );
          final livingRoom = find.descendant(
            of: filter,
            matching: find.text('Living Room'),
          );
          expect(
            tester.getCenter(all).dy,
            closeTo(tester.getCenter(kitchen).dy, .1),
          );
          expect(
            tester.getCenter(all).dy,
            closeTo(tester.getCenter(livingRoom).dy, .1),
          );
          await tester.ensureVisible(livingRoom);
          await tester.pumpAndSettle();
          await tester.tap(livingRoom);
          await settleDatabase(tester);
          expect(
            find.textContaining('active items in Living Room'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
      screenTest(
        '$width dp / ${scale * 100}% onboarding, sheet, Home and semantics',
        (tester) async {
          final semantics = tester.ensureSemantics();
          await pump(tester, width: width, scale: scale, reduceMotion: true);
          await capture(tester, 'orientation-$width-$scale');
          await tapLabel(tester, 'Set up my home');
          await capture(tester, 'ready-$width-$scale');
          await tapLabel(tester, 'Add first item');
          expect(
            MediaQuery.disableAnimationsOf(
              tester.element(find.byType(DropdownButtonFormField<int>)),
            ),
            isTrue,
          );
          await capture(tester, 'identity-$width-$scale');
          await identity(tester);
          await tapLabel(tester, 'Count what remains');
          await tapLabel(tester, 'Yes, at home');
          await capture(tester, 'choices-$width-$scale');
          // At enlarged text, partial scroll-edge semantics can be smaller than
          // the full control. Reveal each choice/action and verify its actual
          // target; run the whole-viewport matcher when all controls fit.
          for (final label in [
            'Use it up',
            'Count what remains',
            'Keep it around',
            'Yes, at home',
            'Not at home',
            'Add item',
            'Back',
          ]) {
            final button = find
                .ancestor(
                  of: find.text(label),
                  matching: find.byWidgetPredicate(
                    (w) => w is ButtonStyleButton,
                  ),
                )
                .first;
            await tester.ensureVisible(button);
            await tester.pumpAndSettle();
            final size = tester.getSize(button);
            expect(size.width, greaterThanOrEqualTo(48));
            expect(size.height, greaterThanOrEqualTo(48));
          }
          if (scale == 1) {
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
          }
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await tapLabel(tester, 'Add item');
          await capture(tester, 'first-value-$width-$scale');
          await tapLabel(tester, 'Done for now');
          await capture(tester, 'complete-$width-$scale');
          await tapLabel(tester, 'Go to Home');
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          expect(tester.takeException(), isNull);
          expect(find.text('Household test'), findsOneWidget);
          expect(
            tester.getTopLeft(find.text('Household test')).dx,
            closeTo(42, .1),
          );
          await capture(tester, 'home-$width-$scale');
          semantics.dispose();
        },
      );
    }
  }
}
