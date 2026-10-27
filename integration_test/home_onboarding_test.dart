import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getto/app/app.dart';
import 'package:getto/app/composition/database_providers.dart';
import 'package:getto/app/composition/onboarding_providers.dart';
import 'package:getto/app/routing/app_router.dart';
import 'package:getto/core/database/app_database.dart';
import 'package:getto/features/household/data/drift_item_repository.dart';
import 'package:getto/features/household/domain/behavior_profile.dart';
import 'package:getto/features/household/domain/stock_status.dart';
import 'package:getto/features/onboarding/data/file_onboarding_store.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// Two device processes: create evidence, then rerun with M232_RESTART=true.
/// All test data is isolated from getto.sqlite and the production setup marker.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const restart = bool.fromEnvironment('M232_RESTART');

  testWidgets(
    restart ? 'M2.3.2 physical process restart preserves Home and Explore' : 'M2.3.2 physical first-use, contextual creation and branch navigation',
    (tester) async {
      final documents = await getApplicationDocumentsDirectory();
      final directory = Directory('${documents.path}/m232_verification');
      await directory.create(recursive: true);
      final file = File('${directory.path}/home.sqlite');
      final store = FileOnboardingStore(
        () async => File('${directory.path}/onboarding.v1'),
      );
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
      final router = createAppRouter();
      Future<void> settle() async {
        await tester.pumpAndSettle();
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await tester.pumpAndSettle();
      }

      Future<void> tap(String label) async {
        final buttons = find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        );
        final target =
            find.byType(DropdownMenuItem<int>).evaluate().isNotEmpty ||
                buttons.evaluate().isEmpty
            ? find.text(label).last
            : buttons.last;
        await tester.ensureVisible(target);
        await tester.tap(target);
        await settle();
      }

      try {
        if (!restart) {
          expect(
            (await store.readCompleted()).valueOrNull,
            isFalse,
            reason: 'Use a fresh verification fixture, never reset ordinary household data.',
          );
        }
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              onboardingStoreProvider.overrideWithValue(store),
            ],
            child: GettoApp(router: router),
          ),
        );
        await settle();
        if (restart) {
          expect(find.byKey(const ValueKey('getto-home-page')), findsOneWidget);
          expect(find.text('Pixel verification item'), findsOneWidget);
          expect((await store.readCompleted()).valueOrNull, isTrue);
          final saved = (await DriftItemRepository(
            db,
          ).getAllItems()).valueOrNull!;
          expect(saved, hasLength(1));
          expect(
            saved.single.behaviorProfile,
            BehaviorProfile.countableReplenishable,
          );
          expect(saved.single.stockStatus, StockStatus.outOfStock);
          expect(saved.single.packageCount, isNull);
          expect(find.text('Not at home'), findsOneWidget);
        } else {
          await tap('Set up my home');
          await tap('Explore my home');
          expect(find.text('Nothing to track yet'), findsOneWidget);
          expect((await store.readCompleted()).valueOrNull, isTrue);
          await tap('Add first item');
          await tester.enterText(
            find.byKey(const Key('item-name')),
            'Pixel verification item',
          );
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.tap(find.byType(DropdownButtonFormField<int>));
          await settle();
          await tap('Custom · Create a home area');
          await tester.enterText(
            find.byKey(const Key('custom-area-name')),
            'Pixel verification area',
          );
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tap('Create area');
          expect(
            find.text('Your new area is saved and selected.'),
            findsOneWidget,
          );
          await tap('Continue');
          await tap('Count what remains');
          await tap('Not at home');
          await tap('Back');
          expect(find.text('Pixel verification item'), findsOneWidget);
          await tap('Continue');
          await tap('Add item');
          expect(find.text('Pixel verification item'), findsOneWidget);
          await tap('Pixel verification area');
          await tester.tap(find.byKey(const ValueKey('getto-nav-buy')));
          await settle();
          await tester.tap(find.byKey(const ValueKey('getto-nav-bills')));
          await settle();
          await tester.tap(find.byKey(const ValueKey('getto-nav-home')));
          await settle();
          expect(
            find.text('1 active item in Pixel verification area'),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await db.close();
        router.dispose();
        if (restart) await directory.delete(recursive: true);
      }
    },
  );
}
