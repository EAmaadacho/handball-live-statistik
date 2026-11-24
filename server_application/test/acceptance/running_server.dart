import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:test_process/test_process.dart';

import '../../bin/server.dart';

/// The answer of the server: HTTP status and JSON body.
typedef Answer = (int status, Map<String, dynamic> json);

/// The real server as its own process, with its own empty data folder.
///
/// Acceptance tests use only what a browser can use: HTTP requests.
/// Example: `await server.post('/teams', body: newTeam())` answers
/// `(201, {"team": {...}, "code": "k7Qm2xPa9RtB4wZe"})`.
class RunningServer {
  final TestProcess _process;
  final String _host;
  final Directory dataDir;

  RunningServer._(this._process, this._host, this.dataDir);

  /// Starts the server on a free port. Pass [dataDir] to start it again
  /// on the data of an earlier run, like after a restart.
  static Future<RunningServer> start({Directory? dataDir}) async {
    final dir = dataDir ?? Directory.systemTemp.createTempSync('acceptance_');
    final process = await TestProcess.start(
      'dart',
      ['run', 'bin/server.dart'],
      environment: {EnvVariables.port: '0', EnvVariables.dataDir: dir.path},
    );
    final line = await process.stdout.next.timeout(const Duration(seconds: 30));
    final port = RegExp(r'port (\d+)').firstMatch(line)!.group(1);
    return RunningServer._(process, 'http://127.0.0.1:$port', dir);
  }

  /// Stops the process but keeps the data folder.
  Future<void> stop() => _process.kill();

  /// Stops the process and deletes the data folder.
  Future<void> stopAndClean() async {
    await stop();
    dataDir.deleteSync(recursive: true);
  }

  // [code] is the secret team code, [tickerCode] the code of the ticker
  // link; each one goes into its own header.

  Future<Answer> get(String path, {String? code}) =>
      _send('GET', path, code: code);

  /// GET for answers that are a list, e.g. GET /teams/{id}/games.
  Future<(int, List<dynamic>)> getList(String path, {String? code}) async {
    final response = await _request('GET', path, code: code);
    return (response.statusCode, jsonDecode(response.body) as List<dynamic>);
  }

  Future<Answer> post(String path,
          {Object? body, String? code, String? tickerCode}) =>
      _send('POST', path, body: body, code: code, tickerCode: tickerCode);

  Future<Answer> put(String path, {Object? body, String? code}) =>
      _send('PUT', path, body: body, code: code);

  Future<Answer> delete(String path, {String? code, String? tickerCode}) =>
      _send('DELETE', path, code: code, tickerCode: tickerCode);

  Future<Answer> _send(String method, String path,
      {Object? body, String? code, String? tickerCode}) async {
    final response = await _request(method, path,
        body: body, code: code, tickerCode: tickerCode);
    return (
      response.statusCode,
      jsonDecode(response.body) as Map<String, dynamic>
    );
  }

  Future<http.Response> _request(String method, String path,
      {Object? body, String? code, String? tickerCode}) async {
    final request = http.Request(method, Uri.parse('$_host$path'));
    if (body != null) request.body = jsonEncode(body);
    if (code != null) request.headers['X-Team-Code'] = code;
    if (tickerCode != null) request.headers['X-Ticker-Code'] = tickerCode;
    return http.Response.fromStream(await request.send());
  }
}

/// Starts a fresh server before each test of the file and removes it after.
RunningServer Function() useRunningServer() {
  late RunningServer server;
  setUp(() async => server = await RunningServer.start());
  tearDown(() => server.stopAndClean());
  return () => server;
}

/// Body of POST /teams; by default TV Mettmann Männer with short code TVM.
Map<String, Object> newTeam({
  String club = 'TV Mettmann',
  String ageGroup = 'men',
  int teamNumber = 1,
  String shortCode = 'TVM',
}) =>
    {
      'name': {'club': club, 'ageGroup': ageGroup, 'teamNumber': teamNumber},
      'shortCode': shortCode,
    };

/// Body of POST/PUT .../players; by default 7 Max Mustermann, field player.
Map<String, Object> aPlayer({
  int number = 7,
  String firstName = 'Max',
  String lastName = 'Mustermann',
  String position = 'fieldPlayer',
}) =>
    {
      'number': number,
      'firstName': firstName,
      'lastName': lastName,
      'position': position,
    };

/// Body of POST /teams/{id}/games; by default against HSG Hilden Männer on
/// 28.11.2026 at 18:00 with halves of 30 minutes.
Map<String, Object> newGame({
  String club = 'HSG Hilden',
  String date = '2026-11-28T17:00:00Z',
  List<Map<String, Object>> players = const [],
  int? halfLengthMinutes,
}) =>
    {
      'opponent': {
        'name': {'club': club, 'ageGroup': 'men', 'teamNumber': 1},
        'shortCode': 'HSG',
        'players': players,
      },
      'date': date,
      if (halfLengthMinutes != null) 'halfLengthMinutes': halfLengthMinutes,
    };
