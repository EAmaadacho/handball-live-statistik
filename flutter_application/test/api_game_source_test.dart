import 'dart:convert';
import 'dart:io';

import 'package:flutter_application/data/api_game_source.dart';
import 'package:flutter_application/data/game_source.dart';
import 'package:flutter_application/data/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openapi/api.dart' as api;

const _id = 'ydVsnTnc';
const _code = 'x9Fw3cNs7Ke2Hy5D';

Map<String, dynamic> _player(String id, int number, String first,
        {bool keeper = false}) =>
    {
      'id': id,
      'number': number,
      'firstName': first,
      'lastName': 'X',
      'position': keeper ? 'goalkeeper' : 'fieldPlayer',
    };

Map<String, dynamic> _team(String name, String short, List players) => {
      'name': {'club': name, 'ageGroup': 'men', 'teamNumber': 1},
      'displayName': name,
      'shortCode': short,
      'players': players,
    };

/// TV Mettmann against HSG Hilden in the second half, 38:47, 15:13.
///
/// Max scored against Lukas (a1), Nico (a8) has 2 minutes, Leon is in the
/// squad but not on the match report.
Map<String, dynamic> _game() => {
      'id': _id,
      'version': 7,
      'homeTeamId': 'tvm12345',
      'date': '2026-11-29T15:00:00.000Z',
      'halfLengthMinutes': 30,
      'status': 'running',
      'home': _team('TV Mettmann', 'TVM', [
        _player('nora1', 1, 'Nora', keeper: true),
        for (final (id, n, name) in [
          ('paul11', 11, 'Paul'),
          ('max7', 7, 'Max'),
          ('lisa4', 4, 'Lisa'),
          ('finn5', 5, 'Finn'),
          ('jonas6', 6, 'Jonas'),
          ('ben8', 8, 'Ben'),
          ('tom9', 9, 'Tom'),
        ])
          _player(id, n, name),
      ]),
      'away': _team('HSG Hilden', 'HSG', [
        _player('a1', 1, 'Lukas', keeper: true),
        for (var n = 2; n <= 8; n++) _player('a$n', n, 'G$n'),
      ]),
      'clock': {
        'phase': 'secondHalf',
        'running': true,
        'gameTimeSeconds': 2327
      },
      'homeLineup': {
        'goalkeeperId': 'nora1',
        'fieldPlayerIds': [
          'paul11',
          'max7',
          'lisa4',
          'finn5',
          'jonas6',
          'ben8'
        ],
      },
      'awayLineup': {
        'goalkeeperId': 'a1',
        // Nico (a8) sits out 2 minutes: Hilden plays with five.
        'fieldPlayerIds': ['a2', 'a3', 'a4', 'a5', 'a6'],
      },
      'score': {'home': 15, 'away': 13},
      'halfTimeScore': {'home': 8, 'away': 7},
      'events': [
        {
          'number': 2,
          'type': 'twoMinutes',
          'side': 'away',
          'playerId': 'a8',
          'leavingPlayerId': 'a8',
          'gameTimeSeconds': 2240,
          'half': 2,
        },
        {
          'number': 3,
          'type': 'goal',
          'side': 'home',
          'playerId': 'max7',
          'goalkeeperId': 'a1',
          'gameTimeSeconds': 2292,
          'half': 2,
        },
        {
          'number': 1,
          'type': 'timeout',
          'side': 'away',
          'gameTimeSeconds': 2000,
          'half': 2,
        },
      ],
      'runningPenalties': [
        {'side': 'away', 'playerId': 'a8', 'remainingSeconds': 82},
      ],
    };

/// Plays the server: answers like api.yaml says and notes every request.
class _FakeServer {
  Map<String, dynamic> game = _game();
  final requests = <http.Request>[];

  /// The answer for the next change, e.g. 409 with a rule's text.
  http.Response? nextAnswer;

  http.Response _json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status,
          headers: {'content-type': 'application/json; charset=utf-8'});

  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    if (path == '/teams/tvm12345') {
      return _json({
        'id': 'tvm12345',
        'name': game['home']['name'],
        'displayName': 'TV Mettmann',
        'shortCode': 'TVM',
        'players': [
          ...game['home']['players'],
          _player('leon18', 18, 'Leon'),
        ],
      });
    }
    if (path == '/games/$_id/ticker-access') {
      return http.Response(
          '', request.headers['X-Ticker-Code'] == _code ? 204 : 403);
    }
    if (request.method == 'GET' && path == '/games/$_id') {
      final known = request.url.queryParameters['version'];
      return known == '${game['version']}'
          ? http.Response('', 204)
          : _json(game);
    }
    if (nextAnswer case final answer?) {
      nextAnswer = null;
      return answer;
    }
    return _json(game);
  }
}

