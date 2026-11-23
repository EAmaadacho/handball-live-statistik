import 'dart:convert';
import 'dart:io';

import 'game_json.dart';
import 'json_file.dart';
import 'stored_game.dart';

/// Keeps the games in memory and writes each one to its own file
/// data/games/<id>.json after every change (ADR-004).
///
/// One file per game: a goal in one game does not rewrite the others.
class GameRepository {
  final Directory _dir;
  final Map<String, StoredGame> _games;

  GameRepository._(this._dir, this._games);

  /// Loads all games from [dirPath], e.g. "data/games".
  factory GameRepository.open(String dirPath) {
    final dir = Directory(dirPath);
    final games = <String, StoredGame>{};
    if (dir.existsSync()) {
      for (final file in dir.listSync().whereType<File>()) {
        if (!file.path.endsWith('.json')) continue;
        final id = file.uri.pathSegments.last.replaceAll('.json', '');
        final json = jsonDecode(file.readAsStringSync());
        games[id] = storedGameFromJson(id, json as Map<String, Object?>);
      }
    }
    return GameRepository._(dir, games);
  }

  /// The game with [id], or `null`.
  StoredGame? byId(String id) => _games[id];

  /// All games of the team [teamId], ordered by date (S1.3).
  List<StoredGame> ofTeam(String teamId) =>
      _games.values.where((g) => g.homeTeamId == teamId).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  /// Stores [stored] and writes its file.
  void save(StoredGame stored) {
    _games[stored.id] = stored;
    writeJsonFile(
        File('${_dir.path}/${stored.id}.json'), storedGameToJson(stored));
  }
}
