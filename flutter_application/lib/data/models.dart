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
}
