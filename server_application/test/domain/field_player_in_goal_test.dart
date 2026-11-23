import 'package:server_application/domain/game.dart';
import 'package:server_application/domain/game_event.dart';
import 'package:test/test.dart';

import 'builders.dart';

/// TV Mettmann after Nora went out for Tom at 20:00: the goal is empty.
Game aGameWithEmptyGoal() =>
    aRunningGame().substitute(Side.home, 'p-nora', 'p-tom', at(20));

void main() {
  group('E5_7 field player in goal', () {
    test('E5_7 Max may start in goal, a save of Jan then counts for Max', () {
      final game = aGame()
          .setLineup(Side.home, 'p-max',
              ['p-nora', 'p-lisa', 'p-ben', 'p-paul', 'p-finn', 'p-leon'])
          .setLineup(Side.away, 'p-kai', hildenFieldPlayers)
          .startClock(at(0));

      final result = game.record(EventType.save, Side.away, 'p-jan', at(5));

      expect(result.activeGoalkeeperOf(Side.home), 'p-max');
      expect(result.events.single.goalkeeperId, 'p-max');
    });

    test('E5_7 Max moves into the empty goal, saves and goals count for him',
        () {
      final game = aGameWithEmptyGoal().putInGoal(Side.home, 'p-max', at(21));

      final result = game
          .record(EventType.save, Side.away, 'p-jan', at(22))
          .record(EventType.goal, Side.away, 'p-jan', at(23));

      final max = result
          .statisticsOf(Side.home)
          .singleWhere((s) => s.playerId == 'p-max');
      expect(max.saves, 1);
      expect(max.goalsAgainst, 1);
      expect(max.savePercentage, 50);
    });

    test('E5_7 "Ins Tor" is stored with game time and keeps 7 on the field',
        () {
      final result = aGameWithEmptyGoal().putInGoal(Side.home, 'p-max', at(21));

      final lineup = result.lineupOf(Side.home)!;
      expect(lineup.goalkeeperId, 'p-max');
      expect(lineup.fieldPlayerIds, hasLength(6));
      expect(result.events.last.type, EventType.movesIntoGoal);
      expect(result.events.last.gameTime, time(21));
    });

    test('E5_7 rejects Max into goal while Nora stands in goal', () {
      final game = aRunningGame();

      expect(() => game.putInGoal(Side.home, 'p-max', at(5)),
          throwsRuleViolation('Im Tor steht schon Nora.'));
    });

    test('E5_7 rejects Lea from the bench, she comes in by substitution', () {
      final game = aGameWithEmptyGoal();

      expect(() => game.putInGoal(Side.home, 'p-lea', at(21)),
          throwsRuleViolation('Dieser Spieler steht nicht auf dem Feld.'));
    });

    test('E5_7 "Ins Tor" cannot be deleted', () {
      final game = aGameWithEmptyGoal().putInGoal(Side.home, 'p-max', at(21));

      expect(
          () => game.deleteEvent(2),
          throwsRuleViolation(
              'Ein Wechsel lässt sich nicht löschen. Bitte zurückwechseln.'));
    });

    test('E5_7 "Ins Tor" cannot be recorded as a normal event', () {
      final game = aGameWithEmptyGoal();

      expect(
          () =>
              game.record(EventType.movesIntoGoal, Side.home, 'p-max', at(21)),
          throwsRuleViolation('Wechsel bitte über „Wechseln“.'));
    });

    test('E5_7 Tom comes in for Nora straight into goal', () {
      final game = aRunningGame();

      final result =
          game.substitute(Side.home, 'p-nora', 'p-tom', at(20), intoGoal: true);

      expect(result.activeGoalkeeperOf(Side.home), 'p-tom');
      expect(result.lineupOf(Side.home)!.fieldPlayerIds, hasLength(6));
    });

    test('E5_7 rejects Tom into goal for Max while Nora stands in goal', () {
      final game = aRunningGame();

      expect(
          () => game.substitute(Side.home, 'p-max', 'p-tom', at(20),
              intoGoal: true),
          throwsRuleViolation('Im Tor steht schon Nora.'));
    });

    test('E1_5 Lea for Nora without "into goal" plays as 7th field player', () {
      final game = aRunningGame();

      final result = game.substitute(Side.home, 'p-nora', 'p-lea', at(55),
          intoGoal: false);

      expect(result.activeGoalkeeperOf(Side.home), isNull);
      expect(result.lineupOf(Side.home)!.fieldPlayerIds, hasLength(7));
    });

    test('E5_6 Max in goal gets two minutes, the goal is empty again', () {
      final game = aGameWithEmptyGoal().putInGoal(Side.home, 'p-max', at(21));

      final result =
          game.record(EventType.twoMinutes, Side.home, 'p-max', at(22));

      expect(result.activeGoalkeeperOf(Side.home), isNull);
    });

    test('E5_7 after her penalty Lea comes onto the field, Max stays in goal',
        () {
      final game = aRunningGame()
          .substitute(Side.home, 'p-nora', 'p-lea', at(10))
          .record(EventType.twoMinutes, Side.home, 'p-lea', at(20))
          .putInGoal(Side.home, 'p-max', at(20));

      final result = game.bringOn(Side.home, 'p-lea', at(22));

      expect(result.activeGoalkeeperOf(Side.home), 'p-max');
      expect(result.lineupOf(Side.home)!.isOnField('p-lea'), isTrue);
      expect(() => game.bringOn(Side.home, 'p-lea', at(22), intoGoal: true),
          throwsRuleViolation('Im Tor steht schon Max.'));
    });

    test('E2 deleting Nora\'s penalty is rejected once Max went into goal', () {
      final game = aRunningGame()
          .record(EventType.twoMinutes, Side.home, 'p-nora', at(20))
          .putInGoal(Side.home, 'p-max', at(20));

      expect(
          () => game.deleteEvent(1),
          throwsRuleViolation(
              'Löschen geht nicht mehr, danach wurde schon gewechselt.'));
    });
  });
}
