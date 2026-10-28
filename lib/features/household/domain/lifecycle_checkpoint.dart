import '../../../core/domain/local_date/local_date.dart';

enum LifecycleCheckpointKind {
  aboutHalf('aboutHalf'),
  nearlyFinished('nearlyFinished');

  const LifecycleCheckpointKind(this.wireName);
  final String wireName;

  static LifecycleCheckpointKind fromWireName(String value) =>
      LifecycleCheckpointKind.values.firstWhere(
        (kind) => kind.wireName == value,
        orElse: () => throw ArgumentError('Unknown lifecycle checkpoint kind.'),
      );
}

/// Optional factual evidence; neither kind is a required consumption stage.
final class LifecycleCheckpoint {
  const LifecycleCheckpoint({
    required this.id,
    required this.cycleId,
    required this.kind,
    required this.observedOn,
  });

  final int id;
  final int cycleId;
  final LifecycleCheckpointKind kind;
  final LocalDate observedOn;

  @override
  bool operator ==(Object other) =>
      other is LifecycleCheckpoint &&
      id == other.id &&
      cycleId == other.cycleId &&
      kind == other.kind &&
      observedOn == other.observedOn;

  @override
  int get hashCode => Object.hash(id, cycleId, kind, observedOn);
}
