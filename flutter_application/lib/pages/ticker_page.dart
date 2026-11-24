import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/game_source.dart';
import '../data/models.dart';
import '../data/ticker_rules.dart';
import '../layout.dart';
import '../widgets/action_sheet.dart';
import '../widgets/court.dart' show fieldPlaces;
import '../widgets/court_with_benches.dart';
import '../widgets/format.dart';
import '../widgets/goalkeeper_choice.dart';
import '../widgets/lineup_board.dart';
import '../widgets/phase_button.dart';
import '../widgets/player_choice.dart';
import '../widgets/scoreboard.dart';
import '../widgets/section_heading.dart';
import '../widgets/ticker_controls.dart';
import '../widgets/ticker_history.dart';
import 'live_page.dart' show livePollInterval;

/// A substitution waiting for its second tap (E5.2).
///
/// Either a place on the court is chosen and a bench player is missing
/// ([place]), or a bench player is chosen and the place is missing
/// ([benchPlayerId]).
class _Swap {
  const _Swap(this.side, {this.place, this.benchPlayerId});

  final Side side;
  final int? place;
  final String? benchPlayerId;
}

/// Ticker page (E1, E2, E5, U1, U3): one person ticks the whole game.
///
/// Tapping a player opens their card with the actions. The server checks
/// every action (R1–R7) and adds the game time; the page shows what it
/// answers. Phone: scoreboard on top, court below. Phone sideways:
/// scoreboard left, court right. Web: history permanently on the right.
class TickerPage extends StatefulWidget {
  const TickerPage({super.key, required this.gameId, required this.tickerCode});

  final String gameId;
  final String tickerCode;

  @override
  State<TickerPage> createState() => _TickerPageState();
}

class _TickerPageState extends State<TickerPage> {
  GameState? _state;
  bool _offline = false;
  _Swap? _swap;
  Timer? _timer;

