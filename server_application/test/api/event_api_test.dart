import 'package:test/test.dart';

import '../domain/builders.dart';
import 'ticker_harness.dart';

void main() {
  late TickerHarness harness;

  setUp(() => harness = TickerHarness());
  tearDown(() => harness.delete());

  /// Records an event at [minute] for [side] by [playerId].
  Future<(int, dynamic)> record(int minute, String type,
      {String side = 'home', String? playerId, String? leaving}) {
    harness.now = at(minute);
    return harness.send('POST', '/games/g1/events', body: {
      'type': type,
      'side': side,
      if (playerId != null) 'playerId': playerId,
      if (leaving != null) 'leavingPlayerId': leaving,
    });
  }

  group('E1 record events', () {
    test('E1 a goal of Max at 5:00 makes 1:0, the server stamps 5:00',
        () async {
      await harness.kickOff();

      final (status, json) = await record(5, 'goal', playerId: 'p-max');

      expect(status, 201);
      expect(json['score'], {'home': 1, 'away': 0});
      final event = json['events'].single;
      expect(event['gameTimeSeconds'], 300);
      expect(event['playerId'], 'p-max');
    });

    test('E1_2 the goal of Max stores Kai, the goalkeeper of Hilden', () async {
      await harness.kickOff();

      final (_, json) = await record(5, 'goal', playerId: 'p-max');

      expect(json['events'].single['goalkeeperId'], 'p-kai');
    });

    test('E1_3 a save is recorded on Jan and counts for Nora', () async {
      await harness.kickOff();

      final (_, json) =
          await record(6, 'save', side: 'away', playerId: 'p-jan');

      expect(json['events'].single['goalkeeperId'], 'p-nora');
      expect(json['score'], {'home': 0, 'away': 0});
    });

    test('U3_1 a timeout of Mettmann stops the clock', () async {
      await harness.kickOff();

      final (_, json) = await record(10, 'timeout');

      expect(json['clock']['running'], isFalse);
      expect(json['clock']['gameTimeSeconds'], 600);
    });

    test('R4_1 before kick-off nothing can be recorded', () async {
      final (status, json) = await record(0, 'goal', playerId: 'p-max');

      expect(status, 409);
      expect(json['message'], 'Das Spiel hat noch nicht begonnen.');
    });

    test('R1_2 a third timeout in the first half answers 409', () async {
      await harness.kickOff();
      await record(5, 'timeout');
      await harness.send('POST', '/games/g1/clock/start');
      await record(10, 'timeout');
      await harness.send('POST', '/games/g1/clock/start');

      final (status, json) = await record(15, 'timeout');

      expect(status, 409);
      expect(json['message'], 'Nur 2 Auszeiten pro Halbzeit.');
    });

    test('R7 a goal of Tom, who sits on the bench, answers 409', () async {
      await harness.kickOff();

      final (status, json) = await record(5, 'goal', playerId: 'p-tom');

      expect(status, 409);
      expect(json['message'], 'Dieser Spieler steht nicht auf dem Feld.');
    });

    test('E1 an unknown event type answers 400', () async {
      await harness.kickOff();

      final (status, _) = await record(5, 'flyingGoal', playerId: 'p-max');

      expect(status, 400);
    });

    test('E1 without the ticker code nothing is recorded (403)', () async {
      await harness.kickOff();

      final (status, _) = await harness.send('POST', '/games/g1/events',
          body: {'type': 'goal', 'side': 'home', 'playerId': 'p-max'},
          code: null);

      expect(status, 403);
    });
  });

  group('E2 delete events', () {
    test('E2 deleting the goal of Max brings back 0:0', () async {
      await harness.kickOff();
      await record(5, 'goal', playerId: 'p-max');

      final (status, json) = await harness.send('DELETE', '/games/g1/events/1');

      expect(status, 200);
      expect(json['score'], {'home': 0, 'away': 0});
      expect(json['events'], isEmpty);
    });

    test('E2 deleting an unknown event answers 409', () async {
      await harness.kickOff();

      final (status, json) =
          await harness.send('DELETE', '/games/g1/events/99');

      expect(status, 409);
      expect(json['message'], 'Ereignis nicht gefunden.');
    });
  });

  group('E5 substitutions', () {
    test('E5_2 Max out, Tom in', () async {
      await harness.kickOff();
      harness.now = at(12);

      final (status, json) = await harness.send(
          'POST', '/games/g1/substitutions',
          body: {'side': 'home', 'outId': 'p-max', 'inId': 'p-tom'});

      expect(status, 201);
      expect(json['homeLineup']['fieldPlayerIds'], contains('p-tom'));
      expect(json['homeLineup']['fieldPlayerIds'], isNot(contains('p-max')));
    });

    test('E5_3 the substitution is not in the list of events', () async {
      await harness.kickOff();
      harness.now = at(12);

      final (_, json) = await harness.send('POST', '/games/g1/substitutions',
          body: {'side': 'home', 'outId': 'p-max', 'inId': 'p-tom'});

      expect(json['events'], isEmpty);
    });

    test('E5_7 Tom for Nora leaves the goal empty, then Max goes into goal',
        () async {
      await harness.kickOff();
      harness.now = at(20);
      await harness.send('POST', '/games/g1/substitutions',
          body: {'side': 'home', 'outId': 'p-nora', 'inId': 'p-tom'});

      final (status, json) = await harness.send('POST', '/games/g1/into-goal',
          body: {'side': 'home', 'playerId': 'p-max'});

      expect(status, 201);
      expect(json['homeLineup']['goalkeeperId'], 'p-max');
    });
  });

  group('L3 penalties', () {
    test('L3_1 Max gets two minutes at 23:00, at 24:37 there are 0:23 left',
        () async {
      await harness.kickOff();
      await record(23, 'twoMinutes', playerId: 'p-max');
      harness.now = at(24, 37);

      final (_, json) = await harness.send('POST', '/games/g1/come-on',
          body: {'side': 'home', 'playerId': 'p-tom'});

      expect(json['message'], 'TV Mettmann Männer ist noch in Unterzahl.');
    });

    test('L3 the running penalty shows its remaining time', () async {
      await harness.kickOff();

      final (_, json) = await record(23, 'twoMinutes', playerId: 'p-max');

      expect(json['runningPenalties'].single,
          {'side': 'home', 'playerId': 'p-max', 'remainingSeconds': 120});
      expect(json['homeLineup']['fieldPlayerIds'], hasLength(5));
    });

    test('E5_4 after the penalty Max comes back on at 25:00', () async {
      await harness.kickOff();
      await record(23, 'twoMinutes', playerId: 'p-max');
      harness.now = at(25);

      final (status, json) = await harness.send('POST', '/games/g1/come-on',
          body: {'side': 'home', 'playerId': 'p-max'});

      expect(status, 201);
      expect(json['homeLineup']['fieldPlayerIds'], contains('p-max'));
      expect(json['runningPenalties'], isEmpty);
    });
  });
}
