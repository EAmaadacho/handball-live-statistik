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
GameClock aClockInTheSecondHalf() =>
    aRunningClock().halfTime(at(30)).start(at(0));

/// Expects a [RuleViolation] with exactly this German [message].
Matcher throwsRuleViolation(String message) => throwsA(
      isA<RuleViolation>().having((e) => e.message, 'message', message),
    );

/// Jan Becker (No. 5) of HSG Hilden, the opponent without registration.
Player jan() =>
    aPlayer(id: 'p-jan', number: 5, firstName: 'Jan', lastName: 'Becker');

/// HSG Hilden with a game squad of its own (S1.1).
GameTeam hilden() =>
    GameTeam(name: 'HSG Hilden', shortCode: 'HSG', squad: [jan()]);

/// TV Mettmann against HSG Hilden before kick-off.
Game aGame() =>
    Game.create(home: GameTeam.fromTeam(mettmann()), away: hilden());

/// TV Mettmann against HSG Hilden, kick-off at 15:00:00, clock running.
Game aRunningGame() => aGame().startClock(at(0));

/// Adds [count] goals for [side] at 15:01:00, by Max (home) or Jan (away).
Game withGoals(Game game, Side side, int count) {
  final playerId = side == Side.home ? 'p-max' : 'p-jan';
  for (var i = 0; i < count; i++) {
    game = game.record(EventType.goal, side, playerId, at(1));
  }
  return game;
}
