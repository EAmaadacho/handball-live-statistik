import 'game_clock.dart';
import 'game_event.dart';
import 'game_team.dart';
import 'lineup.dart';
import 'player.dart';
import 'rule_violation.dart';
import 'score.dart';

/// A game between two teams with its clock, starting lineups and events.
///
/// Only the starting lineups and the events are stored. Score, half-time
/// score and the current lineup are always computed from them (ADR-006).
/// Example: Max scores at 11:10, the score becomes 12:10; deleting that goal
/// brings back 11:10.
class Game {
  final GameTeam home;
  final GameTeam away;
  final GameClock clock;
  final Lineup? homeStartingLineup;
  final Lineup? awayStartingLineup;
  final List<GameEvent> events;
  final int nextEventNumber;

  Game._({
    required this.home,
    required this.away,
    required this.clock,
    required this.homeStartingLineup,
    required this.awayStartingLineup,
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
      homeStartingLineup: null,
      awayStartingLineup: null,
      events: const [],
      nextEventNumber: 1,
    );
  }

  /// Sets the starting lineup of one team before kick-off (E5.1).
  ///
  /// Example: Nora in goal, Max, Lisa, Ben, Paul, Finn and Leon in the field.
  Game setLineup(Side side, String goalkeeperId, List<String> fieldPlayerIds) {
    if (clock.phase != ClockPhase.notStarted) {
      throw const RuleViolation('Nach dem Anpfiff bitte wechseln.');
    }
    final team = teamOf(side);
    final ids = {goalkeeperId, ...fieldPlayerIds};
    if (fieldPlayerIds.length != 6 || ids.length != 7) {
      throw const RuleViolation(
          'Bitte 7 verschiedene Spieler aufstellen: 1 Torwart, 6 Feldspieler.');
    }
    if (!ids.every(team.hasPlayer)) {
      throw RuleViolation('Ein Spieler gehört nicht zu ${team.name}.');
    }
    if (team.playerById(goalkeeperId)!.position != Position.goalkeeper) {
      throw const RuleViolation('Ins Tor darf nur ein Torwart.');
    }
    final lineup =
        Lineup(goalkeeperId: goalkeeperId, fieldPlayerIds: fieldPlayerIds);
    return side == Side.home
        ? _copy(homeStartingLineup: lineup)
        : _copy(awayStartingLineup: lineup);
  }

  /// The lineup of [side] right now: starting lineup plus all substitutions.
  Lineup? lineupOf(Side side) {
    var lineup = side == Side.home ? homeStartingLineup : awayStartingLineup;
    if (lineup == null) return null;
    for (final event in events) {
      if (event.type == EventType.substitution && event.side == side) {
        final incoming = teamOf(side).playerById(event.incomingPlayerId!)!;
        lineup = lineup!.substitute(event.playerId!, incoming);
      }
    }
    return lineup;
  }

  /// The goalkeeper of [side] on the field right now, or `null` (E1.2).
  String? activeGoalkeeperOf(Side side) => lineupOf(side)?.goalkeeperId;

  /// Swaps a player on the field for one from the bench (E5.2).
  ///
  /// Stored as an event with game time (E5.3). Example: Max out, Tom in.
  /// A substitution cannot be deleted; a mistake is undone by swapping back.
  Game substitute(Side side, String outId, String inId, DateTime now) {
    _checkGameIsRunning();
    final team = teamOf(side);
    final lineup = lineupOf(side)!;
    if (!lineup.isOnField(outId)) {
      throw const RuleViolation('Dieser Spieler steht nicht auf dem Feld.');
    }
    if (!team.hasPlayer(inId)) {
      throw RuleViolation('Der Spieler gehört nicht zu ${team.name}.');
    }
    if (lineup.isOnField(inId)) {
      throw const RuleViolation('Dieser Spieler steht schon auf dem Feld.');
    }
    _checkNotDisqualified(side, inId);
    return _append(GameEvent(
      number: nextEventNumber,
      type: EventType.substitution,
      side: side,
      playerId: outId,
      incomingPlayerId: inId,
      gameTime: clock.gameTime(now),
      half: _half,
    ));
  }

  /// Records an event at the current game time (E1).
  ///
  /// The server stamps the time, not the browser. Shots and technical
  /// faults need a player on the field; cards and penalties may also go to
  /// the bench (R7). Goals and saves store the opposing goalkeeper on the
  /// field (E1.2). A timeout has no player and stops the clock (U3.1).
  Game record(EventType type, Side side, String? playerId, DateTime now) {
    _checkGameIsRunning();
    if (type == EventType.substitution) {
      throw const RuleViolation('Wechsel bitte über „Wechseln“.');
    }
    final isTimeout = type == EventType.timeout;
    if (isTimeout && playerId != null) {
      throw const RuleViolation(
          'Eine Auszeit gehört zum Team, nicht zu einem Spieler.');
    }
    if (!isTimeout && playerId == null) {
      throw const RuleViolation('Bitte einen Spieler wählen.');
    }
    final team = teamOf(side);
    if (playerId != null && !team.hasPlayer(playerId)) {
      throw RuleViolation('Der Spieler gehört nicht zu ${team.name}.');
    }
    if (playerId != null) _checkNotDisqualified(side, playerId);
    if (isTimeout) _checkTimeoutAllowed(side, now);
    if (_needsPlayerOnField(type) && !lineupOf(side)!.isOnField(playerId!)) {
      throw const RuleViolation('Dieser Spieler steht nicht auf dem Feld.');
    }
    final defender = opponentOf(side);
    final goalkeeperId = activeGoalkeeperOf(defender);
    if (type == EventType.save && goalkeeperId == null) {
      throw RuleViolation(
          '${teamOf(defender).name} hat keinen Torwart auf dem Feld.');
    }
    final event = GameEvent(
      number: nextEventNumber,
      type: type,
      side: side,
      playerId: playerId,
      goalkeeperId: _storesGoalkeeper(type) ? goalkeeperId : null,
      gameTime: clock.gameTime(now),
      half: _half,
    );
    final stopClock = isTimeout && clock.isRunningAt(now);
    return _append(event, clock: stopClock ? clock.stop(now) : clock);
  }

