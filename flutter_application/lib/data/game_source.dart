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
/// [ApiGameSource] asks the server, e.g. loadGame('ydVsnTnc') →
/// GET /games/ydVsnTnc. [DemoGameSource] answers the same questions from
/// memory, for the tests and without a server.
///
/// The methods for the ticker need the secret [tickerCode] (ADR-005). They
/// throw [RejectedAction] when a rule forbids the action.
abstract class GameSource {
  /// The game with [id], or null if there is none.
  Future<Game?> loadGame(String id);

  /// The team that belongs to the secret [teamCode], or null (ADR-005).
  Future<Team?> loadTeamByCode(String teamCode);

  /// What happens in game [id] right now, or null if there is no such game.
  Future<GameState?> loadState(String id);

  /// Whether [tickerCode] allows ticking game [gameId] (ADR-005).
  Future<bool> isTickerCode(String gameId, String tickerCode);

  /// Records an event; the server adds the game time (E1, ADR-003).
  ///
  /// Example: record('17', code, EventKind.goal, Side.home, playerId: 'max7')
  /// → the event "38:12 Tor · 7 Max Mustermann".
  /// A timeout has no player and stops the clock (U3).
  ///
  /// 2 minutes or red for a player on the bench: [leavingPlayerId] is the
  /// field player who goes off instead, so the team plays one short (E5.4).
  Future<GameEvent> record(
      String gameId, String tickerCode, EventKind kind, Side side,
      {String? playerId, String? leavingPlayerId});

  /// Deletes event [number] after a typing mistake (E2).
  Future<void> deleteEvent(String gameId, String tickerCode, int number);

  /// Puts [inPlayerId] from the bench on [place]; whoever stood there goes
  /// to the bench (E5.2). Example: place 2 (RL), Tom in → Max to the bench.
  ///
  /// On the goal place (TH) [intoGoal] says whether the player comes in as
  /// goalkeeper (true) or as extra field player with an empty goal (false).
  /// Null keeps the squad role: a goalkeeper goes in goal, a field player
  /// leaves it empty (E1.5, IHF rule 4:7).
  Future<void> substitute(
      String gameId, String tickerCode, Side side, int place, String inPlayerId,
      {bool? intoGoal});

  /// Puts [playerId], who stands on the field, in the empty goal; from then
  /// on saves and goals against count for them (E5.6, IHF rule 4:7).
  /// Example: Nora got red, Max goes in goal with a goalkeeper shirt.
  ///
  /// A goalkeeper from the bench comes in with [substitute] instead and
  /// takes the empty goal right away.
  Future<void> putInGoal(
      String gameId, String tickerCode, Side side, String playerId);

  /// Sets the starting lineup of [side] before kick-off (E5.1, E5.5).
  ///
  /// Example: Nora in goal, Paul, Max, Lisa, Finn, Jonas and Ben in the
  /// field, in the order of the places LA, RL, RM, KL, RR, RA.
  /// Any player may start in goal (IHF rule 4:7).
  Future<void> setLineup(String gameId, String tickerCode, Side side,
      String goalkeeperId, List<String> fieldPlayerIds);

  /// Puts a squad player of a registered team on the match report, e.g.
  /// Leon comes late (S1.4). Refused for a 17th player.
  Future<void> addToMatchReport(
      String gameId, String tickerCode, Side side, String playerId);

  /// Adds a new player to the game squad of an opponent without
  /// registration and to the match report (S1.1, S1.4), e.g. "20 Ole Brandt".
  Future<Player> addSquadPlayer(String gameId, String tickerCode, Side side,
      int number, String firstName, String lastName);

  /// Takes [playerId] off the match report, only before kick-off (S1.4).
  ///
  /// Example: Mettmann has 18 players in the squad; the first 16 by number
  /// are on the report, the ticker takes out who does not play today.
  /// After kick-off a player on the report stays there.
  Future<void> removeFromMatchReport(
      String gameId, String tickerCode, Side side, String playerId);

  /// Starts the clock when it stands, stops it when it runs (U1).
  /// The first start is the kick-off; both lineups must be set before.
  /// A start during half time begins the second half.
  Future<void> toggleClock(String gameId, String tickerCode);

  /// Ends the first half, the clock goes to 30:00 (U5.1).
  Future<void> halfTime(String gameId, String tickerCode);

  /// Ends the game at the current game time (U5.2).
  Future<void> endGame(String gameId, String tickerCode);
}
