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
}

/// One thing that happened in a game, stamped by the server with the game
/// time (E1, ADR-006).
///
/// Example: event 14, goal by Max (home) at 23:14 in the first half.
/// A timeout belongs to the team, so it has no player.
/// A save is stored on the shooter: "Parade" on Jan Becker of Hilden is a
/// shot of Jan saved by Mettmann's goalkeeper (E1.3).
class GameEvent {
  final int number;
  final EventType type;
  final Side side;
  final String? playerId;
  final Duration gameTime;
  final int half;

  const GameEvent({
    required this.number,
    required this.type,
    required this.side,
    required this.playerId,
    required this.gameTime,
    required this.half,
  });

  /// Whether this event is a goal for [side]: goal or 7-metre goal.
  bool isGoalFor(Side side) =>
      this.side == side &&
      (type == EventType.goal || type == EventType.sevenMeterGoal);
}
