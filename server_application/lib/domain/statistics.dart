import 'game_event.dart';
import 'game_team.dart';
import 'rules.dart';

/// The statistics of one player in one game (L2).
///
/// Everything is counted from the events, nothing is stored (ADR-006).
/// Example: Max scores 4 of 5 seven-metre throws → 7-metre percentage 80 %.
class PlayerStatistics {
  final String playerId;
  final int goals;
  final int shots;
  final int sevenMeterGoals;
  final int sevenMeters;
  final int technicalFaults;
  final int yellowCards;
  final int twoMinutes;
  final int redCards;
  final int saves;
  final int goalsAgainst;

  const PlayerStatistics({
    required this.playerId,
    required this.goals,
    required this.shots,
    required this.sevenMeterGoals,
    required this.sevenMeters,
    required this.technicalFaults,
    required this.yellowCards,
    required this.twoMinutes,
    required this.redCards,
    required this.saves,
    required this.goalsAgainst,
  });

  /// Goals per shot, 7-metre throws included, e.g. 2 of 3 → 67.
  /// `null` without any shot, shown as "–".
  int? get shootingPercentage => percentage(goals, shots);

  /// 7-metre goals per 7-metre throw (L2.1).
  int? get sevenMeterPercentage => percentage(sevenMeterGoals, sevenMeters);

  /// Saves per shot on goal for a goalkeeper (L2.2): Nora saves 12 and
  /// lets in 18 → 40.
  int? get savePercentage => percentage(saves, saves + goalsAgainst);
}

/// [part] of [whole] in whole percent, rounded: 2 of 3 → 67.
/// `null` when [whole] is 0.
int? percentage(int part, int whole) =>
    whole == 0 ? null : (part * 100 / whole).round();

/// The statistics of every player in the game squad of [side] (L2).
List<PlayerStatistics> computeStatistics(
    List<GameEvent> events, Side side, GameTeam team) {
  return [for (final player in team.squad) _forPlayer(events, side, player.id)];
}

PlayerStatistics _forPlayer(List<GameEvent> events, Side side, String id) {
  final own = events.where((e) => e.side == side && e.playerId == id);
  final against = events.where((e) => e.side != side && e.goalkeeperId == id);
  int count(Iterable<GameEvent> list, Set<EventType> types) =>
      list.where((e) => types.contains(e.type)).length;

  return PlayerStatistics(
    playerId: id,
    goals: count(own, {EventType.goal, EventType.sevenMeterGoal}),
    shots: count(own, {
      EventType.goal,
      EventType.miss,
      EventType.save,
      EventType.sevenMeterGoal,
      EventType.sevenMeterMiss,
    }),
    sevenMeterGoals: count(own, {EventType.sevenMeterGoal}),
    sevenMeters:
        count(own, {EventType.sevenMeterGoal, EventType.sevenMeterMiss}),
    technicalFaults: count(own, {EventType.technicalFault}),
    yellowCards: count(own, {EventType.yellowCard}),
    twoMinutes: count(own, {EventType.twoMinutes}),
    redCards: isDisqualified(events, side, id) ? 1 : 0,
    saves: count(against, {EventType.save}),
    goalsAgainst: count(against, {EventType.goal, EventType.sevenMeterGoal}),
  );
}
