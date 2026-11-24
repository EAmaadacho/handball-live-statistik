import 'dart:convert';

import 'package:openapi/api.dart' as api;

import 'game_source.dart';
import 'models.dart';
import 'server_game.dart';

/// The last answer of the server for one game.
class _Answer {
  _Answer(this.game, this.state, this.receivedAt);

  final api.Game game;
  final GameState state;
  final DateTime receivedAt;
}

/// Asks the Dart server (api.yaml) instead of the demo.
///
/// Every change sends the secret ticker code as X-Ticker-Code and gets the
/// whole game back, so the page is up to date right away. In between the
/// pages ask every second with the version they know: "nothing new" (204)
/// costs no data, and the app lets clock and penalties count on by itself
/// (ADR-002, ADR-003).
///
/// Answers: 409 → [RejectedAction] with the server's text, e.g. "Nur 2
/// Auszeiten pro Halbzeit."; no answer at all → the error is passed on and
/// the ticker shows "Nicht gesendet" (E1.6).
class ApiGameSource implements GameSource {
  /// [now] replaces the system time in tests.
  ApiGameSource(api.ApiClient client, {DateTime Function()? now})
      : _games = api.GamesApi(client),
        _events = api.EventsApi(client),
        _clock = api.ClockApi(client),
        _teams = api.TeamsApi(client),
        _now = now ?? DateTime.now;

  final api.GamesApi _games;
  final api.EventsApi _events;
  final api.ClockApi _clock;
  final api.TeamsApi _teams;
  final DateTime Function() _now;

  final Map<String, _Answer> _answers = {};

  /// Squads of registered teams, by team id, loaded once (S1.4).
  final Map<String, api.Team?> _squads = {};

  // ------------------------------------------------------------------ read

  @override
  Future<Game?> loadGame(String id) async => (await loadState(id))?.game;

  /// The team page follows in Bauplan step 6 (GET /teams/{teamId} with
  /// X-Team-Code); until then no team code opens it.
  @override
  Future<Team?> loadTeamByCode(String teamCode) async => null;

  @override
  Future<GameState?> loadState(String id) async {
    final known = _answers[id];
    final api.Game? game;
    try {
      game = await _games.getGame(id, version: known?.game.version);
    } on api.ApiException catch (e) {
      if (e.code == 404 && e.innerException == null) return null;
      rethrow;
    }
    // No game in the answer = 204, nothing changed since [known].
    final answer = game == null ? known! : await _remember(game);
    final seconds = _now().difference(answer.receivedAt).inSeconds;
    return answer.state.advancedBy(seconds);
  }

  @override
  Future<bool> isTickerCode(String gameId, String tickerCode) async {
    try {
      await _games.checkTickerAccess(gameId, tickerCode);
      return true;
    } on api.ApiException catch (e) {
      if (e.innerException == null && (e.code == 403 || e.code == 404)) {
        return false;
      }
      rethrow;
    }
  }

  // ----------------------------------------------------------------- write

  @override
  Future<GameEvent> record(
      String gameId, String tickerCode, EventKind kind, Side side,
      {String? playerId, String? leavingPlayerId}) async {
    final state = await _write(
        gameId,
        () => _events.recordEvent(
            gameId,
            tickerCode,
            api.NewEvent(
                type: api.EventType.fromJson(kind.name)!,
                side: _apiSide(side),
                playerId: playerId,
                leavingPlayerId: leavingPlayerId)));
    // The newest event is the one just recorded, with the server's time.
    return state.events.first;
  }

  @override
  Future<void> deleteEvent(String gameId, String tickerCode, int number) =>
      _write(gameId, () => _events.deleteEvent(gameId, tickerCode, number));

  /// Someone on [place] → substitution, the place is empty → comes on
  /// (E5.2, E5.4). Either way the incoming player gets this place.
  @override
  Future<void> substitute(
      String gameId, String tickerCode, Side side, int place, String inPlayerId,
      {bool? intoGoal}) {
    final before = _answers[gameId]!.state;
    final outId = before.field[side]![place];
    final wish = before.copyWith(field: {
      ...before.field,
      side: [...before.field[side]!]..[place] = inPlayerId,
    });
    return _write(
      gameId,
      () => outId == null
          ? _events.comeOn(
              gameId,
              tickerCode,
              api.ComeOn(
                  side: _apiSide(side),
                  playerId: inPlayerId,
                  intoGoal: intoGoal))
          : _events.substitute(
              gameId,
              tickerCode,
              api.Substitution(
                  side: _apiSide(side),
                  outId: outId,
                  inId: inPlayerId,
                  intoGoal: intoGoal)),
      before: wish,
    );
  }

