import 'package:server_application/domain/game_event.dart';
import 'package:test/test.dart';

import 'builders.dart';

void main() {
  group('E5_4 a penalised player leaves the field', () {
    test('E5_4 Max gets two minutes and leaves the field, Mettmann has 6', () {
      final game = aRunningGame();

      final result =
          game.record(EventType.twoMinutes, Side.home, 'p-max', at(23));

      final lineup = result.lineupOf(Side.home)!;
      expect(lineup.isOnField('p-max'), isFalse);
      expect(lineup.playerIds, hasLength(6));
    });

    test('E5_4 Tom on the bench gets two minutes, Lisa has to leave the field',
        () {
      final game = aRunningGame();

      final result = game.record(
          EventType.twoMinutes, Side.home, 'p-tom', at(23),
          leavingPlayerId: 'p-lisa');

      expect(result.lineupOf(Side.home)!.isOnField('p-lisa'), isFalse);
      expect(result.lineupOf(Side.home)!.playerIds, hasLength(6));
    });

    test(
        'E5_4 rejects two minutes for Tom on the bench without choosing who leaves',
        () {
      final game = aRunningGame();

      expect(
          () => game.record(EventType.twoMinutes, Side.home, 'p-tom', at(23)),
          throwsRuleViolation('Bitte wählen, wer das Feld verlässt.'));
    });

    test('E5_4 a yellow card leaves Max on the field', () {
      final game = aRunningGame();

      final result =
          game.record(EventType.yellowCard, Side.home, 'p-max', at(23));

      expect(result.lineupOf(Side.home)!.isOnField('p-max'), isTrue);
    });
  });

  group('R7 coming back after the penalty', () {
    test('R7 rejects bringing Tom on while Max\'s penalty runs (24:00)', () {
      final game = aRunningGame()
          .record(EventType.twoMinutes, Side.home, 'p-max', at(23));

      expect(() => game.bringOn(Side.home, 'p-tom', at(24)),
          throwsRuleViolation('TV Mettmann ist noch in Unterzahl.'));
    });

    test('R7 after 25:00 the ticker brings Tom on instead of Max', () {
      final game = aRunningGame()
          .record(EventType.twoMinutes, Side.home, 'p-max', at(23));

      final result = game.bringOn(Side.home, 'p-tom', at(25));

      expect(result.lineupOf(Side.home)!.isOnField('p-tom'), isTrue);
      expect(result.lineupOf(Side.home)!.playerIds, hasLength(7));
    });

    test('R7 rejects bringing a player on when all 7 places are taken', () {
      final game = aRunningGame();

      expect(() => game.bringOn(Side.home, 'p-tom', at(5)),
          throwsRuleViolation('Auf dem Feld ist kein Platz frei.'));
    });

    test('L3_3 after a red card for Lisa, Mettmann plays 2 minutes with 6', () {
      final game =
          aRunningGame().record(EventType.redCard, Side.home, 'p-lisa', at(10));

      expect(() => game.bringOn(Side.home, 'p-tom', at(11)),
          throwsRuleViolation('TV Mettmann ist noch in Unterzahl.'));
      final later = game.bringOn(Side.home, 'p-tom', at(12));
      expect(later.lineupOf(Side.home)!.playerIds, hasLength(7));
    });
  });

  group('E5_6 goalkeeper with a penalty', () {
    test('E5_6 Nora gets two minutes, the goal stays empty', () {
      final game = aRunningGame();

      final result =
          game.record(EventType.twoMinutes, Side.home, 'p-nora', at(20));

      expect(result.activeGoalkeeperOf(Side.home), isNull);
      final goal = result.record(EventType.goal, Side.away, 'p-jan', at(21));
      expect(goal.events.last.goalkeeperId, isNull);
    });

    test('E5_6 Lea goes into goal for Ben while Nora sits out', () {
      final game = aRunningGame()
          .record(EventType.twoMinutes, Side.home, 'p-nora', at(20));

      final result = game.substitute(Side.home, 'p-ben', 'p-lea', at(20));

      expect(result.activeGoalkeeperOf(Side.home), 'p-lea');
      expect(result.lineupOf(Side.home)!.playerIds, hasLength(6));
    });
  });

  group('E1_5 empty goal while short-handed', () {
    test(
        'E1_5 with Max out for two minutes, Tom for Nora gives 6 field players and an empty goal',
        () {
      final game = aRunningGame()
          .record(EventType.twoMinutes, Side.home, 'p-max', at(23));

      final result = game.substitute(Side.home, 'p-nora', 'p-tom', at(23, 30));

      final lineup = result.lineupOf(Side.home)!;
      expect(lineup.goalkeeperId, isNull);
      expect(lineup.fieldPlayerIds, hasLength(6));
    });
  });

  group('L3 remaining time', () {
    test('L3_1 Max gets two minutes at 23:00, at 24:37 there are 0:23 left',
        () {
      final game = aRunningGame()
          .record(EventType.twoMinutes, Side.home, 'p-max', at(23));

      final penalties = game.runningPenalties(at(24, 37));

      expect(penalties.single.playerId, 'p-max');
      expect(penalties.single.remaining, time(0, 23));
      expect(game.isShortHanded(Side.home, at(24, 37)), isTrue);
    });

    test('L3_1 while the clock stands, the remaining time stands too', () {
      final game = aRunningGame()
          .record(EventType.twoMinutes, Side.home, 'p-max', at(23))
          .stopClock(at(24));

      final penalties = game.runningPenalties(at(30));

      expect(penalties.single.remaining, time(1));
    });

    test('L3_1 at 25:00 the penalty is over', () {
      final game = aRunningGame()
          .record(EventType.twoMinutes, Side.home, 'p-max', at(23));

      expect(game.runningPenalties(at(25)), isEmpty);
      expect(game.isShortHanded(Side.home, at(25)), isFalse);
    });

    test('L3_2 two minutes at 29:00 still run at 30:30 in the second half', () {
      final game = aRunningGame()
          .record(EventType.twoMinutes, Side.home, 'p-max', at(29))
          .halfTime(at(30))
          .startClock(at(45));

      final penalties = game.runningPenalties(at(45, 30));

      expect(penalties.single.remaining, time(0, 30));
    });
  });

  group('E2 deleting a penalty', () {
    test('E2 deleting Max\'s penalty brings him back onto the field', () {
      final game = aRunningGame()
          .record(EventType.twoMinutes, Side.home, 'p-max', at(23));

      final result = game.deleteEvent(game.events.last.number);

      expect(result.lineupOf(Side.home)!.isOnField('p-max'), isTrue);
      expect(result.runningPenalties(at(24)), isEmpty);
    });

    test('E2 rejects deleting Max\'s penalty after Tom took his free place',
        () {
      final game = aRunningGame()
          .record(EventType.twoMinutes, Side.home, 'p-max', at(23))
          .bringOn(Side.home, 'p-tom', at(25));

      expect(
          () => game.deleteEvent(1),
          throwsRuleViolation(
              'Löschen geht nicht mehr, danach wurde schon gewechselt.'));
    });
  });
}
