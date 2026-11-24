// Acceptance tests for events, substitutions and the handball rules
// (E1–E5, R1–R7, U2.1, U3.1, U5, L1–L3), see docs/user-stories.md.
//
// Most tests stop the clock right after kick-off and set the game time by
// hand (U2), so they need no waiting: events then get the set time.
import 'package:test/test.dart';

import 'running_server.dart';

void main() {
  final server = useRunningServer();

  /// TV Mettmann against HSG Hilden, kicked off and stopped at 0:00.
  ///
  /// Mettmann: Nora (1) in goal; Max (7), Lisa (12), Ben (4), Paul (5),
  /// Finn (6) and Leon (3) in the field; Tom (9) on the bench.
  /// Hilden: Jan (1) in goal, Nr2 to Nr7 in the field, Nr8 on the bench.
  Future<Match> aStoppedGame({bool kickOff = true}) async {
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
      aPlayer(number: 4, firstName: 'Ben'),
      aPlayer(number: 5, firstName: 'Paul'),
      aPlayer(number: 6, firstName: 'Finn'),
      aPlayer(number: 3, firstName: 'Leon'),
      aPlayer(number: 9, firstName: 'Tom', lastName: 'Neumann'),
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
          for (var number = 2; number <= 8; number++)
            aPlayer(number: number, firstName: 'Nr$number'),
        ]),
        code: code);
    final match = Match(server(), created['game']['id'] as String,
        created['tickerCode'] as String);
    await match
        .lineUp('home', 'Nora', ['Max', 'Lisa', 'Ben', 'Paul', 'Finn', 'Leon']);
    await match
        .lineUp('away', 'Jan', ['Nr2', 'Nr3', 'Nr4', 'Nr5', 'Nr6', 'Nr7']);
    if (kickOff) {
      expect((await match.clock('start')).$1, 200, reason: 'kick-off');
      expect((await match.clock('stop')).$1, 200, reason: 'stop');
    }
    return match;
  }

  group('E1 events with the current game time', () {
    test('E1_1 a goal of Max at 11:10 makes it 12:10', () async {
      final match = await aStoppedGame();
      for (var i = 0; i < 11; i++) {
        await match.event('goal', 'home', 'Lisa');
      }
      for (var i = 0; i < 10; i++) {
        await match.event('goal', 'away', 'Nr2');
      }

      final (status, game) = await match.event('goal', 'home', 'Max');

      expect(status, 201);
      expect(game['score'], {'home': 12, 'away': 10});
    });

    test('E1 the event gets the game time of the server, e.g. 23:14', () async {
      final match = await aStoppedGame();
      await match.setTime(23, 14);

      final (_, game) = await match.event('goal', 'home', 'Max');

      expect(game['events'].last['gameTimeSeconds'], 23 * 60 + 14);
    });

    test('E1_2 a goal of Hilden stores Nora, who stands in goal', () async {
      final match = await aStoppedGame();

      final (_, game) = await match.event('goal', 'away', 'Nr2');

      expect(game['events'].last['goalkeeperId'],
          await match.idOf('home', 'Nora'));
    });

    test('E1_3 a save of Nora is one event: the miss of the Hilden shooter',
        () async {
      final match = await aStoppedGame();

      final (_, game) = await match.event('save', 'away', 'Nr3');

      final save = (game['events'] as List).single;
      expect(save['playerId'], await match.idOf('away', 'Nr3'));
      expect(save['goalkeeperId'], await match.idOf('home', 'Nora'));
      expect(game['score'], {'home': 0, 'away': 0});
    });

    test('E1_5 with Nora off for two minutes, a goal counts for no goalkeeper',
        () async {
      final match = await aStoppedGame();
      await match.event('twoMinutes', 'home', 'Nora');

      final (_, game) = await match.event('goal', 'away', 'Nr2');

      expect(game['events'].last['goalkeeperId'], isNull);
      expect(game['homeLineup']['goalkeeperId'], isNull);
    });
  });

  group('E2 delete an event', () {
    test('E2_1 deleting the goal of Max at 12:11 makes it 11:11', () async {
      final match = await aStoppedGame();
      for (var i = 0; i < 11; i++) {
        await match.event('goal', 'home', 'Lisa');
        await match.event('goal', 'away', 'Nr2');
      }
      final (_, withMax) = await match.event('goal', 'home', 'Max');
      final number = withMax['events'].last['number'];

      final (status, game) = await match.deleteEvent(number);

      expect(status, 200);
      expect(game['score'], {'home': 11, 'away': 11});
    });

    test('E2_2 deleting the third penalty of Max lifts his disqualification',
        () async {
      final match = await aStoppedGame();
      final third = await match.threePenaltiesForMax();

      await match.deleteEvent(third);
      final (status, _) = await match.event('goal', 'home', 'Max');

      expect(status, 201);
    });
  });

  group('E3 only the ticker link records events', () {
    test('E3 without ticker code or with the team code nothing is recorded',
        () async {
      final match = await aStoppedGame();
      final body = {
        'type': 'goal',
        'side': 'home',
        'playerId': await match.idOf('home', 'Max'),
      };

      final (without, _) =
          await server().post('/games/${match.gameId}/events', body: body);
      final (withWrongCode, _) = await server().post(
          '/games/${match.gameId}/events',
          body: body,
          tickerCode: 'guessed');

      expect(without, 403);
      expect(withWrongCode, 403);
    });

    test('E3 without ticker code nothing is deleted', () async {
      final match = await aStoppedGame();
      final (_, game) = await match.event('goal', 'home', 'Max');

      final (status, _) = await server().delete(
          '/games/${match.gameId}/events/${game['events'].last['number']}');

      expect(status, 403);
    });
  });

  group('E5 lineup and substitutions', () {
    test('E5_2 Max out, Tom in', () async {
      final match = await aStoppedGame();

      final (status, game) = await match.substitute('home', 'Max', 'Tom');

      expect(status, 201);
      final field = game['homeLineup']['fieldPlayerIds'] as List;
      expect(field, contains(await match.idOf('home', 'Tom')));
      expect(field, isNot(contains(await match.idOf('home', 'Max'))));
    });

    test('E5_3 a substitution is not shown in the events of the viewers',
        () async {
      final match = await aStoppedGame();

      await match.substitute('home', 'Max', 'Tom');
      final (_, game) = await server().get('/games/${match.gameId}');

      expect(game['events'], isEmpty);
    });

    test('E5_4 Max with two minutes leaves the field, Mettmann has 5 there',
        () async {
      final match = await aStoppedGame();

      final (_, game) = await match.event('twoMinutes', 'home', 'Max');

      final field = game['homeLineup']['fieldPlayerIds'] as List;
      expect(field, hasLength(5));
      expect(field, isNot(contains(await match.idOf('home', 'Max'))));
    });

    test('E5_5 Hilden substitutes the same way: Nr2 out, Nr8 in', () async {
      final match = await aStoppedGame();

      final (status, game) = await match.substitute('away', 'Nr2', 'Nr8');

      expect(status, 201);
      expect(game['awayLineup']['fieldPlayerIds'],
          contains(await match.idOf('away', 'Nr8')));
    });

    test('E5_7 Max goes into the empty goal; a goal of Hilden counts for him',
        () async {
      final match = await aStoppedGame();
      await match.event('twoMinutes', 'home', 'Nora');

      await match.intoGoal('home', 'Max');
      final (_, game) = await match.event('goal', 'away', 'Nr2');

      expect(
          game['events'].last['goalkeeperId'], await match.idOf('home', 'Max'));
    });
  });

  group('R1 timeouts', () {
    test('R1_1 a third timeout in the game is fine, a fourth is rejected',
        () async {
      final match = await aStoppedGame();
      await match.setTime(10, 0);
      await match.timeout('home');
      await match.setTime(29, 50);
      await match.clock('half-time');
      await match.clock('start');
      await match.clock('stop');
      await match.setTime(40, 0);
      await match.timeout('home');
      await match.setTime(45, 0);
      final (third, _) = await match.timeout('home');

      await match.setTime(50, 0);
      final (fourth, json) = await match.timeout('home');

      expect(third, 201);
      expect(fourth, 409);
      expect(json['message'], 'TV Mettmann Männer hat keine Auszeit mehr.');
    });

    test('R1_2 a third timeout in the first half is rejected', () async {
      final match = await aStoppedGame();
      await match.setTime(10, 0);
      await match.timeout('home');
      await match.setTime(20, 0);
      await match.timeout('home');

      await match.setTime(25, 0);
      final (status, json) = await match.timeout('home');

      expect(status, 409);
      expect(json['message'], 'Nur 2 Auszeiten pro Halbzeit.');
    });

    test('R1_3 in the last 5 minutes only one timeout', () async {
      final match = await aStoppedGame();
      await match.setTime(29, 50);
      await match.clock('half-time');
      await match.clock('start');
      await match.clock('stop');
      await match.setTime(56, 0);
      await match.timeout('home');

      await match.setTime(57, 0);
      final (status, json) = await match.timeout('home');

      expect(status, 409);
      expect(json['message'], 'In den letzten 5 Minuten nur eine Auszeit.');
    });
  });

  group('R2 and R3 disqualification', () {
    test('R2 the third penalty of Max disqualifies him', () async {
      final match = await aStoppedGame();
      await match.threePenaltiesForMax();

      final (status, json) = await match.comeOn('home', 'Max');

      expect(status, 409);
      expect(json['message'], 'Max ist disqualifiziert.');
    });

    test('R3 after red, Max gets no more events, not even a yellow card',
        () async {
      final match = await aStoppedGame();
      await match.event('redCard', 'home', 'Max');

      final (status, json) = await match.event('yellowCard', 'home', 'Max');

      expect(status, 409);
      expect(json['message'], 'Max ist disqualifiziert.');
    });
  });

  group('R4 events only during the game', () {
    test('R4_1 before kick-off no event is accepted', () async {
      final match = await aStoppedGame(kickOff: false);

      final (status, json) = await match.event('goal', 'home', 'Max');

      expect(status, 409);
      expect(json['message'], 'Das Spiel hat noch nicht begonnen.');
    });

    test('R4_2 after the end no event is accepted or deleted', () async {
      final match = await aStoppedGame();
      final (_, game) = await match.event('goal', 'home', 'Max');
      final number = game['events'].last['number'];
      await match.clock('half-time');
      await match.clock('start');
      await match.clock('end');

      final (recordStatus, json) = await match.event('goal', 'home', 'Max');
      final (deleteStatus, _) = await match.deleteEvent(number);

      expect(recordStatus, 409);
      expect(json['message'], 'Das Spiel ist beendet.');
      expect(deleteStatus, 409);
    });
  });

  group('R5 and R7 who may get which event', () {
    test('R5 a save on the empty goal of Mettmann is rejected', () async {
      final match = await aStoppedGame();
      await match.event('twoMinutes', 'home', 'Nora');

      final (status, json) = await match.event('save', 'away', 'Nr2');

      expect(status, 409);
      expect(json['message'],
          'TV Mettmann Männer hat keinen Torwart auf dem Feld.');
    });

    test('R7 Tom on the bench gets no technical fault, but a yellow card',
        () async {
      final match = await aStoppedGame();

      final (faultStatus, json) =
          await match.event('technicalFault', 'home', 'Tom');
      final (yellowStatus, _) = await match.event('yellowCard', 'home', 'Tom');

      expect(faultStatus, 409);
      expect(json['message'], 'Dieser Spieler steht nicht auf dem Feld.');
      expect(yellowStatus, 201);
    });

    test('R7 while Max sits out two minutes, Tom cannot come on', () async {
      final match = await aStoppedGame();
      await match.event('twoMinutes', 'home', 'Max');

      final (status, json) = await match.comeOn('home', 'Tom');

      expect(status, 409);
      expect(json['message'], 'TV Mettmann Männer ist noch in Unterzahl.');
    });
  });

  group('U2.1 and U3.1 events and the clock', () {
    test('U2_1 the goal of Max at 23:14 keeps its time after a correction',
        () async {
      final match = await aStoppedGame();
      await match.setTime(23, 14);
      await match.event('goal', 'home', 'Max');

      await match.setTime(23, 5);
      final (_, game) = await server().get('/games/${match.gameId}');

      expect(game['events'].single['gameTimeSeconds'], 23 * 60 + 14);
    });

    test('U3_1 a timeout stops the running clock', () async {
      final match = await aStoppedGame();
      await match.clock('start');

      final (_, game) = await match.timeout('home');

      expect(game['clock']['running'], isFalse);
    });
  });

  group('L1 the live view asks for news', () {
    test('L1 with the known version the answer is 204, after a goal 200',
        () async {
      final match = await aStoppedGame();
      final (_, before) = await server().get('/games/${match.gameId}');
      final version = before['version'];

      final unchanged =
          await server().status('/games/${match.gameId}?version=$version');
      await match.event('goal', 'home', 'Max');
      final changed =
          await server().status('/games/${match.gameId}?version=$version');

      expect(unchanged, 204);
      expect(changed, 200);
    });
  });

  group('L3 running penalties', () {
    test('L3_1 two minutes for Max at 23:00: at 24:37 there are 0:23 left',
        () async {
      final match = await aStoppedGame();
      await match.setTime(23, 0);
      await match.event('twoMinutes', 'home', 'Max');

      final (_, game) = await match.setTime(24, 37);

      final penalty = (game['runningPenalties'] as List).single;
      expect(penalty['playerId'], await match.idOf('home', 'Max'));
      expect(penalty['remainingSeconds'], 23);
    });

    test('L3_2 two minutes at 29:00 still run after half-time: 1:00 left',
        () async {
      final match = await aStoppedGame();
      await match.setTime(29, 0);
      await match.event('twoMinutes', 'home', 'Max');
      await match.clock('half-time');

      final (_, game) = await match.clock('start');
      await match.clock('stop');

      expect((game['runningPenalties'] as List).single['remainingSeconds'],
          inInclusiveRange(59, 60));
    });

    test('L3_3 a red card for Max means two minutes short-handed', () async {
      final match = await aStoppedGame();
      await match.setTime(10, 0);

      final (_, game) = await match.event('redCard', 'home', 'Max');

      expect(
          (game['runningPenalties'] as List).single['remainingSeconds'], 120);
      expect(game['homeLineup']['fieldPlayerIds'], hasLength(5));
    });
  });

  group('L2 statistics per player', () {
    /// The statistics row of a player, e.g. `row(game, 'home', 'Max')`.
    Future<Map<String, dynamic>> row(Match match, Map<String, dynamic> game,
        String side, String name) async {
      final id = await match.idOf(side, name);
      return (game['${side}Statistics'] as List)
          .singleWhere((r) => r['playerId'] == id) as Map<String, dynamic>;
    }

    test('L2_1 Max scores 4 of 5 seven-meters: seven-meter quota 80 %',
        () async {
      final match = await aStoppedGame();
      for (var i = 0; i < 4; i++) {
        await match.event('sevenMeterGoal', 'home', 'Max');
      }
      final (_, game) = await match.event('sevenMeterMiss', 'home', 'Max');

      final max = await row(match, game, 'home', 'Max');

      expect(max['sevenMeterGoals'], 4);
      expect(max['sevenMeters'], 5);
      expect(max['sevenMeterPercentage'], 80);
    });

    test('L2_2 Nora saves 12 of 30 shots: 12 saves, 18 goals, 40 %', () async {
      final match = await aStoppedGame();
      for (var i = 0; i < 12; i++) {
        await match.event('save', 'away', 'Nr2');
      }
      for (var i = 0; i < 17; i++) {
        await match.event('goal', 'away', 'Nr3');
      }
      final (_, game) = await match.event('goal', 'away', 'Nr3');

      final nora = await row(match, game, 'home', 'Nora');

      expect(nora['saves'], 12);
      expect(nora['goalsAgainst'], 18);
      expect(nora['savePercentage'], 40);
    });

    test(
        'L2 Lisa: goals, shots, shooting quota, technical faults and '
        'penalties', () async {
      final match = await aStoppedGame();
      await match.event('goal', 'home', 'Lisa');
      await match.event('goal', 'home', 'Lisa');
      await match.event('goal', 'home', 'Lisa');
      await match.event('miss', 'home', 'Lisa');
      await match.event('technicalFault', 'home', 'Lisa');
      await match.event('yellowCard', 'home', 'Lisa');
      final (_, game) = await match.event('twoMinutes', 'home', 'Lisa');

      final lisa = await row(match, game, 'home', 'Lisa');

      expect(lisa['goals'], 3);
      expect(lisa['shots'], 4);
      expect(lisa['shootingPercentage'], 75);
      expect(lisa['technicalFaults'], 1);
      expect(lisa['yellowCards'], 1);
      expect(lisa['twoMinutes'], 1);
    });

    test('L2 without a seven-meter Max has no seven-meter quota', () async {
      final match = await aStoppedGame();

      final (_, game) = await match.event('goal', 'home', 'Max');

      final max = await row(match, game, 'home', 'Max');
      expect(max['sevenMeters'], 0);
      expect(max['sevenMeterPercentage'], isNull);
    });
  });

  group('U5 half-time score and archive', () {
    test('U5_1 "Halbzeit" at 2:1 keeps 2:1 as half-time score', () async {
      final match = await aStoppedGame();
      await match.event('goal', 'home', 'Max');
      await match.event('goal', 'home', 'Lisa');
      await match.event('goal', 'away', 'Nr2');

      await match.clock('half-time');
      await match.clock('start');
      final (_, game) = await match.event('goal', 'away', 'Nr3');

      expect(game['halfTimeScore'], {'home': 2, 'away': 1});
      expect(game['score'], {'home': 2, 'away': 2});
    });

    test(
        'U5_2 after "Spielende" and a restart Lisa still sees score, '
        'events and statistics', () async {
      final match = await aStoppedGame();
      await match.event('goal', 'home', 'Max');
      await match.event('goal', 'away', 'Nr2');
      await match.clock('half-time');
      await match.clock('start');
      await match.event('goal', 'home', 'Max');
      await match.clock('stop');
      final (endStatus, _) = await match.clock('end');

      await server().stop();
      final restarted = await RunningServer.start(dataDir: server().dataDir);
      final (status, game) = await restarted.get('/games/${match.gameId}');
      await restarted.stop();

      expect(endStatus, 200);
      expect(status, 200);
      expect(game['status'], 'finished');
      expect(game['score'], {'home': 2, 'away': 1});
      expect(game['halfTimeScore'], {'home': 1, 'away': 1});
      expect(game['events'], hasLength(3));
      final maxId = game['events'].first['playerId'];
      final max = (game['homeStatistics'] as List)
          .singleWhere((r) => r['playerId'] == maxId);
      expect(max['goals'], 2);
    });
  });
}

