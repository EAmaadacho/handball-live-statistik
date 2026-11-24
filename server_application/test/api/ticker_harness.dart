import 'dart:convert';
import 'dart:io';

import 'package:server_application/api/game_access.dart';
import 'package:server_application/api/game_api.dart';
import 'package:server_application/api/ticker_api.dart';
import 'package:server_application/storage/game_archive.dart';
import 'package:server_application/storage/game_repository.dart';
import 'package:server_application/storage/team_repository.dart';
import 'package:server_application/storage/stored_game.dart';
import 'package:shelf/shelf.dart';

import '../domain/builders.dart';

const noraInGoal = {
  'goalkeeperId': 'p-nora',
  'fieldPlayerIds': mettmannFieldPlayers,
};
const kaiInGoal = {
  'goalkeeperId': 'p-kai',
  'fieldPlayerIds': hildenFieldPlayers,
};

/// TV Mettmann against HSG Hilden as game "g1" with ticker code
/// "ticker-code", in a temporary folder, and a clock the test sets.
///
/// Example: `harness.now = at(5); await harness.send('POST', ...)`.
class TickerHarness {
  final Directory dir = Directory.systemTemp.createTempSync('ticker_api_');
  DateTime now = at(0);
  late TickerApi tickerApi;
  late GameApi gameApi;

  TickerHarness() {
    _start().games.save(StoredGame(
          id: 'g1',
          homeTeamId: 't1',
          date: DateTime(2026, 11, 28, 18),
          tickerCode: 'ticker-code',
          game: aGame(),
        ));
  }

  /// Reads the games and the archive from the folder again, like after a
  /// server restart.
  void restartServer() => _start();

  GameAccess _start() {
    final games = GameAccess(
        GameRepository.open('${dir.path}/games',
            archive: GameArchive.open('${dir.path}/archive.db')),
        now: () => now);
    tickerApi = TickerApi(games);
    gameApi = GameApi(TeamRepository.open('${dir.path}/teams.json'), games);
    return games;
  }

  void delete() => dir.deleteSync(recursive: true);

  /// Sends one ticker request at the time [now], with the right code.
  Future<(int, dynamic)> send(String method, String path,
      {Object? body, String? code = 'ticker-code'}) async {
    final response = await tickerApi.router.call(Request(
      method,
      Uri.parse('http://localhost$path'),
      body: body == null ? null : jsonEncode(body),
      headers: {if (code != null) GameAccess.tickerCodeHeader: code},
    ));
    return _read(response);
  }

  /// Asks for the game like the live view, e.g. with `?version=5`.
  Future<(int, dynamic)> view(String query) async => _read(await gameApi.router
      .call(Request('GET', Uri.parse('http://localhost/games/g1$query'))));

  /// Status and JSON body; `null` for an answer without content (204).
  Future<(int, dynamic)> _read(Response response) async {
    final body = await response.readAsString();
    return (response.statusCode, body.isEmpty ? null : jsonDecode(body));
  }

  /// Both lineups set, kick-off at 15:00:00.
  Future<void> kickOff() async {
    await send('PUT', '/games/g1/lineups/home', body: noraInGoal);
    await send('PUT', '/games/g1/lineups/away', body: kaiInGoal);
    await send('POST', '/games/g1/clock/start');
  }
}
