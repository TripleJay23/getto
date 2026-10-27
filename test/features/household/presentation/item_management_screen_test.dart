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
import 'package:getto/design_system/components/getto_item_row.dart';
import 'package:getto/features/household/data/drift_area_repository.dart';
import 'package:getto/features/household/data/drift_item_repository.dart';
import 'package:getto/features/household/domain/behavior_profile.dart';
import 'package:getto/features/household/domain/item.dart';
import 'package:getto/features/household/domain/stock_status.dart';
import 'package:go_router/go_router.dart';

import 'home_onboarding_test.dart' show settleDatabase, tapLabel;
import 'item_management_controller_test.dart' show ControlledManagementItems;

Future<T> io<T extends Object>(
  WidgetTester tester,
  Future<T> Function() action,
) async => (await tester.runAsync(action))!;

Future<void> tapAction(WidgetTester tester, String label) async {
  await tester.pumpAndSettle();
  if (find.text(label).evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text(label),
      180,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .last,
    );
  }
  await tapLabel(tester, label);
}

void main() {
  late AppDatabase db;
  late ControlledManagementItems items;
  late Item item;
  late GoRouter router;
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
    items = ControlledManagementItems(db);
    item = (await items.createItem(
      areaId: 1,
      name: 'Coffee',
      behaviorProfile: BehaviorProfile.countableReplenishable,
      stockStatus: StockStatus.inStock,
      unit: 'bags',
    )).valueOrNull!;
  });
  void screenTest(
    String description,
    Future<void> Function(WidgetTester) body,
  ) {
    testWidgets(description, (tester) async {
      try {
        await body(tester);
      } finally {
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
    String? path,
    double width = 430,
    double scale = 1,
    bool reduceMotion = false,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: reduceMotion);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    });
    router = createAppRouter(initialLocation: path ?? '/home/items/${item.id}');
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('capture'),
        child: ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            itemRepositoryProvider.overrideWithValue(items),
          ],
          child: GettoApp(router: router),
        ),
      ),
    );
    await settleDatabase(tester);
  }

  Future<void> snapshot(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('capture')),
      );
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final directory = Directory('build/m233/screens');
      await directory.create(recursive: true);
      await File('${directory.path}/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
    });
  }

  for (final profile in BehaviorProfile.values) {
    screenTest(
      'archived $profile detail is readable and restore-first while deletion remains available',
      (tester) async {
        await tester.runAsync(() async {
          await items.updateItem(item.copyWith(behaviorProfile: profile));
          await items.archiveItem(item.id);
        });
        await pump(tester);
        expect(find.text('Coffee'), findsOneWidget);
        expect(find.text('Edit or move'), findsNothing);
        expect(find.text('Set current count'), findsNothing);
        expect(find.text('Correct presence'), findsNothing);
        expect(
          find.textContaining('Restore this item to edit'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Restore item'),
              )
              .onPressed,
          isNotNull,
        );
        await tester.tap(find.byTooltip('Item options'));
        await tester.pumpAndSettle();
        await tapAction(tester, 'Delete permanently');
        expect(find.text('Delete Coffee?'), findsOneWidget);
        await tapAction(tester, 'Cancel');
        expect(
          (await io(
            tester,
            () => items.getItemById(item.id),
          )).valueOrNull!.isArchived,
          isTrue,
        );
      },
    );
  }
  screenTest(
    'direct archived edit route is gated; restore retains current area/facts and re-enables edit and correction',
    (tester) async {
      await tester.runAsync(() async {
        final archived = (await items.archiveItem(item.id)).valueOrNull!;
        await items.updateMetadata(
          expected: archived,
          name: archived.name,
          areaId: 2,
          unit: 'box',
        );
        await items.updatePackageCount(itemId: item.id, newPackageCount: 4);
      });
      await pump(tester, path: '/home/items/${item.id}/edit');
      expect(find.byKey(const Key('edit-name')), findsNothing);
      expect(find.text('Save changes'), findsNothing);
      await tapAction(tester, 'View item');
      await tapAction(tester, 'Restore item');
      expect(find.textContaining('currently saved area'), findsOneWidget);
      await tapAction(tester, 'Restore item');
      final restored = (await io(
        tester,
        () => items.getItemById(item.id),
      )).valueOrNull!;
      expect(restored.areaId, 2);
      expect(restored.unit, 'box');
      expect(restored.packageCount, 4);
      await tapAction(tester, 'Edit or move');
      await tester.enterText(
        find.byKey(const Key('edit-name')),
        'Restored coffee',
      );
      await tapAction(tester, 'Save changes');
      await tapAction(tester, 'Set current count');
      await tester.enterText(find.byKey(const Key('correction-count')), '0');
      await tapAction(tester, 'Save count');
      expect(
        (await io(
          tester,
          () => items.getItemById(item.id),
        )).valueOrNull!.stockStatus,
        StockStatus.outOfStock,
      );
    },
  );
  screenTest(
    'open edit draft survives external archival and restoration without an archived write',
    (tester) async {
      await pump(tester, path: '/home/items/${item.id}/edit');
      await tester.enterText(
        find.byKey(const Key('edit-name')),
        'My retained draft',
      );
      await tester.runAsync(() => items.archiveItem(item.id));
      await settleDatabase(tester);
      expect(find.text('Archived item'), findsOneWidget);
      expect(find.text('Save changes'), findsNothing);
      expect(
        (await io(tester, () => items.getItemById(item.id))).valueOrNull!.name,
        'Coffee',
      );
      await tester.runAsync(() => items.restoreItem(item.id));
      await settleDatabase(tester);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('edit-name')))
            .controller!
            .text,
        'My retained draft',
      );
      await tapAction(tester, 'Save changes');
      expect(
        (await io(tester, () => items.getItemById(item.id))).valueOrNull!.name,
        'My retained draft',
      );
    },
  );
  screenTest(
    'open correction becomes read-only on external archival and retains input',
    (tester) async {
      await pump(tester);
      await tapAction(tester, 'Set current count');
      await tester.enterText(find.byKey(const Key('correction-count')), '6');
      await tester.runAsync(() => items.archiveItem(item.id));
      await settleDatabase(tester);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('correction-count')))
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('correction-count')))
            .controller!
            .text,
        '6',
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save count'),
            )
            .onPressed,
        isNull,
      );
      await tapAction(tester, 'Cancel');
      expect(
        (await io(
          tester,
          () => items.getItemById(item.id),
        )).valueOrNull!.packageCount,
        isNull,
      );
    },
  );
  for (final operation in ['metadata', 'count', 'presence']) {
    screenTest(
      'pending $operation UI write cannot commit after external archival',
      (tester) async {
        if (operation == 'presence') {
          await tester.runAsync(
            () => items.updateItem(
              item.copyWith(behaviorProfile: BehaviorProfile.durable),
            ),
          );
        }
        await pump(
          tester,
          path: operation == 'metadata' ? '/home/items/${item.id}/edit' : null,
        );
        if (operation == 'metadata') {
          await tester.enterText(
            find.byKey(const Key('edit-name')),
            'Must not save',
          );
        } else {
          await tapAction(
            tester,
            operation == 'count' ? 'Set current count' : 'Correct presence',
          );
          if (operation == 'count') {
            await tester.enterText(
              find.byKey(const Key('correction-count')),
              '9',
            );
          } else {
            await tapAction(tester, 'Not at home');
          }
        }
        await tester.pumpAndSettle();
        items.gate = Completer<void>();
        final label = operation == 'metadata'
            ? 'Save changes'
            : operation == 'count'
            ? 'Save count'
            : 'Save presence';
        await tester.ensureVisible(find.widgetWithText(FilledButton, label));
        await tester.tap(find.widgetWithText(FilledButton, label));
        await tester.pumpAndSettle();
        final archived = (await io(
          tester,
          () => DriftItemRepository(db).archiveItem(item.id),
        )).valueOrNull!;
        items.gate!.complete();
        await settleDatabase(tester);
        expect(
          (await io(tester, () => items.getItemById(item.id))).valueOrNull,
          archived,
        );
        expect(find.textContaining('Restore'), findsWidgets);
        expect(find.text('Item details saved.'), findsNothing);
        expect(find.text('Current availability saved.'), findsNothing);
      },
    );
  }

  screenTest(
    'Home row opens stable ID, detail and edit keep branch/back state and persist metadata',
    (tester) async {
      await pump(tester, path: '/home');
      await tester.tap(find.byType(GettoItemRow));
      await settleDatabase(tester);
      expect(router.state.pathParameters['itemId'], '${item.id}');
      expect(find.text('Current count unknown'), findsOneWidget);
      await snapshot(tester, 'detail-430');
      await tapAction(tester, 'Edit or move');
      await snapshot(tester, 'edit-430');
      await tester.enterText(find.byKey(const Key('edit-name')), '  Beans  ');
      await tester.enterText(find.byKey(const Key('edit-unit')), '');
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tapAction(tester, 'Bathroom');
      await tapAction(tester, 'Save changes');
      final saved = (await io(
        tester,
        () => items.getItemById(item.id),
      )).valueOrNull!;
      expect(saved.name, 'Beans');
      expect(saved.areaId, 2);
      expect(saved.unit, isNull);
      expect(saved.packageCount, isNull);
      await tapAction(tester, 'Buy');
      await tapAction(tester, 'Home');
      expect(find.text('Beans'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await settleDatabase(tester);
      expect(find.text('Beans'), findsOneWidget);
    },
  );
  screenTest(
    'archive removes Home/search and restore in archived area returns to All',
    (tester) async {
      await pump(tester, path: '/home');
      await tester.enterText(find.byKey(const Key('home-search')), 'Coffee');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settleDatabase(tester);
      await tester.tap(find.byType(GettoItemRow));
      await settleDatabase(tester);
      await tapAction(tester, 'Archive item');
      expect(find.textContaining('Archived items leave Home'), findsOneWidget);
      await tapAction(tester, 'Archive item');
      await tester.tap(find.byTooltip('Back'));
      await settleDatabase(tester);
      expect(find.text('No matching items'), findsOneWidget);
      await tester.tap(find.byTooltip('More home options'));
      await tester.pumpAndSettle();
      await tapAction(tester, 'Archived items');
      await snapshot(tester, 'archived-430');
      await tester.runAsync(() => DriftAreaRepository(db).archiveArea(1));
      await settleDatabase(tester);
      await tester.tap(find.byType(GettoItemRow));
      await settleDatabase(tester);
      await tapAction(tester, 'Restore item');
      await tapAction(tester, 'Restore item');
      expect(
        (await io(
          tester,
          () => items.getItemById(item.id),
        )).valueOrNull!.areaId,
        1,
      );
      router.go('/home');
      await settleDatabase(tester);
      expect(find.widgetWithText(GettoItemRow, 'Coffee'), findsOneWidget);
      expect(find.text('1 item in your home'), findsOneWidget);
    },
  );
  screenTest(
    'unknown count requires explicit input; zero and positive counts reconcile facts',
    (tester) async {
      await pump(tester);
      await tapAction(tester, 'Set current count');
      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save count'),
      );
      expect(save.onPressed, isNull);
      expect(find.textContaining('Count unknown.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('correction-count')), '0');
      await tapAction(tester, 'Save count');
      expect(
        (await io(
          tester,
          () => items.getItemById(item.id),
        )).valueOrNull!.stockStatus,
        StockStatus.outOfStock,
      );
      await tapAction(tester, 'Set current count');
      await tester.enterText(find.byKey(const Key('correction-count')), '8');
      await tapAction(tester, 'Save count');
      expect(
        (await io(
          tester,
          () => items.getItemById(item.id),
        )).valueOrNull!.packageCount,
        8,
      );
      expect(
        (await io(
          tester,
          () => items.getItemById(item.id),
        )).valueOrNull!.stockStatus,
        StockStatus.inStock,
      );
    },
  );
  for (final profile in [
    BehaviorProfile.replenishable,
    BehaviorProfile.durable,
  ]) {
    screenTest('$profile corrects presence without inventing a count', (
      tester,
    ) async {
      await tester.runAsync(
        () => items.updateItem(item.copyWith(behaviorProfile: profile)),
      );
      await pump(tester);
      await tapAction(tester, 'Correct presence');
      await tapAction(tester, 'Not at home');
      await tapAction(tester, 'Save presence');
      final saved = (await io(
        tester,
        () => items.getItemById(item.id),
      )).valueOrNull!;
      expect(saved.stockStatus, StockStatus.outOfStock);
      expect(saved.packageCount, isNull);
    });
  }
  screenTest(
    'edit failure retains input, stale metadata requires review and retry',
    (tester) async {
      await pump(tester, path: '/home/items/${item.id}/edit');
      await tester.enterText(find.byKey(const Key('edit-name')), 'My draft');
      items.fail = true;
      await tapAction(tester, 'Save changes');
      expect(find.textContaining("Couldn't save this change."), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('edit-name')))
            .controller!
            .text,
        'My draft',
      );
      items.fail = false;
      await tester.runAsync(
        () => items.updateMetadata(
          expected: item,
          name: 'Newer name',
          areaId: 2,
          unit: 'box',
        ),
      );
      await settleDatabase(tester);
      await tapAction(tester, 'Save changes');
      expect(
        find.textContaining('Latest saved details: Newer name'),
        findsOneWidget,
      );
      await tapAction(tester, 'Use latest saved version with my draft');
      await tapAction(tester, 'Save changes');
      expect(
        (await io(tester, () => items.getItemById(item.id))).valueOrNull!.name,
        'My draft',
      );
    },
  );
  screenTest(
    'named permanent deletion supports cancel and failure recovery before removing row',
    (tester) async {
      await pump(tester);
      Future<void> open() async {
        await tester.tap(find.byTooltip('Item options'));
        await tester.pumpAndSettle();
        await tapAction(tester, 'Delete permanently');
      }

      await open();
      expect(find.text('Delete Coffee?'), findsOneWidget);
      await snapshot(tester, 'delete-430');
      await tapAction(tester, 'Cancel');
      expect(
        (await io(tester, () => items.getItemById(item.id))).isSuccess,
        isTrue,
      );
      await open();
      items.fail = true;
      await tapAction(tester, 'Delete permanently');
      expect(find.textContaining("Couldn't save this change."), findsOneWidget);
      items.fail = false;
      await tapAction(tester, 'Delete permanently');
      expect(router.routeInformationProvider.value.uri.path, '/home');
      expect(
        (await io(tester, () => items.getItemById(item.id))).isFailure,
        isTrue,
      );
    },
  );
  screenTest('missing item and external deletion offer safe Home recovery', (
    tester,
  ) async {
    await pump(tester);
    await tester.runAsync(() => items.deleteItem(item.id));
    await settleDatabase(tester);
    expect(find.text('Item unavailable'), findsOneWidget);
    await tapAction(tester, 'Return to Home');
    router.go('/home/items/999999');
    await settleDatabase(tester);
    expect(find.text('Item unavailable'), findsOneWidget);
  });
  screenTest(
    'commands block duplicate confirmation and Back until persistence completes',
    (tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('Item options'));
      await tester.pumpAndSettle();
      await tapAction(tester, 'Delete permanently');
      items.gate = Completer<void>();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete permanently'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Cancel'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Saving…'))
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Delete Coffee?'), findsOneWidget);
      expect(items.calls, 1);
      items.gate!.complete();
      await settleDatabase(tester);
      expect(
        (await io(tester, () => items.getItemById(item.id))).isFailure,
        isTrue,
      );
      expect(find.byKey(const Key('getto-home-page')), findsOneWidget);
    },
  );
  screenTest('detail and delete dialog expose labeled Android touch targets', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await pump(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await tester.tap(find.byTooltip('Item options'));
      await tester.pumpAndSettle();
      await tapAction(tester, 'Delete permanently');
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await tapAction(tester, 'Cancel');
    } finally {
      semantics.dispose();
    }
  });
  for (final scale in [1.0, 2.0]) {
    screenTest(
      '320dp at ${scale * 100}% with reduced motion exposes usable edit, correction and delete actions',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await pump(tester, width: 320, scale: scale, reduceMotion: true);
        expect(tester.takeException(), isNull);
        await tapAction(tester, 'Edit or move');
        await tester.enterText(find.byKey(const Key('edit-name')), 'Coffee');
        await snapshot(tester, 'edit-320-${scale.toInt()}');
        await tapAction(tester, 'Save changes');
        expect(tester.takeException(), isNull);
        await tapAction(tester, 'Set current count');
        await tester.enterText(find.byKey(const Key('correction-count')), '8');
        await tapAction(tester, 'Save count');
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byTooltip('Item options'));
        await tester.tap(find.byTooltip('Item options'));
        await tester.pumpAndSettle();
        await tapAction(tester, 'Delete permanently');
        await snapshot(tester, 'delete-320-${scale.toInt()}');
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(
          find.widgetWithText(OutlinedButton, 'Cancel'),
        );
        expect(
          tester.getSize(find.widgetWithText(OutlinedButton, 'Cancel')).height,
          greaterThanOrEqualTo(48),
        );
        await tapAction(tester, 'Cancel');
        semantics.dispose();
      },
    );
  }
}