/// One game seen from the ticker: records events and works the clock.
class Match {
  final RunningServer server;
  final String gameId;
  final String tickerCode;

  Match(this.server, this.gameId, this.tickerCode);

  /// The id of a player by first name, e.g. `idOf('home', 'Max')`.
  Future<String> idOf(String side, String firstName) async {
    final (_, game) = await server.get('/games/$gameId');
    return (game[side]['players'] as List)
        .singleWhere((p) => p['firstName'] == firstName)['id'] as String;
  }

  Future<Answer> lineUp(
      String side, String goalkeeper, List<String> fieldPlayers) async {
    return server.put('/games/$gameId/lineups/$side',
        body: {
          'goalkeeperId': await idOf(side, goalkeeper),
          'fieldPlayerIds': [
            for (final name in fieldPlayers) await idOf(side, name)
          ],
        },
        tickerCode: tickerCode);
  }

  /// Records e.g. `event('goal', 'home', 'Max')`.
  Future<Answer> event(String type, String side, String firstName) async =>
      server.post('/games/$gameId/events',
          body: {
            'type': type,
            'side': side,
            'playerId': await idOf(side, firstName),
          },
          tickerCode: tickerCode);

  Future<Answer> timeout(String side) => server.post('/games/$gameId/events',
      body: {'type': 'timeout', 'side': side}, tickerCode: tickerCode);

