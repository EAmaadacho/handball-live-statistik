import 'package:openapi/api.dart' as api;

import '../domain/game_clock.dart';
import '../domain/game_team.dart';
import '../storage/stored_game.dart';
import 'team_mapping.dart';

/// The game as everyone may read it with the viewer link: without the
/// ticker code (S1.2).
api.Game toApiGame(StoredGame stored) => api.Game(
      id: stored.id,
      date: stored.date,
      halfLengthMinutes: stored.game.clock.halfLength.inMinutes,
      status: _statusOf(stored.game.clock.phase),
      home: _toApiGameTeam(stored.game.home),
      away: _toApiGameTeam(stored.game.away),
    );

/// The game with its ticker code, only for the team manager (S1.3).
api.GameWithCode toApiGameWithCode(StoredGame stored) =>
    api.GameWithCode(game: toApiGame(stored), tickerCode: stored.tickerCode);

api.GameTeam _toApiGameTeam(GameTeam team) => api.GameTeam(
      name: toApiName(team.name),
      displayName: team.name.display,
      shortCode: team.shortCode,
      players: [for (final player in team.squad) toApiPlayer(player)],
    );

/// geplant, läuft, beendet (S1.3).
api.GameStatus _statusOf(ClockPhase phase) => switch (phase) {
      ClockPhase.notStarted => api.GameStatus.planned,
      ClockPhase.finished => api.GameStatus.finished,
      _ => api.GameStatus.running,
    };
