// Acceptance tests for S1 (docs/user-stories.md): each test plays the
// example of one criterion against the real server, only over HTTP.
import 'package:test/test.dart';

import 'running_server.dart';

void main() {
  final server = useRunningServer();

  /// TV Mettmann Männer with Max (7), Lisa (12), Tom (9) and Nora (1);
  /// without Tom if [withTom] is false.
  Future<(String id, String code)> createMettmann({bool withTom = true}) async {
    final (_, json) = await server().post('/teams', body: newTeam());
    final id = json['team']['id'] as String;
    final code = json['code'] as String;
    for (final player in [
      aPlayer(),
      aPlayer(number: 12, firstName: 'Lisa'),
      if (withTom) aPlayer(number: 9, firstName: 'Tom', lastName: 'Neumann'),
      aPlayer(
          number: 1,
          firstName: 'Nora',
          lastName: 'Neumann',
          position: 'goalkeeper'),
    ]) {
      await server().post('/teams/$id/players', body: player, code: code);
    }
    return (id, code);
  }

  /// Creates a game for [teamId] and returns its id and ticker code.
  Future<(String gameId, String tickerCode)> createGame(
      String teamId, String code,
      {Map<String, Object>? body}) async {
    final (_, json) = await server()
        .post('/teams/$teamId/games', body: body ?? newGame(), code: code);
    return (json['game']['id'] as String, json['tickerCode'] as String);
  }

  /// The players of one side as "number first name", e.g. "7 Max".
  List<String> names(Map<String, dynamic> team) => [
        for (final player in team['players'])
          '${player['number']} ${player['firstName']}'
      ];

  group('S1 create a game', () {
    test('S1 TV Mettmann creates a game against HSG Hilden on 28.11.',
        () async {
      final (id, code) = await createMettmann();

      final (status, json) = await server().post('/teams/$id/games',
          body: newGame(date: '2026-11-28T17:00:00Z'), code: code);

      expect(status, 201);
      final game = json['game'];
      expect(game['home']['displayName'], 'TV Mettmann Männer');
      expect(game['away']['displayName'], 'HSG Hilden Männer');
      expect(DateTime.parse(game['date']), DateTime.utc(2026, 11, 28, 17));
      expect(game['halfLengthMinutes'], 30);
    });

    test('S1 a B-Jugend game has halves of 25 minutes', () async {
      final (id, code) = await createMettmann();

      final (_, json) = await server().post('/teams/$id/games',
          body: newGame(halfLengthMinutes: 25), code: code);

      expect(json['game']['halfLengthMinutes'], 25);
    });
  });

  group('S1.1 a game squad for the opponent', () {
    test('S1_1 "5 Jan Becker" of Hilden is entered when creating the game',
        () async {
      final (id, code) = await createMettmann();

      final (_, json) = await server().post('/teams/$id/games',
          body: newGame(players: [
            aPlayer(number: 5, firstName: 'Jan', lastName: 'Becker'),
          ]),
          code: code);

      expect(names(json['game']['away']), ['5 Jan']);
    });

    test('S1_1 the ticker adds "12 Paul Becker" before kick-off', () async {
      final (id, code) = await createMettmann();
      final (gameId, tickerCode) = await createGame(id, code);

      final (status, game) = await server().post(
          '/games/$gameId/match-report/away',
          body: aPlayer(number: 12, firstName: 'Paul', lastName: 'Becker'),
          tickerCode: tickerCode);

      expect(status, 201);
      expect(names(game['away']), ['12 Paul']);
    });

    test('S1_1 two players of Hilden with No. 5 are rejected', () async {
      final (id, code) = await createMettmann();
      final (gameId, tickerCode) = await createGame(id, code,
          body: newGame(players: [
            aPlayer(number: 5, firstName: 'Jan', lastName: 'Becker'),
          ]));

      final (status, json) = await server().post(
          '/games/$gameId/match-report/away',
          body: aPlayer(number: 5, firstName: 'Ole', lastName: 'Becker'),
          tickerCode: tickerCode);

      expect(status, 409);
      expect(json['message'], 'Die Nummer 5 ist schon vergeben.');
    });

    test('S1_1 the game squad of Hilden is only for this game', () async {
      final (id, code) = await createMettmann();
      final (first, tickerCode) = await createGame(id, code,
          body: newGame(date: '2026-11-28T17:00:00Z'));
      await server().post('/games/$first/match-report/away',
          body: aPlayer(number: 5, firstName: 'Jan', lastName: 'Becker'),
          tickerCode: tickerCode);

      final (second, _) = await createGame(id, code,
          body: newGame(date: '2027-02-06T17:00:00Z'));
      final (_, game) = await server().get('/games/$second');

      expect(game['away']['players'], isEmpty);
    });
  });

  group('S1.2 ticker link and viewer link', () {
    test(
        'S1_2 the ticker code has 16 characters and differs from the '
        'team code', () async {
      final (id, code) = await createMettmann();

      final (_, tickerCode) = await createGame(id, code);

      expect(tickerCode, hasLength(16));
      expect(tickerCode, isNot(code));
    });

    test(
        'S1_2 Lisa opens the viewer link without any code and sees no '
        'ticker code', () async {
      final (id, code) = await createMettmann();
      final (gameId, tickerCode) = await createGame(id, code);

      final (status, game) = await server().get('/games/$gameId');

      expect(status, 200);
      expect(game['home']['displayName'], 'TV Mettmann Männer');
      expect(game.toString(), isNot(contains(tickerCode)));
    });

    test('S1_2 the viewer link and the team code do not open the ticker',
        () async {
      final (id, code) = await createMettmann();
      final (gameId, _) = await createGame(id, code);
      final paul = aPlayer(number: 12, firstName: 'Paul', lastName: 'Becker');

      final (withoutCode, _) =
          await server().post('/games/$gameId/match-report/away', body: paul);
      final (withTeamCode, _) = await server().post(
          '/games/$gameId/match-report/away',
          body: paul,
          tickerCode: code);

      expect(withoutCode, 403);
      expect(withTeamCode, 403);
    });
  });

  group('S1.3 all games in the team management', () {
    test('S1_3 both games are listed by date with status and ticker code',
        () async {
      final (id, code) = await createMettmann();
      final (later, laterCode) = await createGame(id, code,
          body: newGame(club: 'TuS Erkrath', date: '2027-02-06T17:00:00Z'));
      final (sooner, soonerCode) = await createGame(id, code,
          body: newGame(date: '2026-11-28T17:00:00Z'));

      final (status, list) =
          await server().getList('/teams/$id/games', code: code);

      expect(status, 200);
      expect([for (final entry in list) entry['game']['id']], [sooner, later]);
      expect([for (final entry in list) entry['tickerCode']],
          [soonerCode, laterCode]);
      expect([for (final entry in list) entry['game']['status']],
          ['planned', 'planned']);
    });

    test('S1_3 without the team code the list is not shown', () async {
      final (id, code) = await createMettmann();
      await createGame(id, code);

      final (status, _) = await server().get('/teams/$id/games');

      expect(status, 403);
    });
  });

  group('S1.4 at most 16 players per team in the match report', () {
    test('S1_4 of 18 players the 16 with the lowest numbers are in the report',
        () async {
      final (_, json) = await server().post('/teams', body: newTeam());
      final id = json['team']['id'] as String;
      final code = json['code'] as String;
      for (var number = 18; number >= 1; number--) {
        await server().post('/teams/$id/players',
            body: aPlayer(number: number, firstName: 'Nr$number'), code: code);
      }

      final (gameId, _) = await createGame(id, code);
      final (_, game) = await server().get('/games/$gameId');

      final numbers = [for (final p in game['home']['players']) p['number']];
      expect(numbers, unorderedEquals([for (var n = 1; n <= 16; n++) n]));
    });

    test('S1_4 Tom comes late: added to the squad and then to the report',
        () async {
      final (id, code) = await createMettmann(withTom: false);
      final (gameId, tickerCode) = await createGame(id, code);
      final (_, team) = await server().post('/teams/$id/players',
          body: aPlayer(number: 9, firstName: 'Tom', lastName: 'Neumann'),
          code: code);
      final tomId = (team['players'] as List)
          .singleWhere((player) => player['firstName'] == 'Tom')['id'];

      final (status, game) = await server().post(
          '/games/$gameId/match-report/home',
          body: {'playerId': tomId},
          tickerCode: tickerCode);

      expect(status, 201);
      expect(names(game['home']),
          unorderedEquals(['7 Max', '12 Lisa', '1 Nora', '9 Tom']));
    });

    test('S1_4 Lisa is taken out of the report before kick-off', () async {
      final (id, code) = await createMettmann();
      final (gameId, tickerCode) = await createGame(id, code);
      final (_, before) = await server().get('/games/$gameId');
      final lisaId = (before['home']['players'] as List)
          .singleWhere((player) => player['firstName'] == 'Lisa')['id'];

      final (status, game) = await server().delete(
          '/games/$gameId/match-report/home/$lisaId',
          tickerCode: tickerCode);

      expect(status, 200);
      expect(
          names(game['home']), unorderedEquals(['7 Max', '9 Tom', '1 Nora']));
    });

    test('S1_4 a 17th player of Hilden is rejected', () async {
      final (id, code) = await createMettmann();
      final (gameId, tickerCode) = await createGame(id, code,
          body: newGame(players: [
            for (var number = 1; number <= 16; number++)
              aPlayer(number: number, firstName: 'Nr$number'),
          ]));

      final (status, json) = await server().post(
          '/games/$gameId/match-report/away',
          body: aPlayer(number: 17, firstName: 'Ole', lastName: 'Becker'),
          tickerCode: tickerCode);

      expect(status, 409);
      expect(json['message'], 'Im Spielbericht stehen schon 16 Spieler.');
    });
  });
}
