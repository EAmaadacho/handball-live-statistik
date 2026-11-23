import 'player.dart';
import 'rules.dart' as rules;
import 'team.dart';
import 'team_name.dart';

/// A team as it plays in one game: name, short code and the match report.
///
/// The match report ([squad]) holds copies of the players, at most 16
/// (S1.4). If Max is later removed from TV Mettmann, his goals in this game
/// stay. An opponent that is not registered gets its own players (S1.1),
/// e.g. HSG Hilden Männer with "5 Jan Becker". Its [name] is entered like
/// that of a registered team: club, age group and team number.
class GameTeam {
  final TeamName name;
  final String shortCode;
  final List<Player> squad;

  GameTeam({
    required this.name,
    required this.shortCode,
    required List<Player> squad,
  }) : squad = List.unmodifiable(squad);

  /// The game copy of a registered team, e.g. TV Mettmann Männer.
  ///
  /// With more than 16 players, the 16 lowest numbers are in the match
  /// report; the ticker can swap players before kick-off (S1.4).
  factory GameTeam.fromTeam(Team team) {
    final byNumber = [...team.squad]
      ..sort((a, b) => a.number.compareTo(b.number));
    return GameTeam(
      name: team.name,
      shortCode: team.shortCode,
      squad: byNumber.take(rules.maxMatchReport).toList(),
    );
  }

  /// Whether a player with [playerId] is in the match report.
  bool hasPlayer(String playerId) => playerById(playerId) != null;

  /// The player with [playerId] in the match report, or `null`.
  Player? playerById(String playerId) {
    for (final player in squad) {
      if (player.id == playerId) return player;
    }
    return null;
  }

  /// A copy with [player] added to the match report.
  GameTeam withPlayer(Player player) =>
      GameTeam(name: name, shortCode: shortCode, squad: [...squad, player]);

  /// A copy without the player with [playerId].
  GameTeam withoutPlayer(String playerId) => GameTeam(
        name: name,
        shortCode: shortCode,
        squad: squad.where((p) => p.id != playerId).toList(),
      );
}
