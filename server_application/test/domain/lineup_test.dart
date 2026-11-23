import 'package:server_application/domain/game_event.dart';
import 'package:test/test.dart';

import 'builders.dart';

void main() {
  group('E5 lineup before kick-off', () {
    test('E5_1 Nora in goal, Max and Lisa in the field', () {
      final game = aGameWithLineups();

      final lineup = game.lineupOf(Side.home)!;

      expect(lineup.goalkeeperId, 'p-nora');
      expect(lineup.fieldPlayerIds, containsAll(['p-max', 'p-lisa']));
      expect(lineup.playerIds, hasLength(7));
    });

    test('E5_1 rejects a lineup with only 6 players', () {
      final game = aGame();

      expect(
          () => game.setLineup(
              Side.home, 'p-nora', mettmannFieldPlayers.sublist(1)),
          throwsRuleViolation(
              'Bitte 7 verschiedene Spieler aufstellen: 1 im Tor, 6 im Feld.'));
    });

    test('E5_1 rejects Jan of Hilden in the lineup of Mettmann', () {
      final game = aGame();

      expect(
          () => game.setLineup(Side.home, 'p-nora',
              ['p-jan', 'p-lisa', 'p-ben', 'p-paul', 'p-finn', 'p-leon']),
          throwsRuleViolation('Ein Spieler gehört nicht zu TV Mettmann.'));
    });

    test('E5_1 rejects kick-off before both teams are set up', () {
      final game = aGame().setLineup(Side.home, 'p-nora', mettmannFieldPlayers);

      expect(() => game.startClock(at(0)),
          throwsRuleViolation('Bitte zuerst beide Teams aufstellen.'));
    });

    test('E5_1 rejects changing the lineup after kick-off', () {
      final game = aRunningGame();

      expect(() => game.setLineup(Side.home, 'p-nora', mettmannFieldPlayers),
          throwsRuleViolation('Nach dem Anpfiff bitte wechseln.'));
    });
  });

  group('E5 substitutions', () {
    test('E5_2 Max out, Tom in', () {
      final game = aRunningGame();

      final result = game.substitute(Side.home, 'p-max', 'p-tom', at(12));

      final lineup = result.lineupOf(Side.home)!;
      expect(lineup.isOnField('p-tom'), isTrue);
      expect(lineup.isOnField('p-max'), isFalse);
    });

    test('E5_3 the substitution is stored with game time 12:00', () {
      final game = aRunningGame();

      final result = game.substitute(Side.home, 'p-max', 'p-tom', at(12));

      final event = result.events.single;
      expect(event.type, EventType.substitution);
      expect(event.gameTime, time(12));
      expect(event.playerId, 'p-max');
      expect(event.incomingPlayerId, 'p-tom');
    });

    test('E5_2 rejects bringing in Lisa, who is already on the field', () {
      final game = aRunningGame();

      expect(() => game.substitute(Side.home, 'p-max', 'p-lisa', at(12)),
          throwsRuleViolation('Dieser Spieler steht schon auf dem Feld.'));
    });

    test('E5_2 rejects taking out Tom, who sits on the bench', () {
      final game = aRunningGame();

      expect(() => game.substitute(Side.home, 'p-tom', 'p-max', at(12)),
          throwsRuleViolation('Dieser Spieler steht nicht auf dem Feld.'));
    });

    test('E5_2 a substitution cannot be deleted, swapping back undoes it', () {
      final game =
          aRunningGame().substitute(Side.home, 'p-max', 'p-tom', at(12));

      expect(
          () => game.deleteEvent(1),
          throwsRuleViolation(
              'Ein Wechsel lässt sich nicht löschen. Bitte zurückwechseln.'));
      final back = game.substitute(Side.home, 'p-tom', 'p-max', at(13));
      expect(back.lineupOf(Side.home)!.isOnField('p-max'), isTrue);
    });

    test('E5_2 Max coming back after his penalty cannot be deleted', () {
      final game = aRunningGame()
          .record(EventType.twoMinutes, Side.home, 'p-max', at(10))
          .bringOn(Side.home, 'p-max', at(12));

      expect(game.events.last.type, EventType.comesOn);
      expect(
          () => game.deleteEvent(2),
          throwsRuleViolation(
              'Ein Wechsel lässt sich nicht löschen. Bitte zurückwechseln.'));
    });

    test('E5_5 Hilden substitutes the same way: Jan out, Lars in', () {
      final game = aRunningGame();

      final result = game.substitute(Side.away, 'p-jan', 'p-lars', at(20));

      expect(result.lineupOf(Side.away)!.isOnField('p-lars'), isTrue);
    });
  });

  group('E1 goalkeeper on the field', () {
    test('E1_2 a goal of Jan stores Nora as goalkeeper', () {
      final game = aRunningGame();

      final result = game.record(EventType.goal, Side.away, 'p-jan', at(5));

      expect(result.events.single.goalkeeperId, 'p-nora');
    });

    test('E1_2 after Lea comes in for Nora, the next save is Lea\'s', () {
      final game =
          aRunningGame().substitute(Side.home, 'p-nora', 'p-lea', at(20));

      final result = game.record(EventType.save, Side.away, 'p-jan', at(21));

      expect(result.activeGoalkeeperOf(Side.home), 'p-lea');
      expect(result.events.last.goalkeeperId, 'p-lea');
    });

    test(
        'E1_5 Tom for Nora leaves the goal empty, a goal counts for no goalkeeper',
        () {
      final game =
          aRunningGame().substitute(Side.home, 'p-nora', 'p-tom', at(55));

      final result = game.record(EventType.goal, Side.away, 'p-jan', at(56));

      expect(result.lineupOf(Side.home)!.fieldPlayerIds, hasLength(7));
      expect(result.events.last.goalkeeperId, isNull);
      expect(result.score.away, 1);
    });

    test('E1_5 Nora comes back into the empty goal for Tom', () {
      final game = aRunningGame()
          .substitute(Side.home, 'p-nora', 'p-tom', at(55))
          .substitute(Side.home, 'p-max', 'p-nora', at(56));

      final lineup = game.lineupOf(Side.home)!;

      expect(lineup.goalkeeperId, 'p-nora');
      expect(lineup.fieldPlayerIds, hasLength(6));
    });

    test('R5 rejects a save while Mettmann has no goalkeeper on the field', () {
      final game =
          aRunningGame().substitute(Side.home, 'p-nora', 'p-tom', at(55));

      expect(() => game.record(EventType.save, Side.away, 'p-jan', at(56)),
          throwsRuleViolation('TV Mettmann hat keinen Torwart auf dem Feld.'));
    });
  });

  group('R7 who can get events', () {
    test('R7 rejects a goal by Tom, who sits on the bench', () {
      final game = aRunningGame();

      expect(() => game.record(EventType.goal, Side.home, 'p-tom', at(5)),
          throwsRuleViolation('Dieser Spieler steht nicht auf dem Feld.'));
    });

    test('R7 Tom on the bench can get a yellow card', () {
      final game = aRunningGame();

      final result =
          game.record(EventType.yellowCard, Side.home, 'p-tom', at(5));

      expect(result.events.single.playerId, 'p-tom');
    });

    test('R7 a substitution keeps 7 players on the field', () {
      final game = aRunningGame();

      final result = game.substitute(Side.home, 'p-max', 'p-tom', at(12));

      expect(result.lineupOf(Side.home)!.playerIds, hasLength(7));
    });
  });
}
