import 'demo_data.dart';
import 'game_source.dart';
import 'models.dart';
import 'ticker_rules.dart';

/// Plays the server for the demo: TV Mettmann against HSG Hilden,
/// game 17 running and game 18 before kick-off.
///
/// It keeps the game in memory and changes it as the real server would:
/// the clock runs on (ADR-003), rules are checked (R1–R7), score and
/// statistics follow the events (ADR-006). Later an API source replaces it.
class DemoGameSource implements GameSource {
  /// [now] replaces the system time in tests, e.g. to let 2 minutes pass.
  DemoGameSource({DateTime Function()? now}) : _clock = now ?? DateTime.now {
    _since = _clock();
  }

  static const gameId = 17;
  static const teamCode = 'k7Qp2xVz9LmA4tRb';
  static const tickerCode = 'x9Fw3cNs7Ke2Hy5D';

  /// Game 18 has not started yet: the ticker sets up the lineup (E5.1).
  static const nextGameId = 18;
  static const nextTickerCode = 'Pq4Lm8Rt2Wx6Zc1V';
  static const _tickerCodes = {gameId: tickerCode, nextGameId: nextTickerCode};

  static const mettmann = demoMettmann;
  static const hilden = demoHilden;
  static const game = demoGame;
  static const state = demoState;

  /// Set to false to see how the pages behave without a connection (L1.1, E1.6).
  bool online = true;

  final Map<int, GameState> _states = {
    gameId: demoState,
    nextGameId: demoNextState,
  };

  final DateTime Function() _clock;

  /// When [_states] were last brought up to date.
  late DateTime _since;
  int _nextNumber = 7;

  /// The goalkeeper each goal or save counted for (E1.2), by event number.
  final Map<int, String?> _goalkeeperOf = {
    2: 'a1',
    3: 'nora1',
    5: 'nora1',
    6: 'a1',
  };

  @override
  Future<Game?> loadGame(int id) async => _states[id]?.game;

  @override
  Future<Team?> loadTeamByCode(String code) async =>
      code == teamCode ? mettmann : null;

  @override
  Future<bool> isTickerCode(int id, String code) async =>
      _tickerCodes[id] == code;

  @override
  Future<GameState?> loadState(int id) async {
    if (!online) throw StateError('Keine Verbindung');
    if (!_states.containsKey(id)) return null;
    return _now(id);
  }

  @override
  Future<GameEvent> record(int id, String code, EventKind kind, Side side,
      {String? playerId}) async {
    final s = _forTicker(id, code);
    final reason = kind == EventKind.timeout
        ? timeoutBlockReason(s, side)
        : eventBlockReason(s, kind, side, playerId!);
    if (reason != null) throw RejectedAction(reason);

    final team = s.game.team(side);
    final player = playerId == null ? null : team.player(playerId);
    final goals = {...s.goals};
    if (kind.isGoal) goals[side] = goals[side]! + 1;
    final number = _nextNumber++;
    final event = GameEvent(
      number: number,
      playerId: playerId,
      clockSeconds: s.clockSeconds,
      kind: kind,
      side: side,
      who: player == null
          ? team.name
          : '${player.number} ${player.firstName} ${player.lastName}',
      homeGoals: goals[Side.home]!,
      awayGoals: goals[Side.away]!,
    );
    if (kind == EventKind.goal ||
        kind == EventKind.sevenMeterGoal ||
        kind == EventKind.save) {
      _goalkeeperOf[number] = s.goalkeeperOf(opponentOf(side));
    }

    var next = s.copyWith(
      goals: goals,
      events: [event, ...s.events],
      stats: _counted(s.stats, event, 1),
    );
    if (kind == EventKind.timeout) {
      next = next.copyWith(
          timeouts: {...s.timeouts, side: s.timeouts[side]! + 1},
          clockRunning: false);
    }
    if (kind.isPunishment) next = _punish(next, kind, side, player!);
    _states[id] = next;
    return event;
  }

