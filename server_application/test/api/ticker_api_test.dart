import 'dart:convert';
import 'dart:io';

import 'package:server_application/api/game_access.dart';
import 'package:server_application/api/ticker_api.dart';
import 'package:server_application/storage/game_repository.dart';
import 'package:server_application/storage/stored_game.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../domain/builders.dart';

const noraInGoal = {
  'goalkeeperId': 'p-nora',
  'fieldPlayerIds': mettmannFieldPlayers,
};
const kaiInGoal = {
  'goalkeeperId': 'p-kai',
  'fieldPlayerIds': hildenFieldPlayers,
};

void main() {
  late Directory dir;
  late DateTime now;
  late TickerApi tickerApi;

  GameAccess openGames() =>
      GameAccess(GameRepository.open('${dir.path}/games'), now: () => now);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('ticker_api_');
    now = at(0);
    final games = openGames();
    games.games.save(StoredGame(
      id: 'g1',
      homeTeamId: 't1',
      date: DateTime(2026, 11, 28, 18),
      tickerCode: 'ticker-code',
      game: aGame(),
    ));
    tickerApi = TickerApi(games);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  /// Sends one ticker request at the time [now], with the right code.
  Future<(int, dynamic)> send(String method, String path,
      {Object? body, String? code = 'ticker-code'}) async {
    final response = await tickerApi.router.call(Request(
      method,
      Uri.parse('http://localhost$path'),
      body: body == null ? null : jsonEncode(body),
      headers: {if (code != null) GameAccess.tickerCodeHeader: code},
    ));
    return (response.statusCode, jsonDecode(await response.readAsString()));
  }

  /// Both lineups set, kick-off at 15:00:00.
  Future<void> kickOff() async {
    await send('PUT', '/games/g1/lineups/home', body: noraInGoal);
    await send('PUT', '/games/g1/lineups/away', body: kaiInGoal);
    await send('POST', '/games/g1/clock/start');
  }

  group('E5_1 starting lineup', () {
    test('E5_1 Nora in goal, Max and Lisa in the field', () async {
      final (status, json) =
          await send('PUT', '/games/g1/lineups/home', body: noraInGoal);

      expect(status, 200);
      expect(json['homeLineup']['goalkeeperId'], 'p-nora');
      expect(json['homeLineup']['fieldPlayerIds'],
          containsAll(['p-max', 'p-lisa']));
      expect(json['awayLineup'], isNull);
    });

    test('E5_1 a lineup with only 6 players answers 409', () async {
      final (status, json) = await send('PUT', '/games/g1/lineups/home', body: {
        'goalkeeperId': 'p-nora',
        'fieldPlayerIds': mettmannFieldPlayers.sublist(1),
      });

      expect(status, 409);
      expect(json['message'],
          'Bitte 7 verschiedene Spieler aufstellen: 1 im Tor, 6 im Feld.');
    });

    test('E5_1 kick-off before both teams are set up answers 409', () async {
      await send('PUT', '/games/g1/lineups/home', body: noraInGoal);

      final (status, json) = await send('POST', '/games/g1/clock/start');

      expect(status, 409);
      expect(json['message'], 'Bitte zuerst beide Teams aufstellen.');
    });

    test('a side other than home or away answers 404', () async {
      final (status, _) =
          await send('PUT', '/games/g1/lineups/middle', body: noraInGoal);

      expect(status, 404);
    });
  });

  group('U1 clock like in a sports hall', () {
    test('U1 after kick-off at 15:00:00 the clock shows 5:00 at 15:05:00',
        () async {
      await kickOff();
      now = at(5);

      final (_, json) = await send('POST', '/games/g1/clock/stop');

      expect(json['status'], 'running');
      expect(json['clock']['phase'], 'firstHalf');
      expect(json['clock']['gameTimeSeconds'], 300);
    });

    test('U1_1 stopped at 5:00, the clock still shows 5:00 two minutes later',
        () async {
      await kickOff();
      now = at(5);
      await send('POST', '/games/g1/clock/stop');
      now = at(7);

      final (_, json) = await send('POST', '/games/g1/clock/start');

      expect(json['clock']['gameTimeSeconds'], 300);
      expect(json['clock']['running'], isTrue);
    });

    test('U1 without the ticker code the clock does not start (403)', () async {
      final (status, json) =
          await send('POST', '/games/g1/clock/start', code: null);

      expect(status, 403);
      expect(json['message'], 'Dieser Link ist ungültig.');
    });
  });

  group('U2 correct the time', () {
    test('U2 stopped at 23:14, the ticker corrects it to 23:05', () async {
      await kickOff();
      now = at(23, 14);
      await send('POST', '/games/g1/clock/stop');

      final (status, json) = await send('PUT', '/games/g1/clock',
          body: {'gameTimeSeconds': 23 * 60 + 5});

      expect(status, 200);
      expect(json['clock']['gameTimeSeconds'], 23 * 60 + 5);
    });

    test('U2 while the clock runs the time is not corrected (409)', () async {
      await kickOff();

      final (status, json) =
          await send('PUT', '/games/g1/clock', body: {'gameTimeSeconds': 60});

      expect(status, 409);
      expect(json['message'], 'Bitte erst die Uhr anhalten.');
    });
  });

  group('U3 and U5 end of a half', () {
    test('U3_2 the clock stops by itself at 30:00', () async {
      await kickOff();
      now = at(31);

      final (status, json) = await send('POST', '/games/g1/clock/stop');

      expect(status, 409);
      expect(json['message'], 'Die Uhr steht schon.');
    });

    test('U5_1 "Halbzeit" at 29:50 sets 30:00, the second half starts there',
        () async {
      await kickOff();
      now = at(29, 50);
      final (_, halfTime) = await send('POST', '/games/g1/clock/half-time');
      now = at(45);

      final (_, secondHalf) = await send('POST', '/games/g1/clock/start');

      expect(halfTime['clock']['phase'], 'halfTime');
      expect(halfTime['clock']['gameTimeSeconds'], 1800);
      expect(secondHalf['clock']['phase'], 'secondHalf');
      expect(secondHalf['clock']['gameTimeSeconds'], 1800);
    });

    test('U5_2 after "Spielende" the game is finished', () async {
      await kickOff();
      now = at(30);
      await send('POST', '/games/g1/clock/half-time');
      now = at(40);
      await send('POST', '/games/g1/clock/start');
      now = at(70);

      final (_, json) = await send('POST', '/games/g1/clock/end');

      expect(json['status'], 'finished');
      expect(json['clock']['gameTimeSeconds'], 3600);
    });
  });

  group('U4 the clock runs on the server', () {
    test('U4_1 after a server restart the clock goes on: 12:00 at 15:12',
        () async {
      await kickOff();
      now = at(12);

      tickerApi = TickerApi(openGames());
      final (_, json) = await send('POST', '/games/g1/clock/stop');

      expect(json['clock']['gameTimeSeconds'], 12 * 60);
    });
  });
}
