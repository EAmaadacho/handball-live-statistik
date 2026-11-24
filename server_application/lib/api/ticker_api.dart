import 'package:openapi/api.dart' as api;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../domain/game.dart';
import '../domain/game_event.dart';
import '../domain/rule_violation.dart';
import 'game_access.dart';
import 'responses.dart';

/// The HTTP endpoints the ticker uses during a game: starting lineups,
/// clock, events and substitutions (E1, E2, E5, U1–U5), see api.yaml.
///
/// All of them need the ticker code (X-Ticker-Code). The current time
/// comes from the server, never from the browser (ADR-003).
class TickerApi {
  final GameAccess _games;

  TickerApi(this._games);

  Router get router => Router()
    ..get('/games/<gameId>/ticker-access', _checkAccess)
    ..put('/games/<gameId>/lineups/<side>', _setLineup)
    ..post('/games/<gameId>/clock/start',
        _clockAction((g, now) => g.startClock(now)))
    ..post('/games/<gameId>/clock/stop',
        _clockAction((g, now) => g.stopClock(now)))
    ..post('/games/<gameId>/clock/half-time',
        _clockAction((g, now) => g.halfTime()))
    ..post('/games/<gameId>/clock/end', _clockAction((g, now) => g.end(now)))
    ..put('/games/<gameId>/clock', _adjustClock)
    ..post('/games/<gameId>/events', _recordEvent)
    ..delete('/games/<gameId>/events/<number>', _deleteEvent)
    ..post('/games/<gameId>/substitutions', _substitute)
    ..post('/games/<gameId>/come-on', _comeOn)
    ..post('/games/<gameId>/into-goal', _putInGoal);

  /// GET /games/{gameId}/ticker-access: checks the ticker link when Lisa
  /// opens it, 204 if the code is right, otherwise 403 (S1.2).
  Future<Response> _checkAccess(Request request, String gameId) =>
      withErrorAnswers(() async {
        final stored = _games.find(gameId);
        requireCode(request, GameAccess.tickerCodeHeader, stored.tickerCode);
        return Response(204);
      });

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

  /// POST /games/{gameId}/events: e.g. a goal of Max. The server stamps
  /// the game time and the goalkeeper (E1, E1.2); the rules R1–R7 apply.
  Future<Response> _recordEvent(Request request, String gameId) =>
      _games.change(request, gameId, (stored) async {
        final input = await readBody(request, api.NewEvent.fromJson);
        return stored.game.record(
          EventType.values.byName(input.type.value),
          sideOf(input.side.value),
          input.playerId,
          _games.now(),
          leavingPlayerId: input.leavingPlayerId,
        );
      }, status: 201);

  /// DELETE /games/{gameId}/events/{number}: e.g. Max's goal was a typing
  /// mistake (E2). The number is never given out again.
  Future<Response> _deleteEvent(
          Request request, String gameId, String number) =>
      _games.change(request, gameId, (stored) async {
        final parsed = int.tryParse(number) ??
            (throw const RuleViolation('Ereignis nicht gefunden.'));
        return stored.game.deleteEvent(parsed);
      });

  /// POST /games/{gameId}/substitutions: e.g. Max out, Tom in (E5.2).
  Future<Response> _substitute(Request request, String gameId) =>
      _games.change(request, gameId, (stored) async {
        final input = await readBody(request, api.Substitution.fromJson);
        return stored.game.substitute(
            sideOf(input.side.value), input.outId, input.inId, _games.now(),
            intoGoal: input.intoGoal);
      }, status: 201);

  /// POST /games/{gameId}/come-on: e.g. Max after his penalty (E5.4).
  Future<Response> _comeOn(Request request, String gameId) =>
      _games.change(request, gameId, (stored) async {
        final input = await readBody(request, api.ComeOn.fromJson);
        return stored.game.bringOn(
            sideOf(input.side.value), input.playerId, _games.now(),
            intoGoal: input.intoGoal);
      }, status: 201);

  /// POST /games/{gameId}/into-goal: e.g. Max into the empty goal (E5.7).
  Future<Response> _putInGoal(Request request, String gameId) =>
      _games.change(request, gameId, (stored) async {
        final input = await readBody(request, api.IntoGoal.fromJson);
        return stored.game
            .putInGoal(sideOf(input.side.value), input.playerId, _games.now());
      }, status: 201);
}