  @override
  Future<void> deleteEvent(int id, String code, int number) async {
    final s = _forTicker(id, code);
    if (s.ended) throw const RejectedAction('Das Spiel ist beendet.');
    final matches = s.events.where((e) => e.number == number);
    if (matches.isEmpty) throw const RejectedAction('Ereignis nicht gefunden.');
    final event = matches.single;

    final goals = event.kind.isGoal
        ? {...s.goals, event.side: s.goals[event.side]! - 1}
        : s.goals;
    var next = s.copyWith(
      goals: goals,
      events: _rescored(s.events.where((e) => e != event).toList(), goals),
      stats: _counted(s.stats, event, -1),
    );
    if (event.kind == EventKind.timeout) {
      next = next.copyWith(
          timeouts: {...s.timeouts, event.side: s.timeouts[event.side]! - 1});
    }
    if (event.kind.isPunishment) next = _forgive(next, event);
    _states[id] = next;
  }

  @override
  Future<void> substitute(
      int id, String code, Side side, int place, String inPlayerId,
      {bool? intoGoal}) async {
    final s = _forTicker(id, code);
    final notRunning = gameNotRunningReason(s);
    if (notRunning != null) throw RejectedAction(notRunning);
    if (!s.bench[side]!.contains(inPlayerId)) {
      throw const RejectedAction('Dieser Spieler sitzt nicht auf der Bank.');
    }
    final out = s.field[side]![place];
    if (out == null && s.onField(side).length >= allowedOnField(s, side)) {
      throw const RejectedAction(
          'Der Platz bleibt frei, solange die Zeitstrafe läuft.');
    }
    final field = [...s.field[side]!]..[place] = inPlayerId;
    final bench = [...s.bench[side]!]..remove(inPlayerId);
    if (out != null) bench.add(out);
    final keepers = _keepers(s);
    final isKeeper = s.game.team(side).player(inPlayerId).isGoalkeeper;
    final goalEmpty = keepers[side] == null;
    if (place == 0) {
      keepers[side] = (intoGoal ?? isKeeper) ? inPlayerId : null;
    } else if (goalEmpty && (intoGoal ?? isKeeper)) {
      // Mia comes in for Ben and goes straight into the empty goal;
      // whoever stood on TH (an extra field player) takes Ben's place.
      field[place] = field[0];
      field[0] = inPlayerId;
      keepers[side] = inPlayerId;
    }
    _states[id] = s.copyWith(
        field: {...s.field, side: field},
        bench: {...s.bench, side: bench},
        goalkeepers: keepers);
  }

  @override
  Future<void> putInGoal(
      int id, String code, Side side, String playerId) async {
    final s = _forTicker(id, code);
    if (s.goalkeeperOf(side) case final keeper?) {
      final name = s.game.team(side).player(keeper).firstName;
      throw RejectedAction('Im Tor steht schon $name.');
    }
    final field = [...s.field[side]!];
    if (!field.contains(playerId)) {
      throw const RejectedAction('Dieser Spieler steht nicht auf dem Feld.');
    }
    // Swap with whoever stands on TH, e.g. an extra field player.
    final place = field.indexOf(playerId);
    field[place] = field[0];
    field[0] = playerId;
    _states[id] = s.copyWith(
        field: {...s.field, side: field},
        goalkeepers: _keepers(s)..[side] = playerId);
  }

  @override
  Future<void> toggleClock(int id, String code) async {
    final s = _forTicker(id, code);
    if (s.ended) throw const RejectedAction('Das Spiel ist beendet.');
    final linedUp = Side.values.every((side) => !s.field[side]!.contains(null));
    if (!s.started && !linedUp) {
      throw const RejectedAction('Bitte zuerst beide Teams aufstellen.');
    }
    _states[id] = s.copyWith(clockRunning: !s.clockRunning);
  }

  @override
  Future<void> setLineup(int id, String code, Side side, String goalkeeperId,
      List<String> fieldPlayerIds) async {
    final s = _forTicker(id, code);
    if (s.started) {
      throw const RejectedAction('Nach dem Anpfiff bitte wechseln.');
    }
    final lineup = [goalkeeperId, ...fieldPlayerIds];
    if (fieldPlayerIds.length != 6 || lineup.toSet().length != 7) {
      throw const RejectedAction(
          'Bitte 7 verschiedene Spieler aufstellen: 1 im Tor, 6 im Feld.');
    }
    final report = s.reportOf(side);
    _states[id] = s.copyWith(
      field: {...s.field, side: lineup},
      bench: {
        ...s.bench,
        side: [
          for (final p in report)
            if (!lineup.contains(p)) p
        ]
      },
      goalkeepers: _keepers(s)..[side] = goalkeeperId,
      matchReport: _reports(s),
    );
  }

