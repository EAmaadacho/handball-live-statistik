import 'player.dart';
import 'team.dart';

/// A team as it plays in one game: name, short code and the game squad.
///
/// The squad is a copy made when the game is created. If Max is later
/// removed from TV Mettmann, his goals in this game stay.
/// An opponent that is not registered gets its own game squad (S1.1),
/// e.g. HSG Hilden with "5 Jan Becker".
class GameTeam {
  final String name;
  final String shortCode;
  final List<Player> squad;

  GameTeam({
    required this.name,
    required this.shortCode,
    required List<Player> squad,
  }) : squad = List.unmodifiable(squad);

  /// The game copy of a registered team, e.g. TV Mettmann.
  factory GameTeam.fromTeam(Team team) =>
      GameTeam(name: team.name, shortCode: team.shortCode, squad: team.squad);

  /// Whether a player with [playerId] is in the game squad.
  bool hasPlayer(String playerId) => playerById(playerId) != null;

  /// The player with [playerId] in the game squad, or `null`.
  Player? playerById(String playerId) {
    for (final player in squad) {
      if (player.id == playerId) return player;
    }
    return null;
  }
}
