import 'package:server_application/domain/game_clock.dart';
import 'package:test/test.dart';

import 'builders.dart';

void main() {
  group('U1 start, stop, half-time, end', () {
    test('U1 a new clock stands at 00:00 before kick-off', () {
      final clock = GameClock.initial();

      final shown = clock.gameTime(at(5));

      expect(shown, Duration.zero);
      expect(clock.phase, ClockPhase.notStarted);
    });

    test('U1 after kick-off at 15:00:00 the clock shows 23:14 at 15:23:14', () {
      final clock = GameClock.initial().start(at(0));

      final shown = clock.gameTime(at(23, 14));

      expect(shown, time(23, 14));
      expect(clock.phase, ClockPhase.firstHalf);
    });

    test('U1_1 stopping at 23:14 keeps 23:14 while the clock stands', () {
      final clock = aRunningClock();

      final stopped = clock.stop(at(23, 14));

      expect(stopped.gameTime(at(25)), time(23, 14));
      expect(stopped.isRunningAt(at(25)), isFalse);
    });

    test('U1_1 after a 7-metre break the clock goes on from 23:14', () {
      final stopped = aRunningClock().stop(at(23, 14));

      final restarted = stopped.start(at(24));

      expect(restarted.gameTime(at(24, 10)), time(23, 24));
    });

    test('U1_1 rejects stopping a clock that stands', () {
      final stopped = aRunningClock().stop(at(10));

      expect(() => stopped.stop(at(11)),
          throwsRuleViolation('Die Uhr steht schon.'));
    });

    test('U1_1 rejects starting a clock that runs', () {
      final clock = aRunningClock();

      expect(() => clock.start(at(1)),
          throwsRuleViolation('Die Uhr läuft schon.'));
    });

    test('U1 rejects starting the clock after the game has ended', () {
      final finished = aClockInTheSecondHalf().end(at(30));

      expect(() => finished.start(at(31)),
          throwsRuleViolation('Das Spiel ist beendet.'));
    });

    test('U1 rejects "Spielende" in the first half', () {
      final clock = aRunningClock();

      expect(() => clock.end(at(10)),
          throwsRuleViolation('„Spielende“ geht nur in der zweiten Halbzeit.'));
    });
  });

  group('U2 adjust the time', () {
    test('U2 the stopped clock goes back from 23:14 to 23:05', () {
      final stopped = aRunningClock().stop(at(23, 14));

      final adjusted = stopped.adjust(time(23, 5), at(24));

      expect(adjusted.gameTime(at(25)), time(23, 5));
    });

    test('U2 rejects adjusting while the clock runs', () {
      final clock = aRunningClock();

      expect(() => clock.adjust(time(23, 5), at(23, 14)),
          throwsRuleViolation('Bitte erst die Uhr anhalten.'));
    });

    test('U2 rejects 31:00 in the first half and 29:00 in the second half', () {
      final first = aRunningClock().stop(at(20));
      final second = aClockInTheSecondHalf().stop(at(10));

      expect(() => first.adjust(time(31), at(21)),
          throwsRuleViolation('Diese Zeit liegt nicht in der Halbzeit.'));
      expect(() => second.adjust(time(29), at(11)),
          throwsRuleViolation('Diese Zeit liegt nicht in der Halbzeit.'));
    });

    test('U2 rejects adjusting before kick-off', () {
      final clock = GameClock.initial();

      expect(
          () => clock.adjust(time(1), at(0)),
          throwsRuleViolation(
              'Die Zeit lässt sich nur während einer Halbzeit korrigieren.'));
    });
  });

  group('U3 the clock stops by itself', () {
    test('U3_2 the clock stops at 30:00 at the end of the first half', () {
      final clock = aRunningClock();

      final shown = clock.gameTime(at(31));

      expect(shown, time(30));
      expect(clock.isRunningAt(at(31)), isFalse);
    });

    test('U3_2 the clock stops at 60:00 at the end of the second half', () {
      final clock = aClockInTheSecondHalf();

      final shown = clock.gameTime(at(35));

      expect(shown, time(60));
      expect(clock.isRunningAt(at(35)), isFalse);
    });

    test('U3_2 a B-Jugend game with 25 minutes stops at 25:00', () {
      final clock = GameClock.initial(halfLength: time(25)).start(at(0));

      final shown = clock.gameTime(at(27));

      expect(shown, time(25));
    });

    test('U3_2 rejects starting again at 30:00 before "Halbzeit"', () {
      final clock = aRunningClock();

      expect(
          () => clock.start(at(31)),
          throwsRuleViolation(
              'Die Halbzeit ist vorbei, bitte „Halbzeit“ drücken.'));
    });
  });

  group('U5 half-time and end', () {
    test('U5_1 the second half starts at 30:00', () {
      final halfTime = aRunningClock().halfTime(at(30));

      final secondHalf = halfTime.start(at(45));

      expect(secondHalf.phase, ClockPhase.secondHalf);
      expect(secondHalf.gameTime(at(46)), time(31));
    });

    test('U5_1 "Halbzeit" at 29:50 sets the clock to 30:00', () {
      final clock = aRunningClock();

      final halfTime = clock.halfTime(at(29, 50));

      expect(halfTime.gameTime(at(35)), time(30));
      expect(halfTime.phase, ClockPhase.halfTime);
    });

    test('U5_1 rejects "Halbzeit" in the second half', () {
      final clock = aClockInTheSecondHalf();

      expect(() => clock.halfTime(at(10)),
          throwsRuleViolation('„Halbzeit“ geht nur in der ersten Halbzeit.'));
    });

    test('U5_2 "Spielende" at 60:00 finishes the game and keeps 60:00', () {
      final clock = aClockInTheSecondHalf();

      final finished = clock.end(at(31));

      expect(finished.phase, ClockPhase.finished);
      expect(finished.gameTime(at(40)), time(60));
    });
  });
}
