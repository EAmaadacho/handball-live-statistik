import 'package:openapi/api.dart' as api;

import '../domain/player.dart';
import '../domain/team.dart';
import '../domain/team_name.dart';

/// Translates between the generated API classes (api.yaml) and the domain.
///
/// Enum values have the same names on both sides, e.g. "maleA".

/// The team as everyone may read it: without the secret code.
api.Team toApiTeam(String id, Team team) => api.Team(
      id: id,
      name: toApiName(team.name),
      displayName: team.name.display,
      shortCode: team.shortCode,
      players: [for (final player in team.squad) toApiPlayer(player)],
    );

api.Player toApiPlayer(Player player) => api.Player(
      id: player.id,
      number: player.number,
      firstName: player.firstName,
      lastName: player.lastName,
      position: api.Position.fromJson(player.position.name)!,
    );

api.TeamName toApiName(TeamName name) => api.TeamName(
      club: name.club,
      ageGroup: api.AgeGroup.fromJson(name.ageGroup.name)!,
      teamNumber: name.teamNumber,
    );

TeamName toDomainName(api.TeamName name) => TeamName(
      club: name.club,
      ageGroup: AgeGroup.values.byName(name.ageGroup.value),
      teamNumber: name.teamNumber,
    );

/// A player with [id] from what the team manager entered.
Player toDomainPlayer(String id, api.PlayerData data) => Player(
      id: id,
      number: data.number,
      firstName: data.firstName,
      lastName: data.lastName,
      position: Position.values.byName(data.position.value),
    );
