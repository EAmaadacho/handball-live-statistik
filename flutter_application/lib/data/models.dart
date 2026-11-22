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
  });

  final String id;
  final String name;

  /// 2 to 4 letters shown on the scoreboard, e.g. "TVM".
  final String shortName;
  final List<Player> players;
  final List<Official> officials;

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

  final int id;
  final Team home;
  final Team away;
  final int halfMinutes;

  Team team(Side side) => side == Side.home ? home : away;
}

/// Home team plays at the bottom of the court, guest team at the top (E5).
enum Side { home, away }

enum CardMark { yellow, red }

/// A running penalty, shown on the scoreboard and at the bench.
///
/// Example: Nico (8) of HSG Hilden has 1:22 left → label "8", 82 seconds.
class Penalty {
  const Penalty(
      {required this.side, required this.label, required this.secondsLeft});

  final Side side;

  /// Shirt number of a player or letter of an official, e.g. "8" or "A".
  final String label;
  final int secondsLeft;
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
    this.ended = false,
  });

  final Game game;
  final Map<Side, int> goals;

  /// Seconds played, e.g. 2327 for 38:47.
  final int clockSeconds;
  final bool clockRunning;
  final bool ended;
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

  int get half => clockSeconds < game.halfMinutes * 60 ? 1 : 2;
}
