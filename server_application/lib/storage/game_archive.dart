import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import 'game_json.dart';
import 'stored_game.dart';

/// Finished games in the SQLite database data/archive.db (ADR-004, U5.2).
///
/// Players and events get their own tables, so they can be counted with
/// SQL later, e.g. all goals of Max in the season (T5). What is only needed
/// to show the game again (team names, clock, starting lineups) is kept as
/// JSON in the column `setup`. Statistics are not stored: they are computed
/// from the events again, like in a running game (ADR-006).
class GameArchive {
  final Database _db;

  GameArchive._(this._db) {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS games (
        id TEXT PRIMARY KEY,
        home_team_id TEXT NOT NULL,
        date TEXT NOT NULL,
        ticker_code TEXT NOT NULL,
        version INTEGER NOT NULL,
        setup TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS players (
        game_id TEXT NOT NULL REFERENCES games(id),
        side TEXT NOT NULL,
        id TEXT NOT NULL,
        number INTEGER NOT NULL,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        position TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS events (
        game_id TEXT NOT NULL REFERENCES games(id),
        number INTEGER NOT NULL,
        type TEXT NOT NULL,
        side TEXT NOT NULL,
        player_id TEXT,
        incoming_player_id TEXT,
        incoming_in_goal INTEGER NOT NULL,
        leaving_player_id TEXT,
        goalkeeper_id TEXT,
        game_time_ms INTEGER NOT NULL,
        half INTEGER NOT NULL
      );
    ''');
  }

  /// Opens the database file [path], e.g. "data/archive.db".
  factory GameArchive.open(String path) => GameArchive._(sqlite3.open(path));

  /// An archive only in memory, for tests.
  factory GameArchive.inMemory() => GameArchive._(sqlite3.openInMemory());

  /// Writes the finished game in one transaction: either everything is
  /// stored or nothing (ADR-004).
  void save(StoredGame stored) {
    final json = storedGameToJson(stored);
    _db.execute('BEGIN');
    try {
      _delete(stored.id);
      _insertGame(stored, json);
      _insertPlayers(stored.id, 'home', json['home']);
      _insertPlayers(stored.id, 'away', json['away']);
      _insertEvents(stored.id, json['events'] as List<Object?>);
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// The finished game with [id], or `null`.
  StoredGame? byId(String id) {
    final rows = _db.select('SELECT * FROM games WHERE id = ?', [id]);
    return rows.isEmpty ? null : _read(rows.single);
  }

  /// All finished games of the team [teamId], ordered by date.
  List<StoredGame> ofTeam(String teamId) => [
        for (final row in _db.select(
            'SELECT * FROM games WHERE home_team_id = ? ORDER BY date',
            [teamId]))
          _read(row),
      ];

  // --- Writing -----------------------------------------------------------

  void _delete(String id) {
    for (final table in ['events', 'players']) {
      _db.execute('DELETE FROM $table WHERE game_id = ?', [id]);
    }
    _db.execute('DELETE FROM games WHERE id = ?', [id]);
  }

  void _insertGame(StoredGame stored, Map<String, Object?> json) {
    final setup = {
      'home': _withoutPlayers(json['home']),
      'away': _withoutPlayers(json['away']),
      'clock': json['clock'],
      'homeStartingLineup': json['homeStartingLineup'],
      'awayStartingLineup': json['awayStartingLineup'],
      'nextEventNumber': json['nextEventNumber'],
    };
    _db.execute(
      'INSERT INTO games VALUES (?, ?, ?, ?, ?, ?)',
      [
        stored.id,
        stored.homeTeamId,
        json['date'],
        stored.tickerCode,
        stored.version,
        jsonEncode(setup),
      ],
    );
  }

  void _insertPlayers(String gameId, String side, Object? team) {
    final players = (team as Map<String, Object?>)['players'] as List<Object?>;
    for (final player in players.cast<Map<String, Object?>>()) {
      _db.execute(
        'INSERT INTO players VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          gameId,
          side,
          player['id'],
          player['number'],
          player['firstName'],
          player['lastName'],
          player['position'],
        ],
      );
    }
  }

  void _insertEvents(String gameId, List<Object?> events) {
    for (final event in events.cast<Map<String, Object?>>()) {
      _db.execute(
        'INSERT INTO events VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          gameId,
          event['number'],
          event['type'],
          event['side'],
          event['playerId'],
          event['incomingPlayerId'],
          event['incomingInGoal'] == true ? 1 : 0,
          event['leavingPlayerId'],
          event['goalkeeperId'],
          event['gameTimeMs'],
          event['half'],
        ],
      );
    }
  }

  Map<String, Object?> _withoutPlayers(Object? team) =>
      Map.of(team as Map<String, Object?>)..remove('players');

  // --- Reading -----------------------------------------------------------

  /// Puts the rows together into the same JSON as data/games/<id>.json,
  /// so game_json.dart builds the game, as after a server restart.
  StoredGame _read(Row game) {
    final id = game['id'] as String;
    final setup = jsonDecode(game['setup'] as String) as Map<String, Object?>;
    return storedGameFromJson(id, {
      ...setup,
      'homeTeamId': game['home_team_id'],
      'date': game['date'],
      'tickerCode': game['ticker_code'],
      'version': game['version'],
      'home': _teamWithPlayers(id, 'home', setup),
      'away': _teamWithPlayers(id, 'away', setup),
      'events': _events(id),
    });
  }

  /// Team name and short code from `setup`, the players from their table.
  Map<String, Object?> _teamWithPlayers(
          String gameId, String side, Map<String, Object?> setup) =>
      {
        ...setup[side] as Map<String, Object?>,
        'players': _players(gameId, side),
      };

  List<Map<String, Object?>> _players(String gameId, String side) => [
        for (final row in _db.select(
            'SELECT * FROM players WHERE game_id = ? AND side = ? '
            'ORDER BY rowid',
            [gameId, side]))
          {
            'id': row['id'],
            'number': row['number'],
            'firstName': row['first_name'],
            'lastName': row['last_name'],
            'position': row['position'],
          },
      ];

  List<Map<String, Object?>> _events(String gameId) => [
        for (final row in _db.select(
            'SELECT * FROM events WHERE game_id = ? ORDER BY number', [gameId]))
          {
            'number': row['number'],
            'type': row['type'],
            'side': row['side'],
            'playerId': row['player_id'],
            'incomingPlayerId': row['incoming_player_id'],
            'incomingInGoal': row['incoming_in_goal'] == 1,
            'leavingPlayerId': row['leaving_player_id'],
            'goalkeeperId': row['goalkeeper_id'],
            'gameTimeMs': row['game_time_ms'],
            'half': row['half'],
          },
      ];
}
