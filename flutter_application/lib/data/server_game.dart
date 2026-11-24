/// Turns the server's answer (GET /games/{id}, package openapi) into what
/// the pages show. The pages do not notice whether the demo or the server
/// answers.
///
/// The server sends the events and the statistics (ADR-006); the score
/// after each event, cards and timeouts are read here from the events.
library;

import 'package:openapi/api.dart' as api;

import 'models.dart';

/// The game [game] as the pages show it.
///
/// [homeSquad] is the whole squad of the registered home team: players not
/// on the match report can be registered late (S1.4).
/// [before] is the last state the app showed: everybody keeps their place
/// on the court, because the server only sends who is on the field.
GameState gameStateFrom(api.Game game,
    {api.Team? homeSquad, GameState? before}) {
  final home = _team(game.homeTeamId, game.home, squad: homeSquad);
  final away = _team('${game.id}-away', game.away, gameSquadOnly: true);
  final theGame = Game(
      id: game.id, home: home, away: away, halfMinutes: game.halfLengthMinutes);
  final phase = GamePhase.values.byName(game.clock.phase.value);

  final events = _events(game, theGame);
  final cards = _cards(events);
  final field = {
    Side.home: placesOf(game.homeLineup, before?.field[Side.home]),
    Side.away: placesOf(game.awayLineup, before?.field[Side.away]),
  };
  final penalties = [
    for (final p in game.runningPenalties)
      Penalty(
        side: _side(p.side),
        label: '${theGame.team(_side(p.side)).player(p.playerId).number}',
        secondsLeft: p.remainingSeconds,
        // After red the player stays out, only the team waits (L3.3).
        playerId: cards[p.playerId] == CardMark.red ? null : p.playerId,
      ),
  ];
  final report = {
    Side.home: [for (final p in game.home.players) p.id],
    Side.away: [for (final p in game.away.players) p.id],
  };

  /// On the match report, but not on the field, not sitting out a penalty
  /// and not disqualified.
  List<String> benchOf(Side side) => [
        for (final id in report[side]!)
          if (!field[side]!.contains(id) &&
              !game.runningPenalties.any((p) => p.playerId == id) &&
              cards[id] != CardMark.red)
            id
      ];

  final halfTimeOver =
      phase != GamePhase.notStarted && phase != GamePhase.firstHalf;
  return GameState(
    game: theGame,
    goals: {Side.home: game.score.home, Side.away: game.score.away},
    clockSeconds: game.clock.gameTimeSeconds,
    clockRunning: game.clock.running,
    phase: phase,
    timeouts: {
      for (final side in Side.values)
        side: events
            .where((e) => e.side == side && e.kind == EventKind.timeout)
            .length,
    },
    field: field,
    bench: {for (final side in Side.values) side: benchOf(side)},
    penalties: penalties,
    cards: cards,
    stats: _stats(game),
    events: events,
    halftimeScore: halfTimeOver
        ? '${game.halfTimeScore.home}:${game.halfTimeScore.away}'
        : null,
    goalkeepers: {
      Side.home: game.homeLineup?.goalkeeperId,
      Side.away: game.awayLineup?.goalkeeperId,
    },
    matchReport: report,
  );
}

/// The seven places TH, LA, RL, RM, KL, RR, RA of one team.
///
/// The server only says who is on the field: the goalkeeper and the field
/// players. Who stood on the court before keeps their place, e.g. Max stays
/// on RL. A new player takes a free place, e.g. Tom the RL of Max after a
/// substitution, or Nico his old gap after 2 minutes. Without [before], the
/// server's order is used: LA, RL, RM, KL, RR, RA, then TH for an extra
/// field player with an empty goal.
List<String?> placesOf(api.Lineup? lineup, List<String?>? before) {
  final places = List<String?>.filled(7, null);
  if (lineup == null) return places;
  final keeper = lineup.goalkeeperId;
  if (keeper != null) places[0] = keeper;

  final newcomers = <String>[];
  for (final id in lineup.fieldPlayerIds) {
    final old = before?.indexOf(id) ?? -1;
    if (old >= 0 && places[old] == null) {
      places[old] = id;
    } else {
      newcomers.add(id);
    }
  }
  for (final id in newcomers) {
    final wish = lineup.fieldPlayerIds.indexOf(id) + 1;
    final free = [
      if (wish <= 6) wish,
      for (var place = 1; place <= 6; place++) place,
      0,
    ].firstWhere((place) => places[place] == null, orElse: () => -1);
    if (free >= 0) places[free] = id;
  }
  return places;
}