  /// Deletes the event with [number] after a typing mistake (E2).
  ///
  /// The number is never given out again. Substitutions cannot be deleted.
  Game deleteEvent(int number) {
    if (clock.phase == ClockPhase.finished) {
      throw const RuleViolation('Das Spiel ist beendet.');
    }
    final matches = events.where((e) => e.number == number);
    if (matches.isEmpty) {
      throw const RuleViolation('Ereignis nicht gefunden.');
    }
    if (matches.single.type == EventType.substitution) {
      throw const RuleViolation(
          'Ein Wechsel lässt sich nicht löschen. Bitte zurückwechseln.');
    }
    return _copy(events: events.where((e) => e.number != number).toList());
  }

  /// Whether the player is disqualified: a red card or a third
  /// two-minute penalty (R2).
  ///
  /// Computed from the events, never stored. Deleting Max's third penalty
  /// lifts his disqualification at once (E2.2).
  bool isDisqualified(Side side, String playerId) {
    final own = events.where((e) => e.side == side && e.playerId == playerId);
    return own.any((e) => e.type == EventType.redCard) ||
        own.where((e) => e.type == EventType.twoMinutes).length >= 3;
  }

  /// The current score, computed from goals and 7-metre goals (E1.1).
  Score get score => _scoreOf(events);

  /// The score at half-time: only events of the first half (U5.1).
  Score get halfTimeScore => _scoreOf(events.where((e) => e.half == 1));

  GameTeam teamOf(Side side) => side == Side.home ? home : away;

  /// Starts the clock. Kick-off needs both starting lineups (E5.1).
  Game startClock(DateTime now) {
    if (clock.phase == ClockPhase.notStarted &&
        (homeStartingLineup == null || awayStartingLineup == null)) {
      throw const RuleViolation('Bitte zuerst beide Teams aufstellen.');
    }
    return _copy(clock: clock.start(now));
  }

  Game stopClock(DateTime now) => _copy(clock: clock.stop(now));

  Game adjustClock(Duration newTime, DateTime now) =>
      _copy(clock: clock.adjust(newTime, now));

  Game halfTime(DateTime now) => _copy(clock: clock.halfTime(now));

  Game end(DateTime now) => _copy(clock: clock.end(now));

  int get _half => clock.phase == ClockPhase.secondHalf ? 2 : 1;

  static bool _needsPlayerOnField(EventType type) => const {
        EventType.goal,
        EventType.miss,
        EventType.save,
        EventType.sevenMeterGoal,
        EventType.sevenMeterMiss,
        EventType.technicalFault,
      }.contains(type);

  static bool _storesGoalkeeper(EventType type) => const {
        EventType.goal,
        EventType.sevenMeterGoal,
        EventType.save,
      }.contains(type);

  void _checkNotDisqualified(Side side, String playerId) {
    if (isDisqualified(side, playerId)) {
      final player = teamOf(side).playerById(playerId)!;
      throw RuleViolation('${player.firstName} ist disqualifiziert.');
    }
  }

  /// Timeout rules R1: at most 3 per game, 2 per half and 1 in the last
  /// 5 minutes (from 55:00 with 30-minute halves).
  void _checkTimeoutAllowed(Side side, DateTime now) {
    final timeouts =
        events.where((e) => e.side == side && e.type == EventType.timeout);
    if (timeouts.length >= 3) {
      throw RuleViolation('${teamOf(side).name} hat keine Auszeit mehr.');
    }
    if (timeouts.where((e) => e.half == _half).length >= 2) {
      throw const RuleViolation('Nur 2 Auszeiten pro Halbzeit.');
    }
    final lastFiveMinutes = clock.halfLength * 2 - const Duration(minutes: 5);
    if (clock.gameTime(now) >= lastFiveMinutes &&
        timeouts.any((e) => e.gameTime >= lastFiveMinutes)) {
      throw const RuleViolation('In den letzten 5 Minuten nur eine Auszeit.');
    }
  }

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

  Game _append(GameEvent event, {GameClock? clock}) => _copy(
        clock: clock,
        events: [...events, event],
        nextEventNumber: nextEventNumber + 1,
      );

  Game _copy({
    GameClock? clock,
    Lineup? homeStartingLineup,
    Lineup? awayStartingLineup,
    List<GameEvent>? events,
    int? nextEventNumber,
  }) {
    return Game._(
      home: home,
      away: away,
      clock: clock ?? this.clock,
      homeStartingLineup: homeStartingLineup ?? this.homeStartingLineup,
      awayStartingLineup: awayStartingLineup ?? this.awayStartingLineup,
      events: events ?? this.events,
      nextEventNumber: nextEventNumber ?? this.nextEventNumber,
    );
  }
}
