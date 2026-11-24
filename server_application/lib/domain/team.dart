import 'player.dart';
import 'rule_violation.dart';
import 'team_name.dart';

/// A team with its squad (T1, T2).
///
/// A team never changes. Adding, changing or removing a player returns a
/// new team. Example: TV Mettmann has Max, Lisa and Nora; after adding Tom
/// there is a new team with four players, and the old one still has three.
///
/// The [code] is the secret part of the team link (T1.2). The domain does
/// not create it; the storage layer does and passes it in.
class Team {
  final TeamName name;
  final String shortCode;
  final String code;
  final String? logoRef;
  final List<Player> squad;

  Team._({
    required this.name,
    required this.shortCode,
    required this.code,
    required this.logoRef,
    required List<Player> squad,
  }) : squad = List.unmodifiable(squad);

  /// Creates a team with an empty squad.
  ///
  /// Example: TV Mettmann Männer with short code "TVM" and code "abc123".
  /// Rejects a short code that is not 2 to 4 characters; the [name] checks
  /// itself, see [TeamName].
  factory Team.create({
    required TeamName name,
    required String shortCode,
    required String code,
    String? logoRef,
  }) {
    final length = shortCode.trim().length;
    if (length < 2 || length > 4) {
      throw const RuleViolation('Das Kürzel braucht 2 bis 4 Zeichen.');
    }
    return Team._(
      name: name,
      shortCode: shortCode,
      code: code,
      logoRef: logoRef,
      squad: const [],
    );
  }

  /// Returns a new team with [player] added to the squad.
  ///
  /// Example: adding Tom (No. 9) works; adding a second No. 7 next to Max
  /// fails with "Die Nummer 7 ist schon vergeben." (T2.1).
  Team addPlayer(Player player) {
    checkPlayer(player, otherPlayers: squad);
    return _withSquad([...squad, player]);
  }

  /// Returns a new team in which the player with the same id is replaced.
  ///
  /// Example: Max switches from No. 7 to No. 10 and keeps his id. His own
  /// old number does not count as taken.
  Team updatePlayer(Player player) {
    _requirePlayer(player.id);
    final others = squad.where((p) => p.id != player.id).toList();
    checkPlayer(player, otherPlayers: others);
    return _withSquad([
      for (final p in squad) p.id == player.id ? player : p,
    ]);
  }

  /// Returns a new team without the player with [playerId].
  ///
  /// Games that already took place keep their own copy of the player,
  /// so Max's goals stay in old games.
  Team removePlayer(String playerId) {
    _requirePlayer(playerId);
    return _withSquad(squad.where((p) => p.id != playerId).toList());
  }

  /// The player with [playerId], or `null` if there is none.
  Player? playerById(String playerId) {
    for (final player in squad) {
      if (player.id == playerId) return player;
    }
    return null;
  }

  void _requirePlayer(String playerId) {
    if (playerById(playerId) == null) {
      throw const RuleViolation('Spieler nicht gefunden.');
    }
  }

  /// Returns a new team with the logo file [logoRef], e.g. "t1.png" (T6).
  Team withLogo(String logoRef) => Team._(
        name: name,
        shortCode: shortCode,
        code: code,
        logoRef: logoRef,
        squad: squad,
      );

  Team _withSquad(List<Player> newSquad) {
    return Team._(
      name: name,
      shortCode: shortCode,
      code: code,
      logoRef: logoRef,
      squad: newSquad,
    );
  }
}
