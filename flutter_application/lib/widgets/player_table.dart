import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../theme/app_theme.dart';

const _rowHeight = 38.0;

/// Player statistics of one team like on handball.net (L2, L3), tab "Spieler".
///
/// On a phone the value columns scroll sideways; number and name stay in place.
/// Example row: "7  Max Mustermann | 5  7  71  2/2  1".
class PlayerTable extends StatelessWidget {
  const PlayerTable({super.key, required this.state, required this.side});

  final GameState state;
  final Side side;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CourtColors>()!;
    final team = state.game.team(side);
    final players = [...team.players]
      ..sort((a, b) => a.number.compareTo(b.number));
    // A field player who stood in goal also appears with their saves.
    bool keptGoal(Player p) =>
        p.isGoalkeeper ||
        state.statsOf(p.id).saves + state.statsOf(p.id).goalsAgainst > 0;
    final fieldPlayers = players.where((p) => !p.isGoalkeeper).toList();
    final goalkeepers = players.where(keptGoal).toList();
    final t = TeamTotals.of(state, side);
    String rate(int part, int all) =>
        all == 0 ? '–' : '${(part * 100 / all).round()}';

    Widget card(bool shown, Color color) => shown
        ? Container(width: 9, height: 13, color: color)
        : const SizedBox.shrink();
    Widget penalties(int n) => Text(n == 0 ? '' : '$n×');

    return Column(
      key: Key('PlayerTable-${side.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StickyTable(
          fixedHeaders: const ['Nr.', 'Spieler'],
          valueHeaders: const [
            'Tore',
            'Würfe',
            '%',
            '7 m',
            'TF',
            'G',
            '2′',
            'R'
          ],
          rows: [
            for (final p in fieldPlayers)
              () {
                final s = state.statsOf(p.id);
                return StickyRow(
                  fixed: ['${p.number}', '${p.firstName} ${p.lastName}'],
                  values: [
                    Text('${s.goals}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    Text('${s.shots}'),
                    Text(rate(s.goals, s.shots)),
                    Text(s.sevenMeterShots == 0
                        ? ''
                        : '${s.sevenMeterGoals}/${s.sevenMeterShots}'),
                    Text(s.technicalFaults == 0 ? '' : '${s.technicalFaults}'),
                    card(s.yellowCards > 0, colors.yellowCard),
                    penalties(s.twoMinutes),
                    card(s.redCards > 0, colors.redCard),
                  ],
                  dim: s.goals == 0,
                );
              }(),
            StickyRow(
              fixed: const ['', 'Team'],
              values: [
                Text('${t.goals}'),
                Text('${t.shots}'),
                Text(rate(t.goals, t.shots)),
                Text('${t.sevenMeterGoals}/${t.sevenMeterShots}'),
                Text('${t.technicalFaults}'),
                Text('${t.yellowCards}'),
                Text('${t.twoMinutes}'),
                Text('${t.redCards}'),
              ],
              bold: true,
            ),
          ],
        ),
        const SizedBox(height: 14),
        StickyTable(
          fixedHeaders: const ['Nr.', 'Torwart'],
          valueHeaders: const ['Paraden', 'Gegentore', 'Quote'],
          valueWidth: 84,
          rows: [
            for (final p in goalkeepers)
              () {
                final s = state.statsOf(p.id);
                final all = s.saves + s.goalsAgainst;
                return StickyRow(
                  fixed: ['${p.number}', '${p.firstName} ${p.lastName}'],
                  values: [
                    Text('${s.saves}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    Text('${s.goalsAgainst}'),
                    Text(all == 0 ? '–' : '${rate(s.saves, all)} %'),
                  ],
                  dim: all == 0,
                );
              }(),
          ],
        ),
        const SizedBox(height: 14),
        StickyTable(
          fixedHeaders: const ['', 'Offizielle'],
          valueHeaders: const ['G', '2′', 'R'],
          rows: [
            for (final o in team.officials)
              () {
                final c = state.cards['${side.name}:${o.letter}'];
                return StickyRow(
                  fixed: [o.letter, '${o.name}, ${o.role}'],
                  values: [
                    card(c == CardMark.yellow, colors.yellowCard),
                    const Text(''),
                    card(c == CardMark.red, colors.redCard)
                  ],
                );
              }(),
          ],
        ),
      ],
    );
  }
}

class StickyRow {
  const StickyRow(
      {required this.fixed,
      required this.values,
      this.dim = false,
      this.bold = false});

  final List<String> fixed;
  final List<Widget> values;
  final bool dim;
  final bool bold;
}

/// A table whose first two columns stay in place while the rest scrolls sideways.
class StickyTable extends StatelessWidget {
  const StickyTable(
      {super.key,
      required this.fixedHeaders,
      required this.valueHeaders,
      required this.rows,
      this.valueWidth = 64});

  final List<String> fixedHeaders;
  final List<String> valueHeaders;
  final List<StickyRow> rows;

  /// Width of each value column; wider for long headers like "Gegentore".
  final double valueWidth;

  static const _numberWidth = 34.0;
  static const _nameWidth = 150.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final line = BorderSide(color: theme.dividerTheme.color!);
    final headStyle = TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
        color: muted);

    TextStyle rowStyle(StickyRow r) => TextStyle(
          fontSize: 13,
          color: r.dim ? muted : theme.colorScheme.onSurface,
          fontWeight: r.bold ? FontWeight.w700 : FontWeight.w400,
          fontFeatures: const [FontFeature.tabularFigures()],
        );

    Widget cell(Widget child, double width,
            {bool left = false, Border? border}) =>
        Container(
          width: width,
          height: _rowHeight,
          alignment: left ? Alignment.centerLeft : Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(border: border ?? Border(bottom: line)),
          child: child,
        );

    final fixed = Column(
      children: [
        Row(
          children: [
            cell(Text(fixedHeaders[0].toUpperCase(), style: headStyle),
                _numberWidth,
                left: true),
            cell(Text(fixedHeaders[1].toUpperCase(), style: headStyle),
                _nameWidth,
                left: true, border: Border(bottom: line, right: line)),
          ],
        ),
        for (final r in rows)
          DefaultTextStyle(
            style: rowStyle(r),
            child: Row(
              children: [
                cell(Text(r.fixed[0]), _numberWidth, left: true),
                cell(
                  Text(r.fixed[1],
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  _nameWidth,
                  left: true,
                  border: Border(bottom: line, right: line),
                ),
              ],
            ),
          ),
      ],
    );

    final values = Column(
      children: [
        Row(children: [
          for (final h in valueHeaders)
            cell(Text(h.toUpperCase(), style: headStyle), valueWidth)
        ]),
        for (final r in rows)
          DefaultTextStyle(
            style: rowStyle(r),
            child:
                Row(children: [for (final v in r.values) cell(v, valueWidth)]),
          ),
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        fixed,
        Expanded(
            child: SingleChildScrollView(
                scrollDirection: Axis.horizontal, child: values)),
      ],
    );
  }
}
