import 'package:test/test.dart';

import '../domain/builders.dart';
import 'ticker_harness.dart';

void main() {
  late TickerHarness harness;

  setUp(() => harness = TickerHarness());
  tearDown(() => harness.delete());

  group('L1 live view asks with the version (ADR-002)', () {
    test('L1 without a version the whole game comes, at version 1', () async {
      final (status, json) = await harness.view('');

      expect(status, 200);
      expect(json['version'], 1);
      expect(json['homeTeamId'], 't1');
    });

    test('L1 nothing changed since version 1, the short answer is 204',
        () async {
      final (status, json) = await harness.view('?version=1');

      expect(status, 204);
      expect(json, isNull);
    });

    test('L1 after the goal of Max the version is new and the game comes',
        () async {
      await harness.kickOff();
      final (_, before) = await harness.view('');
      harness.now = at(5);
      await harness.send('POST', '/games/g1/events',
          body: {'type': 'goal', 'side': 'home', 'playerId': 'p-max'});

      final (status, json) =
          await harness.view('?version=${before['version']}');

      expect(status, 200);
      expect(json['version'], before['version'] + 1);
      expect(json['score'], {'home': 1, 'away': 0});
    });

    test('L1 the running clock does not change the version (ADR-003)',
        () async {
      await harness.kickOff();
      final (_, atKickOff) = await harness.view('');

      harness.now = at(10);
      final (status, _) =
          await harness.view('?version=${atKickOff['version']}');

      expect(status, 204);
    });

    test('L1 the version stays after a server restart', () async {
      await harness.kickOff();
      final (_, before) = await harness.view('');

      harness.restartServer();
      final (_, after) = await harness.view('');

      expect(after['version'], before['version']);
    });

    test('a version that is no number gives the whole game', () async {
      final (status, _) = await harness.view('?version=abc');

      expect(status, 200);
    });
  });

  group('ticker link is checked when it is opened', () {
    test('the right ticker code gives 204', () async {
      final (status, _) = await harness.send('GET', '/games/g1/ticker-access');

      expect(status, 204);
    });

    test('a wrong ticker code gives 403', () async {
      final (status, json) =
          await harness.send('GET', '/games/g1/ticker-access', code: 'wrong');

      expect(status, 403);
      expect(json['message'], 'Dieser Link ist ungültig.');
    });

    test('an unknown game gives 404', () async {
      final (status, _) = await harness.send('GET', '/games/xx/ticker-access');

      expect(status, 404);
    });
  });
}
