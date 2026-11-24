import 'package:openapi/api.dart' as api;

import 'api_errors.dart';
import 'models.dart';
import 'team_source.dart';

/// The team management over the Dart server (api.yaml, T1, T2, S1).
///
/// Every change sends the secret code from the team link as X-Team-Code.
/// The server's "no" becomes RejectedAction with its text, e.g.
/// "TV Mettmann Männer gibt es schon." (T1.1).
class ApiTeamSource implements TeamSource {
  ApiTeamSource(api.ApiClient client)
      : _teams = api.TeamsApi(client),
        _games = api.GamesApi(client);

  final api.TeamsApi _teams;
  final api.GamesApi _games;

  static const _forbidden = 'Dieser Team-Link ist ungültig.';

  @override
  Future<({String teamId, String code})> createTeam(
      TeamName name, String shortName) async {
    final created = await _call(() => _teams.createTeam(
        api.NewTeam(name: _apiName(name), shortCode: shortName.trim())));
    return (teamId: created!.team.id, code: created.code);
  }

  /// The games list needs the code: if it answers, the link is right.
  @override
  Future<Team?> loadTeam(String teamId, String code) async {
    try {
      await _games.getTeamGames(teamId, code);
      return _team((await _teams.getTeam(teamId))!);
    } on api.ApiException catch (e) {
      if (e.innerException == null && (e.code == 403 || e.code == 404)) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<Team> addPlayer(String teamId, String code, SquadEntry player) async =>
      _team((await _call(
          () => _teams.addPlayer(teamId, code, _apiPlayer(player))))!);

  @override
  Future<Team> updatePlayer(String teamId, String code, String playerId,
          SquadEntry player) async =>
      _team((await _call(() =>
          _teams.updatePlayer(teamId, code, playerId, _apiPlayer(player))))!);

  @override
  Future<Team> removePlayer(
          String teamId, String code, String playerId) async =>
      _team((await _call(() => _teams.removePlayer(teamId, code, playerId)))!);

  @override
  Future<List<TeamGame>> loadGames(String teamId, String code) async {
    final games = await _call(() => _games.getTeamGames(teamId, code));
    return [for (final g in games ?? const <api.GameWithCode>[]) _game(g)];
  }

  @override
  Future<TeamGame> createGame(
      String teamId, String code, NewGameEntry game) async {
    final created = await _call(() => _games.createGame(
          teamId,
          code,
          api.NewGame(
            opponent: api.Opponent(
              name: _apiName(game.opponent),
              shortCode: game.opponentShortName.trim(),
              players: [for (final p in game.opponentPlayers) _apiPlayer(p)],
            ),
            // With time zone, e.g. 2026-11-29T14:00:00.000Z for 15:00 in Germany.
            date: game.date.toUtc(),
            halfLengthMinutes: game.halfMinutes,
          ),
        ));
    return _game(created!);
  }

  Future<T> _call<T>(Future<T> Function() send) async {
    try {
      return await send();
    } on api.ApiException catch (e) {
      throw rejectionOf(e, forbidden: _forbidden) ?? e;
    }
  }

  static api.TeamName _apiName(TeamName name) => api.TeamName(
      club: name.club.trim(),
      ageGroup: api.AgeGroup.fromJson(name.ageGroup.name)!,
      teamNumber: name.teamNumber);

  static api.PlayerData _apiPlayer(SquadEntry p) => api.PlayerData(
      number: p.number,
      firstName: p.firstName.trim(),
      lastName: p.lastName.trim(),
      position:
          p.isGoalkeeper ? api.Position.goalkeeper : api.Position.fieldPlayer);

  static Team _team(api.Team team) => Team(
        id: team.id,
        name: team.displayName,
        shortName: team.shortCode,
        players: [
          for (final p in team.players)
            Player(
                id: p.id,
                number: p.number,
                firstName: p.firstName,
                lastName: p.lastName,
                isGoalkeeper: p.position == api.Position.goalkeeper),
        ],
      );

  static TeamGame _game(api.GameWithCode g) => TeamGame(
        id: g.game.id,
        tickerCode: g.tickerCode,
        opponent: g.game.away.displayName,
        date: g.game.date.toLocal(),
        status: TeamGameStatus.values.byName(g.game.status.value),
      );
}
