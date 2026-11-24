import 'models.dart';

/// [stats] with [event] counted once more (times 1) or taken away (-1),
/// as the server counts them (ADR-006).
///
/// Example: a goal of Max against Jonas in goal adds 1 goal and 1 shot for
/// Max and 1 goal against for Jonas ([goalkeeperId], E1.2).
/// A save counts as a shot for the shooter and a save for the goalkeeper.
Map<String, PlayerStats> statsWithEvent(
    Map<String, PlayerStats> stats, GameEvent event,
    {String? goalkeeperId, int times = 1}) {
  final result = {...stats};
  void add(String? id, PlayerStats change) {
    if (id != null) {
      result[id] = (result[id] ?? PlayerStats.none).plus(change, times);
    }
  }

  switch (event.kind) {
    case EventKind.goal:
      add(event.playerId, const PlayerStats(goals: 1, shots: 1));
      add(goalkeeperId, const PlayerStats(goalsAgainst: 1));
    case EventKind.sevenMeterGoal:
      add(
          event.playerId,
          const PlayerStats(
              goals: 1, shots: 1, sevenMeterGoals: 1, sevenMeterShots: 1));
      add(goalkeeperId, const PlayerStats(goalsAgainst: 1));
    case EventKind.save:
      add(event.playerId, const PlayerStats(shots: 1));
      add(goalkeeperId, const PlayerStats(saves: 1));
    case EventKind.miss:
      add(event.playerId, const PlayerStats(shots: 1));
    case EventKind.sevenMeterMiss:
      add(event.playerId, const PlayerStats(shots: 1, sevenMeterShots: 1));
    case EventKind.technicalFault:
      add(event.playerId, const PlayerStats(technicalFaults: 1));
    case EventKind.yellowCard:
      add(event.playerId, const PlayerStats(yellowCards: 1));
    case EventKind.twoMinutes:
      add(event.playerId, const PlayerStats(twoMinutes: 1));
    case EventKind.redCard:
      add(event.playerId, const PlayerStats(redCards: 1));
    case EventKind.timeout:
      break;
  }
  return result;
}