Side _side(api.Side side) => side == api.Side.home ? Side.home : Side.away;

Team _team(String id, api.GameTeam team,
    {api.Team? squad, bool gameSquadOnly = false}) {
  final onReport = {for (final p in team.players) p.id};
  return Team(
    id: id,
    name: team.displayName,
    shortName: team.shortCode,
    gameSquadOnly: gameSquadOnly,
    players: [
      for (final p in team.players) _player(p),
      // Squad players not on the match report, e.g. Leon, who comes late.
      for (final p in squad?.players ?? const <api.Player>[])
        if (!onReport.contains(p.id)) _player(p),
    ],
  );
}

Player _player(api.Player p) => Player(
      id: p.id,
      number: p.number,
      firstName: p.firstName,
      lastName: p.lastName,
      isGoalkeeper: p.position == api.Position.goalkeeper,
    );

/// The event history, newest first, with the score after each event.
List<GameEvent> _events(api.Game game, Game theGame) {
  final oldestFirst = [...game.events]
    ..sort((a, b) => a.number.compareTo(b.number));
  var home = 0;
  var away = 0;
  final result = <GameEvent>[];
  for (final e in oldestFirst) {
    final kind = EventKind.values.byName(e.type.value);
    final side = _side(e.side);
    if (kind.isGoal) side == Side.home ? home++ : away++;
    final team = theGame.team(side);
    final player = e.playerId == null ? null : team.player(e.playerId!);
    result.insert(
      0,
      GameEvent(
        number: e.number,
        playerId: e.playerId,
        clockSeconds: e.gameTimeSeconds,
        kind: kind,
        side: side,
        who: player == null
            ? team.name
            : '${player.number} ${player.firstName} ${player.lastName}',
        homeGoals: home,
        awayGoals: away,
      ),
    );
  }
  return result;
}

/// Yellow after a yellow card; red after a red card or the third
/// 2 minutes (R2, L3.3).
Map<String, CardMark> _cards(List<GameEvent> events) {
  final cards = <String, CardMark>{};
  final twoMinutes = <String, int>{};
  for (final e in events.reversed) {
    final id = e.playerId;
    if (id == null) continue;
    if (e.kind == EventKind.yellowCard && cards[id] == null) {
      cards[id] = CardMark.yellow;
    }
    if (e.kind == EventKind.twoMinutes) {
      twoMinutes[id] = (twoMinutes[id] ?? 0) + 1;
    }
    if (e.kind == EventKind.redCard || twoMinutes[id] == 3) {
      cards[id] = CardMark.red;
    }
  }
  return cards;
}

/// Statistics per player as the server counted them from the events,
/// e.g. Max: 5 goals from 7 shots (ADR-006). Rates are worked out by the
/// pages, "–" without a shot.
Map<String, PlayerStats> _stats(api.Game game) => {
      for (final s in [...game.homeStatistics, ...game.awayStatistics])
        s.playerId: PlayerStats(
          goals: s.goals,
          shots: s.shots,
          sevenMeterGoals: s.sevenMeterGoals,
          sevenMeterShots: s.sevenMeters,
          saves: s.saves,
          goalsAgainst: s.goalsAgainst,
          technicalFaults: s.technicalFaults,
          yellowCards: s.yellowCards,
          twoMinutes: s.twoMinutes,
          redCards: s.redCards,
        ),
    };
