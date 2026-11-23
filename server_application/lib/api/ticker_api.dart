import 'package:openapi/api.dart' as api;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../domain/game.dart';
import 'game_access.dart';
import 'responses.dart';

/// The HTTP endpoints the ticker uses during a game: starting lineups and
/// the clock (E5.1, U1–U5), see api.yaml.
///
/// All of them need the ticker code (X-Ticker-Code). The current time
/// comes from the server, never from the browser (ADR-003).
class TickerApi {
  final GameAccess _games;

  TickerApi(this._games);

  Router get router => Router()
    ..put('/games/<gameId>/lineups/<side>', _setLineup)
    ..post('/games/<gameId>/clock/start',
        _clockAction((g, now) => g.startClock(now)))
    ..post('/games/<gameId>/clock/stop',
        _clockAction((g, now) => g.stopClock(now)))
    ..post('/games/<gameId>/clock/half-time',
        _clockAction((g, now) => g.halfTime()))
    ..post('/games/<gameId>/clock/end', _clockAction((g, now) => g.end(now)))
    ..put('/games/<gameId>/clock', _adjustClock);

  /// PUT /games/{gameId}/lineups/{side}: e.g. Nora in goal, Max, Lisa, Ben,
  /// Paul, Finn and Leon in the field (E5.1).
  Future<Response> _setLineup(Request request, String gameId, String side) =>
      _games.change(request, gameId, (stored) async {
        final input = await readBody(request, api.NewLineup.fromJson);
        return stored.game
            .setLineup(sideOf(side), input.goalkeeperId, input.fieldPlayerIds);
      });

  /// A handler for one button of the clock, e.g. "Start" (U1).
  Future<Response> Function(Request, String) _clockAction(
          Game Function(Game game, DateTime now) action) =>
      (request, gameId) => _games.change(
          request, gameId, (stored) async => action(stored.game, _games.now()));

  /// PUT /games/{gameId}/clock: e.g. 23:14 back to 23:05 while the clock
  /// stands (U2). Events keep their time (U2.1).
  Future<Response> _adjustClock(Request request, String gameId) =>
      _games.change(request, gameId, (stored) async {
        final input = await readBody(request, api.ClockTime.fromJson);
        return stored.game.adjustClock(
            Duration(seconds: input.gameTimeSeconds), _games.now());
      });
}
