import 'package:flutter_test/flutter_test.dart';
import 'package:getto/features/household/domain/behavior_profile.dart';
import 'package:getto/features/household/domain/item.dart';
import 'package:getto/features/household/domain/stock_status.dart';

void main() {
  group('Item Entity', () {
    final now = DateTime.utc(2026, 10, 10, 12, 0);

    test('creates valid Item and asserts equality', () {
      final item1 = Item(
        id: 1,
        areaId: 10,
        name: 'Whole Milk',
        behaviorProfile: BehaviorProfile.replenishable,
        stockStatus: StockStatus.inStock,
        unit: 'liters',
        packageCount: 2,
        isArchived: false,
        notes: 'Organic',
        createdAt: now,
        updatedAt: now,
      );

      final item2 = Item(
        id: 1,
        areaId: 10,
        name: 'Whole Milk',
        behaviorProfile: BehaviorProfile.replenishable,
        stockStatus: StockStatus.inStock,
        unit: 'liters',
        packageCount: 2,
        isArchived: false,
        notes: 'Organic',
        createdAt: now,
        updatedAt: now,
      );

      expect(item1, equals(item2));
      expect(item1.hashCode, equals(item2.hashCode));
      expect(item1.toString(), contains('Whole Milk'));
    });

    test('copyWith updates fields correctly', () {
      final item = Item(
        id: 1,
        areaId: 10,
        name: 'Whole Milk',
        behaviorProfile: BehaviorProfile.replenishable,
        stockStatus: StockStatus.inStock,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      );

      final updated = item.copyWith(
        stockStatus: StockStatus.outOfStock,
        packageCount: 0,
        isArchived: true,
      );

      expect(updated.id, 1);
      expect(updated.stockStatus, StockStatus.outOfStock);
      expect(updated.packageCount, 0);
      expect(updated.isArchived, isTrue);
      expect(updated.name, 'Whole Milk');
    });

    test(
      'rejects empty or excessively long names with runtime ArgumentError',
      () {
        expect(
          () => Item(
            id: 1,
            areaId: 10,
            name: '',
            behaviorProfile: BehaviorProfile.replenishable,
            stockStatus: StockStatus.inStock,
            isArchived: false,
            createdAt: now,
            updatedAt: now,
          ),
          throwsArgumentError,
        );

        expect(
          () => Item(
            id: 1,
            areaId: 10,
            name: 'A' * 101,
            behaviorProfile: BehaviorProfile.replenishable,
            stockStatus: StockStatus.inStock,
            isArchived: false,
            createdAt: now,
            updatedAt: now,
          ),
          throwsArgumentError,
        );
      },
    );

    test('rejects negative package count with runtime ArgumentError', () {
      expect(
        () => Item(
          id: 1,
          areaId: 10,
          name: 'Eggs',
          behaviorProfile: BehaviorProfile.countableReplenishable,
          stockStatus: StockStatus.inStock,
          packageCount: -1,
          isArchived: false,
          createdAt: now,
          updatedAt: now,
        ),
        throwsArgumentError,
      );
    });

    test(
      'rejects package count on durable items with runtime ArgumentError',
      () {
        expect(
          () => Item(
            id: 1,
            areaId: 10,
            name: 'Toaster',
            behaviorProfile: BehaviorProfile.durable,
            stockStatus: StockStatus.inStock,
            packageCount: 1,
            isArchived: false,
            createdAt: now,
            updatedAt: now,
          ),
          throwsArgumentError,
        );
      },
    );

    test('rejects positive package count when stockStatus is outOfStock', () {
      expect(
        () => Item(
          id: 1,
          areaId: 10,
          name: 'Paper Towels',
          behaviorProfile: BehaviorProfile.countableReplenishable,
          stockStatus: StockStatus.outOfStock,
          packageCount: 3,
          isArchived: false,
          createdAt: now,
          updatedAt: now,
        ),
        throwsArgumentError,
      );
    });

    test('rejects zero package count when stockStatus is inStock', () {
      expect(
        () => Item(
          id: 1,
          areaId: 10,
          name: 'Paper Towels',
          behaviorProfile: BehaviorProfile.countableReplenishable,
          stockStatus: StockStatus.inStock,
          packageCount: 0,
          isArchived: false,
          createdAt: now,
          updatedAt: now,
        ),
        throwsArgumentError,
      );
    });

    test(
      'validates representative profile, count, and status combinations',
      () {
        // 1. Regular replenishable in stock without count
        final repIn = Item(
          id: 1,
          areaId: 10,
          name: 'Olive Oil',
          behaviorProfile: BehaviorProfile.replenishable,
          stockStatus: StockStatus.inStock,
          isArchived: false,
          createdAt: now,
          updatedAt: now,
        );
        expect(repIn.packageCount, isNull);
        expect(repIn.stockStatus, StockStatus.inStock);

        // 2. Regular replenishable out of stock without count
        final repOut = Item(
          id: 2,
          areaId: 10,
          name: 'Olive Oil',
          behaviorProfile: BehaviorProfile.replenishable,
          stockStatus: StockStatus.outOfStock,
          isArchived: false,
          createdAt: now,
          updatedAt: now,
        );
        expect(repOut.packageCount, isNull);
        expect(repOut.stockStatus, StockStatus.outOfStock);

        // 3. Countable replenishable in stock with positive count
        final countIn = Item(
          id: 3,
          areaId: 10,
          name: 'Eggs',
          behaviorProfile: BehaviorProfile.countableReplenishable,
          stockStatus: StockStatus.inStock,
          packageCount: 12,
          unit: 'count',
          isArchived: false,
          createdAt: now,
          updatedAt: now,
        );
        expect(countIn.packageCount, 12);
        expect(countIn.stockStatus, StockStatus.inStock);

        // 4. Countable replenishable depleted with zero count
        final countOut = Item(
          id: 4,
          areaId: 10,
          name: 'Eggs',
          behaviorProfile: BehaviorProfile.countableReplenishable,
          stockStatus: StockStatus.outOfStock,
          packageCount: 0,
          unit: 'count',
          isArchived: false,
          createdAt: now,
          updatedAt: now,
        );
        expect(countOut.packageCount, 0);
        expect(countOut.stockStatus, StockStatus.outOfStock);

        // 5. Durable possession in stock
        final durable = Item(
          id: 5,
          areaId: 10,
          name: 'Microwave',
          behaviorProfile: BehaviorProfile.durable,
          stockStatus: StockStatus.inStock,
          isArchived: false,
          createdAt: now,
          updatedAt: now,
        );
        expect(durable.packageCount, isNull);
        expect(durable.stockStatus, StockStatus.inStock);
      },
    );
  });
}