  @override
  Future<void> addToMatchReport(
      int id, String code, Side side, String playerId) async {
    final s = _forTicker(id, code);
    _checkLateRegistration(s, side);
    if (s.reportOf(side).contains(playerId)) {
      throw const RejectedAction('Der Spieler steht schon im Spielbericht.');
    }
    _states[id] = _onBench(s, side, playerId);
  }

  @override
  Future<Player> addSquadPlayer(int id, String code, Side side, int number,
      String firstName, String lastName) async {
    final s = _forTicker(id, code);
    _checkLateRegistration(s, side);
    final team = s.game.team(side);
    if (team.players.any((p) => p.number == number)) {
      throw RejectedAction('Die Nummer $number ist schon vergeben.');
    }
    final player = Player(
        id: '${team.id}-$number',
        number: number,
        firstName: firstName,
        lastName: lastName);
    final withPlayer =
        s.copyWith(game: s.game.withTeam(side, team.withPlayer(player)));
    _states[id] = _onBench(withPlayer, side, player.id);
    return player;
  }

  @override
  Future<void> removeFromMatchReport(
      int id, String code, Side side, String playerId) async {
    final s = _forTicker(id, code);
    if (s.started) {
      throw const RejectedAction(
          'Nach dem Anpfiff bleibt der Spieler im Spielbericht.');
    }
    _states[id] = s.copyWith(
      bench: {
        ...s.bench,
        side: [...s.bench[side]!]..remove(playerId)
      },
      matchReport: _reports(s)
        ..[side] = [
          for (final id in s.reportOf(side))
            if (id != playerId) id
        ],
    );
  }

  /// S1.4: at most 16 players per team on the match report.
  static void _checkLateRegistration(GameState s, Side side) {
    if (s.ended) throw const RejectedAction('Das Spiel ist beendet.');
    if (s.reportOf(side).length >= 16) {
      throw const RejectedAction('Im Spielbericht stehen schon 16 Spieler.');
    }
  }

  /// [playerId] joins the match report and sits on the bench.
  static GameState _onBench(GameState s, Side side, String playerId) =>
      s.copyWith(
        bench: {
          ...s.bench,
          side: [...s.bench[side]!, playerId]
        },
        matchReport: _reports(s)..[side] = [...s.reportOf(side), playerId],
      );

  /// The match reports of both teams, as a map that may be changed.
  static Map<Side, List<String>> _reports(GameState s) =>
      {for (final side in Side.values) side: s.reportOf(side)};

  /// The current state, with the clock moved on since the last call.
  ///
  /// A player whose 2 minutes are over goes back to the bench (E5.4).
  GameState _now(int id) {
    final seconds = _clock().difference(_since).inSeconds;
    _since = _since.add(Duration(seconds: seconds));
    for (final game in _states.keys.toList()) {
      _states[game] = _advanced(_states[game]!, seconds);
    }
    return _states[id]!;
  }

  GameState _advanced(GameState before, int seconds) {
    var next = before.advancedBy(seconds);
    for (final p in before.penalties) {
      final over =
          !next.penalties.any((q) => q.side == p.side && q.label == p.label);
      if (over && p.playerId != null) {
        next = next.copyWith(bench: {
          ...next.bench,
          p.side: [...next.bench[p.side]!, p.playerId!]
        });
      }
    }
    return next;
  }

  /// Checks connection and ticker code like the server would (ADR-005).
  GameState _forTicker(int id, String code) {
    if (!online) throw StateError('Keine Verbindung');
    if (_tickerCodes[id] != code) {
      throw const RejectedAction('Dieser Ticker-Link ist ungültig.');
    }
    return _now(id);
  }

