import 'game_clock.dart';
import 'game_event.dart';
import 'game_team.dart';
import 'rule_violation.dart';
import 'score.dart';

/// A game between two teams with its clock and its list of events.
///
/// Only the events are stored. Score and half-time score are always
/// computed from them (ADR-006). Example: Max scores at 11:10, the score
/// becomes 12:10; deleting that goal brings back 11:10.
class Game {
  final GameTeam home;
  final GameTeam away;
  final GameClock clock;
  final List<GameEvent> events;
  final int nextEventNumber;

  Game._({
    required this.home,
    required this.away,
    required this.clock,
    required List<GameEvent> events,
    required this.nextEventNumber,
  }) : events = List.unmodifiable(events);

  /// A new game before kick-off, e.g. TV Mettmann against HSG Hilden.
  factory Game.create({
    required GameTeam home,
    required GameTeam away,
    Duration halfLength = const Duration(minutes: 30),
  }) {
    return Game._(
      home: home,
      away: away,
      clock: GameClock.initial(halfLength: halfLength),
      events: const [],
      nextEventNumber: 1,
    );
  }

  /// Records an event at the current game time (E1).
  ///
  /// The server stamps the time, not the browser. A timeout has no player
  /// and stops the clock (U3.1). Example: goal by Max at 15:23:14 after
  /// kick-off at 15:00:00 is stored with game time 23:14.
  Game record(EventType type, Side side, String? playerId, DateTime now) {
    _checkGameIsRunning();
    final isTimeout = type == EventType.timeout;
    if (isTimeout && playerId != null) {
      throw const RuleViolation(
          'Eine Auszeit gehört zum Team, nicht zu einem Spieler.');
    }
    if (!isTimeout && playerId == null) {
      throw const RuleViolation('Bitte einen Spieler wählen.');
    }
    if (playerId != null && !teamOf(side).hasPlayer(playerId)) {
      throw RuleViolation('Der Spieler gehört nicht zu ${teamOf(side).name}.');
    }
    final event = GameEvent(
      number: nextEventNumber,
      type: type,
      side: side,
      playerId: playerId,
      gameTime: clock.gameTime(now),
      half: clock.phase == ClockPhase.secondHalf ? 2 : 1,
    );
    final stopClock = isTimeout && clock.isRunningAt(now);
    return _copy(
      clock: stopClock ? clock.stop(now) : clock,
      events: [...events, event],
      nextEventNumber: nextEventNumber + 1,
    );
  }

  /// Deletes the event with [number] after a typing mistake (E2).
  ///
  /// The number is never given out again.
  Game deleteEvent(int number) {
    if (clock.phase == ClockPhase.finished) {
      throw const RuleViolation('Das Spiel ist beendet.');
    }
    if (!events.any((e) => e.number == number)) {
      throw const RuleViolation('Ereignis nicht gefunden.');
    }
    return _copy(events: events.where((e) => e.number != number).toList());
  }

  /// The current score, computed from goals and 7-metre goals (E1.1).
  Score get score => _scoreOf(events);

  /// The score at half-time: only events of the first half (U5.1).
  Score get halfTimeScore => _scoreOf(events.where((e) => e.half == 1));

  GameTeam teamOf(Side side) => side == Side.home ? home : away;

  Game startClock(DateTime now) => _copy(clock: clock.start(now));

  Game stopClock(DateTime now) => _copy(clock: clock.stop(now));

  Game adjustClock(Duration newTime, DateTime now) =>
      _copy(clock: clock.adjust(newTime, now));

  Game halfTime(DateTime now) => _copy(clock: clock.halfTime(now));

  Game end(DateTime now) => _copy(clock: clock.end(now));

  void _checkGameIsRunning() {
    if (clock.phase == ClockPhase.notStarted) {
      throw const RuleViolation('Das Spiel hat noch nicht begonnen.');
    }
    if (clock.phase == ClockPhase.finished) {
      throw const RuleViolation('Das Spiel ist beendet.');
    }
  }

  static Score _scoreOf(Iterable<GameEvent> events) => Score(
        events.where((e) => e.isGoalFor(Side.home)).length,
        events.where((e) => e.isGoalFor(Side.away)).length,
      );

  Game _copy({
    GameClock? clock,
    List<GameEvent>? events,
    int? nextEventNumber,
  }) {
    return Game._(
      home: home,
      away: away,
      clock: clock ?? this.clock,
      events: events ?? this.events,
      nextEventNumber: nextEventNumber ?? this.nextEventNumber,
    );
  }
}
