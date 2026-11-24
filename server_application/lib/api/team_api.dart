import 'package:openapi/api.dart' as api;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../domain/logo.dart';
import '../domain/team.dart';
import '../storage/logo_store.dart';
import '../storage/team_repository.dart';
import 'random_code.dart';
import 'responses.dart';
import 'team_mapping.dart';

/// The HTTP endpoints for teams and squads (T1, T2), see api.yaml.
///
/// Each handler reads the request, lets the domain do the work, saves the
/// result and answers with JSON. Reading is open to everyone; changes need
/// the secret team code in the header X-Team-Code (T1.2, ADR-005).
class TeamApi {
  static const codeHeader = 'x-team-code';

  final TeamRepository _teams;
  final LogoStore _logos;
  final String Function() _newCode;
  final String Function() _newId;

  /// [newCode] and [newId] can be replaced in tests to get fixed values.
  TeamApi(this._teams,
      {required LogoStore logos,
      String Function()? newCode,
      String Function()? newId})
      : _logos = logos,
        _newCode = newCode ?? randomCode,
        _newId = newId ?? (() => randomCode(8));

  Router get router => Router()
    ..post('/teams', _createTeam)
    ..get('/teams/<teamId>', _getTeam)
    ..post('/teams/<teamId>/players', _addPlayer)
    ..put('/teams/<teamId>/players/<playerId>', _updatePlayer)
    ..delete('/teams/<teamId>/players/<playerId>', _removePlayer)
    ..put('/teams/<teamId>/logo', _uploadLogo)
    ..get('/teams/<teamId>/logo', _getLogo);

  /// POST /teams: creates TV Mettmann Männer and answers with the code,
  /// which is never sent again (T1, T1.1, T1.2).
  Future<Response> _createTeam(Request request) => withErrorAnswers(() async {
        final input = await readBody(request, api.NewTeam.fromJson);
        final name = toDomainName(input.name);
        if (_teams.isNameTaken(name)) {
          throw HttpError(409, '${name.display} gibt es schon.');
        }
        final id = _newId();
        final team = Team.create(
            name: name, shortCode: input.shortCode, code: _newCode());
        _teams.save(id, team);
        final created =
            api.CreatedTeam(team: toApiTeam(id, team), code: team.code);
        return jsonResponse(created.toJson(), status: 201);
      });

  /// GET /teams/{teamId}: the team with its squad, without the code.
  Future<Response> _getTeam(Request request, String teamId) =>
      withErrorAnswers(() async {
        return jsonResponse(toApiTeam(teamId, _find(teamId)).toJson());
      });

  /// POST /teams/{teamId}/players: adds e.g. 9 Tom Neumann (T2, T2.1).
  Future<Response> _addPlayer(Request request, String teamId) =>
      _changeTeam(request, teamId, (team) async {
        final data = await readBody(request, api.PlayerData.fromJson);
        return team.addPlayer(toDomainPlayer(_newId(), data));
      }, status: 201);

  /// PUT /teams/{teamId}/players/{playerId}: e.g. Max gets No. 10.
  Future<Response> _updatePlayer(
          Request request, String teamId, String playerId) =>
      _changeTeam(request, teamId, (team) async {
        final data = await readBody(request, api.PlayerData.fromJson);
        return team.updatePlayer(toDomainPlayer(playerId, data));
      });

  /// DELETE /teams/{teamId}/players/{playerId}: old games keep the player.
  Future<Response> _removePlayer(
          Request request, String teamId, String playerId) =>
      _changeTeam(request, teamId, (team) async => team.removePlayer(playerId));

  /// PUT /teams/{teamId}/logo: the body is the image itself, e.g. the
  /// PNG of TV Mettmann. Replaces an older logo (T6, T6.1).
  Future<Response> _uploadLogo(Request request, String teamId) =>
      _changeTeam(request, teamId, (team) async {
        final bytes = await request.read().expand((chunk) => chunk).toList();
        final fileType = checkLogo(bytes);
        return team.withLogo(_logos.save(teamId, bytes, fileType));
      });

  /// GET /teams/{teamId}/logo: the logo for everyone, e.g. on the live
  /// page. Without a logo 404, the app then shows the short code (T6.2).
  Future<Response> _getLogo(Request request, String teamId) =>
      withErrorAnswers(() async {
        final logoRef = _find(teamId).logoRef;
        final bytes = logoRef == null ? null : _logos.read(logoRef);
        if (bytes == null) throw const HttpError(404, 'Kein Logo vorhanden.');
        final type = logoRef!.endsWith('.png') ? 'image/png' : 'image/jpeg';
        return Response.ok(bytes, headers: {'content-type': type});
      });

  /// The steps every change shares: find the team (404), check the code
  /// (403), let [change] return the new team, save it and answer with it.
  Future<Response> _changeTeam(
    Request request,
    String teamId,
    Future<Team> Function(Team team) change, {
    int status = 200,
  }) =>
      withErrorAnswers(() async {
        final team = _find(teamId);
        requireCode(request, codeHeader, team.code);
        final changed = await change(team);
        _teams.save(teamId, changed);
        return jsonResponse(toApiTeam(teamId, changed).toJson(),
            status: status);
      });

  Team _find(String teamId) =>
      _teams.byId(teamId) ??
      (throw const HttpError(404, 'Team nicht gefunden.'));
}
