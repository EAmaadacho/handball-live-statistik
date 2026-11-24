import '../domain/game.dart';

/// A game together with what only the server needs: id, home team,
/// date and the secret ticker code (S1, S1.2).
///
/// The id is also the public viewer link (ADR-005).
///
/// [version] counts the changes: 1 after creating, 2 after the first
/// change and so on. The live view asks with it whether anything is new
/// (ADR-002). The running clock does not change it (ADR-003).
class StoredGame {
  final String id;
  final String homeTeamId;
  final DateTime date;
  final String tickerCode;
  final Game game;
  final int version;

  const StoredGame({
    required this.id,
    required this.homeTeamId,
    required this.date,
    required this.tickerCode,
    required this.game,
    this.version = 1,
  });

  /// The same stored game with a changed [game], e.g. after a goal.
  /// Every change gives the next version.
  StoredGame withGame(Game game) => StoredGame(
      id: id,
      homeTeamId: homeTeamId,
      date: date,
      tickerCode: tickerCode,
      game: game,
      version: version + 1);
}
