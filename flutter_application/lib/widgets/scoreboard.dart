import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../theme/app_theme.dart';
import 'format.dart';

/// The dark LED board on top of ticker and live page.
///
/// Example: TVM 14, HSG 12, "2. Halbzeit", 38:47, below HSG "8 1:22"
/// because Nico (8) sits out a penalty.
class Scoreboard extends StatelessWidget {
  const Scoreboard(
      {super.key, required this.state, this.onClockTap, this.large = false});

  final GameState state;

  /// Set on the ticker: tapping the clock starts or stops it (U1).
  /// Null on the live page, where the clock only shows the time.
  final VoidCallback? onClockTap;

  /// Bigger digits for the web layout, where the board spans a wide screen.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CourtColors>()!;
    final label = TextStyle(
      color: colors.onBoard.withValues(alpha: 0.65),
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.4,
    );
    return Container(
      key: const Key('Scoreboard'),
      color: colors.board,
      padding: large
          ? const EdgeInsets.fromLTRB(32, 18, 32, 12)
          : const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              child: _TeamColumn(state: state, side: Side.home, large: large)),
          InkWell(
            onTap: state.ended ? null : onClockTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Text(state.ended ? 'ENDE' : '${state.half}. HALBZEIT',
                      style: label),
                  Text(
                    formatClock(state.clockSeconds),
                    key: const Key('ScoreboardClock'),
                    style: TextStyle(
                      fontFamily: ledFontFamily,
                      fontWeight: FontWeight.w900,
                      fontSize: large ? 54 : 34,
                      height: 1,
                      color: colors.onBoard,
                    ),
                  ),
                  if (onClockTap != null && !state.ended)
                    Text(
                      state.clockRunning
                          ? 'LÄUFT · TIPPEN = STOPP'
                          : 'GESTOPPT · TIPPEN = START',
                      style: label.copyWith(
                          color: state.clockRunning
                              ? colors.onBoard
                              : colors.ledPenalty),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
              child: _TeamColumn(state: state, side: Side.away, large: large)),
        ],
      ),
    );
  }
}

class _TeamColumn extends StatelessWidget {
  const _TeamColumn(
      {required this.state, required this.side, this.large = false});

  final GameState state;
  final Side side;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CourtColors>()!;
    final team = state.game.team(side);
    final right = side == Side.away;
    final penalties = state.penalties.where((p) => p.side == side).toList();
    final led = TextStyle(
        fontFamily: ledFontFamily,
        fontWeight: FontWeight.w800,
        color: colors.ledPenalty,
        fontSize: 15);

    return Column(
      crossAxisAlignment:
          right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          team.shortName,
          style: TextStyle(
              color: colors.onBoard,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2),
        ),
        Text(
          '${state.goals[side]}',
          key: Key('ScoreboardGoals-${side.name}'),
          style: TextStyle(
            fontFamily: ledFontFamily,
            fontWeight: FontWeight.w900,
            fontSize: large ? 72 : 46,
            height: 0.95,
            color: colors.ledScore,
          ),
        ),
        const SizedBox(height: 4),
        // Wrap instead of Row: on a narrow board the dots may break the line.
        Wrap(
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      i < (state.timeouts[side] ?? 0) ? colors.onBoard : null,
                  border: Border.all(
                      color: colors.onBoard.withValues(alpha: 0.6), width: 1.5),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (final p in penalties)
          Text('${p.label} ${formatPenalty(p.secondsLeft)}', style: led),
      ],
    );
  }
}
