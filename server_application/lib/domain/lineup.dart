/// Who stands on the field for one team: the goal slot and the field players.
///
/// Example: Nora in goal, Max, Lisa and four more in the field (E5.1).
/// Any player may stand in the goal slot, also a field player like Max when
/// no goalkeeper is left (E5.7). The goal slot can be empty: then a 7th
/// field player plays and goals against count for no goalkeeper (E1.5).
class Lineup {
  final String? goalkeeperId;
  final List<String> fieldPlayerIds;

  Lineup({required this.goalkeeperId, required List<String> fieldPlayerIds})
      : fieldPlayerIds = List.unmodifiable(fieldPlayerIds);

  /// All players on the field, goalkeeper first.
  List<String> get playerIds =>
      [if (goalkeeperId != null) goalkeeperId!, ...fieldPlayerIds];

  bool isOnField(String playerId) => playerIds.contains(playerId);

  /// Whether the goal is free once [outId] has left, e.g. Nora goes out.
  bool goalIsFreeWithout(String? outId) =>
      goalkeeperId == null || goalkeeperId == outId;

  /// Swaps [outId] for [incomingId] (E5.2).
  ///
  /// With [intoGoal] the incoming player takes the free goal, e.g. Lea for
  /// Nora. Otherwise he plays in the field; if [outId] was in goal, the goal
  /// stays empty, e.g. Tom for Nora (E1.5).
  Lineup substitute(String outId, String incomingId, {required bool intoGoal}) {
    final field = fieldPlayerIds.where((id) => id != outId).toList();
    if (intoGoal) {
      return Lineup(goalkeeperId: incomingId, fieldPlayerIds: field);
    }
    return Lineup(
      goalkeeperId: goalkeeperId == outId ? null : goalkeeperId,
      fieldPlayerIds: [...field, incomingId],
    );
  }

  /// [incomingId] comes onto a free place, with [intoGoal] into the empty
  /// goal.
  Lineup addPlayer(String incomingId, {required bool intoGoal}) => intoGoal
      ? Lineup(goalkeeperId: incomingId, fieldPlayerIds: fieldPlayerIds)
      : Lineup(
          goalkeeperId: goalkeeperId,
          fieldPlayerIds: [...fieldPlayerIds, incomingId],
        );

  /// Field player [playerId] moves into the empty goal, e.g. Max when no
  /// goalkeeper is left (E5.7).
  Lineup moveIntoGoal(String playerId) => Lineup(
        goalkeeperId: playerId,
        fieldPlayerIds: fieldPlayerIds.where((id) => id != playerId).toList(),
      );

  /// The player leaves the field and his place stays free, e.g. Max with a
  /// two-minute penalty (E5.4). For the goalkeeper the goal stays empty (E5.6).
  Lineup remove(String playerId) => Lineup(
        goalkeeperId: goalkeeperId == playerId ? null : goalkeeperId,
        fieldPlayerIds: fieldPlayerIds.where((id) => id != playerId).toList(),
      );
}
