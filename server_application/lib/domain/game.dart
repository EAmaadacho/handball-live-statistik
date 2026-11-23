import 'game_clock.dart';
import 'game_event.dart';
import 'game_team.dart';
import 'lineup.dart';
import 'player.dart';
import 'rule_violation.dart';
import 'rules.dart' as rules;
import 'score.dart';
import 'statistics.dart';

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

  GameTeam teamOf(Side side) => side == Side.home ? home : away;

  // ---------------------------------------------------------------------
  // Lineup and substitutions (E5)
  // ---------------------------------------------------------------------

  /// Sets the starting lineup of one team before kick-off (E5.1).
  ///
  /// Example: Nora in goal, Max, Lisa, Ben, Paul, Finn and Leon in the field.
  /// Any player of the squad may start in goal, also a field player (E5.7).
  Game setLineup(Side side, String goalkeeperId, List<String> fieldPlayerIds) {
    if (clock.phase != ClockPhase.notStarted) {
      throw const RuleViolation('Nach dem Anpfiff bitte wechseln.');
    }
    final team = teamOf(side);
    final ids = {goalkeeperId, ...fieldPlayerIds};
    if (fieldPlayerIds.length != 6 || ids.length != 7) {
      throw const RuleViolation(
          'Bitte 7 verschiedene Spieler aufstellen: 1 im Tor, 6 im Feld.');
    }
    if (!ids.every(team.hasPlayer)) {
      throw RuleViolation('Ein Spieler gehört nicht zu ${team.name.display}.');
    }
    final lineup =
        Lineup(goalkeeperId: goalkeeperId, fieldPlayerIds: fieldPlayerIds);
    return side == Side.home
        ? _copy(homeStartingLineup: lineup)
        : _copy(awayStartingLineup: lineup);
  }

  /// The lineup of [side] right now: the starting lineup replayed through
  /// all events of [side] (ADR-006), `null` before the lineup is set.
  ///
  /// Every stored event was checked when it was added, so the replay fits.
  Lineup? lineupOf(Side side) => _replayLineup(side, events);

  /// Who stands in the goal of [side] right now, or `null` (E1.2).
  String? activeGoalkeeperOf(Side side) => lineupOf(side)?.goalkeeperId;

  /// Swaps a player on the field for one from the bench (E5.2).
  ///
  /// Stored as an event with game time (E5.3). Example: Max out, Tom in.
  /// A substitution cannot be deleted; a mistake is undone by swapping back.
  ///
  /// [intoGoal] says whether [inId] goes into the goal, which must be free
  /// then. Without it, a goalkeeper of the squad takes a free goal and a
  /// field player plays in the field (E1.5, E5.6).
  Game substitute(Side side, String outId, String inId, DateTime now,
      {bool? intoGoal}) {
    _checkGameIsRunning();
    final lineup = lineupOf(side)!;
    _checkOnField(lineup, outId);
    _checkCanComeIn(side, lineup, inId);
    return _append(GameEvent(
      number: nextEventNumber,
      type: EventType.substitution,
      side: side,
      playerId: outId,
      incomingPlayerId: inId,
      incomingInGoal: _goesIntoGoal(side, lineup, outId, inId, intoGoal),
      gameTime: clock.gameTime(now),
      half: _half,
    ));
  }

  /// Brings [inId] onto a free place, e.g. after Max's penalty has run out.
  ///
  /// The ticker decides who comes back; it need not be Max. Rejected while
  /// the team still plays short-handed (R7). [intoGoal] works as for
  /// [substitute].
  Game bringOn(Side side, String inId, DateTime now, {bool? intoGoal}) {
    _checkGameIsRunning();
    final lineup = lineupOf(side)!;
    _checkCanComeIn(side, lineup, inId);
    if (!lineup.hasFreePlace) {
      throw const RuleViolation('Auf dem Feld ist kein Platz frei.');
    }
    final gameTime = clock.gameTime(now);
    if (lineup.playerIds.length >=
        rules.allowedOnField(events, side, gameTime)) {
      throw RuleViolation(
          '${teamOf(side).name.display} ist noch in Unterzahl.');
    }
    return _append(GameEvent(
      number: nextEventNumber,
      type: EventType.comesOn,
      side: side,
      playerId: null,
      incomingPlayerId: inId,
      incomingInGoal: _goesIntoGoal(side, lineup, null, inId, intoGoal),
      gameTime: gameTime,
      half: _half,
    ));
  }

  /// Field player [playerId] moves into the empty goal of [side] (E5.7).
  ///
  /// Example: Lea is out for two minutes and no other goalkeeper is left,
  /// so Max goes into goal in a goalkeeper shirt. From then on saves and
  /// goals against count for Max. Like a substitution it cannot be deleted.
  Game putInGoal(Side side, String playerId, DateTime now) {
    _checkGameIsRunning();
    final lineup = lineupOf(side)!;
    _checkOnField(lineup, playerId);
    _checkGoalIsFree(side, lineup, null);
    return _append(GameEvent(
      number: nextEventNumber,
      type: EventType.movesIntoGoal,
      side: side,
      playerId: playerId,
      gameTime: clock.gameTime(now),
      half: _half,
    ));
  }

  // ---------------------------------------------------------------------
  // Events (E1, E2)
  // ---------------------------------------------------------------------

  /// Records an event at the current game time (E1).
  ///
  /// The server stamps the time, not the browser. Shots and technical
  /// faults need a player on the field; cards and penalties may also go to
  /// the bench (R7). Goals and saves store the goalkeeper in the opposing
  /// goal (E1.2). A timeout has no player and stops the clock (U3.1).
  ///
  /// Two minutes or red send the player off the field (E5.4). For a player
  /// on the bench, the ticker names in [leavingPlayerId] the field player
  /// who has to go off instead.
  Game record(EventType type, Side side, String? playerId, DateTime now,
      {String? leavingPlayerId}) {
    _checkGameIsRunning();
    _checkRecordable(type, playerId);
    final gameTime = clock.gameTime(now);
    if (type == EventType.timeout) {
      _checkTimeoutAllowed(side, gameTime);
    } else {
      _checkMayGetEvent(side, playerId!, type);
    }
    final event = GameEvent(
      number: nextEventNumber,
      type: type,
      side: side,
      playerId: playerId,
      goalkeeperId: _goalkeeperFacing(type, side),
      leavingPlayerId: rules.isPenalty(type)
          ? _whoLeaves(side, playerId!, leavingPlayerId)
          : null,
      gameTime: gameTime,
      half: _half,
    );
    final stopClock = type == EventType.timeout && clock.isRunningAt(now);
    return _append(event, clock: stopClock ? clock.stop(now) : clock);
  }

  /// Deletes the event with [number] after a typing mistake (E2).
  ///
  /// The number is never given out again. Lineup changes cannot be deleted.
  /// Deleting a penalty is rejected if a later lineup change depends on it.
  Game deleteEvent(int number) {
    if (clock.phase == ClockPhase.finished) {
      throw const RuleViolation('Das Spiel ist beendet.');
    }
    final matches = events.where((e) => e.number == number);
    if (matches.isEmpty) {
      throw const RuleViolation('Ereignis nicht gefunden.');
    }
    final event = matches.single;
    if (rules.isLineupChange(event.type)) {
      throw const RuleViolation(
          'Ein Wechsel lässt sich nicht löschen. Bitte zurückwechseln.');
    }
    final remaining = events.where((e) => e.number != number).toList();
    if (_replayLineup(event.side, remaining) == null) {
      throw const RuleViolation(
          'Löschen geht nicht mehr, danach wurde schon gewechselt.');
    }
    return _copy(events: remaining);
  }

  // ---------------------------------------------------------------------
  // Computed from the events (ADR-006)
  // ---------------------------------------------------------------------

  /// The current score, computed from goals and 7-metre goals (E1.1).
  Score get score => _scoreOf(events);

  /// The score at half-time: only events of the first half (U5.1).
  Score get halfTimeScore => _scoreOf(events.where((e) => e.half == 1));

  /// Whether the player is disqualified (R2), see [rules.isDisqualified].
  bool isDisqualified(Side side, String playerId) =>
      rules.isDisqualified(events, side, playerId);

  /// Penalties still running at [now], with remaining time (L3).
  List<rules.RunningPenalty> runningPenalties(DateTime now) =>
      rules.runningPenalties(events, clock.gameTime(now));

  /// Whether [side] plays short-handed at [now], e.g. "TV Mettmann in
  /// Unterzahl" (L3).
  bool isShortHanded(Side side, DateTime now) =>
      runningPenalties(now).any((p) => p.side == side);

  /// The statistics of every player of [side] (L2), e.g. Max: 8 goals
  /// from 10 shots (80 %).
  List<PlayerStatistics> statisticsOf(Side side) =>
      computeStatistics(events, side, teamOf(side));

  // ---------------------------------------------------------------------
  // Clock (U1–U5), see [GameClock]
  // ---------------------------------------------------------------------

  /// Starts the clock. Kick-off needs both starting lineups (E5.1).
  Game startClock(DateTime now) {
    if (clock.phase == ClockPhase.notStarted &&
        (homeStartingLineup == null || awayStartingLineup == null)) {
      throw const RuleViolation('Bitte zuerst beide Teams aufstellen.');
    }
    return _copy(clock: clock.start(now));
  }

  /// Stops the clock, e.g. for an injury (U1.1).
  Game stopClock(DateTime now) => _copy(clock: clock.stop(now));

  /// Sets the stopped clock to [newTime], e.g. back to 12:30 (U2).
  Game adjustClock(Duration newTime, DateTime now) =>
      _copy(clock: clock.adjust(newTime, now));

  /// Ends the first half at 30:00 (U5.1).
  Game halfTime() => _copy(clock: clock.halfTime());

  /// Ends the game; afterwards nothing can be recorded (U5.2, R4.2).
  Game end(DateTime now) => _copy(clock: clock.end(now));

  // ---------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------

  int get _half => clock.phase == ClockPhase.secondHalf ? 2 : 1;

  Lineup? _replayLineup(Side side, Iterable<GameEvent> events) {
    final start = side == Side.home ? homeStartingLineup : awayStartingLineup;
    return start?.replay(events.where((e) => e.side == side));
  }

  /// Lineup changes have their own actions; a timeout has no player, every
  /// other event needs one.
  void _checkRecordable(EventType type, String? playerId) {
    if (rules.isLineupChange(type)) {
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
  }

  /// R1, see [rules.checkTimeoutAllowed].
  void _checkTimeoutAllowed(Side side, Duration gameTime) =>
      rules.checkTimeoutAllowed(events,
          side: side,
          teamName: teamOf(side).name.display,
          gameTime: gameTime,
          half: _half,
          halfLength: clock.halfLength);

  /// The player belongs to [side], is not disqualified (R3) and, for shots
  /// and technical faults, stands on the field (R7).
  void _checkMayGetEvent(Side side, String playerId, EventType type) {
    _checkInSquad(side, playerId);
    _checkNotDisqualified(side, playerId);
    if (rules.needsPlayerOnField(type)) {
      _checkOnField(lineupOf(side)!, playerId);
    }
  }

  /// The goalkeeper in the opposing goal for goals and saves (E1.2),
  /// `null` for other events and for an empty goal (E1.5). A save on an
  /// empty goal is rejected (R5).
  String? _goalkeeperFacing(EventType type, Side side) {
    if (!rules.storesGoalkeeper(type)) return null;
    final defender = opponentOf(side);
    final goalkeeperId = activeGoalkeeperOf(defender);
    if (type == EventType.save && goalkeeperId == null) {
      throw RuleViolation(
          '${teamOf(defender).name.display} hat keinen Torwart auf dem Feld.');
    }
    return goalkeeperId;
  }

  /// Who goes off the field for a penalty of [playerId] (E5.4): he himself,
  /// or for a player on the bench the field player [chosen] by the ticker.
  String _whoLeaves(Side side, String playerId, String? chosen) {
    final lineup = lineupOf(side)!;
    if (lineup.isOnField(playerId)) return playerId;
    if (chosen == null) {
      throw const RuleViolation('Bitte wählen, wer das Feld verlässt.');
    }
    _checkOnField(lineup, chosen);
    return chosen;
  }

  /// Whether [inId] takes the goal when coming in for [outId] (`null` for a
  /// free place). An explicit [intoGoal] needs a free goal; without it a
  /// goalkeeper of the squad takes a free goal (E1.5, E5.6, E5.7).
  bool _goesIntoGoal(
      Side side, Lineup lineup, String? outId, String inId, bool? intoGoal) {
    if (intoGoal == true) _checkGoalIsFree(side, lineup, outId);
    final isGoalkeeper =
        teamOf(side).playerById(inId)!.position == Position.goalkeeper;
    return intoGoal ?? (isGoalkeeper && lineup.goalIsFreeWithout(outId));
  }

  /// [inId] may come onto the field: in the squad, not on the field yet and
  /// not disqualified (R3).
  void _checkCanComeIn(Side side, Lineup lineup, String inId) {
    _checkInSquad(side, inId);
    if (lineup.isOnField(inId)) {
      throw const RuleViolation('Dieser Spieler steht schon auf dem Feld.');
    }
    _checkNotDisqualified(side, inId);
  }

  void _checkInSquad(Side side, String playerId) {
    final team = teamOf(side);
    if (!team.hasPlayer(playerId)) {
      throw RuleViolation('Der Spieler gehört nicht zu ${team.name.display}.');
    }
  }

  void _checkOnField(Lineup lineup, String playerId) {
    if (!lineup.isOnField(playerId)) {
      throw const RuleViolation('Dieser Spieler steht nicht auf dem Feld.');
    }
  }

  /// Rejects when someone other than [outId] stands in goal, e.g.
  /// "Im Tor steht schon Nora."
  void _checkGoalIsFree(Side side, Lineup lineup, String? outId) {
    if (!lineup.goalIsFreeWithout(outId)) {
      final keeper = teamOf(side).playerById(lineup.goalkeeperId!)!;
      throw RuleViolation('Im Tor steht schon ${keeper.firstName}.');
    }
  }

  void _checkNotDisqualified(Side side, String playerId) {
    if (isDisqualified(side, playerId)) {
      final player = teamOf(side).playerById(playerId)!;
      throw RuleViolation('${player.firstName} ist disqualifiziert.');
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
