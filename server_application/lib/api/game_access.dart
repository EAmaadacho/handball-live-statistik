import 'package:shelf/shelf.dart';

import '../domain/game.dart';
import '../domain/game_event.dart';
import '../storage/game_repository.dart';
import '../storage/stored_game.dart';
import 'game_mapping.dart';
import 'responses.dart';

/// What all endpoints of a game share: finding it, checking the ticker
/// code, saving the change and answering with the game (S1.2, ADR-005).
///
/// [now] gives the current time; the server takes it, never the browser
/// (ADR-003). Tests pass a fixed time.
class GameAccess {
  static const tickerCodeHeader = 'x-ticker-code';

  final GameRepository games;
  final DateTime Function() now;

  GameAccess(this.games, {DateTime Function()? now})
      : now = now ?? DateTime.now;

  /// The game with [gameId], or 404 "Spiel nicht gefunden.".
  StoredGame find(String gameId) =>
      games.byId(gameId) ??
      (throw const HttpError(404, 'Spiel nicht gefunden.'));

  /// The game as JSON, with the game time at this moment.
  Response answer(StoredGame stored, {int status = 200}) =>
      jsonResponse(toApiGame(stored, now()).toJson(), status: status);

  /// The steps every ticker change shares: find the game (404), check the
  /// ticker code (403), let [change] return the new game, save, answer.
  Future<Response> change(
    Request request,
    String gameId,
    Future<Game> Function(StoredGame stored) change, {
    int status = 200,
  }) =>
      withErrorAnswers(() async {
        final stored = find(gameId);
        requireCode(request, tickerCodeHeader, stored.tickerCode);
        final changed = stored.withGame(await change(stored));
        games.save(changed);
        return answer(changed, status: status);
      });
}

/// "home" or "away" from the path, otherwise 404.
Side sideOf(String side) =>
    Side.values.asNameMap()[side] ??
    (throw const HttpError(404, 'Diese Seite gibt es nicht.'));
