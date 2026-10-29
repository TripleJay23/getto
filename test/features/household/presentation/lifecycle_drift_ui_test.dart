import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getto/app/app.dart';
import 'package:getto/app/composition/database_providers.dart';
import 'package:getto/app/composition/household_providers.dart';
import 'package:getto/app/composition/lifecycle_providers.dart';
import 'package:getto/app/routing/app_router.dart';
import 'package:getto/features/household/domain/behavior_profile.dart';
import 'package:getto/features/household/domain/item.dart';
import 'package:getto/features/household/domain/lifecycle_checkpoint.dart';
import 'package:getto/features/household/domain/stock_status.dart';
import 'package:getto/features/household/presentation/lifecycle_task_sheet.dart';
import 'package:go_router/go_router.dart';

import '../../../support/lifecycle_repository_fixture.dart';
import 'home_onboarding_test.dart' show settleDatabase;
import 'lifecycle_screen_test.dart' show lifecycleTap, enterDate;

void main() {
  late LifecycleFixture f;
  late Item item;
  GoRouter? router;
  setUp(() async {
    f = LifecycleFixture();
    item = await f.item(
      profile: BehaviorProfile.countableReplenishable,
      count: 3,
      name: 'Coffee',
    );
  });
  Future<T> io<T>(WidgetTester tester, Future<T> Function() action) async =>
      (await tester.runAsync(action)) as T;
  Future<void> pump(WidgetTester tester) async {
    router = createAppRouter(initialLocation: '/home/items/${item.id}');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(f.db),
          itemRepositoryProvider.overrideWithValue(f.items),
          lifecycleRepositoryProvider.overrideWithValue(f.lifecycle),
          localTodayProvider.overrideWithValue(() => currentDate),
        ],
        child: GettoApp(router: router!),
      ),
    );
    await settleDatabase(tester);
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await lifecycleTap(tester, label);
    await settleDatabase(tester);
  }

  void screen(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await tester.runAsync(f.db.close);
        router?.dispose();
        router = null;
      }
    });
  }

  for (final choice in [
    'Finished now',
    'Finished earlier',
    'Previous cycle was wrong',
  ]) {
    screen(
      'SQLite UI $choice replacement failure rolls back all facts; retained Retry commits once',
      (tester) async {
        final original = await io(tester, () => f.start(item, day: 20));
        await io(
          tester,
          () => f.lifecycle.addCheckpoint(
            expectedCycle: original.activeCycle!,
            kind: LifecycleCheckpointKind.aboutHalf,
            observedOn: date(23),
            today: currentDate,
          ),
        );
        final before = await io(tester, () => databaseFacts(f.db));
        await io(
          tester,
          () => f.db.customStatement(
            "CREATE TEMP TRIGGER m304_fail AFTER INSERT ON lifecycle_cycles BEGIN SELECT RAISE(ABORT,'synthetic write failure'); END",
          ),
        );
        await pump(tester);
        await tap(tester, 'Correct');
        await tap(tester, 'Restock');
        await tap(tester, choice);
        if (choice == 'Finished earlier') {
          await enterDate(tester, 'lifecycle-finish-date', '2026-10-26');
        }
        await enterDate(tester, 'lifecycle-count', '4');
        if (choice == 'Previous cycle was wrong') {
          await tap(
            tester,
            'I confirm removal of this observation and its progress notes',
          );
        }
        await tap(tester, 'Resolve and restock');
        expect(find.text('Not Saved'), findsOneWidget);
        expect(await io(tester, () => databaseFacts(f.db)), before);
        expect(find.text('Restocked · new observation started'), findsNothing);
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('lifecycle-count')))
              .controller!
              .text,
          '4',
        );
        await io(tester, () => f.db.customStatement('DROP TRIGGER m304_fail'));
        await tap(tester, 'Retry');
        final committed = await io(tester, () => f.snapshot(item.id));
        expect(committed.activeCycle!.id, isNot(original.activeCycle!.id));
        expect(committed.item.packageCount, 4);
        expect(committed.item.stockStatus, StockStatus.inStock);
        expect(
          committed.completedCycles.length,
          choice == 'Previous cycle was wrong' ? 0 : 1,
        );
        expect(
          committed.checkpoints.length,
          choice == 'Previous cycle was wrong' ? 0 : 1,
        );
        expect(
          find.text('Restocked · new observation started'),
          findsOneWidget,
        );
        expect(find.byType(LifecycleTaskSheet), findsNothing);
      },
    );
  }
  screen(
    'SQLite active zero total Finish resolves physical stock and stream in one accepted command',
    (tester) async {
      await io(tester, () => f.start(item, day: 20));
      await pump(tester);
      await tap(tester, 'Set current count');
      await enterDate(tester, 'lifecycle-count', '0');
      await tap(tester, 'Save count');
      expect(find.text('Resolve active observation'), findsOneWidget);
      expect(
        (await io(tester, () => f.snapshot(item.id))).item.packageCount,
        3,
      );
      await tap(tester, 'Resolve active observation');
      await tap(tester, 'Finished now');
      await tap(tester, 'Save finish');
      final committed = await io(tester, () => f.snapshot(item.id));
      expect(committed.activeCycle, isNull);
      expect(committed.item.packageCount, 0);
      await tester.drag(find.byType(ListView).first, const Offset(0, 1600));
      await tester.pumpAndSettle();
      expect(find.text('Current count: 0'), findsOneWidget);
      expect(find.text('Current count saved'), findsOneWidget);
    },
  );
  for (final remove in [false, true]) {
    screen(
      'M2 count form active-cycle race recovers via ${remove ? 'evidence removal and explicit save' : 'Finish'} without losing draft',
      (tester) async {
        await pump(tester);
        await tap(tester, 'Set current count');
        final field = find.byKey(const Key('correction-count'));
        await tester.ensureVisible(field);
        await tester.enterText(field, '0');
        final active = (await io(
          tester,
          () => f.start(item, day: 20),
        )).activeCycle!;
        await settleDatabase(tester);
        await tap(tester, 'Save count');
        expect(find.text('Resolve active observation'), findsOneWidget);
        expect(
          (await io(tester, () => f.snapshot(item.id))).activeCycle,
          active,
        );
        await tap(tester, 'Resolve active observation');
        await tap(tester, remove ? 'Previous cycle was wrong' : 'Finished now');
        if (remove) {
          await tap(
            tester,
            'I confirm removal of this observation and its progress notes',
          );
        }
        await tap(tester, remove ? 'Remove wrong observation' : 'Save finish');
        if (remove) {
          expect(
            find.textContaining('availability entry has not been saved'),
            findsOneWidget,
          );
          expect(tester.widget<TextField>(field).controller!.text, '0');
          expect(
            (await io(tester, () => f.snapshot(item.id))).item.packageCount,
            3,
          );
          await tap(tester, 'Save count');
        }
        final committed = await io(tester, () => f.snapshot(item.id));
        expect(committed.activeCycle, isNull);
        expect(committed.item.packageCount, 0);
        expect(find.text('Current availability saved.'), findsOneWidget);
      },
    );
  }
  screen(
    'Single-unit active presence correction resolves Out explicitly without inventing a count',
    (tester) async {
      item = await io(tester, () => f.item(name: 'Soap'));
      await io(tester, () => f.start(item, day: 20));
      await pump(tester);
      await tap(tester, 'Correct presence');
      await tap(tester, 'Not at home');
      await tap(tester, 'Save presence');
      expect(find.text('Resolve active observation'), findsOneWidget);
      await tap(tester, 'Resolve active observation');
      await tap(tester, 'Finished now');
      await tap(tester, 'Save finish');
      final committed = await io(tester, () => f.snapshot(item.id));
      expect(committed.activeCycle, isNull);
      expect(committed.item.stockStatus, StockStatus.outOfStock);
      expect(committed.item.packageCount, isNull);
      expect(find.text('Current availability saved.'), findsOneWidget);
    },
  );
  screen(
    'SQLite earlier Finish explicitly corrects owned checkpoint date and retains unrelated history',
    (tester) async {
      final old = (await io(tester, () => f.start(item, day: 1))).activeCycle!;
      await io(
        tester,
        () => f.lifecycle.finish(
          expected: old,
          finishedOn: date(2),
          today: currentDate,
        ),
      );
      final active = saved(
        await io(
          tester,
          () => f.lifecycle.restock(
            itemId: item.id,
            startedOn: date(20),
            today: currentDate,
            absolutePackageCount: 3,
          ),
        ),
      ).activeCycle!;
      final note = saved(
        await io(
          tester,
          () => f.lifecycle.addCheckpoint(
            expectedCycle: active,
            kind: LifecycleCheckpointKind.aboutHalf,
            observedOn: date(25),
            today: currentDate,
          ),
        ),
      ).checkpoints.single;
      await pump(tester);
      await tap(tester, 'Finish');
      await enterDate(tester, 'lifecycle-finish-date', '2026-10-23');
      await tap(tester, 'Save correction');
      expect((await io(tester, () => f.snapshot(item.id))).activeCycle, active);
      await enterDate(tester, 'reconcile-date-${note.id}', '2026-10-22');
      await tap(tester, 'Save correction');
      final committed = await io(tester, () => f.snapshot(item.id));
      expect(committed.completedCycles.length, 2);
      expect(committed.checkpoints.single.observedOn, date(22));
      expect(
        committed.cycles.singleWhere((c) => c.id == old.id).finishedOn,
        date(2),
      );
    },
  );
  screen(
    'SQLite stale completed target is not reopened or retargeted after concurrent removal',
    (tester) async {
      final active = (await io(
        tester,
        () => f.start(item, day: 20),
      )).activeCycle!;
      await pump(tester);
      await tap(tester, 'Finish');
      await io(
        tester,
        () => f.lifecycle.finish(
          expected: active,
          finishedOn: date(26),
          today: currentDate,
        ),
      );
      final replacement = saved(
        await io(
          tester,
          () => f.lifecycle.restock(
            itemId: item.id,
            startedOn: date(27),
            today: currentDate,
            absolutePackageCount: 2,
          ),
        ),
      ).activeCycle!;
      await tap(tester, 'Save correction');
      await tap(tester, 'Review current state');
      expect(find.textContaining('completion state changed'), findsOneWidget);
      expect(
        (await io(tester, () => f.snapshot(item.id))).activeCycle,
        replacement,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save correction'),
            )
            .onPressed,
        isNull,
      );
      await tap(tester, 'Cancel');
      expect(find.text('Finish'), findsOneWidget);
    },
  );
}
