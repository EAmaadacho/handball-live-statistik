import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/game_source.dart';
import '../data/models.dart';
import '../widgets/court_with_benches.dart';
import '../widgets/scoreboard.dart';

/// Ticker page (E1, E5, U1–U3).
///
/// So far it puts the building blocks together: scoreboard, both benches
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
                    child: Align(
                      alignment: Alignment.topCenter,
                      child:
                          CourtWithBenches(state: state, onAddPlayer: (_) {}),
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
