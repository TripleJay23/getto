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
import 'package:getto/design_system/components/getto_item_row.dart';
import 'package:getto/features/household/data/drift_item_repository.dart';
import 'package:getto/features/household/domain/behavior_profile.dart';
import 'package:getto/features/household/domain/stock_status.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// Build only with a distinct, inspected QA applicationId. Install explicitly;
/// attach the driver without Flutter's automatic installation/uninstall fallback.
/// A second process runs the restart assertions against the same fixture.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('M2.3.3 isolated Android management and restart', (tester) async {
    expect(
      const bool.fromEnvironment('M233_ISOLATED_QA'),
      isTrue,
      reason: 'Requires the independently identified QA APK and host protocol.',
    );
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory('${documents.path}/m233_a01_verification');
    final file = File('${directory.path}/household.sqlite');
    final marker = File('${directory.path}/stage1.json');
    final restart = await marker.exists();
    if (!restart) {
      expect(
        await file.exists(),
        isFalse,
        reason: 'Do not reset a failed or existing fixture.',
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
    final items = DriftItemRepository(db);
    final router = createAppRouter(initialLocation: '/home');
    Future<void> settle() async {
      await tester.pumpAndSettle();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await tester.pumpAndSettle();
    }

    Future<void> until(bool Function() ready, String reason) async {
      for (var attempt = 0; attempt < 120; attempt++) {
        if (ready()) return;
        await tester.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
      fail(reason);
    }

    Future<void> phase(String value, {bool acknowledge = false}) async {
      await File('${directory.path}/phase.txt')
          .writeAsString(value, flush: true);
      debugPrint('M233_QA_PHASE:$value');
      if (acknowledge) {
        final ack = File('${directory.path}/ack-$value');
        for (var i = 0; i < 120 && !await ack.exists(); i++) {
          await tester.pump(const Duration(milliseconds: 100));
          await Future<void>.delayed(const Duration(milliseconds: 150));
        }
        expect(
          await ack.exists(),
          isTrue,
          reason: 'Host did not acknowledge $value',
        );
      }
    }

    Future<void> tap(String label) async {
      await tester.pumpAndSettle();
      // On hardware, a success snackbar can cover a scrolled action. Wait for
      // its real dismissal rather than tapping through the overlay.
      if (find.byType(SnackBar).evaluate().isNotEmpty) {
        await Future<void>.delayed(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      }
      final text = find.text(label);
      if (text.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          text,
          160,
          scrollable: find
              .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              )
              .last,
        );
      }
      final buttons = find.ancestor(
        of: text,
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      final target = buttons.evaluate().isEmpty ? text.last : buttons.last;
      await tester.ensureVisible(target);
      await until(
        () => target.hitTestable().evaluate().isNotEmpty,
        'Action remained obscured: $label',
      );
      await tester.tap(target);
      await settle();
    }

    Future<void> enter(Key key, String text) async {
      final target = find.byKey(key);
      await tester.ensureVisible(target);
      await tester.enterText(target, text);
      await settle();
    }

    Future<void> home() async {
      router.go('/home');
      await settle();
    }

    Future<void> open(String name) async {
      await home();
      final row = find.widgetWithText(GettoItemRow, name);
      await until(
        () => row.evaluate().isNotEmpty,
        'Saved Home row did not appear: $name',
      );
      await tester.ensureVisible(row);
      await until(
        () => row.hitTestable().evaluate().isNotEmpty,
        'Home row remained obscured: $name',
      );
      await tester.tap(row);
      await settle();
    }

    Future<void> deleteDialog() async {
      await tester.tap(find.byTooltip('Item options'));
      await settle();
      await tap('Delete permanently');
    }

    tester.testTextInput.register();
    try {
      if (!restart) {
        for (final entry in [
          ('QA count', BehaviorProfile.countableReplenishable),
          ('QA single', BehaviorProfile.replenishable),
          ('QA durable', BehaviorProfile.durable),
          ('QA delete', BehaviorProfile.durable),
        ]) {
          expect(
            (await items.createItem(
              areaId: 1,
              name: entry.$1,
              behaviorProfile: entry.$2,
              stockStatus: StockStatus.inStock,
              unit: entry.$1 == 'QA count' ? 'box' : null,
            )).isSuccess,
            isTrue,
          );
        }
      }
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: GettoApp(router: router),
        ),
      );
      await settle();
      if (restart) {
        final saved = (await items.getAllItems(includeArchived: true))
            .valueOrNull!;
        expect(saved, hasLength(3));
        final count = saved.singleWhere((i) => i.name == 'QA renamed');
        final expected =
            jsonDecode(await marker.readAsString()) as Map<String, dynamic>;
        expect(count.id, expected['id']);
        expect(count.areaId, 2);
        expect(count.unit, isNull);
        expect(count.packageCount, 8);
        expect(count.stockStatus, StockStatus.inStock);
        expect(count.isArchived, isFalse);
        for (final name in ['QA single', 'QA durable']) {
          final item = saved.singleWhere((i) => i.name == name);
          expect(item.packageCount, isNull);
          expect(item.stockStatus, StockStatus.inStock);
        }
        expect(find.text('QA renamed'), findsOneWidget);
        await phase('restart-verified', acknowledge: true);
        debugPrint(
          'M233_RESTART_PASS: same IDs, area, cleared context, count/presence and deletion after process restart',
        );
      } else {
        await open('QA count');
        await tap('Edit or move');
        await enter(const Key('edit-name'), 'QA renamed');
        await enter(const Key('edit-unit'), '');
        await tester.tap(find.byType(DropdownButtonFormField<int>));
        await settle();
        await tap('Bathroom');
        await tap('Save changes');
        var count = (await items.getAllItems()).valueOrNull!.singleWhere(
          (i) => i.name == 'QA renamed',
        );
        expect(count.areaId, 2);
        expect(count.unit, isNull);
        expect(count.packageCount, isNull);
        await tap('Set current count');
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('correction-count')))
              .controller!
              .text,
          '',
        );
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Save count'),
              )
              .onPressed,
          isNull,
        );
        await enter(const Key('correction-count'), '0');
        await tap('Save count');
        expect(
          (await items.getItemById(count.id)).valueOrNull!.stockStatus,
          StockStatus.outOfStock,
        );
        await tap('Set current count');
        await enter(const Key('correction-count'), '8');
        await tap('Save count');
        await tap('Archive item');
        await tap('Archive item');
        await home();
        expect(find.text('QA renamed'), findsNothing);
        await tester.tap(find.byTooltip('More home options'));
        await settle();
        await tap('Archived items');
        await tester.tap(find.widgetWithText(GettoItemRow, 'QA renamed'));
        await settle();
        expect(find.text('Edit or move'), findsNothing);
        expect(find.text('Set current count'), findsNothing);
        await phase('archived-read-only', acknowledge: true);
        router.push('/home/items/${count.id}/edit');
        await settle();
        expect(find.byKey(const Key('edit-name')), findsNothing);
        await tap('View item');
        await tap('Restore item');
        await tap('Restore item');
        count = (await items.getItemById(count.id)).valueOrNull!;
        expect(count.isArchived, isFalse);
        expect(count.areaId, 2);
        expect(count.packageCount, 8);
        expect(count.unit, isNull);
        for (final name in ['QA single', 'QA durable']) {
          await open(name);
          await tap('Correct presence');
          await tap('Not at home');
          await tap('Save presence');
          final absent = (await items.getAllItems()).valueOrNull!.singleWhere(
            (i) => i.name == name,
          );
          expect(absent.stockStatus, StockStatus.outOfStock);
          expect(absent.packageCount, isNull);
          await tap('Correct presence');
          await tap('In home');
          await tap('Save presence');
        }
        await open('QA delete');
        await deleteDialog();
        await tap('Cancel');
        expect(
          (await items.getAllItems()).valueOrNull!.any(
            (i) => i.name == 'QA delete',
          ),
          isTrue,
        );
        await deleteDialog();
        await tap('Delete permanently');
        expect(
          (await items.getAllItems()).valueOrNull!.any(
            (i) => i.name == 'QA delete',
          ),
          isFalse,
        );
        await open('QA renamed');
        await tap('Set current count');
        await enter(const Key('correction-count'), '99');
        await items.archiveItem(count.id);
        await settle();
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Save count'),
              )
              .onPressed,
          isNull,
        );
        await tap('Cancel');
        await tap('Restore item');
        await tap('Restore item');
        expect(
          (await items.getItemById(count.id)).valueOrNull!.packageCount,
          8,
        );

        // Verify real Android keyboard/back delivery separately from test text injection.
        await tap('Edit or move');
        FocusManager.instance.primaryFocus?.unfocus();
        await settle();
        tester.testTextInput.unregister();
        await tester.tap(find.byKey(const Key('edit-name')));
        await settle();
        await until(
          () => tester.view.viewInsets.bottom > 0,
          'Native keyboard did not open',
        );
        await phase('keyboard-visible');
        await until(
          () => tester.view.viewInsets.bottom == 0,
          'Host Android Back did not dismiss keyboard',
        );
        expect(find.byKey(const Key('edit-name')), findsOneWidget);
        await phase('native-back');
        await until(
          () => find.byKey(const Key('edit-name')).evaluate().isEmpty,
          'Native Android Back did not leave edit',
        );
        tester.testTextInput.register();
        await phase('scale-200');
        await until(
          () => tester.platformDispatcher.textScaleFactor >= 2,
          'Native 200% font scale did not arrive',
        );
        await settle();
        await tap('Edit or move');
        await tap('Save changes');
        await tap('Set current count');
        await enter(const Key('correction-count'), '8');
        await tap('Save count');
        await tap('Archive item');
        await tap('Archive item');
        expect(find.text('Edit or move'), findsNothing);
        await phase('archived-200', acknowledge: true);
        await tap('Restore item');
        await tap('Restore item');
        await deleteDialog();
        await phase('delete-200', acknowledge: true);
        await tap('Cancel');
        await home();
        expect(tester.takeException(), isNull);
        await marker.writeAsString(jsonEncode({'id': count.id}), flush: true);
        await phase('stage1-done', acknowledge: true);
        debugPrint(
          'M233_JOURNEYS_PASS: edit/move/clear, unknown/zero/positive, archive/read-only/restore, presence, delete/cancel, external archive, native keyboard/Back and 200%',
        );
      }
      expect(tester.takeException(), isNull);
    } finally {
      tester.testTextInput.unregister();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await db.close();
      router.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}
