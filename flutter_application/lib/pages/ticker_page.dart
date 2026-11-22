import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/game_source.dart';
import '../data/models.dart';
import '../widgets/bench.dart';
import '../widgets/court.dart';
import '../widgets/person_card.dart';
import '../widgets/scoreboard.dart';

/// Ticker page (E1, E5, U1–U3).
///
/// Step 2 puts the building blocks together: scoreboard, both benches
/// and the court. Tapping a person opens their card. Actions and the
/// layouts for landscape and web follow in step 4.
class TickerPage extends StatelessWidget {
  const TickerPage({super.key, required this.gameId});

  final int gameId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<GameState?>(
          future: context.read<GameSource>().loadState(gameId),
          builder: (context, snapshot) {
            final state = snapshot.data;
            if (state == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return Column(
              children: [
                Scoreboard(state: state, onClockTap: () {}),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 64,
                          // Scrolls on short screens instead of overflowing.
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                Bench(
                                    state: state,
                                    side: Side.away,
                                    onAddPlayer: () {},
                                    onPlayerTap: (id) => showPlayerCard(
                                        context, state, Side.away, id),
                                    onOfficialTap: (o) => showOfficialCard(
                                        context, state, Side.away, o)),
                                const SizedBox(height: 8),
                                Bench(
                                    state: state,
                                    side: Side.home,
                                    onAddPlayer: () {},
                                    onPlayerTap: (id) => showPlayerCard(
                                        context, state, Side.home, id),
                                    onOfficialTap: (o) => showOfficialCard(
                                        context, state, Side.home, o)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Align(
                              alignment: Alignment.topCenter,
                              child: Court(
                                  state: state,
                                  onPlaceTap: (side, place) {
                                    final id = state.field[side]![place];
                                    if (id != null) {
                                      showPlayerCard(context, state, side, id);
                                    }
                                  })),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
