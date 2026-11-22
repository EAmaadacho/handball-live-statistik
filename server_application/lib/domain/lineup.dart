import 'player.dart';

/// Who stands on the field for one team: the goal slot and the field players.
///
/// Example: Nora in goal, Max, Lisa and four more in the field (E5.1).
/// The goal slot can be empty: then a 7th field player plays and goals
/// against count for no goalkeeper (E1.5).
class Lineup {
  final String? goalkeeperId;
  final List<String> fieldPlayerIds;

  Lineup({required this.goalkeeperId, required List<String> fieldPlayerIds})
      : fieldPlayerIds = List.unmodifiable(fieldPlayerIds);

  /// All players on the field, goalkeeper first.
  List<String> get playerIds =>
      [if (goalkeeperId != null) goalkeeperId!, ...fieldPlayerIds];

  bool isOnField(String playerId) => playerIds.contains(playerId);

  /// Swaps [outId] for [incoming] (E5.2).
  ///
  /// A goalkeeper coming in takes the goal when the goal is free, e.g. Lea
  /// for Nora. A field player coming in for the goalkeeper leaves the goal
  /// empty and plays as 7th field player, e.g. Tom for Nora (E1.5).
  Lineup substitute(String outId, Player incoming) {
    final field = fieldPlayerIds.where((id) => id != outId).toList();
    final goalIsFree = goalkeeperId == null || goalkeeperId == outId;
    if (goalIsFree && incoming.position == Position.goalkeeper) {
      return Lineup(goalkeeperId: incoming.id, fieldPlayerIds: field);
    }
    return Lineup(
      goalkeeperId: goalkeeperId == outId ? null : goalkeeperId,
      fieldPlayerIds: [...field, incoming.id],
    );
  }
}
