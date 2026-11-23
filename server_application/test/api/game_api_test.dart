import 'dart:convert';
import 'dart:io';

import 'package:server_application/api/game_access.dart';
import 'package:server_application/api/game_api.dart';
import 'package:server_application/api/team_api.dart';
import 'package:server_application/storage/game_repository.dart';
import 'package:server_application/storage/team_repository.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../domain/builders.dart';

/// Sends one request straight to the router, without a running server.
Future<(int, dynamic)> send(
  GameApi gameApi,
  String method,
  String path, {
  Object? body,
  String? teamCode,
  String? tickerCode,
}) async {
  final response = await gameApi.router.call(Request(
    method,
    Uri.parse('http://localhost$path'),
    body: body == null ? null : jsonEncode(body),
    headers: {
      if (teamCode != null) TeamApi.codeHeader: teamCode,
      if (tickerCode != null) GameAccess.tickerCodeHeader: tickerCode,
    },
  ));
  return (response.statusCode, jsonDecode(await response.readAsString()));
}

Map<String, Object> playerData(int number, String firstName,
        [String position = 'fieldPlayer']) =>
    {
      'number': number,
      'firstName': firstName,
      'lastName': 'Becker',
      'position': position,
    };

/// HSG Hilden Männer with Kai in goal and Jan, as the opponent of a game.
final newGame = {
  'opponent': {
    'name': {'club': 'HSG Hilden', 'ageGroup': 'men', 'teamNumber': 1},
    'shortCode': 'HSG',
    'players': [playerData(1, 'Kai', 'goalkeeper'), playerData(5, 'Jan')],
  },
  'date': '2026-11-28T18:00:00.000',
};

void main() {
  late Directory dir;
  late TeamRepository teams;
  late GameApi gameApi;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('game_api_');
    teams = TeamRepository.open('${dir.path}/teams.json')
      ..save('t1', mettmann());
    var ids = 0;
    gameApi = GameApi(
        teams, GameAccess(GameRepository.open('${dir.path}/games')),
        newCode: () => 'ticker-code', newId: () => 'id-${++ids}');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  /// Creates the game against HSG Hilden. Kai and Jan get the ids id-1
  /// and id-2, the game gets id-3.
  Future<void> createGame() => send(gameApi, 'POST', '/teams/t1/games',
      body: newGame, teamCode: 'abc123');

  group('S1 create a game', () {
    test('S1 TV Mettmann creates a game against HSG Hilden, halves of 30',
        () async {
      final (status, json) = await send(gameApi, 'POST', '/teams/t1/games',
          body: newGame, teamCode: 'abc123');

      expect(status, 201);
      final game = json['game'];
      expect(game['id'], 'id-3');
      expect(game['status'], 'planned');
      expect(game['halfLengthMinutes'], 30);
      expect(game['home']['displayName'], 'TV Mettmann Männer');
      expect(game['away']['displayName'], 'HSG Hilden Männer');
      expect(game['home']['players'], hasLength(3));
      expect(
          game['away']['players'].map((p) => p['firstName']), ['Kai', 'Jan']);
    });

    test('S1 a B-Jugend game with halves of 25 minutes', () async {
      final (_, json) = await send(gameApi, 'POST', '/teams/t1/games',
          body: {...newGame, 'halfLengthMinutes': 25}, teamCode: 'abc123');

      expect(json['game']['halfLengthMinutes'], 25);
    });

    test('S1 without the team code the game is not created (403)', () async {
      final (status, _) =
          await send(gameApi, 'POST', '/teams/t1/games', body: newGame);

      expect(status, 403);
    });

    test('S1_1 two players of Hilden with No. 5 are rejected (409)', () async {
      final (status, json) = await send(gameApi, 'POST', '/teams/t1/games',
          body: {
            ...newGame,
            'opponent': {
              ...newGame['opponent'] as Map<String, Object>,
              'players': [playerData(5, 'Jan'), playerData(5, 'Ole')],
            },
          },
          teamCode: 'abc123');

      expect(status, 409);
      expect(json['message'], 'Die Nummer 5 ist schon vergeben.');
    });
  });

  group('S1_2 links', () {
    test('S1_2 the creator gets the ticker code once', () async {
      final (_, json) = await send(gameApi, 'POST', '/teams/t1/games',
          body: newGame, teamCode: 'abc123');

      expect(json['tickerCode'], 'ticker-code');
    });

    test('S1_2 everyone can open the game with its id, without ticker code',
        () async {
      await createGame();

      final (status, json) = await send(gameApi, 'GET', '/games/id-3');

      expect(status, 200);
      expect(json['away']['shortCode'], 'HSG');
      expect(jsonEncode(json), isNot(contains('ticker-code')));
    });

    test('an unknown game answers 404', () async {
      final (status, json) = await send(gameApi, 'GET', '/games/nope');

      expect(status, 404);
      expect(json['message'], 'Spiel nicht gefunden.');
    });
  });

  group('S1_3 games of the team', () {
    test('S1_3 the team manager sees the game with status and ticker code',
        () async {
      await createGame();

      final (status, json) =
          await send(gameApi, 'GET', '/teams/t1/games', teamCode: 'abc123');

      expect(status, 200);
      expect(json.single['game']['status'], 'planned');
      expect(json.single['tickerCode'], 'ticker-code');
    });

    test('S1_3 without the team code the list is not shown (403)', () async {
      final (status, _) = await send(gameApi, 'GET', '/teams/t1/games');

      expect(status, 403);
    });
  });

  group('S1_4 match report', () {
    test('S1_4 Tom joins the squad after the game was created and is added',
        () async {
      await createGame();
      teams.save('t1', teams.byId('t1')!.addPlayer(tom()));

      final (status, json) = await send(
          gameApi, 'POST', '/games/id-3/match-report/home',
          body: {'playerId': 'p-tom'}, tickerCode: 'ticker-code');

      expect(status, 201);
      expect(
          json['home']['players'].map((p) => p['firstName']), contains('Tom'));
    });

    test('S1_4 a player who is not in the squad answers 409', () async {
      await createGame();

      final (status, json) = await send(
          gameApi, 'POST', '/games/id-3/match-report/home',
          body: {'playerId': 'nope'}, tickerCode: 'ticker-code');

      expect(status, 409);
      expect(json['message'], 'Spieler nicht gefunden.');
    });

    test('S1_4 Hilden adds 12 Ole Becker', () async {
      await createGame();

      final (status, json) = await send(
          gameApi, 'POST', '/games/id-3/match-report/away',
          body: playerData(12, 'Ole'), tickerCode: 'ticker-code');

      expect(status, 201);
      expect(json['away']['players'], hasLength(3));
    });

    test('S1_4 without the ticker code nothing is added (403)', () async {
      await createGame();

      final (status, _) = await send(
          gameApi, 'POST', '/games/id-3/match-report/away',
          body: playerData(12, 'Ole'), tickerCode: 'guessed');

      expect(status, 403);
    });

    test('S1_4 Lisa is taken out of the report before kick-off', () async {
      await createGame();

      final (status, json) = await send(
          gameApi, 'DELETE', '/games/id-3/match-report/home/p-lisa',
          tickerCode: 'ticker-code');

      expect(status, 200);
      expect(json['home']['players'].map((p) => p['firstName']),
          isNot(contains('Lisa')));
    });
  });
}
