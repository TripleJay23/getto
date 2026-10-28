import '../../../core/domain/local_date/local_date.dart';

/// One factual observation. Effective dates are calendar facts, not timestamps.
final class LifecycleCycle {
  LifecycleCycle({
    required this.id,
    required this.itemId,
    required this.startedOn,
    this.finishedOn,
  }) {
    if (finishedOn != null && finishedOn!.isBefore(startedOn)) {
      throw ArgumentError('Finish cannot precede Start.');
    }
  }

  final int id;
  final int itemId;
  final LocalDate startedOn;
  final LocalDate? finishedOn;

  bool get isActive => finishedOn == null;

  /// Unknown until completed; same-day completion is exactly zero days.
  int? get durationDays => finishedOn?.differenceInDays(startedOn);

  @override
  bool operator ==(Object other) =>
      other is LifecycleCycle &&
      id == other.id &&
      itemId == other.itemId &&
      startedOn == other.startedOn &&
      finishedOn == other.finishedOn;

  @override
  int get hashCode => Object.hash(id, itemId, startedOn, finishedOn);
}
