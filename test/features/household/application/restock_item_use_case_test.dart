import 'package:flutter_test/flutter_test.dart';
import 'package:getto/core/domain/result/failure.dart';
import 'package:getto/features/household/application/restock_item_use_case.dart';
import 'package:getto/features/household/domain/behavior_profile.dart';
import 'package:getto/features/household/domain/lifecycle_repository.dart';

import '../../../support/lifecycle_repository_fixture.dart';

void main() {
  late LifecycleFixture f;
  setUp(() => f = LifecycleFixture());
  tearDown(() => f.db.close());

  test(
    'application injects current date and requires explicit usable total',
    () async {
      var reads = 0;
      final useCase = RestockItemUseCase(
        f.lifecycle,
        today: () {
          reads++;
          return date(15);
        },
      );
      final item = await f.item(
        profile: BehaviorProfile.countableReplenishable,
      );
      final before = await databaseFacts(f.db);
      expect(
        (await useCase.execute(
          itemId: item.id,
          startedOn: date(16),
          absolutePackageCount: 4,
        )).failureOrNull,
        isA<InvalidLifecycleDateFailure>(),
      );
      expect(await databaseFacts(f.db), before);
      expect(
        (await useCase.execute(
          itemId: item.id,
          startedOn: date(15),
        )).failureOrNull,
        isA<LifecycleCountFailure>(),
      );
      final result = saved(
        await useCase.execute(
          itemId: item.id,
          startedOn: date(15),
          absolutePackageCount: 4,
        ),
      );
      expect(result.item.packageCount, 4);
      expect(reads, 3);
    },
  );

  test('application resolution is one transaction and failed replacement leaves old facts intact', () async {
    final item = await f.item(
      profile: BehaviorProfile.countableReplenishable,
      count: 3,
    );
    final active = (await f.start(item)).activeCycle!;
    final useCase = RestockItemUseCase(f.lifecycle, today: () => currentDate);
    await f.db.customStatement(
      "CREATE TEMP TRIGGER fail_item AFTER UPDATE ON items BEGIN SELECT RAISE(ABORT, 'controlled application fault'); END",
    );
    final before = await databaseFacts(f.db);
    expect(
      (await useCase.execute(
        itemId: item.id,
        startedOn: date(16),
        absolutePackageCount: 4,
        resolution: FinishActiveCycle(expected: active, finishedOn: date(15)),
      )).failureOrNull,
      isA<CheckConstraintFailure>(),
    );
    expect(await databaseFacts(f.db), before);
    await f.db.customStatement('DROP TRIGGER fail_item');
    final savedState = saved(
      await useCase.execute(
        itemId: item.id,
        startedOn: date(16),
        absolutePackageCount: 4,
        resolution: FinishActiveCycle(expected: active, finishedOn: date(15)),
      ),
    );
    expect(savedState.cycles.length, 2);
    expect(savedState.completedCycles.length, 1);
    expect(savedState.item.packageCount, 4);
  });

  test(
    'without an explicit resolution the application retains the active cycle',
    () async {
      final item = await f.item();
      await f.start(item);
      final before = await databaseFacts(f.db);
      final useCase = RestockItemUseCase(f.lifecycle, today: () => currentDate);
      expect(
        (await useCase.execute(
          itemId: item.id,
          startedOn: date(16),
        )).failureOrNull,
        isA<LifecycleConflictFailure>(),
      );
      expect(await databaseFacts(f.db), before);
    },
  );
}
