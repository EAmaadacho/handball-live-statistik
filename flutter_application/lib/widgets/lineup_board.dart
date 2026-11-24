import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import 'court_with_benches.dart';
import 'person_card.dart';
import 'player_choice.dart';

/// The ticker before kick-off: set up 7 players per team (E5.1, E5.5).
///
/// Tap an empty place, then a player of the match report. Tap a player on
/// the court to send them back to the bench. Nothing goes to the server
/// until "Anpfiff": then [onKickoff] gets both lineups, place by place
/// (TH, LA, RL, RM, KL, RR, RA).
class LineupBoard extends StatefulWidget {
  const LineupBoard({
    super.key,
    required this.state,
    required this.onKickoff,
    required this.onAddPlayer,
    required this.onRemoveFromReport,
  });

  final GameState state;
  final void Function(Map<Side, List<String>> lineups) onKickoff;
  final void Function(Side side) onAddPlayer;

  /// A player on the bench does not play today (S1.4, only before kick-off).
  final void Function(Side side, String playerId) onRemoveFromReport;

  @override
  State<LineupBoard> createState() => _LineupBoardState();
}

class _LineupBoardState extends State<LineupBoard> {
  /// The lineup being set up, 7 places per team; null = still free.
  final Map<Side, List<String?>> _lineup = {
    for (final side in Side.values) side: List<String?>.filled(7, null),
  };

  /// The state as it would be with this lineup: who stands where, who sits.
  GameState get _preview {
    final state = widget.state;
    return state.copyWith(
      field: _lineup,
      bench: {
        for (final side in Side.values)
          side: [
            for (final id in state.reportOf(side))
              if (!_lineup[side]!.contains(id)) id
          ],
      },
      goalkeepers: {for (final side in Side.values) side: _lineup[side]![0]},
      matchReport: {for (final side in Side.values) side: state.reportOf(side)},
    );
  }

  Future<void> _choose(Side side, int place) async {
    final lineup = _lineup[side]!;
    final id =
        await choosePlayerForPlace(context, widget.state, side, place, lineup);
    if (id == null) return;
    setState(() {
      final before = lineup.indexOf(id);
      if (before >= 0) lineup[before] = null;
      lineup[place] = id;
    });
  }

  void _onPlayerTap(Side side, String id) {
    final lineup = _lineup[side]!;
    if (lineup.contains(id)) {
      setState(() => lineup[lineup.indexOf(id)] = null);
    } else {
      _showBenchPlayer(side, id);
    }
  }

  /// Card of a bench player with "Aus dem Spielbericht nehmen".
  Future<void> _showBenchPlayer(Side side, String id) async {
    final remove = await showModalBottomSheet<bool>(
      context: context,
      constraints: const BoxConstraints(maxWidth: 480),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PersonCard.player(state: _preview, side: side, playerId: id),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: OutlinedButton(
                key: const Key('RemoveFromReport'),
                onPressed: () => Navigator.of(sheet).pop(true),
                child: const Text('Aus dem Spielbericht nehmen'),
              ),
            ),
          ],
        ),
      ),
    );
    if (remove == true) widget.onRemoveFromReport(side, id);
  }

  /// Why kick-off is not possible yet, e.g. "TV Mettmann: noch 2 Plätze frei".
  String? get _kickoffBlockReason {
    for (final side in Side.values) {
      final free = _lineup[side]!.where((id) => id == null).length;
      if (free > 0) {
        final team = widget.state.game.team(side).name;
        return '$team: noch $free ${free == 1 ? 'Platz' : 'Plätze'} frei';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reason = _kickoffBlockReason;
    String count(Side side) => '${widget.state.game.team(side).shortName} '
        '${_lineup[side]!.whereType<String>().length}/7';

    return Column(
      key: const Key('LineupBoard'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          // Wrap: on a narrow phone the count moves below the title.
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              Text('Aufstellung',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              Text('${count(Side.home)} · ${count(Side.away)}',
                  key: const Key('LineupCount'),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
          child: Text(
              'Freien Platz antippen, dann Spieler wählen. '
              'Spieler auf dem Feld antippen = zurück auf die Bank.',
              style: TextStyle(
                  fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
            child: Align(
              alignment: Alignment.topCenter,
              child: CourtWithBenches(
                state: _preview,
                onPlayerTap: _onPlayerTap,
                onEmptyPlaceTap: _choose,
                onAddPlayer: widget.onAddPlayer,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (reason != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(reason,
                      key: const Key('KickoffReason'),
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                ),
              FilledButton(
                key: const Key('Kickoff'),
                onPressed: reason != null
                    ? null
                    : () => widget.onKickoff({
                          for (final side in Side.values)
                            side: _lineup[side]!.cast<String>(),
                        }),
                child: const Text('Anpfiff'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
