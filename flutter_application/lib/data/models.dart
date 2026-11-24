/// What the pages show. Later these are filled from the API models
/// (package openapi); the pages do not notice the difference.
library;

class Player {
  const Player({
    required this.id,
    required this.number,
    required this.firstName,
    required this.lastName,
    this.isGoalkeeper = false,
  });

  final String id;
  final int number;
  final String firstName;
  final String lastName;
  final bool isGoalkeeper;
}

/// A team official on the bench, e.g. "A Sven Krause, Trainer" (E6).
class Official {
  const Official(
      {required this.letter, required this.name, required this.role});

  /// A, B, C or D.
  final String letter;
  final String name;
  final String role;
}

class Team {
  const Team({
    required this.id,
    required this.name,
    required this.shortName,
    this.players = const [],
    this.officials = const [],
    this.gameSquadOnly = false,
  });

  final String id;
  final String name;

  /// 2 to 4 letters shown on the scoreboard, e.g. "TVM".
  final String shortName;
  final List<Player> players;
  final List<Official> officials;

  /// An opponent without registration: its players exist only for this
  /// game (Spielkader, S1.1). Late players are typed in with number and name.
  final bool gameSquadOnly;

  /// The same team with [player] added, e.g. a late player of the opponent.
  Team withPlayer(Player player) => Team(
      id: id,
      name: name,
      shortName: shortName,
      players: [...players, player],
      officials: officials,
      gameSquadOnly: gameSquadOnly);

  /// The player with [id], e.g. player('max7') → Max Mustermann.
  Player player(String id) => players.firstWhere((p) => p.id == id);
}

class Game {
  const Game({
    required this.id,
    required this.home,
    required this.away,
    this.halfMinutes = 30,
  });

  /// Opaque id from the server, also part of the viewer link, e.g. "ydVsnTnc".
  final String id;
  final Team home;
  final Team away;
  final int halfMinutes;

  Team team(Side side) => side == Side.home ? home : away;

  /// The same game with [team] in place of the team of [side].
  Game withTeam(Side side, Team team) => Game(
      id: id,
      home: side == Side.home ? team : home,
      away: side == Side.away ? team : away,
      halfMinutes: halfMinutes);
}

/// Home team plays at the bottom of the court, guest team at the top (E5).
enum Side { home, away }

enum CardMark { yellow, red }

/// Where the game stands, as the server's clock says (U1, U5).
///
/// The clock stops by itself at 30:00; the ticker then presses "Halbzeit".
/// The next start begins the second half, "Abpfiff" ends the game.
enum GamePhase { notStarted, firstHalf, halfTime, secondHalf, finished }

/// A running penalty, shown on the scoreboard and at the bench.
///
/// Example: Nico (8) of HSG Hilden has 1:22 left → label "8", 82 seconds.
class Penalty {
  const Penalty(
      {required this.side,
      required this.label,
      required this.secondsLeft,
      this.playerId});

  final Side side;

  /// Shirt number of a player or letter of an official, e.g. "8" or "A".
  final String label;
  final int secondsLeft;

  /// The player who comes back to the bench when the time is up.
  /// Null after a red card: the team waits 2 minutes, the player stays out (L3.3).
  final String? playerId;

  Penalty after(int seconds) => Penalty(
      side: side,
      label: label,
      secondsLeft: secondsLeft - seconds,
      playerId: playerId);
}

enum EventKind {
  goal('Tor'),
  miss('Fehlwurf'),
  save('Parade'),
  sevenMeterGoal('7 m Tor'),
  sevenMeterMiss('7 m vorbei'),
  technicalFault('Techn. Fehler'),
  yellowCard('Gelb'),
  twoMinutes('2 Minuten'),
  redCard('Rot'),
  timeout('Auszeit');

  const EventKind(this.label);

  /// Shown in the event history, e.g. "Tor".
  final String label;

  /// Shots and technical faults: only for players on the field (R7).
  bool get needsPlayerOnField => const {
        goal,
        miss,
        save,
        sevenMeterGoal,
        sevenMeterMiss,
        technicalFault
      }.contains(this);

  /// Yellow, 2 minutes and red: also for players on the bench (R7).
  bool get isPunishment =>
      const {yellowCard, twoMinutes, redCard}.contains(this);

  bool get isGoal => this == goal || this == sevenMeterGoal;
}

/// One entry of the event history, e.g. 38:12 Tor · 7 Max Mustermann → 14:12.
///
/// A save belongs to the shooter whose shot was saved (E1.3, R5):
/// "Parade · 3 Jan Vogel" counts as a save for Mettmann's goalkeeper.
class GameEvent {
  const GameEvent({
    required this.number,
    this.playerId,
    required this.clockSeconds,
    required this.kind,
    required this.side,
    required this.who,
    required this.homeGoals,
    required this.awayGoals,
  });

