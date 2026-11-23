import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../theme/app_theme.dart';
import 'format.dart';

/// Players of the match report per team (IHF rule 4:1, S1.4).
const maxPlayers = 16;

/// Officials A to D per team (IHF rule 4:2, E6).
const maxOfficials = 4;

/// The bench of one team next to the court: substitutes, officials, penalties.
///
/// Example for TV Mettmann: Tom (9), Erik (15), Mia (16, goalkeeper),
/// officials A, B, C and "10/16 Sp. · 3/4 Off.".
class Bench extends StatelessWidget {
  const Bench({
    super.key,
    required this.state,
    required this.side,
    this.onPlayerTap,
    this.onOfficialTap,
    this.onAddPlayer,
  });

  final GameState state;
  final Side side;
  final void Function(String playerId)? onPlayerTap;
  final void Function(Official official)? onOfficialTap;

  /// Late registration (S1.4). Hidden when 16 players are on the match report.
  final VoidCallback? onAddPlayer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<CourtColors>()!;
    final team = state.game.team(side);
    final muted = theme.colorScheme.onSurfaceVariant;
    final small = TextStyle(
        fontSize: 8,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
        color: muted);
    final onReport = state.reportOf(side).length;

    return Container(
      key: Key('Bench-${side.name}'),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(6),
        border: Border(
            left: BorderSide(color: theme.dividerTheme.color!, width: 3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('BANK ${team.shortName}', style: small),
          for (final p in state.penalties.where((p) => p.side == side))
            Text(
              '${p.label} ${formatPenalty(p.secondsLeft)}',
              style: TextStyle(
                  fontFamily: ledFontFamily,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: colors.penaltyText),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 5,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final id in state.bench[side]!)
                _Seat(
                  key: Key('BenchPlayer-$id'),
                  label: '${team.player(id).number}',
                  side: side,
                  isGoalkeeper: team.player(id).isGoalkeeper,
                  card: state.cards[id],
                  semantics:
                      'Bank: Nr. ${team.player(id).number} ${team.player(id).firstName}',
                  onTap: onPlayerTap == null ? null : () => onPlayerTap!(id),
                ),
              if (onAddPlayer != null && onReport < maxPlayers && !state.ended)
                _Seat(
                  key: Key('BenchAdd-${side.name}'),
                  label: '+',
                  side: side,
                  add: true,
                  semantics: 'Spieler nachmelden',
                  onTap: onAddPlayer,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Divider(color: theme.dividerTheme.color),
          const SizedBox(height: 4),
          Text('OFFIZIELLE', style: small),
          const SizedBox(height: 4),
          Wrap(
            spacing: 5,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final o in team.officials)
                _Seat(
                  key: Key('BenchOfficial-${side.name}-${o.letter}'),
                  label: o.letter,
                  side: side,
                  official: true,
                  card: state.cards['${side.name}:${o.letter}'],
                  semantics: 'Offizielle ${o.letter}: ${o.name}',
                  onTap: onOfficialTap == null ? null : () => onOfficialTap!(o),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$onReport/$maxPlayers Sp.\n${team.officials.length}/$maxOfficials Off.',
            key: Key('BenchCount-${side.name}'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 9, color: muted, height: 1.2),
          ),
        ],
      ),
    );
  }
}

class _Seat extends StatelessWidget {
  const _Seat({
    super.key,
    required this.label,
    required this.side,
    required this.semantics,
    this.isGoalkeeper = false,
    this.official = false,
    this.add = false,
    this.card,
    this.onTap,
  });

  final String label;
  final Side side;
  final String semantics;
  final bool isGoalkeeper;
  final bool official;
  final bool add;
  final CardMark? card;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<CourtColors>()!;
    final fill = side == Side.home ? colors.home : colors.away;
    final onFill = side == Side.home ? colors.onHome : colors.onAway;
    final filled = !official && !add && !isGoalkeeper;
    final ring = add
        ? theme.colorScheme.primary
        : official
            ? theme.colorScheme.onSurfaceVariant
            : fill;

    return Semantics(
      button: onTap != null,
      label: semantics,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: official ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: official ? BorderRadius.circular(5) : null,
                color: filled ? fill : null,
                border: filled
                    ? null
                    : Border.all(color: ring, width: official ? 1.5 : 2),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: add ? 15 : 11,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: filled
                      ? onFill
                      : (official ? theme.colorScheme.onSurface : ring),
                ),
              ),
            ),
            if (card != null)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  width: 7,
                  height: 10,
                  decoration: BoxDecoration(
                    color: card == CardMark.yellow
                        ? colors.yellowCard
                        : colors.redCard,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
