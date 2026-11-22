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

  int get half => clockSeconds < game.halfMinutes * 60 ? 1 : 2;
}
