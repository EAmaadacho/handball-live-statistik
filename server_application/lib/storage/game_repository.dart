import 'dart:convert';
import 'dart:io';

import '../domain/game_clock.dart';
import 'game_archive.dart';
import 'game_json.dart';
import 'json_file.dart';
import 'stored_game.dart';

/// Keeps the running games in memory and writes each one to its own file
/// data/games/<id>.json after every change. A finished game goes into the
/// [GameArchive] instead (ADR-004, U5.2).
///
/// One file per game: a goal in one game does not rewrite the others.
class GameRepository {
  final Directory _dir;
  final GameArchive _archive;
  final Map<String, StoredGame> _running = {};

  /// Loads all running games from [dirPath], e.g. "data/games".
  /// Without [archive] finished games are kept only in memory (tests).
  GameRepository.open(String dirPath, {GameArchive? archive})
      : _dir = Directory(dirPath),
        _archive = archive ?? GameArchive.inMemory() {
    if (!_dir.existsSync()) return;
    for (final file in _dir.listSync().whereType<File>()) {
      if (!file.path.endsWith('.json')) continue;
      final id = file.uri.pathSegments.last.replaceAll('.json', '');
      final json = jsonDecode(file.readAsStringSync());
      // A finished game still as a file: the server stopped between
      // archiving and deleting the file, so this is done now.
      save(storedGameFromJson(id, json as Map<String, Object?>));
    }
  }

  /// The game with [id], running or finished, or `null`.
  StoredGame? byId(String id) => _running[id] ?? _archive.byId(id);

  /// All games of the team [teamId], ordered by date (S1.3).
  List<StoredGame> ofTeam(String teamId) => [
        ..._running.values.where((g) => g.homeTeamId == teamId),
        ..._archive.ofTeam(teamId),
      ]..sort((a, b) => a.date.compareTo(b.date));

  /// Stores [stored]: a running game in its file, a finished game in the
  /// archive. The file is deleted only after the archive has it (ADR-004).
  void save(StoredGame stored) {
    final file = File('${_dir.path}/${stored.id}.json');
    if (stored.game.clock.phase == ClockPhase.finished) {
      _archive.save(stored);
      _running.remove(stored.id);
      if (file.existsSync()) file.deleteSync();
    } else {
      _running[stored.id] = stored;
      writeJsonFile(file, storedGameToJson(stored));
    }
  }
}
