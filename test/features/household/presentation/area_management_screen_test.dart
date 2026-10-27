import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getto/app/app.dart';
import 'package:getto/app/composition/database_providers.dart';
import 'package:getto/app/composition/household_providers.dart';
import 'package:getto/app/routing/app_router.dart';
import 'package:getto/core/database/app_database.dart';
import 'package:getto/design_system/components/getto_home_area_row.dart';
import 'package:getto/features/household/data/drift_item_repository.dart';
import 'package:getto/features/household/domain/behavior_profile.dart';
import 'package:getto/features/household/domain/stock_status.dart';
import 'package:go_router/go_router.dart';

import 'area_management_controller_test.dart' show ControlledAreas;
import 'home_onboarding_test.dart' show settleDatabase;

void main() {
  late AppDatabase db;
  late ControlledAreas areas;
  late DriftItemRepository items;
  late GoRouter router;
  late int activeId;
  late int archivedId;
  setUpAll(() async {
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope[wght].ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    areas = ControlledAreas(db);
    items = DriftItemRepository(db);
    activeId = (await items.createItem(
      areaId: 1,
      name: 'Visible saved item',
      behaviorProfile: BehaviorProfile.countableReplenishable,
      stockStatus: StockStatus.inStock,
      packageCount: 8,
    )).valueOrNull!.id;
    archivedId = (await items.createItem(
      areaId: 1,
      name: 'Archived saved item',
      behaviorProfile: BehaviorProfile.durable,
      stockStatus: StockStatus.inStock,
    )).valueOrNull!.id;
    await items.archiveItem(archivedId);
  });
  void screenTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await body(tester);
      } finally {
        semantics.dispose();
        if (areas.gate != null && !areas.gate!.isCompleted) {
          areas.gate!.complete();
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        final closing = db.close();
        await tester.pumpAndSettle();
        await closing;
        router.dispose();
      }
    });
  }

  Future<void> pump(
    WidgetTester tester, {
    String path = '/home/manage-areas',
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(scale == 1 ? 430 : 320, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    });
    router = createAppRouter(initialLocation: path);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('area-capture'),
        child: ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            areaRepositoryProvider.overrideWithValue(areas),
          ],
          child: GettoApp(router: router),
        ),
      ),
    );
    await settleDatabase(tester);
  }

  Future<void> tap(WidgetTester tester, String label) async {
    if (find.text(label).evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.text(label),
        160,
        scrollable: find.byType(Scrollable).last,
      );
    }
    final buttons = find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );
    final target = buttons.evaluate().isEmpty
        ? find.text(label).last
        : buttons.last;
    await Scrollable.ensureVisible(tester.element(target), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await settleDatabase(tester);
  }

  Future<void> manage(WidgetTester tester, String name) async {
    if (find.byType(SnackBar).evaluate().isNotEmpty) {
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    }
    final id = switch (name) {
      'Kitchen' || 'Old kitchen' => 1,
      'Studio' => 5,
      _ => -1,
    };
    final row = find.byKey(ValueKey('manage-area-$id'));
    final scroll = find
        .byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        )
        .last;
    if (row.evaluate().isEmpty) {
      await tester.drag(scroll, const Offset(0, 4000));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(row, 200, scrollable: scroll);
    }
    final target = find.descendant(of: row, matching: find.text('Manage'));
    await Scrollable.ensureVisible(tester.element(target), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await settleDatabase(tester);
  }

  Future<void> destination(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(DropdownButtonFormField<int>));
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bathroom').last);
    await tester.pumpAndSettle();
  }

  Future<void> snapshot(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('area-capture')),
      );
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final directory = Directory('build/m234-correction/screens');
      await directory.create(recursive: true);
      await File('${directory.path}/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
    });
  }

  screenTest(
    'Home entry, default/custom parity, name-only save and reactive filters',
    (tester) async {
      await tester.runAsync(() => areas.createArea(name: 'Studio'));
      await pump(tester, path: '/home');
      await tester.tap(find.byTooltip('More home options'));
      await tester.pumpAndSettle();
      await tap(tester, 'Manage areas');
      expect(find.byType(GettoHomeAreaRow), findsWidgets);
      await manage(tester, 'Studio');
      expect(find.text('Rename area'), findsOneWidget);
      await tap(tester, 'Cancel');
      await manage(tester, 'Kitchen');
      await tap(tester, 'Rename area');
      await tester.enterText(find.byKey(const Key('area-name')), 'Cook room');
      await tap(tester, 'Save area');
      expect(
        (await tester.runAsync(() => areas.getAreaById(1)))!
            .valueOrNull!
            .isSystem,
        isTrue,
      );
      await tester.tap(find.byTooltip('Back'));
      await settleDatabase(tester);
      expect(find.text('Cook room'), findsWidgets);
      expect(find.text('Visible saved item'), findsOneWidget);
    },
  );

  screenTest(
    'standalone creation retains failed draft and commits after retry',
    (tester) async {
      await pump(tester);
      await tap(tester, 'Add custom area');
      await tester.enterText(find.byKey(const Key('area-name')), 'Kitchen');
      await tap(tester, 'Save area');
      expect(find.textContaining('already has this name'), findsOneWidget);
      expect(find.text('Kitchen'), findsWidgets);
      await tester.enterText(find.byKey(const Key('area-name')), 'Studio');
      await tap(tester, 'Save area');
      expect(find.byKey(const Key('area-name')), findsNothing);
      expect(
        (await tester.runAsync(() => areas.getAreas()))!.valueOrNull!
            .any((a) => a.name == 'Studio'),
        isTrue,
      );
    },
  );

  screenTest(
    'stale rename requires explicit saved-name review while retaining input',
    (tester) async {
      await pump(tester);
      await manage(tester, 'Kitchen');
      await tap(tester, 'Rename area');
      await tester.enterText(find.byKey(const Key('area-name')), 'My draft');
      await tester.runAsync(() async {
        final area = (await areas.getAreaById(1)).valueOrNull!;
        await areas.renameArea(expected: area, name: 'Saved winner');
      });
      await settleDatabase(tester);
      await tap(tester, 'Save area');
      expect(find.text('My draft'), findsOneWidget);
      expect(
        find.textContaining('Latest saved name: Saved winner'),
        findsOneWidget,
      );
      await tap(tester, 'Review saved name');
      await tap(tester, 'Save area');
      expect(
        (await tester.runAsync(() => areas.getAreaById(1)))!.valueOrNull!.name,
        'My draft',
      );
    },
  );

  screenTest(
    'accessible reorder has disabled boundaries and survives branch switching',
    (tester) async {
      await pump(tester);
      final first = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Move Kitchen up'),
      );
      expect(first.onPressed, isNull);
      expect(
        tester
            .getSize(find.widgetWithText(OutlinedButton, 'Move Kitchen up'))
            .height,
        greaterThanOrEqualTo(48),
      );
      await tap(tester, 'Move Kitchen down');
      expect(
        (await tester.runAsync(() => areas.getAreas()))!.valueOrNull!
            .map((a) => a.id),
        [2, 1, 3, 4],
      );
      await tester.tap(find.byKey(const ValueKey('getto-nav-buy')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('getto-nav-home')));
      await settleDatabase(tester);
      expect(
        router.routeInformationProvider.value.uri.path,
        '/home/manage-areas',
      );
    },
  );

  screenTest(
    'archive keeps active items in All and restore conflict offers rename recovery',
    (tester) async {
      await pump(tester);
      await manage(tester, 'Kitchen');
      await tap(tester, 'Archive area');
      await tap(tester, 'Archive area');
      expect(
        (await tester.runAsync(() => areas.getAreaById(1)))!
            .valueOrNull!
            .isArchived,
        isTrue,
      );
      await tester.runAsync(() => areas.createArea(name: 'Kitchen'));
      await settleDatabase(tester);
      await manage(tester, 'Kitchen');
      await tap(tester, 'Restore area');
      expect(find.textContaining('rename the archived area'), findsWidgets);
      await manage(tester, 'Kitchen');
      await tap(tester, 'Rename area');
      await tester.enterText(find.byKey(const Key('area-name')), 'Old kitchen');
      await tap(tester, 'Save area');
      await manage(tester, 'Old kitchen');
      await tap(tester, 'Restore area');
      router.go('/home');
      await settleDatabase(tester);
      expect(find.text('Visible saved item'), findsOneWidget);
    },
  );

  screenTest(
    'populated cancellation then bulk relocation preserves active/archived facts',
    (tester) async {
      await pump(tester, path: '/home/manage-areas/1/remove');
      expect(find.text('Archived saved item'), findsOneWidget);
      await tap(tester, 'Review move all and delete');
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(DropdownButtonFormField<int>),
        ),
        findsOneWidget,
      );
      await destination(tester);
      expect(find.text('Delete Kitchen area?'), findsOneWidget);
      expect(find.text('1 archived item included.'), findsOneWidget);
      await tap(tester, 'Cancel');
      expect(
        (await tester.runAsync(() => items.getItemById(activeId)))!
            .valueOrNull!
            .areaId,
        1,
      );
      await tap(tester, 'Review move all and delete');
      await destination(tester);
      await tap(tester, 'Move all and delete area');
      expect(
        router.routeInformationProvider.value.uri.path,
        '/home/manage-areas',
      );
      expect(
        (await tester.runAsync(() => items.getItemById(activeId)))!
            .valueOrNull!
            .packageCount,
        8,
      );
      expect(
        (await tester.runAsync(() => items.getItemById(archivedId)))!
            .valueOrNull!
            .isArchived,
        isTrue,
      );
      expect(
        (await tester.runAsync(() => items.restoreItem(archivedId)))!
            .valueOrNull!
            .areaId,
        2,
      );
    },
  );

  screenTest(
    'equal-count membership change requires refreshed consent before relocation',
    (tester) async {
      await pump(tester, path: '/home/manage-areas/1/remove');
      await tap(tester, 'Review move all and delete');
      await destination(tester);
      final mutation = (() async {
        await items.deleteItem(activeId);
        await items.createItem(
          areaId: 1,
          name: 'Replacement',
          behaviorProfile: BehaviorProfile.durable,
          stockStatus: StockStatus.inStock,
        );
      })();
      await settleDatabase(tester);
      await mutation;
      await tap(tester, 'Move all and delete area');
      expect(
        find.textContaining('Saved areas or contained items changed'),
        findsWidgets,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Move all and delete area'),
            )
            .onPressed,
        isNull,
      );
      await tap(tester, 'Refresh review');
      expect(
        (await tester.runAsync(() => areas.getAreaById(1)))!.isSuccess,
        isTrue,
      );
      await tap(tester, 'Move all and delete area');
      expect(
        (await tester.runAsync(() => areas.getAreaById(1)))!.isFailure,
        isTrue,
      );
    },
  );

  screenTest(
    'busy empty deletion blocks Cancel/Back; failure retains confirmation for retry',
    (tester) async {
      await pump(tester, path: '/home/manage-areas/4/remove');
      await tap(tester, 'Review deletion');
      areas.gate = Completer<void>();
      areas.fail = true;
      await tester.tap(find.text('Delete empty area'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Cancel'),
            )
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Delete Living Room area?'), findsOneWidget);
      areas.gate!.complete();
      await settleDatabase(tester);
      expect(find.textContaining("Couldn't save this change"), findsWidgets);
      areas.fail = false;
      areas.gate = null;
      await tap(tester, 'Delete empty area');
      expect(
        (await tester.runAsync(() => areas.getAreaById(4)))!.isFailure,
        isTrue,
      );
    },
  );

  screenTest(
    'no eligible destination disables relocation and missing routes recover safely',
    (tester) async {
      await tester.runAsync(() async {
        for (final id in [2, 3, 4]) {
          await areas.archiveArea(id);
        }
      });
      await pump(tester, path: '/home/manage-areas/1/remove');
      expect(find.textContaining('No other active area'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Review move all and delete'),
            )
            .onPressed,
        isNull,
      );
      router.go('/home/manage-areas/999/remove');
      await settleDatabase(tester);
      expect(find.textContaining('This area is unavailable'), findsOneWidget);
      await tap(tester, 'Manage areas');
      expect(
        router.routeInformationProvider.value.uri.path,
        '/home/manage-areas',
      );
    },
  );

  screenTest(
    '320dp 200 percent reduced-motion name and confirmation remain usable',
    (tester) async {
      await pump(tester, scale: 2);
      expect(find.bySemanticsLabel(RegExp('Manage Kitchen')), findsWidgets);
      await snapshot(tester, 'manage-320-200');
      await manage(tester, 'Kitchen');
      await tap(tester, 'Rename area');
      await tester.enterText(
        find.byKey(const Key('area-name')),
        'Accessible kitchen',
      );
      await tester.pumpAndSettle();
      await tester.showKeyboard(find.byKey(const Key('area-name')));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(Focus.of(tester.element(find.text('Save area'))).hasFocus, isTrue);
      await snapshot(tester, 'rename-320-200');
      await tap(tester, 'Save area');
      router.go('/home/manage-areas/4/remove');
      await settleDatabase(tester);
      await tap(tester, 'Review deletion');
      await snapshot(tester, 'delete-320-200');
      final cancel = find.widgetWithText(OutlinedButton, 'Cancel');
      await tester.ensureVisible(cancel);
      expect(tester.getSize(cancel).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
      await tap(tester, 'Cancel');
      expect(
        (await tester.runAsync(() => areas.getAreaById(4)))!.isSuccess,
        isTrue,
      );
    },
  );

  screenTest(
    'W37 Reorder areas action reveals and focuses the existing controls',
    (tester) async {
      await pump(tester);
      await manage(tester, 'Kitchen');
      await tap(tester, 'Reorder areas');
      expect(
        find.text('Reorder areas using Move up and Move down.'),
        findsOneWidget,
      );
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'Area reorder controls',
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Move Kitchen up'),
            )
            .onPressed,
        isNull,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        Focus.of(tester.element(find.text('Move Kitchen down'))).hasFocus,
        isTrue,
      );
      await tap(tester, 'Move Kitchen down');
      expect(
        (await tester.runAsync(() => areas.getAreas()))!.valueOrNull!
            .map((a) => a.id),
        [2, 1, 3, 4],
      );
    },
  );

  for (final count in [0, 1, 2]) {
    screenTest(
      'combined W46 sheet uses correct grammar for $count archived items',
      (tester) async {
        await tester.runAsync(() async {
          if (count == 0) await items.restoreItem(archivedId);
          if (count == 2) await items.archiveItem(activeId);
          await areas.archiveArea(4);
        });
        await pump(tester, path: '/home/manage-areas/1/remove');
        expect(find.byType(DropdownButtonFormField<int>), findsNothing);
        await tap(tester, 'Review move all and delete');
        final sheet = find.byType(BottomSheet);
        final dropdown = find.byType(DropdownButtonFormField<int>);
        expect(find.descendant(of: sheet, matching: dropdown), findsOneWidget);
        final choices = tester
            .widget<DropdownButton<int>>(
              find.descendant(
                of: dropdown,
                matching: find.byType(DropdownButton<int>),
              ),
            )
            .items!;
        expect(choices.map((item) => item.value), [2, 3]);
        expect(
          find.text(
            '$count archived ${count == 1 ? 'item' : 'items'} included.',
          ),
          findsOneWidget,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Move all and delete area'),
              )
              .onPressed,
          isNull,
        );
        await destination(tester);
        expect(
          find.textContaining('to Bathroom, then delete Kitchen'),
          findsOneWidget,
        );
        await tap(tester, 'Cancel');
        expect(
          (await tester.runAsync(() => items.getItemById(activeId)))!
              .valueOrNull!
              .areaId,
          1,
        );
      },
    );
  }

  screenTest(
    'combined W46 sheet remains usable at 320dp/200 percent and loses invalid destinations',
    (tester) async {
      await pump(tester, path: '/home/manage-areas/1/remove', scale: 2);
      await tap(tester, 'Review move all and delete');
      final dropdown = find.byType(DropdownButtonFormField<int>);
      if (dropdown.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          dropdown,
          160,
          scrollable: find.byType(Scrollable).last,
        );
      }
      await destination(tester);
      await snapshot(tester, 'w46-combined-320-200');
      final mutation = areas.archiveArea(2);
      await settleDatabase(tester);
      await mutation;
      final confirm = find.widgetWithText(
        FilledButton,
        'Move all and delete area',
      );
      await tester.ensureVisible(confirm);
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tap(tester, 'Cancel');
      expect(
        (await tester.runAsync(() => areas.getAreaById(1)))!.isSuccess,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  screenTest('idle create/rename backdrop and Back dismiss without writes', (
    tester,
  ) async {
    await pump(tester);
    await tap(tester, 'Add custom area');
    await tester.enterText(
      find.byKey(const Key('area-name')),
      'Unsaved studio',
    );
    var route = ModalRoute.of(
      tester.element(find.byKey(const Key('area-name'))),
    )!;
    expect(route.barrierDismissible, isTrue);
    await tester.tapAt(const Offset(6, 6));
    await settleDatabase(tester);
    expect(find.byKey(const Key('area-name')), findsNothing);
    expect(
      (await tester.runAsync(() => areas.getAreas()))!.valueOrNull,
      hasLength(4),
    );
    await manage(tester, 'Kitchen');
    await tap(tester, 'Rename area');
    await tester.enterText(find.byKey(const Key('area-name')), 'Unsaved name');
    route = ModalRoute.of(tester.element(find.byKey(const Key('area-name'))))!;
    expect(route.barrierDismissible, isTrue);
    await tester.binding.handlePopRoute();
    await settleDatabase(tester);
    expect(find.byKey(const Key('area-name')), findsNothing);
    expect(
      (await tester.runAsync(() => areas.getAreaById(1)))!.valueOrNull!.name,
      'Kitchen',
    );
  });

  for (final creating in [true, false]) {
    screenTest(
      'pending ${creating ? 'create' : 'rename'} blocks backdrop/Back/duplicates and retains failed input',
      (tester) async {
        await pump(tester);
        if (creating) {
          await tap(tester, 'Add custom area');
        } else {
          await manage(tester, 'Kitchen');
          await tap(tester, 'Rename area');
        }
        await tester.enterText(
          find.byKey(const Key('area-name')),
          'Retained draft',
        );
        areas.gate = Completer<void>();
        areas.fail = true;
        await tester.tap(find.text('Save area'));
        await tester.pumpAndSettle();
        var route = ModalRoute.of(
          tester.element(find.byKey(const Key('area-name'))),
        )!;
        expect(route.barrierDismissible, isFalse);
        expect((route as ModalBottomSheetRoute).enableDrag, isFalse);
        final calls = areas.calls;
        await tester.tapAt(const Offset(6, 6));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('area-name')), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Save area'),
              )
              .onPressed,
          isNull,
        );
        expect(areas.calls, calls);
        areas.gate!.complete();
        await settleDatabase(tester);
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('area-name')))
              .controller!
              .text,
          'Retained draft',
        );
        expect(find.textContaining("Couldn't save this change"), findsWidgets);
        route = ModalRoute.of(
          tester.element(find.byKey(const Key('area-name'))),
        )!;
        expect(route.barrierDismissible, isTrue);
        areas.fail = false;
        areas.gate = null;
        await tap(tester, 'Save area');
        expect(find.byKey(const Key('area-name')), findsNothing);
        expect(areas.calls, calls + 1);
      },
    );
  }
}
