import 'dart:typed_data';

import 'demo_data.dart';
import 'demo_game_source.dart';
import 'game_source.dart';
import 'logo_check.dart';
import 'models.dart';
import 'team_source.dart';

/// One team in the demo memory.
class _DemoTeam {
  _DemoTeam(this.name, this.code, this.team);

  final TeamName name;
  final String code;
  Team team;
  final List<TeamGame> games = [];
}

/// Plays the server for the team management in the demo (T1, T2, S1).
///
/// TV Mettmann exists already, with games 17 (running) and 18 (planned).
/// A game created here goes to [games], so the ticker can open it.
/// The rules and messages are the server's (T1.1, T2.1).
class DemoTeamSource implements TeamSource {
  DemoTeamSource(this.games) {
    final mettmann = _DemoTeam(
        const TeamName(club: 'TV Mettmann', ageGroup: AgeGroup.men),
        teamCode,
        demoMettmann);
    mettmann.games.addAll([
      TeamGame(
          id: DemoGameSource.gameId,
          tickerCode: DemoGameSource.tickerCode,
          opponent: 'HSG Hilden Männer',
          date: DateTime(2026, 11, 22, 15),
          status: TeamGameStatus.running),
      TeamGame(
          id: DemoGameSource.nextGameId,
          tickerCode: DemoGameSource.nextTickerCode,
          opponent: 'HSG Hilden Männer',
          date: DateTime(2026, 11, 29, 15),
          status: TeamGameStatus.planned),
    ]);
    _teams[teamId] = mettmann;
  }

  /// The team link of the demo: /team/tvm/k7Qp2xVz9LmA4tRb.
  static const teamId = 'tvm';
  static const teamCode = 'k7Qp2xVz9LmA4tRb';

  final DemoGameSource games;
  final Map<String, _DemoTeam> _teams = {};
  int _counter = 1;

  /// A new id or code; in the demo simply counted up, e.g. "demo3".
  String _next(String prefix) => '$prefix${_counter++}';

  @override
  Future<({String teamId, String code})> createTeam(
      TeamName name, String shortName) async {
    _checkShortName(shortName);
    final same = _teams.values.any((t) =>
        t.name.club.toLowerCase() == name.club.trim().toLowerCase() &&
        t.name.ageGroup == name.ageGroup &&
        t.name.teamNumber == name.teamNumber);
    if (same) throw RejectedAction('${name.display} gibt es schon.');
    final id = _next('team');
    final code = _next('code');
    _teams[id] = _DemoTeam(name, code,
        Team(id: id, name: name.display, shortName: shortName.toUpperCase()));
    return (teamId: id, code: code);
  }

  @override
  Future<Team?> loadTeam(String teamId, String code) async {
    final entry = _teams[teamId];
    return entry != null && entry.code == code ? entry.team : null;
  }

  @override
  Future<Team> addPlayer(String teamId, String code, SquadEntry player) async {
    final entry = _forManager(teamId, code);
    _checkPlayer(entry.team, player);
    final added = _player(_next('p'), player);
    return entry.team =
        _withPlayers(entry.team, [...entry.team.players, added]);
  }

  @override
  Future<Team> updatePlayer(
      String teamId, String code, String playerId, SquadEntry player) async {
    final entry = _forManager(teamId, code);
    _checkPlayer(entry.team, player, except: playerId);
    return entry.team = _withPlayers(entry.team, [
      for (final p in entry.team.players)
        p.id == playerId ? _player(playerId, player) : p
    ]);
  }

  @override
  Future<Team> removePlayer(String teamId, String code, String playerId) async {
    final entry = _forManager(teamId, code);
    return entry.team = _withPlayers(entry.team, [
      for (final p in entry.team.players)
        if (p.id != playerId) p
    ]);
  }

  @override
  Future<Team> uploadLogo(String teamId, String code, Uint8List logo) async {
    final entry = _forManager(teamId, code);
    if (logoProblem(logo) case final problem?) throw RejectedAction(problem);
    games.showLogo(teamId, logo);
    return entry.team = entry.team.withLogo(logo);
  }

  @override
  Future<List<TeamGame>> loadGames(String teamId, String code) async {
    final entry = _forManager(teamId, code);
    return [
      for (final g in entry.games) _withStatus(g),
    ]..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Future<TeamGame> createGame(
      String teamId, String code, NewGameEntry game) async {
    final entry = _forManager(teamId, code);
    _checkShortName(game.opponentShortName);
    final id = _next('spiel');
    final tickerCode = _next('ticker');
    final away = Team(
      id: '$id-away',
      name: game.opponent.display,
      shortName: game.opponentShortName.toUpperCase(),
      gameSquadOnly: true,
      players: [
        for (final p in game.opponentPlayers) _player('$id-${p.number}', p),
      ],
    );
    games.addGame(id, tickerCode, entry.team, away,
        halfMinutes: game.halfMinutes);
    final created = TeamGame(
        id: id,
        tickerCode: tickerCode,
        opponent: game.opponent.display,
        date: game.date,
        status: TeamGameStatus.planned);
    entry.games.add(created);
    return created;
  }

  /// Checks the team code like the server (T1.2).
  _DemoTeam _forManager(String teamId, String code) {
    final entry = _teams[teamId];
    if (entry == null || entry.code != code) {
      throw const RejectedAction('Dieser Team-Link ist ungültig.');
    }
    return entry;
  }

  /// The status as the ticker left it: planned, running or finished.
  TeamGame _withStatus(TeamGame g) {
    final state = games.stateOf(g.id);
    if (state == null) return g;
    return TeamGame(
      id: g.id,
      tickerCode: g.tickerCode,
      opponent: g.opponent,
      date: g.date,
      status: state.ended
          ? TeamGameStatus.finished
          : state.started
              ? TeamGameStatus.running
              : TeamGameStatus.planned,
    );
  }

  static void _checkShortName(String shortName) {
    final length = shortName.trim().length;
    if (length < 2 || length > 4) {
      throw const RejectedAction('Das Kürzel braucht 2 bis 4 Zeichen.');
    }
  }

  /// T2.1: numbers 1–99, unique in the team; both names are needed.
  static void _checkPlayer(Team team, SquadEntry player, {String? except}) {
    if (player.number < 1 || player.number > 99) {
      throw const RejectedAction('Nummern gehen von 1 bis 99.');
    }
    if (team.players.any((p) => p.number == player.number && p.id != except)) {
      throw RejectedAction('Die Nummer ${player.number} ist schon vergeben.');
    }
    if (player.firstName.trim().isEmpty || player.lastName.trim().isEmpty) {
      throw const RejectedAction('Bitte Vor- und Nachnamen eingeben.');
    }
  }

  static Player _player(String id, SquadEntry p) => Player(
      id: id,
      number: p.number,
      firstName: p.firstName.trim(),
      lastName: p.lastName.trim(),
      isGoalkeeper: p.isGoalkeeper);

  static Team _withPlayers(Team team, List<Player> players) => Team(
      id: team.id,
      name: team.name,
      shortName: team.shortName,
      players: players,
      officials: team.officials,
      gameSquadOnly: team.gameSquadOnly,
      logo: team.logo);
}