  Future<Answer> deleteEvent(Object number) =>
      server.delete('/games/$gameId/events/$number', tickerCode: tickerCode);

  Future<Answer> clock(String button) =>
      server.post('/games/$gameId/clock/$button', tickerCode: tickerCode);

  /// Sets the stopped clock, e.g. `setTime(23, 14)` for 23:14 (U2).
  Future<Answer> setTime(int minutes, int seconds) =>
      server.put('/games/$gameId/clock',
          body: {'gameTimeSeconds': minutes * 60 + seconds},
          tickerCode: tickerCode);

  Future<Answer> substitute(String side, String out, String into) async =>
      server.post('/games/$gameId/substitutions',
          body: {
            'side': side,
            'outId': await idOf(side, out),
            'inId': await idOf(side, into),
          },
          tickerCode: tickerCode);

  Future<Answer> comeOn(String side, String firstName) async =>
      server.post('/games/$gameId/come-on',
          body: {'side': side, 'playerId': await idOf(side, firstName)},
          tickerCode: tickerCode);

  Future<Answer> intoGoal(String side, String firstName) async =>
      server.post('/games/$gameId/into-goal',
          body: {'side': side, 'playerId': await idOf(side, firstName)},
          tickerCode: tickerCode);

  /// Max gets two minutes at 10:00, 12:01 and 14:02 and comes back on in
  /// between. Returns the number of the third penalty (R2).
  Future<int> threePenaltiesForMax() async {
    await setTime(10, 0);
    await event('twoMinutes', 'home', 'Max');
    await setTime(12, 1);
    await comeOn('home', 'Max');
    await event('twoMinutes', 'home', 'Max');
    await setTime(14, 2);
    await comeOn('home', 'Max');
    final (status, game) = await event('twoMinutes', 'home', 'Max');
    expect(status, 201, reason: 'third penalty');
    return game['events'].last['number'] as int;
  }
}
