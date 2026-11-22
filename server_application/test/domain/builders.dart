import 'package:server_application/domain/player.dart';
import 'package:server_application/domain/team.dart';

/// Test data with sensible defaults. A test only names the values it cares about.

Player aPlayer({
  String id = 'p-max',
  int number = 7,
  String firstName = 'Max',
  String lastName = 'Mustermann',
  Position position = Position.fieldPlayer,
}) {
  return Player(
    id: id,
    number: number,
    firstName: firstName,
    lastName: lastName,
    position: position,
  );
}

Player max() => aPlayer();

Player lisa() => aPlayer(id: 'p-lisa', number: 12, firstName: 'Lisa');

Player tom() =>
    aPlayer(id: 'p-tom', number: 9, firstName: 'Tom', lastName: 'Neumann');

Player nora() => aPlayer(
      id: 'p-nora',
      number: 1,
      firstName: 'Nora',
      lastName: 'Neumann',
      position: Position.goalkeeper,
    );

/// TV Mettmann without players.
Team anEmptyTeam() =>
    Team.create(name: 'TV Mettmann', shortCode: 'TVM', code: 'abc123');

/// TV Mettmann with Max (7), Lisa (12) and Nora (1). Tom is not in it yet.
Team mettmann() =>
    anEmptyTeam().addPlayer(max()).addPlayer(lisa()).addPlayer(nora());
