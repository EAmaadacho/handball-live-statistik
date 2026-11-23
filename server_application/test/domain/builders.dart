import 'package:test/test.dart';
import 'package:server_application/domain/rule_violation.dart';
import 'package:server_application/domain/game.dart';
import 'package:server_application/domain/game_clock.dart';
import 'package:server_application/domain/game_event.dart';
import 'package:server_application/domain/game_team.dart';
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

/// A fixed moment on game day: 22.11.2026, 15:00:00 plus [minutes] and [seconds].
DateTime at(int minutes, [int seconds = 0]) => DateTime(2026, 11, 22, 15)
    .add(Duration(minutes: minutes, seconds: seconds));

/// A game time like "23:14", written as `time(23, 14)`.
Duration time(int minutes, [int seconds = 0]) =>
    Duration(minutes: minutes, seconds: seconds);

/// A clock in the first half, started at 15:00:00 and running from 00:00.
GameClock aRunningClock() => GameClock.initial().start(at(0));

/// A clock in the second half, started at 15:00:00 and running from 30:00.
GameClock aClockInTheSecondHalf() => aRunningClock().halfTime().start(at(0));

/// Expects a [RuleViolation] with exactly this German [message].
Matcher throwsRuleViolation(String message) => throwsA(
      isA<RuleViolation>().having((e) => e.message, 'message', message),
    );

Player _field(String name, int number, [String lastName = 'Schulz']) => aPlayer(
    id: 'p-${name.toLowerCase()}',
    number: number,
    firstName: name,
    lastName: lastName);

Player _keeper(String name, int number, String lastName) => aPlayer(
      id: 'p-${name.toLowerCase()}',
      number: number,
      firstName: name,
      lastName: lastName,
      position: Position.goalkeeper,
    );

/// Lea Neumann (No. 16), second goalkeeper of TV Mettmann, on the bench.
Player lea() => _keeper('Lea', 16, 'Neumann');

/// Jan Becker (No. 5) of HSG Hilden, the opponent without registration.
Player jan() => _field('Jan', 5, 'Becker');

/// TV Mettmann for one game. Starting: Nora in goal; Max, Lisa, Ben, Paul,
/// Finn, Leon in the field. Bench: Tom and goalkeeper Lea.
GameTeam mettmannInGame() => GameTeam(
      name: 'TV Mettmann',
      shortCode: 'TVM',
      squad: [
        nora(),
        max(),
        lisa(),
        _field('Ben', 2),
        _field('Paul', 3),
        _field('Finn', 4),
        _field('Leon', 6),
        tom(),
        lea(),
      ],
    );

/// HSG Hilden with a game squad of its own (S1.1). Starting: Kai in goal;
/// Jan, Ole, Tim, Nils, Erik, Moritz in the field. Bench: Lars.
GameTeam hilden() => GameTeam(
      name: 'HSG Hilden',
      shortCode: 'HSG',
      squad: [
        _keeper('Kai', 1, 'Becker'),
        jan(),
        _field('Ole', 3, 'Becker'),
        _field('Tim', 4, 'Becker'),
        _field('Nils', 6, 'Becker'),
        _field('Erik', 8, 'Becker'),
        _field('Moritz', 10, 'Becker'),
        _field('Lars', 11, 'Becker'),
      ],
    );

const mettmannFieldPlayers = [
  'p-max',
  'p-lisa',
  'p-ben',
  'p-paul',
  'p-finn',
  'p-leon'
];
const hildenFieldPlayers = [
  'p-jan',
  'p-ole',
  'p-tim',
  'p-nils',
  'p-erik',
  'p-moritz'
];

/// TV Mettmann against HSG Hilden before kick-off, without lineups.
Game aGame() => Game.create(home: mettmannInGame(), away: hilden());

/// Both teams set up with their starting lineups, before kick-off.
Game aGameWithLineups() => aGame()
    .setLineup(Side.home, 'p-nora', mettmannFieldPlayers)
    .setLineup(Side.away, 'p-kai', hildenFieldPlayers);

/// TV Mettmann against HSG Hilden, kick-off at 15:00:00, clock running.
Game aRunningGame() => aGameWithLineups().startClock(at(0));

/// Adds [count] goals for [side] at 15:01:00, by Max (home) or Jan (away).
Game withGoals(Game game, Side side, int count) {
  final playerId = side == Side.home ? 'p-max' : 'p-jan';
  for (var i = 0; i < count; i++) {
    game = game.record(EventType.goal, side, playerId, at(1));
  }
  return game;
}
