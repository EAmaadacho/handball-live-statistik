import '../domain/game.dart';

/// A game together with what only the server needs: id, home team,
/// date and the secret ticker code (S1, S1.2).
///
/// The id is also the public viewer link (ADR-005).
class StoredGame {
  final String id;
  final String homeTeamId;
  final DateTime date;
  final String tickerCode;
  final Game game;

  const StoredGame({
    required this.id,
    required this.homeTeamId,
    required this.date,
    required this.tickerCode,
    required this.game,
  });

  /// The same stored game with a changed [game], e.g. after a goal.
  StoredGame withGame(Game game) => StoredGame(
      id: id,
      homeTeamId: homeTeamId,
      date: date,
      tickerCode: tickerCode,
      game: game);
}
