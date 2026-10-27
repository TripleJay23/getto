/// The consumption and replenishment behavior profile of an item.
enum BehaviorProfile {
  /// Depleting single-unit item tracked through consumption cycles (open -> finished).
  replenishable('replenishable'),

  /// Discrete inventory tracked by natural package/unit counts.
  countableReplenishable('countableReplenishable'),

  /// Permanent household asset that never depletes and never undergoes lifecycle learning.
  durable('durable');

  const BehaviorProfile(this.wireName);
  final String wireName;

  static BehaviorProfile fromWireName(String wireName) {
    return BehaviorProfile.values.firstWhere(
      (profile) => profile.wireName == wireName,
      orElse: () =>
          throw ArgumentError('Unknown BehaviorProfile wire name: $wireName'),
    );
  }
}
