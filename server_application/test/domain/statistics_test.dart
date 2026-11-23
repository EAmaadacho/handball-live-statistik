import 'package:server_application/domain/game.dart';
import 'package:server_application/domain/game_event.dart';
import 'package:server_application/domain/statistics.dart';
import 'package:test/test.dart';

import 'builders.dart';

/// Records [count] events of [type] by [playerId] of [side] at 15:01:00.
Game times(Game game, int count, EventType type, Side side, String playerId) {
  for (var i = 0; i < count; i++) {
    game = game.record(type, side, playerId, at(1));
  }
  return game;
}

PlayerStatistics statsOf(Game game, Side side, String playerId) =>
    game.statisticsOf(side).singleWhere((s) => s.playerId == playerId);

void main() {
  group('L2 player statistics', () {
    test('L2_1 Max scores 4 of 5 seven-metre throws → 80 %', () {
      var game = times(
          aRunningGame(), 4, EventType.sevenMeterGoal, Side.home, 'p-max');
      game = times(game, 1, EventType.sevenMeterMiss, Side.home, 'p-max');

      final max = statsOf(game, Side.home, 'p-max');

      expect(max.sevenMeterGoals, 4);
      expect(max.sevenMeters, 5);
      expect(max.sevenMeterPercentage, 80);
    });

    test('L2_2 Nora saves 12 of 30 shots → 40 %', () {
      var game = times(aRunningGame(), 12, EventType.save, Side.away, 'p-jan');
      game = times(game, 18, EventType.goal, Side.away, 'p-jan');

      final nora = statsOf(game, Side.home, 'p-nora');

      expect(nora.saves, 12);
      expect(nora.goalsAgainst, 18);
      expect(nora.savePercentage, 40);
    });

    test('L2 shots count goals, misses, saved shots and 7-metre throws', () {
      var game = times(aRunningGame(), 3, EventType.goal, Side.home, 'p-max');
      game = times(game, 1, EventType.miss, Side.home, 'p-max');
      game = times(game, 1, EventType.sevenMeterGoal, Side.home, 'p-max');
      game = times(game, 1, EventType.sevenMeterMiss, Side.home, 'p-max');

      final max = statsOf(game, Side.home, 'p-max');

      expect(max.goals, 4);
      expect(max.shots, 6);
      expect(max.shootingPercentage, 67);
    });

    test('L2 a shot of Jan saved by Nora counts as a shot for Jan', () {
      final game = times(aRunningGame(), 1, EventType.save, Side.away, 'p-jan');

      final jan = statsOf(game, Side.away, 'p-jan');

      expect(jan.shots, 1);
      expect(jan.goals, 0);
      expect(jan.shootingPercentage, 0);
    });

    test('L2 without any shot the percentage is empty, not 0 %', () {
      final game = aRunningGame();

      final tom = statsOf(game, Side.home, 'p-tom');

      expect(tom.shootingPercentage, isNull);
      expect(tom.sevenMeterPercentage, isNull);
      expect(tom.savePercentage, isNull);
    });

    test('L2 technical faults and cards are counted', () {
      var game = times(
          aRunningGame(), 2, EventType.technicalFault, Side.home, 'p-lisa');
      game = times(game, 1, EventType.yellowCard, Side.home, 'p-lisa');
      game = game.record(EventType.twoMinutes, Side.home, 'p-lisa', at(5));

      final lisa = statsOf(game, Side.home, 'p-lisa');

      expect(lisa.technicalFaults, 2);
      expect(lisa.yellowCards, 1);
      expect(lisa.twoMinutes, 1);
      expect(lisa.redCards, 0);
    });

    test('L2 the red card after Max\'s third penalty (R2) is counted', () {
      var game = aRunningGame();
      for (final minute in [5, 15]) {
        game = game
            .record(EventType.twoMinutes, Side.home, 'p-max', at(minute))
            .bringOn(Side.home, 'p-max', at(minute + 2));
      }
      game = game.record(EventType.twoMinutes, Side.home, 'p-max', at(25));

      final max = statsOf(game, Side.home, 'p-max');

      expect(max.twoMinutes, 3);
      expect(max.redCards, 1);
    });

    test('L2 a goal against an empty goal counts for no goalkeeper', () {
      final game = aRunningGame()
          .substitute(Side.home, 'p-nora', 'p-tom', at(55))
          .record(EventType.goal, Side.away, 'p-jan', at(56));

      final nora = statsOf(game, Side.home, 'p-nora');

      expect(nora.goalsAgainst, 0);
    });

    test('E2_1 deleting a goal of Max removes it from his statistics too', () {
      final game = times(aRunningGame(), 2, EventType.goal, Side.home, 'p-max');

      final result = game.deleteEvent(2);

      expect(statsOf(result, Side.home, 'p-max').goals, 1);
    });

    test('L2 every player of the game squad has a line, also Tom on the bench',
        () {
      final game = aRunningGame();

      final lines = game.statisticsOf(Side.home);

      expect(lines, hasLength(9));
    });
  });

  test('L2 percentages are rounded to whole numbers', () {
    expect(percentage(2, 3), 67);
    expect(percentage(1, 3), 33);
    expect(percentage(4, 5), 80);
    expect(percentage(0, 0), isNull);
  });
}
