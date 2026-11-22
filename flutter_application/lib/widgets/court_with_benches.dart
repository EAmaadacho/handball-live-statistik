import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import 'bench.dart';
import 'court.dart';
import 'person_card.dart';

/// Court with both benches on the left, used by ticker and live page.
///
/// Tapping a player or official opens their card.
class CourtWithBenches extends StatelessWidget {
  const CourtWithBenches(
      {super.key, required this.state, this.onAddPlayer, this.benchWidth = 64});

  final GameState state;

  /// Only the ticker may register players late (S1.4).
  final void Function(Side side)? onAddPlayer;
  final double benchWidth;

  @override
  Widget build(BuildContext context) {
    Widget bench(Side side) => Bench(
          state: state,
          side: side,
          onAddPlayer: onAddPlayer == null ? null : () => onAddPlayer!(side),
          onPlayerTap: (id) => showPlayerCard(context, state, side, id),
          onOfficialTap: (o) => showOfficialCard(context, state, side, o),
        );

    return Row(
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
            onPlaceTap: (side, place) {
              final id = state.field[side]![place];
              if (id != null) {
                showPlayerCard(context, state, side, id);
              }
            },
          ),
        ),
      ],
    );
  }
}
