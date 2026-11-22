/// A score like 12:10, always home first.
class Score {
  final int home;
  final int away;

  const Score(this.home, this.away);

  @override
  bool operator ==(Object other) =>
      other is Score && other.home == home && other.away == away;

  @override
  int get hashCode => Object.hash(home, away);

  /// Example: "12:10".
  @override
  String toString() => '$home:$away';
}