  /// 2 minutes and red take the player off the field and the team plays
  /// one short for 2 minutes. The third 2 minutes count as red (R2, L3.3).
  GameState _punish(GameState s, EventKind kind, Side side, Player player) {
    if (kind == EventKind.yellowCard) {
      return s.copyWith(cards: {...s.cards, player.id: CardMark.yellow});
    }
    final red =
        kind == EventKind.redCard || s.statsOf(player.id).twoMinutes >= 3;
    final keepers = _keepers(s);
    if (keepers[side] == player.id) keepers[side] = null;
    return s.copyWith(
      goalkeepers: keepers,
      field: {
        ...s.field,
        side: [for (final id in s.field[side]!) id == player.id ? null : id]
      },
      bench: {
        ...s.bench,
        side: [...s.bench[side]!]..remove(player.id)
      },
      penalties: [
        ...s.penalties,
        Penalty(
            side: side,
            label: '${player.number}',
            secondsLeft: 120,
            playerId: red ? null : player.id),
      ],
      cards: red ? {...s.cards, player.id: CardMark.red} : s.cards,
    );
  }

  /// Who is in goal for both teams, as a map that may be changed.
  static Map<Side, String?> _keepers(GameState s) =>
      {for (final side in Side.values) side: s.goalkeeperOf(side)};

  /// Undoes what [_punish] did when the event is deleted (E2.2).
  GameState _forgive(GameState s, GameEvent event) {
    final id = event.playerId!;
    if (event.kind == EventKind.yellowCard) {
      return s.copyWith(cards: {...s.cards}..remove(id));
    }
    final label = '${s.game.team(event.side).player(id).number}';
    final running = s.penalties
        .where((p) => p.side == event.side && p.label == label)
        .toList();
    final stillRed =
        s.statsOf(id).redCards > 0 || s.statsOf(id).twoMinutes >= 3;
    final onField = s.field[event.side]!.contains(id);
    final onBench = s.bench[event.side]!.contains(id);
    return s.copyWith(
      penalties: running.isEmpty
          ? s.penalties
          : (s.penalties.toList()..remove(running.first)),
      cards: s.cards[id] == CardMark.red && !stillRed
          ? ({...s.cards}..remove(id))
          : s.cards,
      bench: onField || onBench || stillRed
          ? s.bench
          : {
              ...s.bench,
              event.side: [...s.bench[event.side]!, id]
            },
    );
  }

  /// Statistics with [event] counted once more (times 1) or taken away (-1).
  Map<String, PlayerStats> _counted(
      Map<String, PlayerStats> stats, GameEvent event, int times) {
    final result = {...stats};
    void add(String? id, PlayerStats change) {
      if (id != null) {
        result[id] = (result[id] ?? PlayerStats.none).plus(change, times);
      }
    }

    final keeper = _goalkeeperOf[event.number];
    switch (event.kind) {
      case EventKind.goal:
        add(event.playerId, const PlayerStats(goals: 1, shots: 1));
        add(keeper, const PlayerStats(goalsAgainst: 1));
      case EventKind.sevenMeterGoal:
        add(
            event.playerId,
            const PlayerStats(
                goals: 1, shots: 1, sevenMeterGoals: 1, sevenMeterShots: 1));
        add(keeper, const PlayerStats(goalsAgainst: 1));
      case EventKind.save:
        add(event.playerId, const PlayerStats(shots: 1));
        add(keeper, const PlayerStats(saves: 1));
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

  /// The score after each event, counted again from the oldest (E2.1).
  ///
  /// [goals] is the score now; the events before the list make up the rest.
  static List<GameEvent> _rescored(
      List<GameEvent> newestFirst, Map<Side, int> goals) {
    int goalsIn(Side side) =>
        newestFirst.where((e) => e.side == side && e.kind.isGoal).length;
    var home = goals[Side.home]! - goalsIn(Side.home);
    var away = goals[Side.away]! - goalsIn(Side.away);
    final result = <GameEvent>[];
    for (final e in newestFirst.reversed) {
      if (e.kind.isGoal) e.side == Side.home ? home++ : away++;
      result.insert(
        0,
        GameEvent(
            number: e.number,
            playerId: e.playerId,
            clockSeconds: e.clockSeconds,
            kind: e.kind,
            side: e.side,
            who: e.who,
            homeGoals: home,
            awayGoals: away),
      );
    }
    return result;
  }
}
