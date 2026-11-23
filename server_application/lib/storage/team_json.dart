import '../domain/player.dart';
import '../domain/team.dart';
import '../domain/team_name.dart';

/// Turns a team into JSON for data/teams.json and back (ADR-004).
///
/// Unlike the API, the stored JSON contains the secret code.
/// Example: {"name": {"club": "TV Mettmann", "ageGroup": "men",
/// "teamNumber": 1}, "shortCode": "TVM", "code": "...", "players": [...]}.
Map<String, Object?> teamToJson(Team team) => {
      'name': teamNameToJson(team.name),
      'shortCode': team.shortCode,
      'code': team.code,
      'logoRef': team.logoRef,
      'players': [for (final player in team.squad) playerToJson(player)],
    };

/// Builds the team again. The rules of the domain are checked once more,
/// so a broken file cannot create an invalid team.
Team teamFromJson(Map<String, Object?> json) {
  var team = Team.create(
    name: teamNameFromJson(json['name'] as Map<String, Object?>),
    shortCode: json['shortCode'] as String,
    code: json['code'] as String,
    logoRef: json['logoRef'] as String?,
  );
  for (final player in json['players'] as List<Object?>) {
    team = team.addPlayer(playerFromJson(player as Map<String, Object?>));
  }
  return team;
}

Map<String, Object?> playerToJson(Player player) => {
      'id': player.id,
      'number': player.number,
      'firstName': player.firstName,
      'lastName': player.lastName,
      'position': player.position.name,
    };

Player playerFromJson(Map<String, Object?> json) => Player(
      id: json['id'] as String,
      number: json['number'] as int,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      position: Position.values.byName(json['position'] as String),
    );

Map<String, Object?> teamNameToJson(TeamName name) => {
      'club': name.club,
      'ageGroup': name.ageGroup.name,
      'teamNumber': name.teamNumber,
    };

TeamName teamNameFromJson(Map<String, Object?> json) => TeamName(
      club: json['club'] as String,
      ageGroup: AgeGroup.values.byName(json['ageGroup'] as String),
      teamNumber: json['teamNumber'] as int,
    );
