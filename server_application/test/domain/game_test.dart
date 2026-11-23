import 'package:server_application/domain/game_event.dart';
import 'package:server_application/domain/score.dart';
import 'package:test/test.dart';

import 'builders.dart';

void main() {
  group('E1 record events', () {
    test('E1_1 a goal by Max at 11:10 makes it 12:10', () {
      final game =
          withGoals(withGoals(aRunningGame(), Side.home, 11), Side.away, 10);

      final result = game.record(EventType.goal, Side.home, 'p-max', at(23));

      expect(result.score, const Score(12, 10));
      expect(result.score.toString(), '12:10');
    });

    test('E1_1 a 7-metre goal counts, a 7-metre miss does not', () {
      final game = aRunningGame();

      final result = game
          .record(EventType.sevenMeterGoal, Side.home, 'p-max', at(5))
          .record(EventType.sevenMeterMiss, Side.home, 'p-max', at(6));

      expect(result.score, const Score(1, 0));
    });

    test('E1 the server stamps the event with the game time 23:14', () {
      final game = aRunningGame();

      final result =
          game.record(EventType.goal, Side.home, 'p-max', at(23, 14));

      expect(result.events.single.gameTime, time(23, 14));
      expect(result.events.single.number, 1);
    });

    test('E1_3 a save is stored on the shooter Jan of Hilden', () {
      final game = aRunningGame();

      final result = game.record(EventType.save, Side.away, 'p-jan', at(10));

      expect(result.events.single.playerId, 'p-jan');
      expect(result.score, const Score(0, 0));
    });

    test('E1 rejects a player who is not in the game squad of that side', () {
      final game = aRunningGame();

      expect(() => game.record(EventType.goal, Side.home, 'p-jan', at(1)),
          throwsRuleViolation('Der Spieler gehört nicht zu TV Mettmann.'));
    });

    test('E1 rejects a goal without a player', () {
      final game = aRunningGame();

      expect(() => game.record(EventType.goal, Side.home, null, at(1)),
          throwsRuleViolation('Bitte einen Spieler wählen.'));
    });

    test('E1 rejects a timeout for a single player', () {
      final game = aRunningGame();

      expect(
          () => game.record(EventType.timeout, Side.home, 'p-max', at(1)),
          throwsRuleViolation(
              'Eine Auszeit gehört zum Team, nicht zu einem Spieler.'));
    });
  });

  group('E2 delete events', () {
    test('E2_1 deleting Max\'s goal at 12:11 makes it 11:11', () {
      final game =
          withGoals(withGoals(aRunningGame(), Side.home, 12), Side.away, 11);
      final maxLastGoal =
          game.events.lastWhere((e) => e.side == Side.home).number;

      final result = game.deleteEvent(maxLastGoal);

      expect(result.score, const Score(11, 11));
    });

    test('E2 a deleted number is never given out again', () {
      final game = withGoals(aRunningGame(), Side.home, 2).deleteEvent(2);

      final result = game.record(EventType.miss, Side.home, 'p-max', at(3));

      expect(result.events.map((e) => e.number), [1, 3]);
    });

    test('E2 rejects deleting an event that does not exist', () {
      final game = aRunningGame();

      expect(() => game.deleteEvent(99),
          throwsRuleViolation('Ereignis nicht gefunden.'));
    });
  });

  group('R4 events only during the game', () {
    test('R4_1 rejects an event before kick-off', () {
      final game = aGame();

      expect(() => game.record(EventType.goal, Side.home, 'p-max', at(0)),
          throwsRuleViolation('Das Spiel hat noch nicht begonnen.'));
    });

    test('R4_2 rejects recording and deleting after the end', () {
      final finished = withGoals(aRunningGame(), Side.home, 1)
          .halfTime()
          .startClock(at(45))
          .end(at(75));

      expect(() => finished.record(EventType.goal, Side.home, 'p-max', at(76)),
          throwsRuleViolation('Das Spiel ist beendet.'));
      expect(() => finished.deleteEvent(1),
          throwsRuleViolation('Das Spiel ist beendet.'));
    });
  });

  group('U2, U3, U5 events and the clock', () {
    test('U2_1 adjusting the clock keeps the time of earlier events', () {
      final game = aRunningGame()
          .record(EventType.goal, Side.home, 'p-max', at(23, 14))
          .stopClock(at(23, 20));

      final result = game.adjustClock(time(23, 5), at(24));

      expect(result.events.single.gameTime, time(23, 14));
    });

    test('U3_1 a timeout of Mettmann at 23:14 stops the clock', () {
      final game = aRunningGame();

      final result =
          game.record(EventType.timeout, Side.home, null, at(23, 14));

      expect(result.clock.isRunningAt(at(25)), isFalse);
      expect(result.clock.gameTime(at(25)), time(23, 14));
    });

    test('U5_1 the half-time score only counts the first half', () {
      final firstHalf =
          withGoals(withGoals(aRunningGame(), Side.home, 14), Side.away, 12);
      final secondHalf = firstHalf.halfTime().startClock(at(45));

      final result = withGoals(secondHalf, Side.home, 3);

      expect(result.halfTimeScore, const Score(14, 12));
      expect(result.score, const Score(17, 12));
    });
  });
}
