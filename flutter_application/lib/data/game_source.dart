import 'models.dart';

/// Where the pages get their data from.
///
/// Today [DemoGameSource] answers from memory. Later an API source answers
/// the same questions via the server, e.g. loadGame(17) → GET /games/17.
abstract class GameSource {
  /// The game with [id], or null if there is none.
  Future<Game?> loadGame(int id);

  /// The team that belongs to the secret [teamCode], or null (ADR-005).
  Future<Team?> loadTeamByCode(String teamCode);

  /// Whether [tickerCode] allows ticking game [gameId] (ADR-005).
  Future<bool> isTickerCode(int gameId, String tickerCode);
}
