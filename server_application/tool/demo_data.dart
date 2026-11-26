// Prepares the live demo on a running server: creates TV Mettmann with
// 8 players and prints the team link and the link to "Spiel anlegen".
// With DEMO_PREFILL the client fills in HSG Hilden there (game_create_page).
// Run from server_application while the server runs:
//   dart run tool/demo_data.dart
// Optional: dart run tool/demo_data.dart <server url> <client url>
import 'dart:convert';
import 'dart:io';

const _defaultServer = 'http://127.0.0.1:8080';
const _defaultClient = 'http://localhost:5000';

/// TV Mettmann: Nora in goal, Max (No. 7) and Tom (No. 9) in the field.
const _mettmann = [
  (1, 'Nora', 'Neumann', 'goalkeeper'),
  (3, 'Ben', 'Wagner', 'fieldPlayer'),
  (5, 'Paul', 'Schmitz', 'fieldPlayer'),
  (7, 'Max', 'Mustermann', 'fieldPlayer'),
  (9, 'Tom', 'Neumann', 'fieldPlayer'),
  (11, 'Finn', 'Becker', 'fieldPlayer'),
  (14, 'Leon', 'Krämer', 'fieldPlayer'),
  (17, 'Erik', 'Hoffmann', 'fieldPlayer'),
];

Future<void> main(List<String> args) async {
  final server = args.isNotEmpty ? args[0] : _defaultServer;
  final client = args.length > 1 ? args[1] : _defaultClient;
  final http = HttpClient();
  try {
    final created = await _post(http, '$server/teams', {
      'name': _name('TV Mettmann'),
      'shortCode': 'TVM',
    });
    final teamId = created['team']['id'] as String;
    final teamCode = created['code'] as String;

    for (final player in _mettmann) {
      await _post(http, '$server/teams/$teamId/players', _player(player),
          teamCode: teamCode);
    }

    stdout
        .writeln('TV Mettmann ist mit ${_mettmann.length} Spielern angelegt.');
    stdout.writeln('Team-Link:          $client/team/$teamId/$teamCode');
    stdout.writeln(
        'Spiel-anlegen-Link: $client/team/$teamId/$teamCode/spiel-neu');
  } on SocketException {
    stderr
        .writeln('Kein Server unter $server. Läuft dart run bin/server.dart?');
    exitCode = 1;
  } on HttpException catch (e) {
    stderr.writeln(e.message);
    exitCode = 1;
  } finally {
    http.close();
  }
}

Map<String, Object> _name(String club) =>
    {'club': club, 'ageGroup': 'men', 'teamNumber': 1};

Map<String, Object> _player((int, String, String, String) player) {
  final (number, firstName, lastName, position) = player;
  return {
    'number': number,
    'firstName': firstName,
    'lastName': lastName,
    'position': position,
  };
}

/// Sends [body] as JSON and returns the JSON answer, e.g. the new team.
Future<Map<String, dynamic>> _post(
    HttpClient http, String url, Map<String, Object> body,
    {String? teamCode}) async {
  final request = await http.postUrl(Uri.parse(url));
  request.headers.contentType = ContentType.json;
  if (teamCode != null) request.headers.set('X-Team-Code', teamCode);
  request.add(utf8.encode(jsonEncode(body)));
  final response = await request.close();
  final text = await utf8.decodeStream(response);
  if (response.statusCode == 409) {
    throw HttpException('Abgelehnt: $text Gibt es das Team schon? '
        'Dann Server stoppen, den Ordner server_application/data löschen '
        'und neu starten.');
  }
  if (response.statusCode != 201) {
    throw HttpException('Fehler ${response.statusCode} bei $url: $text');
  }
  return jsonDecode(text) as Map<String, dynamic>;
}
