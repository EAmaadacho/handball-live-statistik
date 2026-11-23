import 'rule_violation.dart';

/// Whether a player plays in the field or in goal.
///
/// Only a goalkeeper can make saves or concede goals (R5).
enum Position { fieldPlayer, goalkeeper }

/// A player in a team's squad (T2).
///
/// The [id] never changes. When Max switches from No. 7 to No. 10,
/// he keeps his id and therefore his statistics.
class Player {
  final String id;
  final int number;
  final String firstName;
  final String lastName;
  final Position position;

  const Player({
    required this.id,
    required this.number,
    required this.firstName,
    required this.lastName,
    required this.position,
  });

  /// How the ticker shows the player (E1.4), e.g. "7 Max Mustermann".
  String get displayName => '$number $firstName $lastName';

  /// Returns a new player with the given values changed.
  ///
  /// Example: `max.copyWith(number: 10)` is Max with No. 10 and the same id.
  Player copyWith({
    int? number,
    String? firstName,
    String? lastName,
    Position? position,
  }) {
    return Player(
      id: id,
      number: number ?? this.number,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      position: position ?? this.position,
    );
  }
}

/// Checks [player] against the rules for a squad (T2.1): number 1 to 99,
/// not taken by one of [otherPlayers], first and last name given.
///
/// Used for a team's squad and for a game's match report (S1.1, S1.4).
void checkPlayer(Player player, {required List<Player> otherPlayers}) {
  if (player.number < 1 || player.number > 99) {
    throw const RuleViolation('Nummern gehen von 1 bis 99.');
  }
  if (otherPlayers.any((p) => p.number == player.number)) {
    throw RuleViolation('Die Nummer ${player.number} ist schon vergeben.');
  }
  if (player.firstName.trim().isEmpty || player.lastName.trim().isEmpty) {
    throw const RuleViolation('Bitte Vor- und Nachnamen eingeben.');
  }
}
