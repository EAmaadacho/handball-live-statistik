import 'dart:convert';
import 'dart:io';

import 'package:server_application/api/game_access.dart';
import 'package:server_application/api/ticker_api.dart';
import 'package:server_application/storage/game_repository.dart';
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

  TickerHarness() {
    final games = openGames();
    games.games.save(StoredGame(
      id: 'g1',
      homeTeamId: 't1',
      date: DateTime(2026, 11, 28, 18),
      tickerCode: 'ticker-code',
      game: aGame(),
    ));
    tickerApi = TickerApi(games);
  }

  /// Reads the games from the folder again, like after a server restart.
  GameAccess openGames() =>
      GameAccess(GameRepository.open('${dir.path}/games'), now: () => now);

  void restartServer() => tickerApi = TickerApi(openGames());

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
    return (response.statusCode, jsonDecode(await response.readAsString()));
  }

  /// Both lineups set, kick-off at 15:00:00.
  Future<void> kickOff() async {
    await send('PUT', '/games/g1/lineups/home', body: noraInGoal);
    await send('PUT', '/games/g1/lineups/away', body: kaiInGoal);
    await send('POST', '/games/g1/clock/start');
  }
}
