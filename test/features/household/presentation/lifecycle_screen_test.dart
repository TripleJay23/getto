import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getto/app/app.dart';
import 'package:getto/app/composition/household_providers.dart';
import 'package:getto/app/composition/lifecycle_providers.dart';
import 'package:getto/core/domain/result/failure.dart';
import 'package:getto/features/household/domain/behavior_profile.dart';
import 'package:getto/features/household/domain/item_lifecycle.dart';
import 'package:getto/features/household/domain/lifecycle_cycle.dart';
import 'package:getto/features/household/presentation/item_management_screen.dart';
import 'package:getto/features/household/presentation/lifecycle_task_sheet.dart';
import 'package:getto/features/household/presentation/lifecycle_widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../support/lifecycle_fake.dart';

Future<void> lifecycleTap(WidgetTester tester, String label) async {
  final matches = find.text(label);
  if (matches.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      matches,
      180,
      scrollable: find.byType(Scrollable).last,
    );
  }
  final finder = matches.last;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> enterDate(WidgetTester tester, String key, String text) async {
  final field = find.byKey(Key(key));
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

Future<void> lifecycleSnapshot(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('m304-capture')),
    );
    final rendered = await boundary.toImage();
    final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
    rendered.dispose();
    final directory = Directory('build/m304/screens');
    await directory.create(recursive: true);
    await File('${directory.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  late FakeLifecycleRepository repo;
  GoRouter? router;
  setUpAll(() async {
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope[wght].ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() {
    repo = FakeLifecycleRepository(lifecycleFixture(count: 3, history: true));
  });
  Future<void> pump(
    WidgetTester tester, {
    double width = 430,
    double scale = 1,
    bool reduce = false,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: reduce);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    });
    router = GoRouter(
      initialLocation: '/home/items/1',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Home destination')),
        ),
        GoRoute(
          path: '/home/items/:id',
          builder: (_, _) => const ItemDetailScreen(itemId: 1),
        ),
      ],
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('m304-capture'),
        child: ProviderScope(
          overrides: [
            lifecycleRepositoryProvider.overrideWithValue(repo),
            localTodayProvider.overrideWithValue(() => testToday),
            allAreasStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: GettoApp(router: router!),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void screen(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        repo.gate?.complete();
        repo.gate = null;
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        router?.dispose();
        router = null;
        await repo.close();
      }
    });
  }

  screen(
    'Active detail displays factual dates and dominant Finish with compact history',
    (tester) async {
      await pump(tester);
      expect(find.text('Finish'), findsOneWidget);
      expect(find.text('Start'), findsNothing);
      expect(find.text('Current count: 3'), findsOneWidget);
      expect(find.textContaining('Started 9 days ago'), findsOneWidget);
      expect(find.textContaining('Oct 20, 2026'), findsOneWidget);
      expect(find.text('Actual duration: 1 day'), findsOneWidget);
      expect(find.textContaining('No estimate is available'), findsOneWidget);
      expect(repo.watches, 1);
      expect(repo.historyReads, 1);
      expect(repo.lastLimit, 5);
      await lifecycleSnapshot(tester, 'w11-active-430');
    },
  );
  for (final out in [false, true]) {
    screen(
      'Inactive detail distinguishes unknown count and out=$out with explicit Start or Restock',
      (tester) async {
        repo.saved = lifecycleFixture(active: false, count: out ? 0 : null);
        await pump(tester);
        expect(find.text(out ? 'Restock' : 'Start'), findsOneWidget);
        expect(
          find.text(out ? 'Current count: 0' : 'Current count unknown'),
          findsOneWidget,
        );
        expect(find.text('No recorded observation'), findsOneWidget);
        expect(find.textContaining('No completed cycles yet'), findsOneWidget);
        expect(repo.calls, isEmpty);
        await lifecycleTap(tester, out ? 'Restock' : 'Start');
        if (out) {
          await enterDate(tester, 'lifecycle-count', '2');
        }
        await lifecycleTap(tester, out ? 'Save restock' : 'Start observation');
        expect(repo.saved.activeCycle, isNotNull);
        expect(repo.saved.item.packageCount, out ? 2 : null);
        expect(find.byType(LifecycleTaskSheet), findsNothing);
      },
    );
  }
  screen('Durable detail preserves presence-only behavior', (tester) async {
    repo.saved = lifecycleFixture(
      active: false,
      profile: BehaviorProfile.durable,
    );
    await pump(tester);
    expect(find.textContaining('Physical presence only'), findsOneWidget);
    expect(find.text('Correct presence'), findsOneWidget);
    expect(find.text('Current observation'), findsNothing);
    expect(find.text('Start'), findsNothing);
    expect(find.text('Finish'), findsNothing);
    expect(repo.historyReads, 0);
  });
  screen(
    'Archived detail retains readable history and gates changes behind Restore',
    (tester) async {
      repo.saved = lifecycleFixture(archived: true, history: true);
      await pump(tester);
      expect(find.text('Restore item'), findsOneWidget);
      expect(find.text('Finish'), findsNothing);
      expect(find.text('Correct dates'), findsNothing);
      expect(find.text('Actual duration: 1 day'), findsOneWidget);
      expect(find.textContaining('Restore this item to edit'), findsOneWidget);
    },
  );
  screen(
    'Same-day Finish shows zero-day duration and committed feedback exactly once',
    (tester) async {
      repo.saved = lifecycleFixture(
        active: false,
        count: 1,
      ).start(cycleId: 10, startedOn: testToday, today: testToday).valueOrNull!;
      await pump(tester);
      await lifecycleTap(tester, 'Finish');
      expect(find.text('Cycle duration: 0 days'), findsOneWidget);
      await lifecycleTap(tester, 'Save correction');
      expect(repo.saved.cycles.single.durationDays, 0);
      expect(find.text('Finished · observation saved'), findsOneWidget);
      expect(find.text('Actual duration: 0 days'), findsOneWidget);
      expect(find.text('Current count: 0'), findsOneWidget);
    },
  );
  screen('Finished earlier date picker and typed date save the actual finish', (
    tester,
  ) async {
    await pump(tester);
    await lifecycleTap(tester, 'Finish');
    await lifecycleTap(tester, 'Finished earlier');
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await lifecycleTap(tester, 'Cancel');
    await enterDate(tester, 'lifecycle-finish-date', '2026-10-24');
    await lifecycleTap(tester, 'Save correction');
    expect(
      repo.saved.cycles.singleWhere((c) => c.id == 10).finishedOn,
      day(24),
    );
  });
  for (final choice in [
    'Finished now',
    'Finished earlier',
    'Previous cycle was wrong',
  ]) {
    screen(
      'W18 $choice resolves replacement atomically with explicit total and confirmation',
      (tester) async {
        await pump(tester);
        await lifecycleTap(tester, 'Correct');
        await lifecycleTap(tester, 'Restock');
        expect(find.text('A cycle is already active'), findsOneWidget);
        expect(repo.calls, isEmpty);
        await lifecycleTap(tester, choice);
        if (choice == 'Finished earlier') {
          await enterDate(tester, 'lifecycle-finish-date', '2026-10-26');
        }
        await enterDate(tester, 'lifecycle-count', '4');
        if (choice == 'Previous cycle was wrong') {
          await lifecycleTap(tester, 'Resolve and restock');
          expect(repo.calls, isEmpty);
          await lifecycleTap(
            tester,
            'I confirm removal of this observation and its progress notes',
          );
        }
        await lifecycleTap(tester, 'Resolve and restock');
        expect(repo.calls, ['restock']);
        expect(repo.saved.item.packageCount, 4);
        expect(repo.saved.activeCycle!.id, isNot(10));
        expect(repo.saved.cycles.any((c) => c.id == 1), isTrue);
      },
    );
  }
  screen('Cancel, Back, scrim and drag dismiss idle drafts without writes', (
    tester,
  ) async {
    await pump(tester);
    for (final dismiss in ['Cancel', 'back', 'scrim', 'drag']) {
      await lifecycleTap(tester, 'Finish');
      switch (dismiss) {
        case 'Cancel':
          await lifecycleTap(tester, 'Cancel');
        case 'back':
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        case 'scrim':
          await tester.tapAt(const Offset(10, 20));
          await tester.pumpAndSettle();
        case 'drag':
          await tester.drag(find.byType(BottomSheet), const Offset(0, 800));
          await tester.pumpAndSettle();
      }
      expect(find.byType(LifecycleTaskSheet), findsNothing, reason: dismiss);
    }
    expect(repo.calls, isEmpty);
  });
  screen(
    'Optional progress note Skip writes nothing; existing kind is corrected in place',
    (tester) async {
      repo.saved = lifecycleFixture(notes: true, history: true, count: 3);
      await pump(tester);
      await lifecycleTap(tester, 'Add progress note');
      await lifecycleTap(tester, 'Skip');
      expect(repo.calls, isEmpty);
      await lifecycleTap(tester, 'Add progress note');
      await lifecycleTap(tester, 'About half');
      await enterDate(tester, 'lifecycle-observed-date', '2026-10-26');
      await lifecycleTap(tester, 'Save corrected note');
      expect(repo.calls, ['checkpoint-date']);
      expect(
        repo.saved.checkpoints.singleWhere((p) => p.id == 10).observedOn,
        day(26),
      );
      await lifecycleTap(tester, 'Add progress note');
      await lifecycleTap(tester, 'Nearly finished');
      await lifecycleTap(tester, 'Save progress note');
      expect(repo.saved.checkpoints.where((p) => p.cycleId == 10).length, 2);
    },
  );
  screen(
    'Historical date correction and deliberate removal preserve current physical facts',
    (tester) async {
      await pump(tester);
      await lifecycleTap(tester, 'Correct dates');
      expect(
        find.textContaining('Current stock stays unchanged'),
        findsOneWidget,
      );
      await enterDate(tester, 'lifecycle-start-date', '2026-10-02');
      await lifecycleTap(tester, 'Save correction');
      expect(repo.saved.item.packageCount, 3);
      expect(repo.saved.cycles.first.durationDays, 0);
      await lifecycleTap(tester, 'Remove observation');
      await lifecycleTap(
        tester,
        'I confirm removal of this observation and its progress notes',
      );
      await lifecycleTap(tester, 'Remove observation');
      expect(repo.saved.cycles.single.id, 10);
      expect(repo.saved.item.packageCount, 3);
    },
  );
  screen('Earlier Finish cannot silently discard conflicting checkpoints', (
    tester,
  ) async {
    repo.saved = lifecycleFixture(notes: true, history: true, count: 3);
    await pump(tester);
    await lifecycleTap(tester, 'Finish');
    await enterDate(tester, 'lifecycle-finish-date', '2026-10-23');
    await lifecycleTap(tester, 'Save correction');
    expect(
      find.textContaining('Some progress notes fall outside'),
      findsOneWidget,
    );
    expect(repo.saved.activeCycle, isNotNull);
    await lifecycleTap(tester, 'Remove About half note');
    await lifecycleTap(tester, 'Save correction');
    expect(repo.saved.checkpoints.single.id, 1);
    expect(
      repo.saved.cycles.singleWhere((c) => c.id == 10).finishedOn,
      day(23),
    );
  });
  screen(
    'Active zero count offers actionable resolution and retains draft through wrong evidence removal',
    (tester) async {
      await pump(tester);
      await lifecycleTap(tester, 'Set current count');
      await enterDate(tester, 'lifecycle-count', '0');
      await lifecycleTap(tester, 'Save count');
      expect(find.text('Resolve active observation'), findsOneWidget);
      expect(find.text('Not Saved'), findsNothing);
      await lifecycleTap(tester, 'Resolve active observation');
      await lifecycleTap(tester, 'Previous cycle was wrong');
      await lifecycleTap(
        tester,
        'I confirm removal of this observation and its progress notes',
      );
      await lifecycleTap(tester, 'Remove wrong observation');
      expect(
        find.textContaining('count has not been saved yet'),
        findsOneWidget,
      );
      expect(repo.saved.item.packageCount, 3);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('lifecycle-count')))
            .controller!
            .text,
        '0',
      );
      await lifecycleTap(tester, 'Save count');
      expect(repo.saved.item.packageCount, 0);
    },
  );
  screen(
    'Validation and Not Saved preserve draft with Retry and Keep editing',
    (tester) async {
      await pump(tester);
      await lifecycleTap(tester, 'Finish');
      await enterDate(tester, 'lifecycle-finish-date', '2026-10-30');
      await lifecycleTap(tester, 'Save correction');
      expect(find.textContaining('Choose valid dates'), findsOneWidget);
      expect(find.text('Finished · observation saved'), findsNothing);
      await enterDate(tester, 'lifecycle-finish-date', '2026-10-26');
      repo.writeFailure = const StorageIoFailure('injected');
      await lifecycleTap(tester, 'Save correction');
      expect(find.text('Not Saved'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      await lifecycleSnapshot(tester, 'w35-not-saved-430');
      await lifecycleTap(tester, 'Keep editing');
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('lifecycle-finish-date')))
            .controller!
            .text,
        '2026-10-26',
      );
      await lifecycleTap(tester, 'Save correction');
      repo.writeFailure = null;
      await lifecycleTap(tester, 'Retry');
      expect(find.text('Finished · observation saved'), findsOneWidget);
    },
  );
  screen(
    'Pending write locks duplicate, Back, scrim and drag; facts and success wait for commit',
    (tester) async {
      await pump(tester);
      await lifecycleTap(tester, 'Finish');
      repo.gate = Completer<void>();
      await lifecycleTap(tester, 'Save correction');
      expect(find.text('Saving…'), findsOneWidget);
      expect(repo.saved.activeCycle, isNotNull);
      expect(find.text('Finished · observation saved'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Saving…'))
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 20));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(BottomSheet), const Offset(0, 800));
      await tester.pumpAndSettle();
      expect(find.byType(LifecycleTaskSheet), findsOneWidget);
      expect(repo.calls, ['finish']);
      repo.gate!.complete();
      repo.gate = null;
      await tester.pumpAndSettle();
      expect(find.byType(LifecycleTaskSheet), findsNothing);
      expect(find.text('Finished · observation saved'), findsOneWidget);
    },
  );
  screen(
    'Stale target requires review and retains entered dates without overwriting newer facts',
    (tester) async {
      await pump(tester);
      await lifecycleTap(tester, 'Finish');
      await enterDate(tester, 'lifecycle-finish-date', '2026-10-26');
      repo.publish(
        repo.saved
            .correctCycleDates(
              expected: repo.saved.activeCycle!,
              startedOn: day(19),
              finishedOn: null,
              today: testToday,
            )
            .valueOrNull!,
      );
      await lifecycleTap(tester, 'Save correction');
      expect(find.text('Review current state'), findsOneWidget);
      expect(repo.saved.activeCycle!.startedOn, day(19));
      await lifecycleTap(tester, 'Review current state');
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('lifecycle-finish-date')))
            .controller!
            .text,
        '2026-10-26',
      );
      await lifecycleTap(tester, 'Save correction');
      expect(repo.saved.activeCycle, isNull);
    },
  );
  for (final race in ['archived', 'deleted']) {
    screen(
      '$race race retains unsaved task with truthful failure and safe Cancel',
      (tester) async {
        await pump(tester);
        await lifecycleTap(tester, 'Finish');
        if (race == 'archived') {
          repo.publish(
            ItemLifecycle(
              item: repo.saved.item.copyWith(isArchived: true),
              cycles: repo.saved.cycles,
            ),
          );
        } else {
          repo.readFailure = const EntityNotFoundFailure('deleted');
          repo.publishFailure(repo.readFailure!);
        }
        await lifecycleTap(tester, 'Save correction');
        expect(find.byType(LifecycleTaskSheet), findsOneWidget);
        expect(find.text('Finished · observation saved'), findsNothing);
        await lifecycleTap(tester, 'Cancel');
        expect(
          find.text(race == 'archived' ? 'Restore item' : 'Item unavailable'),
          findsOneWidget,
        );
      },
    );
  }
  screen(
    'Failed/missing aggregate has explicit retry or return states without cached success',
    (tester) async {
      repo.readFailure = const StorageIoFailure('injected');
      await pump(tester);
      expect(find.textContaining("Couldn't load this item"), findsOneWidget);
      repo.readFailure = null;
      await lifecycleTap(tester, 'Retry');
      expect(find.text('Finish'), findsOneWidget);
      repo.publishFailure(const EntityNotFoundFailure('deleted'));
      await tester.pumpAndSettle();
      expect(find.text('Item unavailable'), findsOneWidget);
      expect(find.text('Finish'), findsNothing);
      await lifecycleTap(tester, 'Return to Home');
      expect(find.text('Home destination'), findsOneWidget);
    },
  );
  screen(
    'Bounded history paging avoids new reads for unchanged evidence, metadata and typing',
    (tester) async {
      repo.saved = ItemLifecycle(
        item: repo.saved.item,
        cycles: [
          repo.saved.activeCycle!,
          for (var i = 1; i <= 7; i++)
            LifecycleCycle(
              id: i,
              itemId: 1,
              startedOn: day(1),
              finishedOn: day(2),
            ),
        ],
      );
      await pump(tester);
      expect(repo.historyReads, 1);
      expect(find.text('Actual duration: 1 day'), findsNWidgets(5));
      repo.publish(
        ItemLifecycle(
          item: repo.saved.item.copyWith(name: 'Renamed coffee'),
          cycles: repo.saved.cycles,
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.historyReads, 1);
      await lifecycleTap(tester, 'Finish');
      await enterDate(tester, 'lifecycle-finish-date', '2026-10-26');
      expect(repo.reads, 0);
      expect(repo.historyReads, 1);
      await lifecycleTap(tester, 'Cancel');
      await lifecycleTap(tester, 'Older observations');
      expect(repo.lastBefore, 3);
      expect(repo.lastLimit, 5);
      expect(repo.historyReads, 2);
      expect(find.text('Actual duration: 1 day'), findsNWidgets(2));
      await lifecycleTap(tester, 'Back to recent observations');
      expect(find.text('Actual duration: 1 day'), findsNWidgets(5));
    },
  );
  screen('Loading and stream-error recovery never show old committed facts', (
    tester,
  ) async {
    repo.emitInitial = false;
    await pump(tester);
    expect(find.text('Loading saved item…'), findsOneWidget);
    expect(find.text('Finish'), findsNothing);
    repo.publish(repo.saved);
    await tester.pumpAndSettle();
    expect(find.text('Finish'), findsOneWidget);
    repo.changes.addError(StateError('synthetic unavailable stream'));
    await tester.pumpAndSettle();
    expect(find.textContaining("Couldn't load this item"), findsOneWidget);
    expect(find.text('Finish'), findsNothing);
    repo.emitInitial = true;
    await lifecycleTap(tester, 'Retry');
    expect(find.text('Finish'), findsOneWidget);
  });
  screen(
    'History failure is recoverable without resetting evidence or the aggregate stream',
    (tester) async {
      repo.historyFailure = const StorageIoFailure('synthetic history failure');
      await pump(tester);
      expect(
        find.textContaining("Couldn't load recent observations"),
        findsOneWidget,
      );
      expect(find.text('Finish'), findsOneWidget);
      repo.historyFailure = null;
      await lifecycleTap(tester, 'Retry history');
      expect(find.text('Actual duration: 1 day'), findsOneWidget);
      expect(repo.watches, 1);
      expect(repo.historyReads, 2);
    },
  );
  screen(
    'Keyboard focus stays in the modal and idle system Back preserves committed state',
    (tester) async {
      await pump(tester);
      await lifecycleTap(tester, 'Finish');
      await enterDate(tester, 'lifecycle-finish-date', '2026-10-26');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focusContext = FocusManager.instance.primaryFocus!.context!;
      expect(
        focusContext.findAncestorWidgetOfExactType<LifecycleTaskSheet>(),
        isNotNull,
      );
      tester.testTextInput.hide();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(repo.calls, isEmpty);
      expect(repo.saved.activeCycle, isNotNull);
      expect(find.byType(LifecycleTaskSheet), findsNothing);
    },
  );
  screen(
    'Unrelated metadata emission during a pending task preserves draft and commit acknowledgement',
    (tester) async {
      await pump(tester);
      await lifecycleTap(tester, 'Finish');
      await enterDate(tester, 'lifecycle-finish-date', '2026-10-26');
      repo.gate = Completer<void>();
      await lifecycleTap(tester, 'Save correction');
      repo.publish(
        ItemLifecycle(
          item: repo.saved.item.copyWith(name: 'Renamed coffee'),
          cycles: repo.saved.cycles,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Finished · observation saved'), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('lifecycle-finish-date')))
            .controller!
            .text,
        '2026-10-26',
      );
      repo.gate!.complete();
      repo.gate = null;
      await tester.pumpAndSettle();
      expect(repo.saved.item.name, 'Renamed coffee');
      expect(find.text('Finished · observation saved'), findsOneWidget);
    },
  );
  screen(
    'Count correction exposes labeled 48dp targets and commit acknowledgement semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await pump(tester);
        await lifecycleTap(tester, 'Set current count');
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await enterDate(tester, 'lifecycle-count', '4');
        await lifecycleTap(tester, 'Save count');
        final feedback = tester.getSemantics(find.text('Current count saved'));
        expect(
          feedback.getSemanticsData().flagsCollection.isLiveRegion,
          isTrue,
        );
      } finally {
        semantics.dispose();
      }
    },
  );
  screen(
    'Pasted signed and decimal counts stay unchanged for explicit correction',
    (tester) async {
      await pump(tester);
      await lifecycleTap(tester, 'Set current count');
      for (final text in ['-1', '2.5', '0x10']) {
        await enterDate(tester, 'lifecycle-count', text);
        await lifecycleTap(tester, 'Save count');
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('lifecycle-count')))
              .controller!
              .text,
          text,
        );
        expect(repo.calls, isEmpty);
        expect(tester.takeException(), isNull);
        expect(
          find.textContaining('explicit nonnegative whole'),
          findsOneWidget,
        );
      }
      await lifecycleTap(tester, 'Cancel');
    },
  );
  screen(
    '320dp at 200 percent has growing targets, scrollable recovery and reduced motion semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();

      await pump(tester, width: 320, scale: 2, reduce: true);
      await lifecycleTap(tester, 'Correct');
      expect(tester.takeException(), isNull);
      for (final choice in tester.widgetList<LifecycleChoice>(
        find.byType(LifecycleChoice),
      )) {
        expect(
          tester.getSize(find.byWidget(choice)).height,
          greaterThanOrEqualTo(48),
        );
      }
      await lifecycleSnapshot(tester, 'w15-320-200');
      await lifecycleTap(tester, 'Restock');
      final route = ModalRoute.of(
        tester.element(find.byType(LifecycleTaskSheet)),
      )!;
      expect(route.transitionDuration, Duration.zero);
      await lifecycleTap(tester, 'Finished now');
      final selected = tester.getSemantics(find.byType(LifecycleChoice).first);
      expect(selected.flagsCollection.isSelected, ui.Tristate.isTrue);
      await enterDate(tester, 'lifecycle-count', '9223372036854775807');
      expect(tester.takeException(), isNull);
      await enterDate(tester, 'lifecycle-count', '4');
      expect(
        tester.getSemantics(find.byKey(const Key('lifecycle-count'))).label,
        contains('Current usable total'),
      );
      final save = find.widgetWithText(FilledButton, 'Resolve and restock');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      expect(tester.getSize(save).height, greaterThanOrEqualTo(48));
      await lifecycleSnapshot(tester, 'w18-320-200');
      expect(tester.takeException(), isNull);
      await lifecycleTap(tester, 'Cancel');
      expect(repo.calls, isEmpty);
      semantics.dispose();
    },
  );
}
