// Acceptance tests for the lineup and the clock (E5.1, U1–U5) and for
// adding players during the game (S1.4), see docs/user-stories.md.
//
// The real server uses the real time, so these tests wait a few seconds.
// A clock value may be one second off, because a request takes a moment.
import 'package:test/test.dart';

import 'running_server.dart';

void main() {
  final server = useRunningServer();

  /// A game of TV Mettmann against HSG Hilden, 7 players each, not set up.
  /// Mettmann: Nora (1) in goal, Max (7), Lisa (12), Tom (9), Ben (4),
  /// Paul (5), Finn (6). Hilden: Jan (1) in goal and Nr2 to Nr7.
  Future<(String gameId, String tickerCode)> aGame() async {
    final (_, json) = await server().post('/teams', body: newTeam());
    final id = json['team']['id'] as String;
    final code = json['code'] as String;
    for (final player in [
      aPlayer(
          number: 1,
          firstName: 'Nora',
          lastName: 'Neumann',
          position: 'goalkeeper'),
      aPlayer(),
      aPlayer(number: 12, firstName: 'Lisa'),
      aPlayer(number: 9, firstName: 'Tom', lastName: 'Neumann'),
      aPlayer(number: 4, firstName: 'Ben'),
      aPlayer(number: 5, firstName: 'Paul'),
      aPlayer(number: 6, firstName: 'Finn'),
    ]) {
      await server().post('/teams/$id/players', body: player, code: code);
    }
    final (_, created) = await server().post('/teams/$id/games',
        body: newGame(players: [
          aPlayer(
              number: 1,
              firstName: 'Jan',
              lastName: 'Becker',
              position: 'goalkeeper'),
          for (var number = 2; number <= 7; number++)
            aPlayer(number: number, firstName: 'Nr$number'),
        ]),
        code: code);
    return (created['game']['id'] as String, created['tickerCode'] as String);
  }

  /// Puts No. 1 in goal and the next six numbers in the field, e.g. Nora
  /// in goal and Ben, Paul, Finn, Max, Tom and Lisa in the field.
  Future<Answer> lineUp(String gameId, String tickerCode, String side) async {
    final (_, game) = await server().get('/games/$gameId');
    final players = [...game[side]['players'] as List]
      ..sort((a, b) => (a['number'] as int).compareTo(b['number'] as int));
    return server().put('/games/$gameId/lineups/$side',
        body: {
          'goalkeeperId': players.first['id'],
          'fieldPlayerIds': [for (final p in players.skip(1).take(6)) p['id']],
        },
        tickerCode: tickerCode);
  }

  /// Presses a button of the clock, e.g. "start" or "half-time" (U1).
  Future<Answer> clock(String gameId, String tickerCode, String button) =>
      server().post('/games/$gameId/clock/$button', tickerCode: tickerCode);

  Future<Answer> setTime(String gameId, String tickerCode, int seconds) =>
      server().put('/games/$gameId/clock',
          body: {'gameTimeSeconds': seconds}, tickerCode: tickerCode);

  /// A game with both lineups set, kicked off.
  Future<(String gameId, String tickerCode)> aRunningGame() async {
    final (gameId, tickerCode) = await aGame();
    await lineUp(gameId, tickerCode, 'home');
    await lineUp(gameId, tickerCode, 'away');
    final (status, _) = await clock(gameId, tickerCode, 'start');
    expect(status, 200, reason: 'kick-off');
    return (gameId, tickerCode);
  }

  Future<Map<String, dynamic>> clockOf(String gameId) async {
    final (_, game) = await server().get('/games/$gameId');
    return game['clock'] as Map<String, dynamic>;
  }

  Future<void> wait(int seconds) => Future.delayed(Duration(seconds: seconds));

  group('E5.1 seven players per team before kick-off', () {
    test('E5_1 Nora in goal, Max, Lisa and four more in the field', () async {
      final (gameId, tickerCode) = await aGame();

      final (status, game) = await lineUp(gameId, tickerCode, 'home');

      expect(status, 200);
      expect(game['homeLineup'], isNotNull);
    });

    test('E5_1 a lineup with only 6 players is rejected', () async {
      final (gameId, tickerCode) = await aGame();
      final (_, game) = await server().get('/games/$gameId');
      final ids = [for (final p in game['home']['players']) p['id']];

      final (status, json) = await server().put('/games/$gameId/lineups/home',
          body: {'goalkeeperId': ids[0], 'fieldPlayerIds': ids.sublist(1, 6)},
          tickerCode: tickerCode);

      expect(status, 409);
      expect(json['message'],
          'Bitte 7 verschiedene Spieler aufstellen: 1 im Tor, 6 im Feld.');
    });

    test('E5_1 no kick-off before both teams are set up', () async {
      final (gameId, tickerCode) = await aGame();
      await lineUp(gameId, tickerCode, 'home');

      final (status, json) = await clock(gameId, tickerCode, 'start');

      expect(status, 409);
      expect(json['message'], 'Bitte zuerst beide Teams aufstellen.');
    });
  });

  group('U1 the clock works like a clock in a sports hall', () {
    test('U1 after kick-off the clock runs on the server', () async {
      final (gameId, _) = await aRunningGame();

      await wait(2);
      final clockNow = await clockOf(gameId);

      expect(clockNow['phase'], 'firstHalf');
      expect(clockNow['running'], isTrue);
      expect(clockNow['gameTimeSeconds'], inInclusiveRange(2, 3));
    });

    test('U1_1 stopped for a 7-meter, the time stands, then runs on', () async {
      final (gameId, tickerCode) = await aRunningGame();
      await wait(1);
      final (_, stopped) = await clock(gameId, tickerCode, 'stop');
      final stoppedAt = stopped['clock']['gameTimeSeconds'] as int;

      await wait(2);
      final whileStopped = await clockOf(gameId);
      await clock(gameId, tickerCode, 'start');
      await wait(2);
      final afterRestart = await clockOf(gameId);

      expect(whileStopped['gameTimeSeconds'], stoppedAt);
      expect(afterRestart['gameTimeSeconds'],
          inInclusiveRange(stoppedAt + 2, stoppedAt + 3));
    });

    test('U1 without the ticker code nobody starts the clock', () async {
      final (gameId, tickerCode) = await aGame();
      await lineUp(gameId, tickerCode, 'home');
      await lineUp(gameId, tickerCode, 'away');

      final (status, _) = await server().post('/games/$gameId/clock/start');

      expect(status, 403);
    });
  });

  group('U2 correct the time while the clock stands', () {
    test('U2 23:14 is corrected to 23:05', () async {
      final (gameId, tickerCode) = await aRunningGame();
      await clock(gameId, tickerCode, 'stop');
      await setTime(gameId, tickerCode, 23 * 60 + 14);

      final (status, game) = await setTime(gameId, tickerCode, 23 * 60 + 5);

      expect(status, 200);
      expect(game['clock']['gameTimeSeconds'], 23 * 60 + 5);
    });

    test('U2 while the clock runs the time is not corrected', () async {
      final (gameId, tickerCode) = await aRunningGame();

      final (status, json) = await setTime(gameId, tickerCode, 60);

      expect(status, 409);
      expect(json['message'], 'Bitte erst die Uhr anhalten.');
    });
  });

  group('U3.2 the clock stops by itself at the end of the half', () {
    test('U3_2 started at 29:58, the clock stands at 30:00', () async {
      final (gameId, tickerCode) = await aRunningGame();
      await clock(gameId, tickerCode, 'stop');
      await setTime(gameId, tickerCode, 29 * 60 + 58);
      await clock(gameId, tickerCode, 'start');

      await wait(3);
      final clockNow = await clockOf(gameId);

      expect(clockNow['gameTimeSeconds'], 30 * 60);
      expect(clockNow['running'], isFalse);
    });
  });

  group('U4 all clients show the same time', () {
    test('U4 Lisa and the ticker see the same time', () async {
      final (gameId, tickerCode) = await aRunningGame();
      await wait(1);
      await clock(gameId, tickerCode, 'stop');

      final lisa = await clockOf(gameId);
      final ticker = await clockOf(gameId);

      expect(lisa['gameTimeSeconds'], ticker['gameTimeSeconds']);
    });

    test('U4_1 after a server restart the clock goes on', () async {
      final (gameId, _) = await aRunningGame();
      await wait(1);

      await server().stop();
      final restarted = await RunningServer.start(dataDir: server().dataDir);
      await wait(1);
      final (_, game) = await restarted.get('/games/$gameId');
      await restarted.stop();

      expect(game['clock']['running'], isTrue);
      expect(game['clock']['gameTimeSeconds'], greaterThanOrEqualTo(2));
    });
  });

  group('U5 half-time and end of the game', () {
    test('U5_1 "Halbzeit" at 29:50: the second half starts at 30:00', () async {
      final (gameId, tickerCode) = await aRunningGame();
      await clock(gameId, tickerCode, 'stop');
      await setTime(gameId, tickerCode, 29 * 60 + 50);

      final (_, halfTime) = await clock(gameId, tickerCode, 'half-time');
      final (_, secondHalf) = await clock(gameId, tickerCode, 'start');

      expect(halfTime['clock']['phase'], 'halfTime');
      expect(secondHalf['clock']['phase'], 'secondHalf');
      expect(secondHalf['clock']['gameTimeSeconds'], 30 * 60);
    });

    test(
        'U5_2 after "Spielende" Lisa still sees the finished game, '
        'also after a restart', () async {
      final (gameId, tickerCode) = await aRunningGame();
      await clock(gameId, tickerCode, 'half-time');
      await clock(gameId, tickerCode, 'start');
      await clock(gameId, tickerCode, 'stop');
      await setTime(gameId, tickerCode, 59 * 60 + 59);
      await clock(gameId, tickerCode, 'start');
      await wait(2);

      final (status, _) = await clock(gameId, tickerCode, 'end');
      await server().stop();
      final restarted = await RunningServer.start(dataDir: server().dataDir);
      final (viewerStatus, game) = await restarted.get('/games/$gameId');
      await restarted.stop();

      expect(status, 200);
      expect(viewerStatus, 200);
      expect(game['status'], 'finished');
      expect(game['clock']['gameTimeSeconds'], 60 * 60);
    });
  });

  group('S1.4 adding players during the game', () {
    test('S1_4 Ole Becker of Hilden comes late and is added after kick-off',
        () async {
      final (gameId, tickerCode) = await aRunningGame();

      final (status, game) = await server().post(
          '/games/$gameId/match-report/away',
          body: aPlayer(number: 8, firstName: 'Ole', lastName: 'Becker'),
          tickerCode: tickerCode);

      expect(status, 201);
      expect(
          [for (final p in game['away']['players']) p['number']], contains(8));
    });

    test('S1_4 after kick-off Ole on the bench stays in the report', () async {
      final (gameId, tickerCode) = await aGame();
      final (_, withOle) = await server().post(
          '/games/$gameId/match-report/away',
          body: aPlayer(number: 8, firstName: 'Ole', lastName: 'Becker'),
          tickerCode: tickerCode);
      final oleId = (withOle['away']['players'] as List)
          .singleWhere((p) => p['firstName'] == 'Ole')['id'];
      await lineUp(gameId, tickerCode, 'home');
      await lineUp(gameId, tickerCode, 'away');
      await clock(gameId, tickerCode, 'start');

      final (status, json) = await server().delete(
          '/games/$gameId/match-report/away/$oleId',
          tickerCode: tickerCode);

      expect(status, 409);
      expect(json['message'],
          'Nach dem Anpfiff bleibt der Spieler im Spielbericht.');
    });
  });
}
