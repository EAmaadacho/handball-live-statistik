import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/game_source.dart';
import '../data/models.dart';
import '../layout.dart';
import '../widgets/court_with_benches.dart';
import '../widgets/event_feed.dart';
import '../widgets/live_notices.dart';
import '../widgets/player_table.dart';
import '../widgets/scoreboard.dart';
import '../widgets/section_heading.dart';
import '../widgets/tab_strip.dart';
import '../widgets/team_comparison.dart';
import '../widgets/team_switch.dart';

/// How often the live page asks for the latest state (ADR-002).
const livePollInterval = Duration(seconds: 1);

enum LiveTab {
  history('Verlauf'),
  field('Feld'),
  game('Spiel'),
  players('Spieler');

  const LiveTab(this.label);
  final String label;
}

/// Live page for spectators (L1–L7, U4, U5): read only, refreshes itself.
///
/// Phone: scoreboard on top, tabs below. Phone sideways: scoreboard left,
/// tabs right. Web: event history left, the other tabs right.
class LivePage extends StatefulWidget {
  const LivePage({super.key, required this.gameId});

  final int gameId;

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  GameState? _state;
  bool _offline = false;
  LiveTab _tab = LiveTab.history;
  Side _tableSide = Side.home;
  Timer? _timer;

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

  /// Keeps the last state when the connection breaks and shows a notice (L1.1).
  Future<void> _load() async {
    try {
      final state = await context.read<GameSource>().loadState(widget.gameId);
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
            : LayoutBuilder(
                builder: (context, box) => switch (screenKindFor(box.biggest)) {
                  ScreenKind.phone => _phone(state),
                  ScreenKind.phoneLandscape => _landscape(state),
                  ScreenKind.web => _web(state),
                },
              ),
      ),
    );
  }

  Widget _top(GameState state, {bool large = false}) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Scoreboard(state: state, large: large),
          if (_offline) OfflineNotice(state: state),
          ShortHandedLines(state: state)
        ],
      );

  Widget _phone(GameState state) => ListView(
        children: [
          _top(state),
          TabStrip(
              tabs: _tabsOf(LiveTab.values), selected: _tab, onSelect: _select),
          _content(state, _tab)
        ],
      );

  Widget _landscape(GameState state) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 330, child: SingleChildScrollView(child: _top(state))),
          const VerticalDivider(width: 1),
          Expanded(
            child: ListView(
              children: [
                TabStrip(
                    tabs: _tabsOf(LiveTab.values),
                    selected: _tab,
                    onSelect: _select),
                _content(state, _tab)
              ],
            ),
          ),
        ],
      );

  /// The history is always visible on the left, so it is not a tab here.
  Widget _web(GameState state) {
    final tabs = LiveTab.values.where((t) => t != LiveTab.history).toList();
    final tab = _tab == LiveTab.history ? LiveTab.players : _tab;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _top(state, large: true),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: ListView(children: [
                  const SectionHeading('Verlauf'),
                  EventFeed(events: state.events)
                ]),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                flex: 3,
                child: ListView(
                  children: [
                    TabStrip(
                        tabs: _tabsOf(tabs), selected: tab, onSelect: _select),
                    _content(state, tab)
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static List<(LiveTab, String)> _tabsOf(List<LiveTab> tabs) =>
      [for (final t in tabs) (t, t.label)];

  void _select(LiveTab tab) => setState(() => _tab = tab);

  Widget _content(GameState state, LiveTab tab) => switch (tab) {
        LiveTab.history => EventFeed(events: state.events),
        LiveTab.field => Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: CourtWithBenches(state: state),
              ),
            ),
          ),
        LiveTab.game => TeamComparison(state: state),
        LiveTab.players => Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TeamSwitch(
                    state: state,
                    selected: _tableSide,
                    onSelect: (s) => setState(() => _tableSide = s)),
                const SizedBox(height: 8),
                PlayerTable(state: state, side: _tableSide),
              ],
            ),
          ),
      };
}
