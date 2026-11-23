import 'game_event.dart';
import 'rules.dart' as rules;

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

  /// Whether a free place is left, i.e. fewer than 7 players on the field.
  bool get hasFreePlace => playerIds.length < rules.maxPlayersOnField;

  /// Whether the goal is free once [outId] has left, e.g. Nora goes out.
  /// With `null` nobody leaves.
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

  /// This lineup after the [events] of its team, in order (ADR-006).
  ///
  /// Example: Nora in goal, then "Tom for Nora" → the goal is empty.
  /// Returns `null` when an event does not fit any more, e.g. Tom comes onto
  /// a free place that is no longer free because a penalty was deleted (E2).
  Lineup? replay(Iterable<GameEvent> events) {
    Lineup? lineup = this;
    for (final event in events) {
      lineup = lineup?._apply(event);
    }
    return lineup;
  }

  /// This lineup after one [event], or `null` if the event does not fit.
  Lineup? _apply(GameEvent event) {
    final inGoal = event.incomingInGoal;
    switch (event.type) {
      case EventType.substitution:
        final out = event.playerId!;
        final incoming = event.incomingPlayerId!;
        final fits = isOnField(out) &&
            !isOnField(incoming) &&
            (!inGoal || goalIsFreeWithout(out));
        return fits ? substitute(out, incoming, intoGoal: inGoal) : null;
      case EventType.comesOn:
        final incoming = event.incomingPlayerId!;
        final fits = hasFreePlace &&
            !isOnField(incoming) &&
            (!inGoal || goalIsFreeWithout(null));
        return fits ? addPlayer(incoming, intoGoal: inGoal) : null;
      case EventType.movesIntoGoal:
        final player = event.playerId!;
        final fits = goalIsFreeWithout(null) && isOnField(player);
        return fits ? moveIntoGoal(player) : null;
      default:
        final leaving = event.leavingPlayerId;
        if (leaving == null) return this;
        return isOnField(leaving) ? remove(leaving) : null;
    }
  }
}