  /// Given by the server, used to delete the event (E2).
  final int number;

  /// Null for a timeout, which belongs to the team.
  final String? playerId;
  final int clockSeconds;
  final EventKind kind;
  final Side side;

  /// Player or official, e.g. "7 Max Mustermann"; for a timeout the team name.
  final String who;

  /// Score after this event.
  final int homeGoals;
  final int awayGoals;
}

/// What a player did in this game, counted by the server from the events (ADR-006).
///
/// Example: Max has 5 goals from 7 shots, both 7 m converted → goals 5,
/// shots 7, sevenMeterGoals 2, sevenMeterShots 2.
class PlayerStats {
  const PlayerStats({
    this.goals = 0,
    this.shots = 0,
    this.sevenMeterGoals = 0,
    this.sevenMeterShots = 0,
    this.saves = 0,
    this.goalsAgainst = 0,
    this.technicalFaults = 0,
    this.yellowCards = 0,
    this.twoMinutes = 0,
    this.redCards = 0,
  });

  static const none = PlayerStats();

  final int goals;
  final int shots;
  final int sevenMeterGoals;
  final int sevenMeterShots;

  /// Only goalkeepers have saves and goals against (R5).
  final int saves;
  final int goalsAgainst;
  final int technicalFaults;
  final int yellowCards;
  final int twoMinutes;
  final int redCards;

  /// These numbers plus [other] times [times]; times -1 takes it away again.
  PlayerStats plus(PlayerStats other, [int times = 1]) => PlayerStats(
        goals: goals + other.goals * times,
        shots: shots + other.shots * times,
        sevenMeterGoals: sevenMeterGoals + other.sevenMeterGoals * times,
        sevenMeterShots: sevenMeterShots + other.sevenMeterShots * times,
        saves: saves + other.saves * times,
        goalsAgainst: goalsAgainst + other.goalsAgainst * times,
        technicalFaults: technicalFaults + other.technicalFaults * times,
        yellowCards: yellowCards + other.yellowCards * times,
        twoMinutes: twoMinutes + other.twoMinutes * times,
        redCards: redCards + other.redCards * times,
      );
}

/// Everything the scoreboard, the court and the bench show at one moment.
class GameState {
  const GameState({
    required this.game,
    required this.goals,
    required this.clockSeconds,
    required this.clockRunning,
    required this.timeouts,
    required this.field,
    required this.bench,
    this.penalties = const [],
    this.cards = const {},
    this.stats = const {},
    this.events = const [],
    this.halftimeScore,
    required this.phase,
    this.goalkeepers,
    this.matchReport,
  });

  final Game game;
  final Map<Side, int> goals;

  /// Seconds played, e.g. 2327 for 38:47.
  final int clockSeconds;
  final bool clockRunning;
  final GamePhase phase;

  bool get ended => phase == GamePhase.finished;

  /// Who is in goal for each team, as the server says (Lineup.goalkeeperId).
  /// Any player may be goalkeeper in a game (IHF rule 4:7), e.g. Max with a
  /// goalkeeper shirt. Null for a team = empty goal (E1.5).
  /// Without this map the squad goalkeeper standing on TH counts.
  final Map<Side, String?>? goalkeepers;

  /// Players on the match report, at most 16 per team (S1.4). Without this
  /// map everyone on the field, on the bench or sitting out a penalty counts.
  final Map<Side, List<String>>? matchReport;

  /// The match report of [side], e.g. the 10 players of TV Mettmann.
  List<String> reportOf(Side side) =>
      matchReport?[side] ??
      [
        ...onField(side),
        ...bench[side]!,
        for (final p in penalties)
          if (p.side == side && p.playerId != null) p.playerId!,
      ];
  final Map<Side, int> timeouts;
  final List<Penalty> penalties;

  /// Seven places per team: TH, LA, RL, RM, KL, RR, RA. Null = place empty.
  final Map<Side, List<String?>> field;

  /// Players of the match report who are not on the field.
  final Map<Side, List<String>> bench;

  /// Cards of players (key: player id) and officials (key: "home:A").
  final Map<String, CardMark> cards;

  /// Per player id; players without an entry have done nothing yet.
  final Map<String, PlayerStats> stats;

  PlayerStats statsOf(String playerId) => stats[playerId] ?? PlayerStats.none;

  /// Event history, newest first (L1).
  final List<GameEvent> events;

  /// Score at half time, e.g. "8:7"; null before half time (U5).
  final String? halftimeScore;

  /// 1 until the second half starts, then 2.
  int get half =>
      phase == GamePhase.secondHalf || phase == GamePhase.finished ? 2 : 1;

  /// Before kick-off the ticker sets up the lineups (R4.1, E5.1).
  bool get started => phase != GamePhase.notStarted;

