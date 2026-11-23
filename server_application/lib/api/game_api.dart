import 'package:openapi/api.dart' as api;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../domain/game.dart';
import '../domain/game_event.dart';
import '../domain/game_team.dart';
import '../domain/rule_violation.dart';
import '../domain/team.dart';
import '../storage/game_repository.dart';
import '../storage/stored_game.dart';
import '../storage/team_repository.dart';
import 'game_mapping.dart';
import 'random_code.dart';
import 'responses.dart';
import 'team_api.dart';
import 'team_mapping.dart';

/// The HTTP endpoints for creating games and their match reports (S1),
/// see api.yaml.
///
/// The team manager creates a game with the team code and gets the ticker
/// code once (S1.2). The ticker changes the match report with the ticker
/// code in the header X-Ticker-Code. The game id is the viewer link.
class GameApi {
  static const tickerCodeHeader = 'x-ticker-code';

  final TeamRepository _teams;
  final GameRepository _games;
  final String Function() _newCode;
  final String Function() _newId;

  /// [newCode] and [newId] can be replaced in tests to get fixed values.
  GameApi(this._teams, this._games,
      {String Function()? newCode, String Function()? newId})
      : _newCode = newCode ?? randomCode,
        _newId = newId ?? (() => randomCode(8));

  Router get router => Router()
    ..post('/teams/<teamId>/games', _createGame)
    ..get('/teams/<teamId>/games', _teamGames)
    ..get('/games/<gameId>', _getGame)
    ..post('/games/<gameId>/match-report/home', _addHomePlayer)
    ..post('/games/<gameId>/match-report/away', _addAwayPlayer)
    ..delete('/games/<gameId>/match-report/<side>/<playerId>', _removePlayer);

  /// POST /teams/{teamId}/games: e.g. TV Mettmann Männer against HSG
  /// Hilden Männer on 28.11. at 18:00, halves of 30 minutes (S1, S1.1).
  Future<Response> _createGame(Request request, String teamId) =>
      withErrorAnswers(() async {
        final home = _teamWithCode(request, teamId);
        final input = await readBody(request, api.NewGame.fromJson);
        final opponent = input.opponent;
        final away = GameTeam(
          name: toDomainName(opponent.name),
          shortCode: opponent.shortCode,
          squad: const [],
        );
        var game = Game.create(
          home: GameTeam.fromTeam(home),
          away: away,
          halfLength: Duration(minutes: input.halfLengthMinutes),
        );
        for (final player in opponent.players) {
          game = game.addToMatchReport(
              Side.away, toDomainPlayer(_newId(), player));
        }
        final stored = StoredGame(
          id: _newId(),
          homeTeamId: teamId,
          date: input.date,
          tickerCode: _newCode(),
          game: game,
        );
        _games.save(stored);
        return jsonResponse(toApiGameWithCode(stored).toJson(), status: 201);
      });

  /// GET /teams/{teamId}/games: all games with status and links (S1.3).
  Future<Response> _teamGames(Request request, String teamId) =>
      withErrorAnswers(() async {
        _teamWithCode(request, teamId);
        return jsonResponse([
          for (final stored in _games.ofTeam(teamId))
            toApiGameWithCode(stored).toJson(),
        ]);
      });

  /// GET /games/{gameId}: the game for everyone with the viewer link.
  Future<Response> _getGame(Request request, String gameId) => withErrorAnswers(
      () async => jsonResponse(toApiGame(_find(gameId)).toJson()));

  /// POST /games/{gameId}/match-report/home: e.g. Tom arrives late and is
  /// taken from the squad of TV Mettmann into the match report (S1.4).
  Future<Response> _addHomePlayer(Request request, String gameId) =>
      _changeGame(request, gameId, (stored) async {
        final ref = await readBody(request, api.SquadPlayerRef.fromJson);
        final team = _teams.byId(stored.homeTeamId)!;
        final player = team.playerById(ref.playerId) ??
            (throw const RuleViolation('Spieler nicht gefunden.'));
        return stored.game.addToMatchReport(Side.home, player);
      }, status: 201);

  /// POST /games/{gameId}/match-report/away: e.g. "12 Paul Becker" for
  /// HSG Hilden, which is not registered (S1.1, S1.4).
  Future<Response> _addAwayPlayer(Request request, String gameId) =>
      _changeGame(request, gameId, (stored) async {
        final data = await readBody(request, api.PlayerData.fromJson);
        return stored.game
            .addToMatchReport(Side.away, toDomainPlayer(_newId(), data));
      }, status: 201);

  /// DELETE /games/{gameId}/match-report/{side}/{playerId}: only before
  /// kick-off (S1.4).
  Future<Response> _removePlayer(
          Request request, String gameId, String side, String playerId) =>
      _changeGame(request, gameId, (stored) async {
        final which = Side.values.asNameMap()[side] ??
            (throw const HttpError(404, 'Diese Seite gibt es nicht.'));
        return stored.game.removeFromMatchReport(which, playerId);
      });

  /// The steps every ticker change shares: find the game (404), check the
  /// ticker code (403), let [change] return the new game, save, answer.
  Future<Response> _changeGame(
    Request request,
    String gameId,
    Future<Game> Function(StoredGame stored) change, {
    int status = 200,
  }) =>
      withErrorAnswers(() async {
        final stored = _find(gameId);
        requireCode(request, tickerCodeHeader, stored.tickerCode);
        final changed = stored.withGame(await change(stored));
        _games.save(changed);
        return jsonResponse(toApiGame(changed).toJson(), status: status);
      });

  /// The team [teamId] if the request carries its code (404, 403).
  Team _teamWithCode(Request request, String teamId) {
    final team = _teams.byId(teamId) ??
        (throw const HttpError(404, 'Team nicht gefunden.'));
    requireCode(request, TeamApi.codeHeader, team.code);
    return team;
  }

  StoredGame _find(String gameId) =>
      _games.byId(gameId) ??
      (throw const HttpError(404, 'Spiel nicht gefunden.'));
}
