import 'package:server_application/domain/game.dart';
import 'package:server_application/domain/game_event.dart';
import 'package:server_application/domain/game_team.dart';
import 'package:test/test.dart';

import 'builders.dart';

/// Adds players No. 20, 21, … to the home report until it has 16 players.
Game withFullHomeReport(Game game) {
  var number = 20;
  while (game.home.squad.length < 16) {
    game = game.addToMatchReport(
        Side.home, aPlayer(id: 'p-$number', number: number));
    number++;
  }
  return game;
}

/// Kick-off at 15:00 without Tom, who is not there yet.
Game aGameWithoutTom() => aGameWithLineups()
    .removeFromMatchReport(Side.home, 'p-tom')
    .startClock(at(0));

void main() {
  group('S1_4 match report', () {
    test('S1_4 with 18 players in the squad, numbers 1 to 16 are in it', () {
      var team = anEmptyTeam();
      for (var number = 1; number <= 18; number++) {
        team = team.addPlayer(aPlayer(id: 'p$number', number: number));
      }

      final report = GameTeam.fromTeam(team).squad;

      expect(report, hasLength(16));
      expect(report.map((p) => p.number), List.generate(16, (i) => i + 1));
    });

    test('S1_4 Tom arrives late at 12:00 and sits on the bench', () {
      final game = aGameWithoutTom().addToMatchReport(Side.home, tom());

      expect(game.home.hasPlayer('p-tom'), isTrue);
      expect(game.lineupOf(Side.home)!.isOnField('p-tom'), isFalse);
    });

    test('S1_4 the late player can come in by substitution', () {
      final game = aGameWithoutTom().addToMatchReport(Side.home, tom());

      final result = game.substitute(Side.home, 'p-max', 'p-tom', at(13));

      expect(result.lineupOf(Side.home)!.isOnField('p-tom'), isTrue);
    });

    test('S1_4 a 17th player is rejected', () {
      final game = withFullHomeReport(aRunningGame());

      expect(
          () =>
              game.addToMatchReport(Side.home, aPlayer(id: 'p-99', number: 99)),
          throwsRuleViolation('Im Spielbericht stehen schon 16 Spieler.'));
    });

    test('S1_4 Tom with No. 7 next to Max is rejected', () {
      final game = aGameWithoutTom();

      expect(() => game.addToMatchReport(Side.home, tom().copyWith(number: 7)),
          throwsRuleViolation('Die Nummer 7 ist schon vergeben.'));
    });

    test('S1_4 Max cannot be added twice', () {
      final game = aRunningGame();

      expect(() => game.addToMatchReport(Side.home, max()),
          throwsRuleViolation('Max steht schon im Spielbericht.'));
    });

    test('S1_1 Hilden adds 12 Paul Becker to its own game squad', () {
      final game = aGame().addToMatchReport(
          Side.away, aPlayer(id: 'p-hpaul', number: 12, firstName: 'Paul'));

      expect(game.away.playerById('p-hpaul')!.number, 12);
    });

    test('S1_4 nothing can be added after the end of the game', () {
      final game = aGameWithoutTom().halfTime().startClock(at(40)).end(at(70));

      expect(() => game.addToMatchReport(Side.home, tom()),
          throwsRuleViolation('Das Spiel ist beendet.'));
    });
  });

  group('S1_4 take a player out of the match report', () {
    test('S1_4 Tom on the bench can be taken out before kick-off', () {
      final game = aGameWithLineups();

      final result = game.removeFromMatchReport(Side.home, 'p-tom');

      expect(result.home.hasPlayer('p-tom'), isFalse);
    });

    test('S1_4 Max in the starting lineup cannot be taken out', () {
      final game = aGameWithLineups();

      expect(() => game.removeFromMatchReport(Side.home, 'p-max'),
          throwsRuleViolation('Der Spieler steht in der Aufstellung.'));
    });

    test('S1_4 after kick-off nobody is taken out', () {
      final game = aRunningGame();

      expect(
          () => game.removeFromMatchReport(Side.home, 'p-tom'),
          throwsRuleViolation(
              'Nach dem Anpfiff bleibt der Spieler im Spielbericht.'));
    });
  });
}
