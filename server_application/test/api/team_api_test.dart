import 'dart:convert';
import 'dart:io';

import 'package:server_application/api/team_api.dart';
import 'package:server_application/storage/team_repository.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// Sends one request straight to the router, without a running server.
Future<(int, Map<String, dynamic>)> send(
  TeamApi teamApi,
  String method,
  String path, {
  Object? body,
  String? code,
}) async {
  final response = await teamApi.router.call(Request(
    method,
    Uri.parse('http://localhost$path'),
    body: body == null ? null : jsonEncode(body),
    headers: {if (code != null) TeamApi.codeHeader: code},
  ));
  final json = jsonDecode(await response.readAsString());
  return (response.statusCode, json as Map<String, dynamic>);
}

const newMettmann = {
  'name': {'club': 'TV Mettmann', 'ageGroup': 'men', 'teamNumber': 1},
  'shortCode': 'TVM',
};

const max = {
  'number': 7,
  'firstName': 'Max',
  'lastName': 'Mustermann',
  'position': 'fieldPlayer',
};

void main() {
  late Directory dir;
  late TeamApi teamApi;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('team_api_');
    var ids = 0;
    teamApi = TeamApi(
      TeamRepository.open('${dir.path}/teams.json'),
      newCode: () => 'secret-code',
      newId: () => 'id-${++ids}',
    );
  });
  tearDown(() => dir.deleteSync(recursive: true));

  /// Creates TV Mettmann Männer; its id is "id-1", its code "secret-code".
  Future<void> createMettmann() =>
      send(teamApi, 'POST', '/teams', body: newMettmann);

  group('T1 create a team', () {
    test('T1 POST /teams answers 201 with the team and its code', () async {
      final (status, json) =
          await send(teamApi, 'POST', '/teams', body: newMettmann);

      expect(status, 201);
      expect(json['code'], 'secret-code');
      expect(json['team']['id'], 'id-1');
      expect(json['team']['displayName'], 'TV Mettmann Männer');
      expect(json['team']['players'], isEmpty);
    });

    test('T1_1 a second "tv mettmann" Männer is rejected with 409', () async {
      await createMettmann();

      final (status, json) = await send(teamApi, 'POST', '/teams', body: {
        ...newMettmann,
        'name': {'club': 'tv mettmann', 'ageGroup': 'men', 'teamNumber': 1},
      });

      expect(status, 409);
      expect(json['message'], 'tv mettmann Männer gibt es schon.');
    });

    test('T1 a rule of the domain answers 409 with its message', () async {
      final (status, json) = await send(teamApi, 'POST', '/teams',
          body: {...newMettmann, 'shortCode': 'T'});

      expect(status, 409);
      expect(json['message'], 'Das Kürzel braucht 2 bis 4 Zeichen.');
    });

    test('T1 a body without shortCode answers 400', () async {
      final (status, json) = await send(teamApi, 'POST', '/teams',
          body: {'name': newMettmann['name']});

      expect(status, 400);
      expect(json['message'], 'Die Anfrage ist unvollständig.');
    });

    test('T1 an unknown age group answers 400', () async {
      final (status, _) = await send(teamApi, 'POST', '/teams', body: {
        ...newMettmann,
        'name': {'club': 'TV Mettmann', 'ageGroup': 'herren', 'teamNumber': 1},
      });

      expect(status, 400);
    });
  });

  group('T1 read a team', () {
    test('T1_2 GET /teams/{id} works without code and never shows the code',
        () async {
      await createMettmann();

      final (status, json) = await send(teamApi, 'GET', '/teams/id-1');

      expect(status, 200);
      expect(json['displayName'], 'TV Mettmann Männer');
      expect(jsonEncode(json), isNot(contains('secret-code')));
    });

    test('T1 an unknown team answers 404', () async {
      final (status, json) = await send(teamApi, 'GET', '/teams/nope');

      expect(status, 404);
      expect(json['message'], 'Team nicht gefunden.');
    });
  });

  group('T2 squad', () {
    test('T2 adding Max answers 201 with Max in the squad', () async {
      await createMettmann();

      final (status, json) = await send(teamApi, 'POST', '/teams/id-1/players',
          body: max, code: 'secret-code');

      expect(status, 201);
      expect(json['players'].single['firstName'], 'Max');
      expect(json['players'].single['id'], 'id-2');
    });

    test('T1_2 adding without code answers 403', () async {
      await createMettmann();

      final (status, json) =
          await send(teamApi, 'POST', '/teams/id-1/players', body: max);

      expect(status, 403);
      expect(json['message'], 'Dieser Link ist ungültig.');
    });

    test('T1_2 adding with a wrong code answers 403', () async {
      await createMettmann();

      final (status, _) = await send(teamApi, 'POST', '/teams/id-1/players',
          body: max, code: 'guessed');

      expect(status, 403);
    });

    test('T2_1 a second No. 7 answers 409', () async {
      await createMettmann();
      await send(teamApi, 'POST', '/teams/id-1/players',
          body: max, code: 'secret-code');

      final (status, json) = await send(teamApi, 'POST', '/teams/id-1/players',
          body: {...max, 'firstName': 'Tom'}, code: 'secret-code');

      expect(status, 409);
      expect(json['message'], 'Die Nummer 7 ist schon vergeben.');
    });

    test('T2 Max gets No. 10 with PUT and keeps his id', () async {
      await createMettmann();
      await send(teamApi, 'POST', '/teams/id-1/players',
          body: max, code: 'secret-code');

      final (status, json) = await send(
          teamApi, 'PUT', '/teams/id-1/players/id-2',
          body: {...max, 'number': 10}, code: 'secret-code');

      expect(status, 200);
      expect(json['players'].single['number'], 10);
      expect(json['players'].single['id'], 'id-2');
    });

    test('T2 DELETE removes Max', () async {
      await createMettmann();
      await send(teamApi, 'POST', '/teams/id-1/players',
          body: max, code: 'secret-code');

      final (status, json) = await send(
          teamApi, 'DELETE', '/teams/id-1/players/id-2',
          code: 'secret-code');

      expect(status, 200);
      expect(json['players'], isEmpty);
    });

    test('T2 removing an unknown player answers 409', () async {
      await createMettmann();

      final (status, json) = await send(
          teamApi, 'DELETE', '/teams/id-1/players/nope',
          code: 'secret-code');

      expect(status, 409);
      expect(json['message'], 'Spieler nicht gefunden.');
    });

    test('ADR-004 Max is still there after the server restarts', () async {
      await createMettmann();
      await send(teamApi, 'POST', '/teams/id-1/players',
          body: max, code: 'secret-code');

      final restarted = TeamApi(TeamRepository.open('${dir.path}/teams.json'));
      final (_, json) = await send(restarted, 'GET', '/teams/id-1');

      expect(json['players'].single['firstName'], 'Max');
    });
  });
}
