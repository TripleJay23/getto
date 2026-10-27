import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getto/app/app.dart';
import 'package:getto/app/composition/database_providers.dart';
import 'package:getto/app/routing/app_router.dart';
import 'package:getto/core/database/app_database.dart';
import 'package:getto/features/household/data/drift_area_repository.dart';
import 'package:getto/features/household/data/drift_item_repository.dart';
import 'package:getto/features/household/domain/behavior_profile.dart';
import 'package:getto/features/household/domain/stock_status.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// Opt-in QA only. Build in an isolated copy with a separately verified package.
/// Install explicitly and attach the driver; never use automatic install fallback.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('M2.3.4 correction journeys and separate-process restart', (
    tester,
  ) async {
    expect(const bool.fromEnvironment('M234_ISOLATED_QA'), isTrue);
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${documents.path}/m234_correction_verification',
    );
    final marker = File('${directory.path}/stage1.json');
    final file = File('${directory.path}/household.sqlite');
    final restart = await marker.exists();
    if (!restart) {
      expect(
        await file.exists(),
        isFalse,
        reason:
            'Refuse an existing failed fixture; never reset household data.',
      );
    }
    await directory.create(recursive: true);
    final db = AppDatabase(
      NativeDatabase.createInBackground(
        file,
        setup: (raw) {
          raw.execute('PRAGMA foreign_keys = ON;');
          raw.execute('PRAGMA journal_mode = WAL;');
          raw.execute('PRAGMA synchronous = FULL;');
        },
      ),
    );
    final areas = DriftAreaRepository(db);
    final items = DriftItemRepository(db);
    final router = createAppRouter(initialLocation: '/home');
    Future<void> settle() async {
      await tester.pumpAndSettle();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await tester.pumpAndSettle();
    }

    Future<void> tap(String label) async {
      if (find.byType(SnackBar).evaluate().isNotEmpty) {
        await Future<void>.delayed(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      }
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
      await settle();
    }

    Future<void> manage(int id) async {
      if (find.byType(SnackBar).evaluate().isNotEmpty) {
        await Future<void>.delayed(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      }
      final row = find.byKey(ValueKey('manage-area-$id'));
      final scroll = find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .last;
      if (row.evaluate().isEmpty) {
        await tester.drag(scroll, const Offset(0, 4000));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(row, 160, scrollable: scroll);
      }
      final target = find.descendant(of: row, matching: find.text('Manage'));
      await Scrollable.ensureVisible(tester.element(target), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await settle();
    }

    Future<void> enter(String text) async {
      await tester.enterText(find.byKey(const Key('area-name')), text);
      FocusManager.instance.primaryFocus?.unfocus();
      await settle();
    }

    Future<void> capture(String phase) async {
      if (!const bool.fromEnvironment('M234_HOST_CAPTURE')) return;
      await File('${directory.path}/phase.txt')
          .writeAsString(phase, flush: true);
      final ack = File('${directory.path}/ack-$phase');
      for (var attempt = 0; attempt < 90 && !await ack.exists(); attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      expect(
        await ack.exists(),
        isTrue,
        reason: 'Host capture was not acknowledged.',
      );
    }

    Future<void> selectDestination() async {
      final dropdown = find.byType(DropdownButtonFormField<int>);
      if (dropdown.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          dropdown,
          160,
          scrollable: find
              .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              )
              .last,
        );
      }
      expect(
        find.descendant(of: find.byType(BottomSheet), matching: dropdown),
        findsOneWidget,
      );
      await Scrollable.ensureVisible(tester.element(dropdown), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bathroom').last);
      await settle();
    }

    try {
      int active;
      int archived;
      if (!restart) {
        active = (await items.createItem(
          areaId: 1,
          name: 'QA active',
          behaviorProfile: BehaviorProfile.countableReplenishable,
          stockStatus: StockStatus.inStock,
          packageCount: 8,
          notes: 'Preserved QA facts',
        )).valueOrNull!.id;
        archived = (await items.createItem(
          areaId: 1,
          name: 'QA archived',
          behaviorProfile: BehaviorProfile.durable,
          stockStatus: StockStatus.inStock,
        )).valueOrNull!.id;
        await items.archiveItem(archived);
      } else {
        final saved =
            jsonDecode(await marker.readAsString()) as Map<String, dynamic>;
        active = saved['active'] as int;
        archived = saved['archived'] as int;
        final catalog = (await areas.getAreas(includeArchived: true))
            .valueOrNull!;
        expect([
          for (final a in catalog) [a.id, a.name, a.displayOrder, a.isArchived],
        ], saved['catalog']);
        expect((await areas.getAreaById(1)).isFailure, isTrue);
        expect((await areas.getAreaById(3)).isFailure, isTrue);
        expect((await items.getItemById(active)).valueOrNull!.areaId, 2);
        expect((await items.getItemById(active)).valueOrNull!.packageCount, 8);
        expect(
          (await items.getItemById(archived)).valueOrNull!.isArchived,
          isTrue,
        );
        expect((await items.restoreItem(archived)).valueOrNull!.areaId, 2);
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      }
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: GettoApp(router: router),
        ),
      );
      await settle();
      if (!restart) {
        await tester.tap(find.byTooltip('More home options'));
        await tester.pumpAndSettle();
        await tap('Manage areas');
        await tap('Add custom area');
        await enter('Unsaved QA area');
        final sheetTop = tester.getTopLeft(find.byType(BottomSheet)).dy;
        expect(sheetTop, greaterThan(40));
        await tester.tapAt(Offset(8, sheetTop / 2));
        await settle();
        expect(find.byKey(const Key('area-name')), findsNothing);
        expect((await areas.getAreas()).valueOrNull, hasLength(4));
        await manage(1);
        await tap('Rename area');
        await enter('Unsaved QA name');
        if (const bool.fromEnvironment('M234_HOST_CAPTURE')) {
          await capture('rename-back-ready');
        } else {
          await tester.binding.handlePopRoute();
        }
        await settle();
        expect(find.byKey(const Key('area-name')), findsNothing);
        expect((await areas.getAreaById(1)).valueOrNull!.name, 'Kitchen');
        await manage(1);
        await tap('Rename area');
        await enter('QA kitchen');
        await tap('Save area');
        await manage(1);
        await tap('Reorder areas');
        expect(
          FocusManager.instance.primaryFocus?.debugLabel,
          'Area reorder controls',
        );
        if (find
            .text('Reorder areas using Move up and Move down.')
            .evaluate()
            .isEmpty) {
          await tester.drag(
            find
                .byWidgetPredicate(
                  (w) =>
                      w is Scrollable && w.axisDirection == AxisDirection.down,
                )
                .last,
            const Offset(0, 2000),
          );
          await settle();
        }
        expect(
          find.text('Reorder areas using Move up and Move down.'),
          findsOneWidget,
        );
        await capture('w37-reorder-ready');
        await tap('Move QA kitchen down');
        await manage(1);
        await tap('Archive area');
        await tap('Archive area');
        router.go('/home');
        await settle();
        expect(find.text('QA active'), findsOneWidget);
        router.go('/home/manage-areas');
        await settle();
        await manage(1);
        await tap('Restore area');
        await tap('Add custom area');
        await enter('QA studio');
        await tap('Save area');
        await manage(4);
        await tap('Archive area');
        await tap('Archive area');
        router.go('/home/manage-areas/3/remove');
        await settle();
        await tap('Review deletion');
        await tap('Cancel');
        expect((await areas.getAreaById(3)).isSuccess, isTrue);
        await tap('Review deletion');
        await tap('Delete empty area');
        router.go('/home/manage-areas/1/remove');
        await settle();
        expect(find.byType(DropdownButtonFormField<int>), findsNothing);
        await tap('Review move all and delete');
        await selectDestination();
        expect(find.text('1 archived item included.'), findsOneWidget);
        await tap('Cancel');
        expect((await areas.getAreaById(1)).isSuccess, isTrue);
        expect((await items.getItemById(active)).valueOrNull!.areaId, 1);
        await tap('Review move all and delete');
        await selectDestination();
        await capture('w46-ready');
        await tap('Move all and delete area');
        expect((await items.getItemById(active)).valueOrNull!.areaId, 2);
        expect((await items.getItemById(active)).valueOrNull!.packageCount, 8);
        expect(
          (await items.getItemById(active)).valueOrNull!.notes,
          'Preserved QA facts',
        );
        expect((await items.getItemById(archived)).valueOrNull!.areaId, 2);
        expect(
          (await items.getItemById(archived)).valueOrNull!.isArchived,
          isTrue,
        );
        final catalog = (await areas.getAreas(includeArchived: true))
            .valueOrNull!;
        await marker.writeAsString(
          jsonEncode({
            'active': active,
            'archived': archived,
            'catalog': [
              for (final a in catalog)
                [a.id, a.name, a.displayOrder, a.isArchived],
            ],
          }),
          flush: true,
        );
        debugPrint(
          'M234_CORRECTION_STAGE1_PASS: reorder action, idle backdrop/native Back, combined W46 destination/confirmation, singular grammar, archive/restore and atomic relocation',
        );
      } else {
        expect(find.text('QA active'), findsOneWidget);
        expect(find.text('QA archived'), findsOneWidget);
        await capture('restart-ready');
        debugPrint(
          'M234_CORRECTION_RESTART_PASS: separate process, saved catalog/order/archive flags, deleted defaults absent, item destination/facts retained',
        );
      }
      await File('${directory.path}/phase.txt')
          .writeAsString(restart ? 'restart-pass' : 'stage1-pass', flush: true);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await db.close();
      router.dispose();
    }
  });
}
