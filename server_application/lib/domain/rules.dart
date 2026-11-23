import 'game_event.dart';
import 'rule_violation.dart';

/// Handball rules that are checked on the list of events (R1–R3, R7, L3).
///
/// All functions are pure: events in, answer out. `Game` calls them.

/// How long a two-minute penalty or the team penalty after red lasts.
const penaltyLength = Duration(minutes: 2);

/// At most this many players of one team are in the match report (S1.4).
const maxMatchReport = 16;

/// At most this many players of one team stand on the field (R7).
const maxPlayersOnField = 7;

/// A penalty that is still running at the current game time (L3).
///
/// Example: Max gets two minutes at 23:00; at 24:37 the remaining time
/// is 0:23.
class RunningPenalty {
  final Side side;
  final String playerId;
  final Duration remaining;

  const RunningPenalty(this.side, this.playerId, this.remaining);
}

/// Whether the player is disqualified: a red card or a third
/// two-minute penalty (R2).
///
/// Computed from the events, never stored. Deleting Max's third penalty
/// lifts his disqualification at once (E2.2).
bool isDisqualified(List<GameEvent> events, Side side, String playerId) {
  final own = events.where((e) => e.side == side && e.playerId == playerId);
  return own.any((e) => e.type == EventType.redCard) ||
      own.where((e) => e.type == EventType.twoMinutes).length >= 3;
}

/// All penalties still running at [gameTime] (L3).
///
/// They run with the game clock, so they stand when the clock stands
/// (L3.1) and carry over half-time: two minutes at 29:00 end at 31:00
/// (L3.2). A red card means two minutes for the team too (L3.3).
List<RunningPenalty> runningPenalties(
    List<GameEvent> events, Duration gameTime) {
  return [
    for (final e in events)
      if (isPenalty(e.type) && e.gameTime + penaltyLength > gameTime)
        RunningPenalty(
            e.side, e.playerId!, e.gameTime + penaltyLength - gameTime),
  ];
}

/// How many players [side] may have on the field at [gameTime] (R7).
///
/// Example: Mettmann with Max's penalty running may have 6.
int allowedOnField(List<GameEvent> events, Side side, Duration gameTime) {
  final running =
      runningPenalties(events, gameTime).where((p) => p.side == side).length;
  return maxPlayersOnField - running;
}

/// Checks the timeout rules R1: at most 3 per game, 2 per half and 1 in
/// the last 5 minutes (from 55:00 with 30-minute halves).
void checkTimeoutAllowed(
  List<GameEvent> events, {
  required Side side,
  required String teamName,
  required Duration gameTime,
  required int half,
  required Duration halfLength,
}) {
  final timeouts =
      events.where((e) => e.side == side && e.type == EventType.timeout);
  if (timeouts.length >= 3) {
    throw RuleViolation('$teamName hat keine Auszeit mehr.');
  }
  if (timeouts.where((e) => e.half == half).length >= 2) {
    throw const RuleViolation('Nur 2 Auszeiten pro Halbzeit.');
  }
  final lastFiveMinutes = halfLength * 2 - const Duration(minutes: 5);
  if (gameTime >= lastFiveMinutes &&
      timeouts.any((e) => e.gameTime >= lastFiveMinutes)) {
    throw const RuleViolation('In den letzten 5 Minuten nur eine Auszeit.');
  }
}

/// Substitutions, coming on and "Ins Tor" change the lineup. They have
/// their own actions and cannot be deleted (E5.2, E5.3).
bool isLineupChange(EventType type) => const {
      EventType.substitution,
      EventType.comesOn,
      EventType.movesIntoGoal,
    }.contains(type);

/// Two minutes and red take a player off the field (E5.4, L3.3).
bool isPenalty(EventType type) =>
    type == EventType.twoMinutes || type == EventType.redCard;

/// Shots and technical faults need a player on the field; cards and
/// penalties may also go to the bench (R7).
bool needsPlayerOnField(EventType type) => const {
      EventType.goal,
      EventType.miss,
      EventType.save,
      EventType.sevenMeterGoal,
      EventType.sevenMeterMiss,
      EventType.technicalFault,
    }.contains(type);

/// Goals and saves store the opposing goalkeeper on the field (E1.2).
bool storesGoalkeeper(EventType type) => const {
      EventType.goal,
      EventType.sevenMeterGoal,
      EventType.save,
    }.contains(type);
