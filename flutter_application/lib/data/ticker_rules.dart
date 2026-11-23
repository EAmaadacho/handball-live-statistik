/// Why the ticker greys out a button, as the server would answer (R1–R7).
///
/// The ticker only uses these texts to explain a disabled button. The server
/// checks the same rules again and has the last word (HTTP 409).
/// Each function returns null when the action is allowed.
library;

import 'models.dart';

/// R4: events only between kick-off and the end of the game.
String? gameNotRunningReason(GameState state) {
  if (state.ended) return 'Das Spiel ist beendet.';
  if (!state.started) return 'Das Spiel hat noch nicht begonnen.';
  return null;
}

/// Whether [playerId] is disqualified: red card or third 2 minutes (R2, R3).
bool isDisqualified(GameState state, String playerId) =>
    state.cards[playerId] == CardMark.red;

/// Why [kind] cannot be recorded for [playerId] of [side].
///
/// Example: "Parade" for Jan Vogel of Hilden while Mettmann's goal is empty
/// → "TV Mettmann hat keinen Torwart auf dem Feld." (R5).
String? eventBlockReason(
    GameState state, EventKind kind, Side side, String playerId) {
  final notRunning = gameNotRunningReason(state);
  if (notRunning != null) return notRunning;
  final player = state.game.team(side).player(playerId);
  if (isDisqualified(state, playerId)) {
    return '${player.firstName} ist disqualifiziert.';
  }
  if (kind.needsPlayerOnField && !state.onField(side).contains(playerId)) {
    return 'Dieser Spieler steht nicht auf dem Feld.';
  }
  final defender = opponentOf(side);
  if (kind == EventKind.save && state.goalkeeperOf(defender) == null) {
    return '${state.game.team(defender).name} hat keinen Torwart auf dem Feld.';
  }
  return null;
}

/// R1: 3 timeouts per game, 2 per half, 1 in the last 5 minutes.
///
/// Example: Hilden took its 3rd timeout → "HSG Hilden hat keine Auszeit mehr."
String? timeoutBlockReason(GameState state, Side side) {
  final notRunning = gameNotRunningReason(state);
  if (notRunning != null) return notRunning;
  final halfSeconds = state.game.halfMinutes * 60;
  if ((state.timeouts[side] ?? 0) >= 3) {
    return '${state.game.team(side).name} hat keine Auszeit mehr.';
  }
  final own = state.events
      .where((e) => e.side == side && e.kind == EventKind.timeout)
      .toList();
  final inThisHalf =
      own.where((e) => (e.clockSeconds < halfSeconds ? 1 : 2) == state.half);
  if (inThisHalf.length >= 2) return 'Nur 2 Auszeiten pro Halbzeit.';
  final lastFive = halfSeconds * 2 - 5 * 60;
  if (state.clockSeconds >= lastFive &&
      own.any((e) => e.clockSeconds >= lastFive)) {
    return 'In den letzten 5 Minuten nur eine Auszeit.';
  }
  return null;
}

/// How many players [side] may have on the field: 7 minus running penalties (R7).
///
/// Example: Nico sits out 2 minutes → Hilden may have 6.
int allowedOnField(GameState state, Side side) =>
    7 - state.penalties.where((p) => p.side == side).length;

/// R6 (hint only): a second yellow for the player or a 4th for the team
/// should be a 2-minute penalty instead.
bool yellowShouldBeTwoMinutes(GameState state, Side side, String playerId) {
  final teamYellows = state.game
      .team(side)
      .players
      .where((p) => state.cards[p.id] == CardMark.yellow)
      .length;
  return state.cards[playerId] == CardMark.yellow || teamYellows >= 3;
}

/// The other team: home → away, away → home.
Side opponentOf(Side side) => side == Side.home ? Side.away : Side.home;
