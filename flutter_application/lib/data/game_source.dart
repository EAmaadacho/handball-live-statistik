import 'models.dart';

/// The server said no and explains why, e.g. "Nur 2 Auszeiten pro Halbzeit."
/// (HTTP 409). Any other error means the request did not arrive (E1.6).
class RejectedAction implements Exception {
  const RejectedAction(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Where the pages get their data from.
///
/// Today [DemoGameSource] answers from memory. Later an API source answers
/// the same questions via the server, e.g. loadGame(17) → GET /games/17.
///
/// The methods for the ticker need the secret [tickerCode] (ADR-005). They
/// throw [RejectedAction] when a rule forbids the action.
abstract class GameSource {
  /// The game with [id], or null if there is none.
  Future<Game?> loadGame(int id);

  /// The team that belongs to the secret [teamCode], or null (ADR-005).
  Future<Team?> loadTeamByCode(String teamCode);

  /// What happens in game [id] right now, or null if there is no such game.
  Future<GameState?> loadState(int id);

  /// Whether [tickerCode] allows ticking game [gameId] (ADR-005).
  Future<bool> isTickerCode(int gameId, String tickerCode);

  /// Records an event; the server adds the game time (E1, ADR-003).
  ///
  /// Example: record(17, code, EventKind.goal, Side.home, playerId: 'max7')
  /// → the event "38:12 Tor · 7 Max Mustermann".
  /// A timeout has no player and stops the clock (U3).
  Future<GameEvent> record(
      int gameId, String tickerCode, EventKind kind, Side side,
      {String? playerId});

  /// Deletes event [number] after a typing mistake (E2).
  Future<void> deleteEvent(int gameId, String tickerCode, int number);

  /// Puts [inPlayerId] from the bench on [place]; whoever stood there goes
  /// to the bench (E5.2). Example: place 2 (RL), Tom in → Max to the bench.
  Future<void> substitute(
      int gameId, String tickerCode, Side side, int place, String inPlayerId);

  /// Puts [playerId] in goal after the goalkeeper got a penalty (E5.6).
  ///
  /// A field player moves into goal and leaves their place empty. A goalkeeper
  /// from the bench comes in for [outPlayerId], whose place stays empty.
  Future<void> putInGoal(
      int gameId, String tickerCode, Side side, String playerId,
      {String? outPlayerId});

  /// Starts the clock when it stands, stops it when it runs (U1).
  Future<void> toggleClock(int gameId, String tickerCode);
}
