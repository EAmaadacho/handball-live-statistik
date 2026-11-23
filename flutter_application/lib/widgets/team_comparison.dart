import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../theme/app_theme.dart';

/// Both teams side by side with bars (L7), tab "Spiel" on the live page.
///
/// Example row: "14   Tore   12" with a red bar left and a dark bar right.
class TeamComparison extends StatelessWidget {
  const TeamComparison({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<CourtColors>()!;
    final muted = theme.colorScheme.onSurfaceVariant;
    final h = TeamTotals.of(state, Side.home);
    final a = TeamTotals.of(state, Side.away);
    int rate(TeamTotals t) =>
        t.shots == 0 ? 0 : (t.goals * 100 / t.shots).round();

    final rows = <(String, int, int, String?, String?)>[
      ('Tore', h.goals, a.goals, null, null),
      ('Würfe', h.shots, a.shots, null, null),
      ('Wurfquote', rate(h), rate(a), '${rate(h)} %', '${rate(a)} %'),
      (
        '7-Meter',
        h.sevenMeterGoals,
        a.sevenMeterGoals,
        '${h.sevenMeterGoals}/${h.sevenMeterShots}',
        '${a.sevenMeterGoals}/${a.sevenMeterShots}'
      ),
      ('Paraden', h.saves, a.saves, null, null),
      ('Techn. Fehler', h.technicalFaults, a.technicalFaults, null, null),
      ('Gelbe Karten', h.yellowCards, a.yellowCards, null, null),
      ('Zeitstrafen', h.twoMinutes, a.twoMinutes, null, null),
      ('Rote Karten', h.redCards, a.redCards, null, null),
      ('Auszeiten', h.timeouts, a.timeouts, null, null),
    ];

    final head = TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: muted);
    return Padding(
      key: const Key('TeamComparison'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(state.game.home.shortName, style: head),
                if (state.halftimeScore != null)
                  Text('Halbzeit ${state.halftimeScore}', style: head),
                Text(state.game.away.shortName, style: head),
              ],
            ),
          ),
          for (final (label, x, y, xText, yText) in rows)
            Container(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: theme.dividerTheme.color!))),
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(
                          width: 64,
                          child: Text(xText ?? '$x',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700))),
                      Expanded(
                          child: Text(label,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: muted))),
                      SizedBox(
                        width: 64,
                        child: Text(yText ?? '$y',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 4,
                    child: Row(
                      children: [
                        if (x > 0)
                          Expanded(
                              flex: x, child: ColoredBox(color: colors.home)),
                        if (x > 0 && y > 0) const SizedBox(width: 3),
                        if (y > 0)
                          Expanded(
                              flex: y, child: ColoredBox(color: colors.away)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
