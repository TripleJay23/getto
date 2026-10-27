/// The factual availability and physical presence of an item.
enum StockStatus {
  /// Available in the household.
  inStock('inStock'),

  /// Completely depleted or missing.
  outOfStock('outOfStock');

  const StockStatus(this.wireName);
  final String wireName;

  static StockStatus fromWireName(String wireName) {
    return StockStatus.values.firstWhere(
      (status) => status.wireName == wireName,
      orElse: () =>
          throw ArgumentError('Unknown StockStatus wire name: $wireName'),
    );
  }
}