  /// Where the clock stops by itself: 30:00 in the first, 60:00 in the
  /// second half (for 30 minutes per half).
  int get halfEndSeconds => game.halfMinutes * 60 * half;

  /// The goalkeeper in goal right now, or null for an empty goal (E1.2, E1.5).
  ///
  /// Tom standing on TH as extra field player is not a goalkeeper, Max who went
  /// into goal with a goalkeeper shirt is.
  String? goalkeeperOf(Side side) {
    if (goalkeepers case final keepers?) return keepers[side];
    final id = field[side]![0];
    return id != null && game.team(side).player(id).isGoalkeeper ? id : null;
  }

  /// Players of [side] on the field, without empty places.
  List<String> onField(Side side) => field[side]!.whereType<String>().toList();

  /// The same state with some values changed.
  GameState copyWith({
    Game? game,
    Map<Side, int>? goals,
    int? clockSeconds,
    bool? clockRunning,
    Map<Side, int>? timeouts,
    Map<Side, List<String?>>? field,
    Map<Side, List<String>>? bench,
    List<Penalty>? penalties,
    Map<String, CardMark>? cards,
    Map<String, PlayerStats>? stats,
    Map<Side, String?>? goalkeepers,
    Map<Side, List<String>>? matchReport,
    List<GameEvent>? events,
    String? halftimeScore,
    GamePhase? phase,
  }) =>
      GameState(
        game: game ?? this.game,
        goals: goals ?? this.goals,
        clockSeconds: clockSeconds ?? this.clockSeconds,
        clockRunning: clockRunning ?? this.clockRunning,
        timeouts: timeouts ?? this.timeouts,
        field: field ?? this.field,
        bench: bench ?? this.bench,
        penalties: penalties ?? this.penalties,
        cards: cards ?? this.cards,
        stats: stats ?? this.stats,
        goalkeepers: goalkeepers ?? this.goalkeepers,
        matchReport: matchReport ?? this.matchReport,
        events: events ?? this.events,
        halftimeScore: halftimeScore ?? this.halftimeScore,
        phase: phase ?? this.phase,
      );

  /// The same state [seconds] later: clock and penalties have moved on.
  ///
  /// The app counts on by itself between two answers of the server
  /// (ADR-003). Example: 23:14 running, 3 seconds later → 23:17.
  /// At the end of a half the clock stops by itself, e.g. at 30:00.
  /// A player whose 2 minutes are over goes back to the bench (E5.4).
  GameState advancedBy(int seconds) {
    if (!clockRunning || seconds <= 0) return this;
    final played = seconds.clamp(0, halfEndSeconds - clockSeconds);
    final over = [
      for (final p in penalties)
        if (p.secondsLeft <= played && p.playerId != null) p
    ];
    return copyWith(
      clockSeconds: clockSeconds + played,
      clockRunning: clockSeconds + played < halfEndSeconds,
      penalties: [
        for (final p in penalties)
          if (p.secondsLeft > played) p.after(played),
      ],
      bench: {
        for (final side in Side.values)
          side: [
            ...bench[side]!,
            for (final p in over)
              if (p.side == side) p.playerId!
          ]
      },
    );
  }
}

/// Sums over all players of one team, plus cards of the officials and timeouts (L7).
///
/// Example: TV Mettmann has 14 goals from 21 shots and 1 timeout.
class TeamTotals {
  TeamTotals.of(GameState state, Side side)
      : timeouts = state.timeouts[side] ?? 0,
        officialYellow = state.game
            .team(side)
            .officials
            .where((o) =>
                state.cards['${side.name}:${o.letter}'] == CardMark.yellow)
            .length,
        officialRed = state.game
            .team(side)
            .officials
            .where(
                (o) => state.cards['${side.name}:${o.letter}'] == CardMark.red)
            .length,
        _players = [
          for (final p in state.game.team(side).players) state.statsOf(p.id)
        ];

  final List<PlayerStats> _players;
  final int timeouts;
  final int officialYellow;
  final int officialRed;

  int _sum(int Function(PlayerStats s) f) =>
      _players.fold(0, (n, s) => n + f(s));

  int get goals => _sum((s) => s.goals);
  int get shots => _sum((s) => s.shots);
  int get sevenMeterGoals => _sum((s) => s.sevenMeterGoals);
  int get sevenMeterShots => _sum((s) => s.sevenMeterShots);
  int get saves => _sum((s) => s.saves);
  int get technicalFaults => _sum((s) => s.technicalFaults);
  int get yellowCards => _sum((s) => s.yellowCards) + officialYellow;
  int get twoMinutes => _sum((s) => s.twoMinutes);
  int get redCards => _sum((s) => s.redCards) + officialRed;
}