  GameSource get _source => context.read<GameSource>();

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(livePollInterval, (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final state = await _source.loadState(widget.gameId);
      if (!mounted) return;
      setState(() {
        _state = state ?? _state;
        _offline = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _offline = true);
    }
  }

  // ---------------------------------------------------------------- sending

  /// Sends [action] to the server and loads the new state.
  ///
  /// Refused → the server's reason is shown, e.g. "Nur 2 Auszeiten pro
  /// Halbzeit." No connection → "Nicht gesendet: [what]" with "Erneut
  /// senden", which runs [retry] (E1.6). Returns whether it arrived.
  Future<bool> _send(String what, Future<void> Function() action,
      {required VoidCallback retry}) async {
    try {
      await action();
    } on RejectedAction catch (e) {
      _message(e.message);
      return false;
    } catch (_) {
      setState(() => _offline = true);
      _message('Nicht gesendet: $what',
          actionLabel: 'Erneut senden',
          onAction: retry,
          duration: const Duration(minutes: 5));
      return false;
    }
    await _load();
    return mounted;
  }

  void _message(String text,
      {String? actionLabel, VoidCallback? onAction, Duration? duration}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      key: const Key('TickerMessage'),
      content: Text(text),
      duration: duration ?? const Duration(seconds: 6),
      action: actionLabel == null
          ? null
          : SnackBarAction(label: actionLabel, onPressed: onAction!),
    ));
  }

  /// Records [kind] and shows "Tor · 7 Max · 38:12" with "Rückgängig".
  ///
  /// After 2 minutes or red for the goalkeeper on the field, asks who goes
  /// in goal (E5.6). Yellow shows the hint of R6 when it applies.
  Future<void> _record(EventKind kind, Side side, String? playerId,
      {String? leavingPlayerId}) async {
    final state = _state!;
    final sentOff = kind == EventKind.twoMinutes || kind == EventKind.redCard;
    if (sentOff &&
        leavingPlayerId == null &&
        !state.onField(side).contains(playerId)) {
      // Paul on the bench gets 2 minutes: a field player goes off (E5.4).
      leavingPlayerId = await chooseWhoLeaves(context, state, side,
          title: 'Wer verlässt dafür das Feld?', cancel: 'Abbrechen');
      if (leavingPlayerId == null) return;
    }
    final team = state.game.team(side);
    final player = playerId == null ? null : team.player(playerId);
    final what = player == null
        ? '${kind.label} · ${team.name}'
        : '${kind.label} · ${player.number} ${player.firstName}';
    final wasInGoal = playerId != null &&
        state.goalkeeperOf(side) == playerId &&
        (kind == EventKind.twoMinutes || kind == EventKind.redCard);
    final hint = kind == EventKind.yellowCard &&
        yellowShouldBeTwoMinutes(state, side, playerId!);

    GameEvent? event;
    final ok = await _send(
      what,
      () async => event = await _source.record(
          widget.gameId, widget.tickerCode, kind, side,
          playerId: playerId, leavingPlayerId: leavingPlayerId),
      retry: () =>
          _record(kind, side, playerId, leavingPlayerId: leavingPlayerId),
    );
    if (!ok) return;
    _message(
      '$what · ${formatClock(event!.clockSeconds)}'
      '${hint ? '\nLaut Regel sollte jetzt eine Zeitstrafe folgen.' : ''}',
      actionLabel: 'Rückgängig',
      onAction: () => _delete(event!),
    );
    if (wasInGoal) await _askGoalkeeper(side);
  }

  Future<void> _delete(GameEvent event) async {
    final what = '${event.kind.label} · ${event.who}';
    final ok = await _send(
      'Löschen: $what',
      () => _source.deleteEvent(widget.gameId, widget.tickerCode, event.number),
      retry: () => _delete(event),
    );
    if (ok) _message('Gelöscht: $what');
  }

  /// On the goal place a field player may come in as goalkeeper or as
  /// extra field player; a squad goalkeeper simply goes in goal (IHF 4:7).
  Future<void> _substitute(Side side, int place, String inPlayerId,
      {bool? intoGoal}) async {
    final team = _state!.game.team(side);
    if (place == 0 &&
        intoGoal == null &&
        !team.player(inPlayerId).isGoalkeeper) {
      setState(() => _swap = null);
      intoGoal = await chooseGoalRole(context, team.player(inPlayerId));
      if (intoGoal == null) return;
    }
    final outId = _state!.field[side]![place];
    final inPlayer = team.player(inPlayerId);
    final what = outId == null
        ? 'Wechsel: ${inPlayer.number} ${inPlayer.firstName} auf ${fieldPlaces[place]}'
        : 'Wechsel: ${inPlayer.number} ${inPlayer.firstName} für '
            '${team.player(outId).number} ${team.player(outId).firstName}';
    setState(() => _swap = null);
    final ok = await _send(
      what,
      () => _source.substitute(
          widget.gameId, widget.tickerCode, side, place, inPlayerId,
          intoGoal: intoGoal),
      retry: () => _substitute(side, place, inPlayerId, intoGoal: intoGoal),
    );
    if (!ok) return;
    // A field player in goal leaves the goal empty: an extra field player,
    // also while short-handed (E1.5).
    final emptyGoal = _state!.goalkeeperOf(side) == null;
    _message(emptyGoal
        ? '$what\nTor leer: ${team.name} greift mit '
            'Feldspieler statt Torwart an.'
        : what);
  }

  /// "Ins Tor": Max takes the empty goal and counts as goalkeeper from now on.
  Future<void> _putInGoal(Side side, String playerId) async {
    final p = _state!.game.team(side).player(playerId);
    final what = '${p.number} ${p.firstName} geht ins Tor';
    final ok = await _send(
      what,
      () => _source.putInGoal(widget.gameId, widget.tickerCode, side, playerId),
      retry: () => _putInGoal(side, playerId),
    );
    if (ok) _message('$what und zählt jetzt als Torwart.');
  }

  Future<void> _toggleClock() =>
      _send('Uhr', () => _source.toggleClock(widget.gameId, widget.tickerCode),
          retry: _toggleClock);

  Future<void> _halfTime() => _send(
      'Halbzeit', () => _source.halfTime(widget.gameId, widget.tickerCode),
      retry: _halfTime);

  Future<void> _endGame() =>
      _send('Abpfiff', () => _source.endGame(widget.gameId, widget.tickerCode),
          retry: _endGame);

  /// E5.6: a goalkeeper from the bench comes in for a field player, or a
  /// field player moves into goal, or the goal stays empty.
  Future<void> _askGoalkeeper(Side side) async {
    final keeper = await chooseGoalkeeper(context, _state!, side);
    if (keeper == null || !mounted) return;
    String? out;
    if (!_state!.onField(side).contains(keeper)) {
      out = await chooseWhoLeaves(context, _state!, side);
      if (out == null) return;
    }
    await _send(
      'Torwechsel',
      () => out == null
          ? _source.putInGoal(widget.gameId, widget.tickerCode, side, keeper)
          : _source.substitute(widget.gameId, widget.tickerCode, side,
              _state!.field[side]!.indexOf(out), keeper,
              intoGoal: true),
      retry: () => _askGoalkeeper(side),
    );
  }

  /// Kick-off: both lineups to the server, then the clock starts (E5.1, U1).
  Future<void> _kickoff(Map<Side, List<String>> lineups) => _send(
        'Anpfiff',
        () async {
          for (final MapEntry(key: side, value: places) in lineups.entries) {
            await _source.setLineup(widget.gameId, widget.tickerCode, side,
                places.first, places.sublist(1));
          }
          await _source.toggleClock(widget.gameId, widget.tickerCode);
        },
        retry: () => _kickoff(lineups),
      );

  /// Late registration over "+" at the bench, before and during the game
  /// (S1.4). A registered team picks from its squad, an opponent without
  /// registration types in number and name (S1.1).
  Future<void> _addPlayer(Side side) async {
    final team = _state!.game.team(side);
    if (team.gameSquadOnly) {
      final p = await enterNewPlayer(context, team);
      if (p == null) return;
      final what = 'Nachgemeldet: ${p.number} ${p.firstName}';
      final ok = await _send(
        what,
        () => _source.addSquadPlayer(widget.gameId, widget.tickerCode, side,
            p.number, p.firstName, p.lastName),
        retry: () => _addPlayer(side),
      );
      if (ok) _message('$what, sitzt auf der Bank.');
      return;
    }
    final id = await chooseLatePlayer(context, _state!, side);
    if (id == null) return;
    final p = team.player(id);
    final what = 'Nachgemeldet: ${p.number} ${p.firstName}';
    final ok = await _send(
      what,
      () =>
          _source.addToMatchReport(widget.gameId, widget.tickerCode, side, id),
      retry: () => _addPlayer(side),
    );
    if (ok) _message('$what, sitzt auf der Bank.');
  }

  /// Before kick-off: [playerId] does not play today and leaves the report.
  Future<void> _removeFromReport(Side side, String playerId) async {
    final p = _state!.game.team(side).player(playerId);
    final what = '${p.number} ${p.firstName} aus dem Spielbericht genommen';
    final ok = await _send(
      what,
      () => _source.removeFromMatchReport(
          widget.gameId, widget.tickerCode, side, playerId),
      retry: () => _removeFromReport(side, playerId),
    );
    if (ok) _message('$what. Über „+“ kann er wieder nachgemeldet werden.');
  }

  // ------------------------------------------------------------------ taps

  /// A player on the court or bench: finishes a waiting substitution,
  /// otherwise opens the card with the actions.
  Future<void> _onPlayerTap(Side side, String playerId) async {
    final state = _state!;
    final swap = _swap;
    final place = state.field[side]!.indexOf(playerId);
    final onBench = place < 0;
    if (swap != null && swap.side == side) {
      if (swap.place != null && onBench) {
        return _substitute(side, swap.place!, playerId);
      }
      if (swap.benchPlayerId != null && !onBench) {
        return _substitute(side, place, swap.benchPlayerId!);
      }
    }
    setState(() => _swap = null);

    final choice = await showActionSheet(context, state, side, playerId);
    if (choice == null || !mounted) return;
    final kind = choice.kind;
    if (kind != null) return _record(kind, side, playerId);
    if (choice.intoGoal) return _putInGoal(side, playerId);
    setState(() => _swap = onBench
        ? _Swap(side, benchPlayerId: playerId)
        : _Swap(side, place: place));
  }

  /// An empty place: a bench player may come on, unless a penalty keeps
  /// the place free (E5.4, R7).
  void _onEmptyPlaceTap(Side side, int place) {
    final state = _state!;
    final swap = _swap;
    if (swap != null && swap.side == side && swap.benchPlayerId != null) {
      _substitute(side, place, swap.benchPlayerId!);
      return;
    }
    if (state.onField(side).length >= allowedOnField(state, side)) {
      _message('Platz ${fieldPlaces[place]} bleibt frei, '
          'solange die Zeitstrafe läuft.');
      return;
    }
    setState(() => _swap = _Swap(side, place: place));
  }

  String _swapText(GameState state, _Swap swap) {
    final team = state.game.team(swap.side);
    if (swap.benchPlayerId case final id?) {
      final p = team.player(id);
      return '${p.number} ${p.firstName} rein: Spieler oder freien Platz '
          'von ${team.shortName} antippen';
    }
    final outId = state.field[swap.side]![swap.place!];
    if (outId == null) {
      return 'Platz ${fieldPlaces[swap.place!]}: Bankspieler von '
          '${team.shortName} antippen';
    }
    final p = team.player(outId);
    return '${p.number} ${p.firstName} raus: Bankspieler von '
        '${team.shortName} antippen';
  }

  void _openHistory() {
    final state = _state!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 520),
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(sheet).size.height * 0.8),
          child: ListView(
            shrinkWrap: true,
            children: [
              const SectionHeading('Verlauf'),
              TickerHistory(
                events: state.events,
                onDelete: state.ended
                    ? null
                    : (e) {
                        Navigator.of(sheet).pop();
                        _delete(e);
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- layout

  @override
  Widget build(BuildContext context) {
    final state = _state;
    return Scaffold(
      body: SafeArea(
        child: state == null
            ? Center(
                child: Text(_offline
                    ? 'Verbindung unterbrochen. Neuer Versuch läuft …'
                    : 'Lädt …'))
            : !state.started
                ? _beforeKickoff(state)
                : LayoutBuilder(
                    builder: (context, box) =>
                        switch (screenKindFor(box.biggest)) {
                      ScreenKind.phone => _phone(state),
                      ScreenKind.phoneLandscape => _landscape(state),
                      ScreenKind.web => _web(state),
                    },
                  ),
      ),
    );
  }

  /// Before kick-off the ticker sets up both teams (E5.1).
  Widget _beforeKickoff(GameState state) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Scoreboard(state: state),
              if (_offline) const _OfflineLine(),
              Expanded(
                child: LineupBoard(
                    state: state,
                    onKickoff: _kickoff,
                    onAddPlayer: _addPlayer,
                    onRemoveFromReport: _removeFromReport),
              ),
            ],
          ),
        ),
      );

  List<Widget> _top(GameState state,
          {bool large = false, bool withHistory = true}) =>
      [
        Scoreboard(state: state, onClockTap: _toggleClock, large: large),
        if (_offline) const _OfflineLine(),
        TickerControls(
          state: state,
          onTimeout: (side) => _record(EventKind.timeout, side, null),
          onHistory: withHistory ? _openHistory : null,
        ),
        PhaseButton(state: state, onHalfTime: _halfTime, onEnd: _endGame),
        if (_swap case final swap?)
          SwapBanner(
              text: _swapText(state, swap),
              onCancel: () => setState(() => _swap = null)),
      ];

  Widget _court(GameState state, {double benchWidth = 64}) => Padding(
        // Room below for the name under the goalkeeper.
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
        child: Align(
          alignment: Alignment.topCenter,
          child: CourtWithBenches(
            state: state,
            benchWidth: benchWidth,
            selected:
                _swap?.place == null ? null : (_swap!.side, _swap!.place!),
            onAddPlayer: _addPlayer,
            onPlayerTap: _onPlayerTap,
            onEmptyPlaceTap: _onEmptyPlaceTap,
          ),
        ),
      );

  Widget _phone(GameState state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [..._top(state), Expanded(child: _court(state))],
      );

  Widget _landscape(GameState state) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 330,
            child: SingleChildScrollView(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _top(state)),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _court(state)),
        ],
      );

  Widget _web(GameState state) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ..._top(state, large: true, withHistory: false),
                Expanded(child: _court(state, benchWidth: 84)),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          SizedBox(
            width: 400,
            child: ListView(
              children: [
                const SectionHeading('Verlauf'),
                TickerHistory(
                    events: state.events,
                    onDelete: state.ended ? null : _delete),
              ],
            ),
          ),
        ],
      );
}

class _OfflineLine extends StatelessWidget {
  const _OfflineLine();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('TickerOffline'),
      color: scheme.onSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        'Keine Verbindung zum Server. Nicht gesendete Eingaben bitte erneut senden.',
        style: TextStyle(
            color: scheme.surface, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}
