import 'package:flutter_test/flutter_test.dart';
import 'package:getto/core/domain/local_date/local_date.dart';

void main() {
  group('LocalDate', () {
    test('creates valid date and formats as ISO-8601 string', () {
      final date = LocalDate(2026, 10, 10);
      expect(date.year, 2026);
      expect(date.month, 10);
      expect(date.day, 10);
      expect(date.toString(), '2026-10-10');
    });

    test('parses valid ISO string', () {
      final date = LocalDate.parse('2026-02-28');
      expect(date.year, 2026);
      expect(date.month, 2);
      expect(date.day, 28);
    });

    test('handles leap years correctly', () {
      expect(LocalDate.daysInMonth(2024, 2), 29);
      expect(LocalDate.daysInMonth(2026, 2), 28);
      expect(LocalDate.daysInMonth(2000, 2), 29);
      expect(LocalDate.daysInMonth(1900, 2), 28);

      final leapDate = LocalDate.parse('2024-02-29');
      expect(leapDate.day, 29);

      expect(() => LocalDate.parse('2026-02-29'), throwsFormatException);
    });

    test('rejects invalid format and values in parse', () {
      expect(() => LocalDate.parse('invalid'), throwsFormatException);
      expect(() => LocalDate.parse('2026-13-01'), throwsFormatException);
      expect(() => LocalDate.parse('2026-04-31'), throwsFormatException);
      expect(LocalDate.tryParse('invalid'), isNull);
      expect(LocalDate.tryParse(null), isNull);
    });

    test(
      'rejects out-of-range constructor arguments with runtime ArgumentError',
      () {
        expect(() => LocalDate(1899, 1, 1), throwsArgumentError);
        expect(() => LocalDate(2201, 1, 1), throwsArgumentError);
        expect(() => LocalDate(2026, 0, 1), throwsArgumentError);
        expect(() => LocalDate(2026, 13, 1), throwsArgumentError);
        expect(() => LocalDate(2026, 2, 29), throwsArgumentError);
        expect(() => LocalDate(2026, 4, 31), throwsArgumentError);
      },
    );

    test('arithmetic: addDays and subtractDays', () {
      final start = LocalDate(2026, 1, 30);
      final next = start.addDays(2);
      expect(next, LocalDate(2026, 2, 1));

      final prev = next.subtractDays(2);
      expect(prev, start);
    });

    test('differenceInDays calculates exact calendar days', () {
      final d1 = LocalDate(2026, 10, 10);
      final d2 = LocalDate(2026, 10, 15);
      expect(d2.differenceInDays(d1), 5);
      expect(d1.differenceInDays(d2), -5);
      expect(d1.differenceInDays(d1), 0);
    });

    test('comparison operators and ordering', () {
      final early = LocalDate(2026, 1, 1);
      final late = LocalDate(2026, 12, 31);
      expect(early.isBefore(late), isTrue);
      expect(late.isAfter(early), isTrue);
      expect(early.compareTo(late), isNegative);
      expect(early == LocalDate(2026, 1, 1), isTrue);
    });

    test('constructs from DateTime', () {
      final dt = DateTime(2026, 5, 20, 14, 30);
      final localDate = LocalDate.fromDateTime(dt);
      expect(localDate, LocalDate(2026, 5, 20));
    });
  });
}