  @override
  Future<void> putInGoal(
          String gameId, String tickerCode, Side side, String playerId) =>
      _write(
          gameId,
          () => _events.putInGoal(gameId, tickerCode,
              api.IntoGoal(side: _apiSide(side), playerId: playerId)));

  /// The places the ticker chose stay as they are: Paul on LA, Max on RL …
  @override
  Future<void> setLineup(String gameId, String tickerCode, Side side,
      String goalkeeperId, List<String> fieldPlayerIds) {
    final before = _answers[gameId]!.state;
    return _write(
      gameId,
      () => _games.setLineup(
          gameId,
          tickerCode,
          _apiSide(side),
          api.NewLineup(
              goalkeeperId: goalkeeperId, fieldPlayerIds: fieldPlayerIds)),
      before: before.copyWith(field: {
        ...before.field,
        side: [goalkeeperId, ...fieldPlayerIds],
      }),
    );
  }

  /// Only the registered home team has a squad to choose from (S1.4).
  @override
  Future<void> addToMatchReport(
          String gameId, String tickerCode, Side side, String playerId) =>
      _write(
          gameId,
          () => _games.addHomePlayerToMatchReport(
              gameId, tickerCode, api.SquadPlayerRef(playerId: playerId)));

  @override
  Future<Player> addSquadPlayer(String gameId, String tickerCode, Side side,
      int number, String firstName, String lastName) async {
    final state = await _write(
        gameId,
        () => _games.addAwayPlayerToMatchReport(
            gameId,
            tickerCode,
            api.PlayerData(
                number: number,
                firstName: firstName,
                lastName: lastName,
                position: api.Position.fieldPlayer)));
    return state.game.team(side).players.firstWhere((p) => p.number == number);
  }

  @override
  Future<void> removeFromMatchReport(
          String gameId, String tickerCode, Side side, String playerId) =>
      _write(
          gameId,
          () => _games.removeFromMatchReport(
              gameId, tickerCode, _apiSide(side), playerId));

  @override
  Future<void> toggleClock(String gameId, String tickerCode) async {
    final answer = _answers[gameId]!;
    final seconds = _now().difference(answer.receivedAt).inSeconds;
    final running = answer.state.advancedBy(seconds).clockRunning;
    await _write(
        gameId,
        () => running
            ? _clock.stopClock(gameId, tickerCode)
            : _clock.startClock(gameId, tickerCode));
  }

  @override
  Future<void> halfTime(String gameId, String tickerCode) =>
      _write(gameId, () => _clock.halfTime(gameId, tickerCode));

  @override
  Future<void> endGame(String gameId, String tickerCode) =>
      _write(gameId, () => _clock.endGame(gameId, tickerCode));

  // --------------------------------------------------------------- helpers

  /// Sends a change and keeps the game the server answers with.
  ///
  /// [before] is the state the places are taken from, e.g. with Tom
  /// already on the place of Max after a substitution.
  Future<GameState> _write(String gameId, Future<api.Game?> Function() send,
      {GameState? before}) async {
    final api.Game? game;
    try {
      game = await send();
    } on api.ApiException catch (e) {
      throw _rejection(e) ?? e;
    }
    return (await _remember(game!, before: before)).state;
  }

  Future<_Answer> _remember(api.Game game, {GameState? before}) async {
    final squad = _squads.containsKey(game.homeTeamId)
        ? _squads[game.homeTeamId]
        : _squads[game.homeTeamId] = await _loadSquad(game.homeTeamId);
    final state = gameStateFrom(game,
        homeSquad: squad, before: before ?? _answers[game.id]?.state);
    return _answers[game.id] = _Answer(game, state, _now());
  }

  /// Without the squad the ticker still works, only late registration of
  /// squad players is not offered.
  Future<api.Team?> _loadSquad(String teamId) async {
    try {
      return await _teams.getTeam(teamId);
    } on api.ApiException {
      return null;
    }
  }

  /// The server said no (403, 404, 409): its text for the ticker.
  /// Null if the request did not arrive, e.g. no network (E1.6).
  static RejectedAction? _rejection(api.ApiException e) {
    if (e.innerException != null) return null;
    if (e.code == 403) {
      return const RejectedAction('Dieser Ticker-Link ist ungültig.');
    }
    if (e.code != 400 && e.code != 404 && e.code != 409) return null;
    try {
      final body = jsonDecode(e.message ?? '') as Map<String, dynamic>;
      return RejectedAction(body['message'] as String);
    } catch (_) {
      return const RejectedAction('Der Server hat die Eingabe abgelehnt.');
    }
  }

  static api.Side _apiSide(Side side) =>
      side == Side.home ? api.Side.home : api.Side.away;
}
