/// The two teams of a game. Home is always left on the field (E5).
enum Side { home, away }

/// What can happen in a game (E1).
enum EventType {
  goal,
  miss,
  save,
  sevenMeterGoal,
  sevenMeterMiss,
  twoMinutes,
  yellowCard,
  redCard,
  technicalFault,
  timeout,
  substitution,

  /// A field player on the field moves into the empty goal (E5.7).
  movesIntoGoal,
}

/// One thing that happened in a game, stamped by the server with the game
/// time (E1, ADR-006).
///
/// Example: event 14, goal by Max (home) at 23:14 in the first half.
/// A timeout belongs to the team, so it has no player.
/// A save is stored on the shooter: "Parade" on Jan Becker of Hilden is a
/// shot of Jan saved by Mettmann's goalkeeper (E1.3).
///
/// [goalkeeperId] is the opposing goalkeeper on the field at that moment,
/// stored with goals and saves (E1.2). It is `null` for an empty goal (E1.5).
/// A substitution stores the player going out in [playerId] and the player
/// coming in in [incomingPlayerId] (E5.3). Without [playerId] the player
/// comes in on a free place, e.g. after a penalty has run out.
/// [incomingInGoal] says whether the incoming player took the goal slot.
/// "Ins Tor" stores in [playerId] the field player who moves into goal.
/// A two-minute penalty or a red card stores in [leavingPlayerId] who leaves
/// the field: the punished player, or a field player for a punished
/// player on the bench (E5.4).
class GameEvent {
  final int number;
  final EventType type;
  final Side side;
  final String? playerId;
  final String? incomingPlayerId;
  final String? leavingPlayerId;
  final String? goalkeeperId;
  final bool incomingInGoal;
  final Duration gameTime;
  final int half;

  const GameEvent({
    required this.number,
    required this.type,
    required this.side,
    required this.playerId,
    this.incomingPlayerId,
    this.leavingPlayerId,
    this.goalkeeperId,
    this.incomingInGoal = false,
    required this.gameTime,
    required this.half,
  });

  /// Whether this event is a goal for [side]: goal or 7-metre goal.
  bool isGoalFor(Side side) =>
      this.side == side &&
      (type == EventType.goal || type == EventType.sevenMeterGoal);
}

/// The other team: home → away, away → home.
Side opponentOf(Side side) => side == Side.home ? Side.away : Side.home;