void main() {
  late _FakeServer server;
  late DateTime time;
  late ApiGameSource source;

  setUp(() {
    server = _FakeServer();
    time = DateTime(2026, 11, 29, 16, 20);
    final client = api.ApiClient(basePath: 'http://server')
      ..client = MockClient(server.handle);
    source = ApiGameSource(client, now: () => time);
  });

  test('L1 the answer of the server becomes score, history and statistics',
      () async {
    final s = (await source.loadState(_id))!;
    expect(s.game.home.name, 'TV Mettmann');
    expect((s.goals[Side.home], s.goals[Side.away]), (15, 13));
    expect((s.clockSeconds, s.half, s.halftimeScore), (2327, 2, '8:7'));
    expect(s.events.map((e) => e.number), [3, 2, 1]);
    expect(s.events.first.who, '7 Max X');
    expect(s.statsOf('max7').goals, 1);
    expect(s.statsOf('a1').goalsAgainst, 1);
    expect(s.timeouts[Side.away], 1);
    expect(s.penalties.single.label, '8');
    expect(s.bench[Side.home], ['tom9']);
    expect(s.bench[Side.away], ['a7']);
    expect(s.goalkeeperOf(Side.home), 'nora1');
  });

  test('ADR-002 nothing new (204): the app counts the clock on by itself',
      () async {
    await source.loadState(_id);
    time = time.add(const Duration(seconds: 5));
    final s = (await source.loadState(_id))!;
    expect(server.requests.last.url.queryParameters['version'], '7');
    expect(s.clockSeconds, 2332);
    expect(s.penalties.single.secondsLeft, 77);
  });

  test('E5_4 after 2 minutes Nico is back on the bench of Hilden', () async {
    await source.loadState(_id);
    time = time.add(const Duration(seconds: 82));
    expect((await source.loadState(_id))!.bench[Side.away], contains('a8'));
  });

  test('E1 a goal goes to the server with the ticker code', () async {
    await source.loadState(_id);
    server.game = _game()
      ..['version'] = 8
      ..['events'] = [
        ..._game()['events'],
        {
          'number': 4,
          'type': 'goal',
          'side': 'home',
          'playerId': 'lisa4',
          'goalkeeperId': 'a1',
          'gameTimeSeconds': 2330,
          'half': 2,
        },
      ];
    final event = await source.record(_id, _code, EventKind.goal, Side.home,
        playerId: 'lisa4');
    final sent = server.requests.last;
    expect(sent.url.path, '/games/$_id/events');
    expect(sent.headers['X-Ticker-Code'], _code);
    expect(jsonDecode(sent.body), {
      'type': 'goal',
      'side': 'home',
      'playerId': 'lisa4',
      'leavingPlayerId': null
    });
    expect(
        (event.number, event.who, event.clockSeconds), (4, '4 Lisa X', 2330));
  });

  test('R1 the server says no (409): its text is shown', () async {
    await source.loadState(_id);
    server.nextAnswer = http.Response(
        jsonEncode({'message': 'Nur 2 Auszeiten pro Halbzeit.'}), 409);
    expect(
        () => source.record(_id, _code, EventKind.timeout, Side.away),
        throwsA(isA<RejectedAction>().having(
            (e) => e.message, 'message', 'Nur 2 Auszeiten pro Halbzeit.')));
  });

  test('E1_6 no answer at all is no rejection: "Nicht gesendet"', () async {
    await source.loadState(_id);
    final offline = ApiGameSource(
        api.ApiClient(basePath: 'http://server')
          ..client = MockClient(
              (_) => throw const SocketException('Keine Verbindung')),
        now: () => time);
    expect(() => offline.record(_id, _code, EventKind.timeout, Side.away),
        throwsA(isNot(isA<RejectedAction>())));
  });

  test('ADR-005 the ticker link is checked when it is opened', () async {
    expect(await source.isTickerCode(_id, _code), isTrue);
    expect(await source.isTickerCode(_id, 'falsch'), isFalse);
  });

  test('E5_2 Tom comes in for Max and takes his place RL', () async {
    await source.loadState(_id);
    server.game = _game()
      ..['version'] = 8
      ..['homeLineup'] = {
        'goalkeeperId': 'nora1',
        'fieldPlayerIds': [
          'paul11',
          'tom9',
          'lisa4',
          'finn5',
          'jonas6',
          'ben8'
        ],
      };
    await source.substitute(_id, _code, Side.home, 2, 'tom9');
    expect(jsonDecode(server.requests.last.body),
        {'side': 'home', 'outId': 'max7', 'inId': 'tom9', 'intoGoal': null});
    final s = (await source.loadState(_id))!;
    expect(s.field[Side.home]![2], 'tom9');
    expect(s.bench[Side.home], ['max7']);
  });

  test('E5_4 Nico comes back on his old gap, not at the end', () async {
    await source.loadState(_id);
    // Before: Hilden with five, the gap is RA (place 6).
    expect((await source.loadState(_id))!.field[Side.away]![6], isNull);
    time = time.add(const Duration(seconds: 82));
    await source.loadState(_id);
    server.game = _game()
      ..['version'] = 8
      ..['runningPenalties'] = []
      ..['awayLineup'] = {
        'goalkeeperId': 'a1',
        'fieldPlayerIds': ['a2', 'a3', 'a4', 'a5', 'a6', 'a8'],
      };
    await source.substitute(_id, _code, Side.away, 6, 'a8');
    expect(server.requests.last.url.path, '/games/$_id/come-on');
    expect((await source.loadState(_id))!.field[Side.away]![6], 'a8');
  });

  test('S1_4 Leon from the squad can be registered late', () async {
    final s = (await source.loadState(_id))!;
    expect(s.game.home.player('leon18').number, 18);
    expect(s.reportOf(Side.home), isNot(contains('leon18')));
  });
}
