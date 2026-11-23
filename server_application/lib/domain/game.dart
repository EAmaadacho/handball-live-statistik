import 'game_clock.dart';
import 'game_event.dart';
import 'game_team.dart';
import 'lineup.dart';
import 'player.dart';
import 'rule_violation.dart';
import 'rules.dart' as rules;
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

  /// The lineup of [side] right now: starting lineup, then every
  /// substitution and every player sent off with a penalty, in order.
  Lineup? lineupOf(Side side) => _replayLineup(side, events);

  /// The goalkeeper of [side] on the field right now, or `null` (E1.2).
  String? activeGoalkeeperOf(Side side) => lineupOf(side)?.goalkeeperId;

  /// Swaps a player on the field for one from the bench (E5.2).
  ///
  /// Stored as an event with game time (E5.3). Example: Max out, Tom in.
  /// A substitution cannot be deleted; a mistake is undone by swapping back.
  Game substitute(Side side, String outId, String inId, DateTime now) {
    _checkGameIsRunning();
    if (!lineupOf(side)!.isOnField(outId)) {
      throw const RuleViolation('Dieser Spieler steht nicht auf dem Feld.');
    }
    _checkCanComeIn(side, inId);
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

  /// Brings [inId] onto a free place, e.g. after Max's penalty has run out.
  ///
  /// The ticker decides who comes back; it need not be Max. Rejected while
  /// the team still plays short-handed (R7).
  Game bringOn(Side side, String inId, DateTime now) {
    _checkGameIsRunning();
    _checkCanComeIn(side, inId);
    final onField = lineupOf(side)!.playerIds.length;
    if (onField >= rules.maxPlayersOnField) {
      throw const RuleViolation('Auf dem Feld ist kein Platz frei.');
    }
    final gameTime = clock.gameTime(now);
    if (onField >= rules.allowedOnField(events, side, gameTime)) {
      throw RuleViolation('${teamOf(side).name} ist noch in Unterzahl.');
    }
    return _append(GameEvent(
      number: nextEventNumber,
      type: EventType.substitution,
      side: side,
      playerId: null,
      incomingPlayerId: inId,
      gameTime: gameTime,
      half: _half,
    ));
  }

  /// Records an event at the current game time (E1).
  ///
  /// The server stamps the time, not the browser. Shots and technical
  /// faults need a player on the field; cards and penalties may also go to
  /// the bench (R7). Goals and saves store the opposing goalkeeper on the
  /// field (E1.2). A timeout has no player and stops the clock (U3.1).
  ///
  /// Two minutes or red send the player off the field (E5.4). For a player
  /// on the bench, the ticker names in [leavingPlayerId] the field player
  /// who has to go off instead.
  Game record(EventType type, Side side, String? playerId, DateTime now,
      {String? leavingPlayerId}) {
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
    if (isTimeout) {
      rules.checkTimeoutAllowed(events,
          side: side,
          teamName: team.name,
          gameTime: clock.gameTime(now),
          half: _half,
          halfLength: clock.halfLength);
    }
    final lineup = lineupOf(side)!;
    if (rules.needsPlayerOnField(type) && !lineup.isOnField(playerId!)) {
      throw const RuleViolation('Dieser Spieler steht nicht auf dem Feld.');
    }
    final leaving = rules.isPenalty(type)
        ? _whoLeaves(lineup, playerId!, leavingPlayerId)
        : null;
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
      goalkeeperId: rules.storesGoalkeeper(type) ? goalkeeperId : null,
      leavingPlayerId: leaving,
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
    final remaining = events.where((e) => e.number != number).toList();
    final side = matches.single.side;
    if (_replayLineup(side, remaining, check: true) == null) {
      throw const RuleViolation(
          'Löschen geht nicht mehr, danach wurde schon gewechselt.');
    }
    return _copy(events: remaining);
  }

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

  /// Replays the starting lineup of [side] through [events].
  ///
  /// With [check], returns `null` when the events no longer fit together,
  /// e.g. Tom came onto a free place that would not be free any more.
  Lineup? _replayLineup(Side side, List<GameEvent> events,
      {bool check = false}) {
    var lineup = side == Side.home ? homeStartingLineup : awayStartingLineup;
    if (lineup == null) return null;
    for (final e in events.where((e) => e.side == side)) {
      if (e.type == EventType.substitution) {
        final incoming = teamOf(side).playerById(e.incomingPlayerId!)!;
        final out = e.playerId;
        final fits = !lineup!.isOnField(incoming.id) &&
            (out == null
                ? lineup.playerIds.length < rules.maxPlayersOnField
                : lineup.isOnField(out));
        if (check && !fits) return null;
        lineup = out == null
            ? lineup.addPlayer(incoming)
            : lineup.substitute(out, incoming);
      } else if (e.leavingPlayerId != null) {
        lineup = lineup!.remove(e.leavingPlayerId!);
      }
    }
    return lineup;
  }

  /// Who goes off the field for a penalty of [playerId] (E5.4).
  String _whoLeaves(Lineup lineup, String playerId, String? chosen) {
    if (lineup.isOnField(playerId)) return playerId;
    if (chosen == null) {
      throw const RuleViolation('Bitte wählen, wer das Feld verlässt.');
    }
    if (!lineup.isOnField(chosen)) {
      throw const RuleViolation('Dieser Spieler steht nicht auf dem Feld.');
    }
    return chosen;
  }

  /// Checks that [inId] may come onto the field: in the squad, not on the
  /// field yet and not disqualified (R3).
  void _checkCanComeIn(Side side, String inId) {
    final team = teamOf(side);
    if (!team.hasPlayer(inId)) {
      throw RuleViolation('Der Spieler gehört nicht zu ${team.name}.');
    }
    if (lineupOf(side)!.isOnField(inId)) {
      throw const RuleViolation('Dieser Spieler steht schon auf dem Feld.');
    }
    _checkNotDisqualified(side, inId);
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
