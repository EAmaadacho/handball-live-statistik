import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import 'bench.dart';
import 'court.dart';
import 'person_card.dart';

/// Court with both benches on the left, used by ticker and live page.
///
/// Tapping a player or official opens their card. The ticker passes
/// [onPlayerTap] and [onEmptyPlaceTap] to show its actions instead.
class CourtWithBenches extends StatelessWidget {
  const CourtWithBenches({
    super.key,
    required this.state,
    this.onAddPlayer,
    this.onPlayerTap,
    this.onEmptyPlaceTap,
    this.selected,
    this.benchWidth = 64,
  });

  final GameState state;

  /// A player on the court or on the bench was tapped.
  final void Function(Side side, String playerId)? onPlayerTap;

  /// An empty place on the court was tapped, e.g. (Side.away, 4) for KL.
  final void Function(Side side, int place)? onEmptyPlaceTap;

  /// The place that is marked, e.g. while choosing whom to bring on.
  final (Side, int)? selected;

  /// Only the ticker may register players late (S1.4).
  final void Function(Side side)? onAddPlayer;
  final double benchWidth;

  @override
  Widget build(BuildContext context) {
    void tapPlayer(Side side, String id) => onPlayerTap != null
        ? onPlayerTap!(side, id)
        : showPlayerCard(context, state, side, id);

    Widget bench(Side side) => Bench(
          state: state,
          side: side,
          onAddPlayer: onAddPlayer == null ? null : () => onAddPlayer!(side),
          onPlayerTap: (id) => tapPlayer(side, id),
          onOfficialTap: (o) => showOfficialCard(context, state, side, o),
        );

    return Row(
      // As wide as bench and court need, so a parent can centre it.
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: benchWidth,
          // Scrolls on short screens instead of overflowing.
          child: SingleChildScrollView(
            child: Column(children: [
              bench(Side.away),
              const SizedBox(height: 8),
              bench(Side.home)
            ]),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Court(
            state: state,
            selected: selected,
            onPlaceTap: (side, place) {
              final id = state.field[side]![place];
              if (id != null) {
                tapPlayer(side, id);
              } else {
                onEmptyPlaceTap?.call(side, place);
              }
            },
          ),
        ),
      ],
    );
  }
}
