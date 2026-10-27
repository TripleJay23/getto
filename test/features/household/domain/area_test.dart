import 'package:flutter_test/flutter_test.dart';
import 'package:getto/features/household/domain/area.dart';

void main() {
  group('Area Entity', () {
    final now = DateTime.utc(2026, 10, 10, 12, 0);

    test('creates valid Area and asserts equality', () {
      final area1 = Area(
        id: 1,
        name: 'Kitchen',
        iconName: 'kitchen',
        displayOrder: 0,
        isArchived: false,
        isSystem: true,
        createdAt: now,
        updatedAt: now,
      );

      final area2 = Area(
        id: 1,
        name: 'Kitchen',
        iconName: 'kitchen',
        displayOrder: 0,
        isArchived: false,
        isSystem: true,
        createdAt: now,
        updatedAt: now,
      );

      expect(area1, equals(area2));
      expect(area1.hashCode, equals(area2.hashCode));
      expect(area1.toString(), contains('Kitchen'));
      expect(area1.isSystem, isTrue);
    });

    test('copyWith updates specified fields', () {
      final area = Area(
        id: 1,
        name: 'Kitchen',
        iconName: 'kitchen',
        displayOrder: 0,
        isArchived: false,
        isSystem: true,
        createdAt: now,
        updatedAt: now,
      );

      final updated = area.copyWith(
        name: 'Main Kitchen',
        displayOrder: 2,
        isArchived: true,
        isSystem: false,
      );

      expect(updated.id, 1);
      expect(updated.name, 'Main Kitchen');
      expect(updated.displayOrder, 2);
      expect(updated.isArchived, isTrue);
      expect(updated.isSystem, isFalse);
      expect(updated.iconName, 'kitchen');
    });

    test(
      'rejects empty or excessively long names with runtime ArgumentError',
      () {
        expect(
          () => Area(
            id: 1,
            name: '',
            iconName: 'kitchen',
            displayOrder: 0,
            isArchived: false,
            createdAt: now,
            updatedAt: now,
          ),
          throwsArgumentError,
        );

        expect(
          () => Area(
            id: 1,
            name: 'A' * 51,
            iconName: 'kitchen',
            displayOrder: 0,
            isArchived: false,
            createdAt: now,
            updatedAt: now,
          ),
          throwsArgumentError,
        );
      },
    );

    test('rejects negative display order with runtime ArgumentError', () {
      expect(
        () => Area(
          id: 1,
          name: 'Pantry',
          iconName: 'pantry',
          displayOrder: -1,
          isArchived: false,
          createdAt: now,
          updatedAt: now,
        ),
        throwsArgumentError,
      );
    });
  });
}
