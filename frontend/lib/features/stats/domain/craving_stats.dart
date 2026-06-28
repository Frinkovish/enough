class CravingStats {
  const CravingStats({required this.totalDelayed, required this.currentStreak});

  /// How many cravings the user has successfully delayed (outcome:
  /// didn't smoke), ever. Counts up, never down — progress, not perfection.
  final int totalDelayed;

  /// Consecutive "didn't smoke" outcomes counting back from the most
  /// recent completed session. Resets quietly on a relapse — never
  /// shown as a loss, just a fresh count starting from the next craving.
  final int currentStreak;

  static const empty = CravingStats(totalDelayed: 0, currentStreak: 0);
}
