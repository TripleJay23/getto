/// Pure Dart representation of an ISO-8601 calendar date (YYYY-MM-DD)
/// without a timezone or time-of-day component.
class LocalDate implements Comparable<LocalDate> {
  LocalDate(this.year, this.month, this.day) {
    if (year < 1900 || year > 2200) {
      throw ArgumentError('Year must be between 1900 and 2200 (got $year)');
    }
    if (month < 1 || month > 12) {
      throw ArgumentError('Month must be between 1 and 12 (got $month)');
    }
    final maxDays = daysInMonth(year, month);
    if (day < 1 || day > maxDays) {
      throw ArgumentError('Invalid day $day for month $month in year $year');
    }
  }

  final int year;
  final int month;
  final int day;

  /// Creates a [LocalDate] from a standard Dart [DateTime] in local time.
  factory LocalDate.fromDateTime(DateTime dateTime) {
    return LocalDate(dateTime.year, dateTime.month, dateTime.day);
  }

  /// Parses an ISO-8601 formatted date string (YYYY-MM-DD).
  factory LocalDate.parse(String formattedString) {
    final parts = formattedString.split('-');
    if (parts.length != 3) {
      throw FormatException('Invalid LocalDate format: $formattedString');
    }
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final d = int.parse(parts[2]);

    if (m < 1 || m > 12) {
      throw FormatException('Invalid month in LocalDate: $m');
    }
    final maxDays = daysInMonth(y, m);
    if (d < 1 || d > maxDays) {
      throw FormatException('Invalid day $d for month $m in year $y');
    }

    return LocalDate(y, m, d);
  }

  /// Tries to parse an ISO-8601 formatted date string, returning null on error.
  static LocalDate? tryParse(String? formattedString) {
    if (formattedString == null || formattedString.isEmpty) return null;
    try {
      return LocalDate.parse(formattedString);
    } on FormatException {
      return null;
    }
  }

  /// Returns the number of days in a given year and month.
  static int daysInMonth(int year, int month) {
    if (month == 2) {
      final isLeapYear =
          (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
      return isLeapYear ? 29 : 28;
    }
    const days = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return days[month];
  }

  /// Adds [days] to this date and returns a new [LocalDate].
  LocalDate addDays(int days) {
    final dt = DateTime.utc(year, month, day).add(Duration(days: days));
    return LocalDate(dt.year, dt.month, dt.day);
  }

  /// Subtracts [days] from this date and returns a new [LocalDate].
  LocalDate subtractDays(int days) {
    return addDays(-days);
  }

  /// Returns the number of days between this date and [other].
  /// Positive if this date is after [other], negative if before.
  int differenceInDays(LocalDate other) {
    final dtThis = DateTime.utc(year, month, day);
    final dtOther = DateTime.utc(other.year, other.month, other.day);
    return dtThis.difference(dtOther).inDays;
  }

  bool isBefore(LocalDate other) => compareTo(other) < 0;
  bool isAfter(LocalDate other) => compareTo(other) > 0;
  bool isAtSameMomentAs(LocalDate other) => compareTo(other) == 0;

  @override
  int compareTo(LocalDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalDate &&
          runtimeType == other.runtimeType &&
          year == other.year &&
          month == other.month &&
          day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);

  /// Returns the date formatted as ISO-8601 `YYYY-MM-DD`.
  @override
  String toString() {
    final yStr = year.toString().padLeft(4, '0');
    final mStr = month.toString().padLeft(2, '0');
    final dStr = day.toString().padLeft(2, '0');
    return '$yStr-$mStr-$dStr';
  }
}
