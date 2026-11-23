import 'package:server_application/domain/game.dart';
import 'package:server_application/domain/game_event.dart';
import 'package:test/test.dart';

import 'builders.dart';

/// Mettmann's timeout at [minutes] after the clock was (re)started at 15:00.
Game timeout(Game game, int minutes) =>
    game.record(EventType.timeout, Side.home, null, at(minutes));

/// A running game in the second half; the clock restarted at 15:00:00 at 30:00.
Game aGameInTheSecondHalf() => aRunningGame().halfTime().startClock(at(0));

/// Two minutes for a Mettmann player on the field at [minutes].
Game penalty(Game game, String playerId, int minutes) =>
    game.record(EventType.twoMinutes, Side.home, playerId, at(minutes));

/// Two minutes at [minutes]; when they have run out the player comes back.
Game penaltyAndBack(Game game, String playerId, int minutes) =>
    penalty(game, playerId, minutes)
        .bringOn(Side.home, playerId, at(minutes + 2));

/// Max with two penalties served and back on the field at 17:00.
Game maxWithTwoPenalties() =>
    penaltyAndBack(penaltyAndBack(aRunningGame(), 'p-max', 5), 'p-max', 15);

void main() {
  group('R1 timeouts', () {
    test('R1_1 a team gets at most three timeouts per game', () {
      final firstHalf =
          timeout(timeout(aRunningGame(), 10).startClock(at(11)), 20);
      final secondHalf = firstHalf.halfTime().startClock(at(31));
      final game = timeout(secondHalf, 35).startClock(at(36));

      expect(() => timeout(game, 40),
          throwsRuleViolation('TV Mettmann hat keine Auszeit mehr.'));
    });

    test('R1_2 rejects a third timeout in the first half', () {
      final game = timeout(timeout(aRunningGame(), 10).startClock(at(11)), 20)
          .startClock(at(21));

      expect(() => timeout(game, 25),
          throwsRuleViolation('Nur 2 Auszeiten pro Halbzeit.'));
    });

    test('R1_2 Hilden still has its timeouts when Mettmann has none left', () {
      final game = timeout(timeout(aRunningGame(), 10).startClock(at(11)), 20)
          .startClock(at(21));

      final result = game.record(EventType.timeout, Side.away, null, at(25));

      expect(result.events.last.side, Side.away);
    });

    test('R1_3 rejects a second timeout in the last 5 minutes (56:00, 58:00)',
        () {
      final game = timeout(aGameInTheSecondHalf(), 26).startClock(at(27));

      expect(() => timeout(game, 28),
          throwsRuleViolation('In den letzten 5 Minuten nur eine Auszeit.'));
    });

    test('R1_3 a timeout at 40:00 does not count for the last 5 minutes', () {
      final game = timeout(aGameInTheSecondHalf(), 10).startClock(at(11));

      final result = timeout(game, 26);

      expect(result.events.where((e) => e.type == EventType.timeout),
          hasLength(2));
    });
  });

  group('R2 third two-minute penalty', () {
    test('R2 Max is disqualified after his third two-minute penalty', () {
      final game = maxWithTwoPenalties();

      final result = penalty(game, 'p-max', 25);

      expect(game.isDisqualified(Side.home, 'p-max'), isFalse);
      expect(result.isDisqualified(Side.home, 'p-max'), isTrue);
    });

    test('R2 a red card disqualifies Lisa at once', () {
      final game = aRunningGame();

      final result =
          game.record(EventType.redCard, Side.home, 'p-lisa', at(12));

      expect(result.isDisqualified(Side.home, 'p-lisa'), isTrue);
    });

    test('E2_2 deleting Max\'s third penalty removes the automatic red card',
        () {
      final game = penalty(maxWithTwoPenalties(), 'p-max', 25);
      final third = game.events.last.number;

      final result = game.deleteEvent(third);

      expect(result.isDisqualified(Side.home, 'p-max'), isFalse);
    });
  });

  group('R3 a disqualified player gets no more events', () {
    test('R3 rejects a goal by Lisa after her red card', () {
      final game =
          aRunningGame().record(EventType.redCard, Side.home, 'p-lisa', at(12));

      expect(() => game.record(EventType.goal, Side.home, 'p-lisa', at(13)),
          throwsRuleViolation('Lisa ist disqualifiziert.'));
    });

    test('R3 rejects a yellow card for Lisa on the bench after her red card',
        () {
      final game =
          aRunningGame().record(EventType.redCard, Side.home, 'p-lisa', at(12));

      expect(
          () => game.record(EventType.yellowCard, Side.home, 'p-lisa', at(13)),
          throwsRuleViolation('Lisa ist disqualifiziert.'));
    });

    test('R3 rejects bringing Max back in after his third penalty', () {
      final game = penalty(maxWithTwoPenalties(), 'p-max', 25);

      expect(() => game.bringOn(Side.home, 'p-max', at(27)),
          throwsRuleViolation('Max ist disqualifiziert.'));
    });
  });
}
