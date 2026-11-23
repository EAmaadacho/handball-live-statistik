import 'package:openapi/api.dart' as api;

import '../domain/game_clock.dart';
import '../domain/game_event.dart';
import '../domain/game_team.dart';
import '../domain/lineup.dart';
import '../domain/rules.dart' as rules;
import '../domain/score.dart';
import '../storage/stored_game.dart';
import 'team_mapping.dart';

/// The game as everyone may read it with the viewer link: without the
/// ticker code (S1.2). The clock shows the game time at [now] (ADR-003).
api.Game toApiGame(StoredGame stored, DateTime now) {
  final game = stored.game;
  return api.Game(
    id: stored.id,
    date: stored.date,
    halfLengthMinutes: game.clock.halfLength.inMinutes,
    status: _statusOf(game.clock.phase),
    home: _toApiGameTeam(game.home),
    away: _toApiGameTeam(game.away),
    clock: _toApiClock(game.clock, now),
    homeLineup: _toApiLineup(game.lineupOf(Side.home)),
    awayLineup: _toApiLineup(game.lineupOf(Side.away)),
    score: _toApiScore(game.score),
    halfTimeScore: _toApiScore(game.halfTimeScore),
    events: [
      for (final event in game.events)
        if (!rules.isLineupChange(event.type)) _toApiEvent(event),
    ],
    runningPenalties: [
      for (final penalty in game.runningPenalties(now))
        api.RunningPenalty(
          side: api.Side.fromJson(penalty.side.name)!,
          playerId: penalty.playerId,
          remainingSeconds: penalty.remaining.inSeconds,
        ),
    ],
  );
}

api.Score _toApiScore(Score score) =>
    api.Score(home: score.home, away: score.away);

/// e.g. event 14, goal by Max at 23:14 (1394 seconds) in the first half.
api.Event _toApiEvent(GameEvent event) => api.Event(
      number: event.number,
      type: api.EventType.fromJson(event.type.name)!,
      side: api.Side.fromJson(event.side.name)!,
      playerId: event.playerId,
      leavingPlayerId: event.leavingPlayerId,
      goalkeeperId: event.goalkeeperId,
      gameTimeSeconds: event.gameTime.inSeconds,
      half: event.half,
    );

/// The game with its ticker code, only for the team manager (S1.3).
api.GameWithCode toApiGameWithCode(StoredGame stored, DateTime now) =>
    api.GameWithCode(
        game: toApiGame(stored, now), tickerCode: stored.tickerCode);

/// e.g. first half, running, 1394 seconds = 23:14.
api.Clock _toApiClock(GameClock clock, DateTime now) => api.Clock(
      phase: api.ClockPhase.fromJson(clock.phase.name)!,
      running: clock.isRunningAt(now),
      gameTimeSeconds: clock.gameTime(now).inSeconds,
    );

/// The lineup right now, `null` before it is set.
api.Lineup? _toApiLineup(Lineup? lineup) => lineup == null
    ? null
    : api.Lineup(
        goalkeeperId: lineup.goalkeeperId,
        fieldPlayerIds: lineup.fieldPlayerIds,
      );

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
