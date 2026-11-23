// Acceptance tests for T1 and T2 (docs/user-stories.md): each test plays
// the example of one criterion against the real server, only over HTTP.
import 'package:test/test.dart';

import 'running_server.dart';

void main() {
  final server = useRunningServer();

  /// Creates a team and returns its id and secret code.
  Future<(String id, String code)> createTeam(Map<String, Object> body) async {
    final (_, json) = await server().post('/teams', body: body);
    return (json['team']['id'] as String, json['code'] as String);
  }

  group('T1.1 a team exists only once', () {
    test('T1_1 a second TV Mettmann Männer is rejected', () async {
      await createTeam(newTeam());

      final (status, json) = await server().post('/teams', body: newTeam());

      expect(status, 409);
      expect(json['message'], 'TV Mettmann Männer gibt es schon.');
    });

    test('T1_1 "tv mettmann" Männer is rejected as well', () async {
      await createTeam(newTeam());

      final (status, _) =
          await server().post('/teams', body: newTeam(club: 'tv mettmann'));

      expect(status, 409);
    });

    test('T1_1 TV Mettmann Männer II is accepted', () async {
      await createTeam(newTeam());

      final (status, json) =
          await server().post('/teams', body: newTeam(teamNumber: 2));

      expect(status, 201);
      expect(json['team']['displayName'], 'TV Mettmann Männer II');
    });
  });

  group('T1.2 the team link holds a random code', () {
    test('T1_2 Mettmann and Hilden get different codes of 16 characters',
        () async {
      final (_, mettmann) = await createTeam(newTeam());
      final (_, hilden) =
          await createTeam(newTeam(club: 'HSG Hilden', shortCode: 'HSG'));

      expect(mettmann, hasLength(16));
      expect(hilden, hasLength(16));
      expect(mettmann, isNot(hilden));
    });

    test('T1_2 the code is only in the answer to creating the team', () async {
      final (id, code) = await createTeam(newTeam());

      final (status, json) = await server().get('/teams/$id');

      expect(status, 200);
      expect(json.toString(), isNot(contains(code)));
    });

    test('T1_2 adding Max without code answers 403', () async {
      final (id, _) = await createTeam(newTeam());

      final (status, json) =
          await server().post('/teams/$id/players', body: aPlayer());

      expect(status, 403);
      expect(json['message'], 'Dieser Link ist ungültig.');
    });

    test('T1_2 the code of HSG Hilden does not open TV Mettmann', () async {
      final (mettmann, _) = await createTeam(newTeam());
      final (_, hildenCode) =
          await createTeam(newTeam(club: 'HSG Hilden', shortCode: 'HSG'));

      final (status, _) = await server()
          .post('/teams/$mettmann/players', body: aPlayer(), code: hildenCode);

      expect(status, 403);
    });

    test('T1_2 without code nobody can change or remove Max', () async {
      final (id, code) = await createTeam(newTeam());
      final (_, team) = await server()
          .post('/teams/$id/players', body: aPlayer(), code: code);
      final maxId = team['players'].single['id'];

      final (changeStatus, _) = await server()
          .put('/teams/$id/players/$maxId', body: aPlayer(number: 10));
      final (removeStatus, _) =
          await server().delete('/teams/$id/players/$maxId');

      expect(changeStatus, 403);
      expect(removeStatus, 403);
    });
  });

  group('T2 the squad', () {
    test('T2 Max, Lisa and Nora are added, Max changed, Lisa removed',
        () async {
      final (id, code) = await createTeam(newTeam());
      final (_, withMax) = await server()
          .post('/teams/$id/players', body: aPlayer(), code: code);
      final maxId = withMax['players'].single['id'];
      final (_, withLisa) = await server().post('/teams/$id/players',
          body: aPlayer(number: 12, firstName: 'Lisa'), code: code);
      final lisaId = (withLisa['players'] as List)
          .singleWhere((player) => player['firstName'] == 'Lisa')['id'];
      await server().post('/teams/$id/players',
          body: aPlayer(
              number: 1,
              firstName: 'Nora',
              lastName: 'Neumann',
              position: 'goalkeeper'),
          code: code);

      await server().put('/teams/$id/players/$maxId',
          body: aPlayer(number: 10), code: code);
      await server().delete('/teams/$id/players/$lisaId', code: code);

      final (_, team) = await server().get('/teams/$id');
      expect(
        [
          for (final player in team['players'])
            '${player['number']} ${player['firstName']} ${player['position']}'
        ],
        unorderedEquals(['10 Max fieldPlayer', '1 Nora goalkeeper']),
      );
    });

    test('T2 the squad is still there after the server restarts', () async {
      final (id, code) = await createTeam(newTeam());
      await server().post('/teams/$id/players', body: aPlayer(), code: code);

      await server().stop();
      final restarted = await RunningServer.start(dataDir: server().dataDir);
      final (_, team) = await restarted.get('/teams/$id');
      await restarted.stop();

      expect(team['players'].single['firstName'], 'Max');
    });
  });

  group('T2.1 numbers are unique and between 1 and 99', () {
    test('T2_1 Tom cannot take No. 7 of Max', () async {
      final (id, code) = await createTeam(newTeam());
      await server().post('/teams/$id/players', body: aPlayer(), code: code);

      final (status, json) = await server().post('/teams/$id/players',
          body: aPlayer(firstName: 'Tom', lastName: 'Neumann'), code: code);

      expect(status, 409);
      expect(json['message'], 'Die Nummer 7 ist schon vergeben.');
    });

    test('T2_1 No. 1 and No. 99 are accepted, No. 0 and No. 100 not', () async {
      final (id, code) = await createTeam(newTeam());

      Future<int> add(int number) async {
        final (status, _) = await server().post('/teams/$id/players',
            body: aPlayer(number: number, firstName: 'Nr$number'), code: code);
        return status;
      }

      expect(await add(1), 201);
      expect(await add(99), 201);
      expect(await add(0), 409);
      expect(await add(100), 409);
    });
  });
}
