import '../domain/game.dart';
import '../domain/game_clock.dart';
import '../domain/game_event.dart';
import '../domain/game_team.dart';
import '../domain/lineup.dart';
import 'stored_game.dart';
import 'team_json.dart';

/// Turns a game into JSON for data/games/<id>.json and back (ADR-004).
///
/// Only what ADR-006 stores is written: teams, clock, starting lineups and
/// events. Score, lineup and statistics are computed again after loading.
/// Durations are stored in milliseconds, times as ISO 8601.
Map<String, Object?> storedGameToJson(StoredGame stored) {
  final game = stored.game;
  return {
    'homeTeamId': stored.homeTeamId,
    'date': stored.date.toIso8601String(),
    'tickerCode': stored.tickerCode,
    'home': _gameTeamToJson(game.home),
    'away': _gameTeamToJson(game.away),
    'clock': _clockToJson(game.clock),
    'homeStartingLineup': _lineupToJson(game.homeStartingLineup),
    'awayStartingLineup': _lineupToJson(game.awayStartingLineup),
    'events': [for (final event in game.events) _eventToJson(event)],
    'nextEventNumber': game.nextEventNumber,
  };
}

StoredGame storedGameFromJson(String id, Map<String, Object?> json) =>
    StoredGame(
      id: id,
      homeTeamId: json['homeTeamId'] as String,
      date: DateTime.parse(json['date'] as String),
      tickerCode: json['tickerCode'] as String,
      game: Game.restore(
        home: _gameTeamFromJson(json['home'] as Map<String, Object?>),
        away: _gameTeamFromJson(json['away'] as Map<String, Object?>),
        clock: _clockFromJson(json['clock'] as Map<String, Object?>),
        homeStartingLineup: _lineupFromJson(json['homeStartingLineup']),
        awayStartingLineup: _lineupFromJson(json['awayStartingLineup']),
        events: [
          for (final event in json['events'] as List<Object?>)
            _eventFromJson(event as Map<String, Object?>),
        ],
        nextEventNumber: json['nextEventNumber'] as int,
      ),
    );

Map<String, Object?> _gameTeamToJson(GameTeam team) => {
      'name': teamNameToJson(team.name),
      'shortCode': team.shortCode,
      'players': [for (final player in team.squad) playerToJson(player)],
    };

GameTeam _gameTeamFromJson(Map<String, Object?> json) => GameTeam(
      name: teamNameFromJson(json['name'] as Map<String, Object?>),
      shortCode: json['shortCode'] as String,
      squad: [
        for (final player in json['players'] as List<Object?>)
          playerFromJson(player as Map<String, Object?>),
      ],
    );

Map<String, Object?> _clockToJson(GameClock clock) => {
      'phase': clock.phase.name,
      'running': clock.running,
      'startedAt': clock.startedAt?.toIso8601String(),
      'elapsedBeforeMs': clock.elapsedBefore.inMilliseconds,
      'halfLengthMs': clock.halfLength.inMilliseconds,
    };

GameClock _clockFromJson(Map<String, Object?> json) {
  final startedAt = json['startedAt'] as String?;
  return GameClock.restore(
    phase: ClockPhase.values.byName(json['phase'] as String),
    running: json['running'] as bool,
    startedAt: startedAt == null ? null : DateTime.parse(startedAt),
    elapsedBefore: Duration(milliseconds: json['elapsedBeforeMs'] as int),
    halfLength: Duration(milliseconds: json['halfLengthMs'] as int),
  );
}

Map<String, Object?>? _lineupToJson(Lineup? lineup) => lineup == null
    ? null
    : {
        'goalkeeperId': lineup.goalkeeperId,
        'fieldPlayerIds': lineup.fieldPlayerIds,
      };

Lineup? _lineupFromJson(Object? json) {
  if (json == null) return null;
  final map = json as Map<String, Object?>;
  return Lineup(
    goalkeeperId: map['goalkeeperId'] as String?,
    fieldPlayerIds: (map['fieldPlayerIds'] as List<Object?>).cast<String>(),
  );
}

Map<String, Object?> _eventToJson(GameEvent event) => {
      'number': event.number,
      'type': event.type.name,
      'side': event.side.name,
      'playerId': event.playerId,
      'incomingPlayerId': event.incomingPlayerId,
      'incomingInGoal': event.incomingInGoal,
      'leavingPlayerId': event.leavingPlayerId,
      'goalkeeperId': event.goalkeeperId,
      'gameTimeMs': event.gameTime.inMilliseconds,
      'half': event.half,
    };

GameEvent _eventFromJson(Map<String, Object?> json) => GameEvent(
      number: json['number'] as int,
      type: EventType.values.byName(json['type'] as String),
      side: Side.values.byName(json['side'] as String),
      playerId: json['playerId'] as String?,
      incomingPlayerId: json['incomingPlayerId'] as String?,
      incomingInGoal: json['incomingInGoal'] as bool,
      leavingPlayerId: json['leavingPlayerId'] as String?,
      goalkeeperId: json['goalkeeperId'] as String?,
      gameTime: Duration(milliseconds: json['gameTimeMs'] as int),
      half: json['half'] as int,
    );
