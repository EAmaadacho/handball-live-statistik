import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../theme/app_theme.dart';
import 'court.dart' show fieldPlaces;
import 'format.dart';

/// Opens the card of a tapped player, e.g. Max on the court or Tom on the bench.
Future<void> showPlayerCard(
        BuildContext context, GameState state, Side side, String playerId) =>
    _showCard(context,
        PersonCard.player(state: state, side: side, playerId: playerId));

/// Opens the card of a tapped official, e.g. A Sven Krause.
Future<void> showOfficialCard(
        BuildContext context, GameState state, Side side, Official official) =>
    _showCard(context,
        PersonCard.official(state: state, side: side, official: official));

Future<void> _showCard(BuildContext context, Widget card) =>
    showModalBottomSheet<void>(
      context: context,
      constraints: const BoxConstraints(maxWidth: 480),
      builder: (context) => SafeArea(child: card),
    );

/// Card with what matters about one person in this game.
///
/// Example for Max: "7 Max Mustermann · TV Mettmann · Feldspieler",
/// "Auf dem Feld · RM", 5 goals from 7 shots (71 %), 7 m 2/2,
/// 1 technical fault, penalties: none.
class PersonCard extends StatelessWidget {
  const PersonCard.player(
      {super.key,
      required this.state,
      required this.side,
      required String this.playerId})
      : official = null;

  const PersonCard.official(
      {super.key,
      required this.state,
      required this.side,
      required Official this.official})
      : playerId = null;

  final GameState state;
  final Side side;
  final String? playerId;
  final Official? official;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<CourtColors>()!;
    final team = state.game.team(side);
    final muted = theme.colorScheme.onSurfaceVariant;
    final fill = side == Side.home ? colors.home : colors.away;
    final onFill = side == Side.home ? colors.onHome : colors.onAway;

    final Widget badge;
    final String name;
    final String subtitle;
    final String status;
    final List<(String, String)> values;
    final String penalties;

    if (official case final o?) {
      final card = state.cards['${side.name}:${o.letter}'];
      final penalty = _penaltyOf(o.letter);
      badge = _Badge(label: o.letter, color: muted, square: true);
      name = o.name;
      subtitle = '${team.name} · ${o.role}';
      status = card == CardMark.red
          ? 'Disqualifiziert, darf nicht mehr an die Bank'
          : penalty != null
              ? 'Zeitstrafe, noch ${formatPenalty(penalty.secondsLeft)}'
              : 'Offizielle ${o.letter} an der Bank';
      values = const [];
      penalties = card == CardMark.yellow
          ? 'Gelb'
          : card == CardMark.red
              ? 'Rot'
              : 'keine';
    } else {
      final p = team.player(playerId!);
      final s = state.statsOf(p.id);
      badge = p.isGoalkeeper
          ? _Badge(label: '${p.number}', color: fill, ring: true)
          : _Badge(label: '${p.number}', color: fill, textColor: onFill);
      name = '${p.firstName} ${p.lastName}';
      subtitle = '${team.name} · ${p.isGoalkeeper ? 'Torwart' : 'Feldspieler'}';
      status = _playerStatus(p, s);
      values = p.isGoalkeeper
          ? [
              ('${s.saves}', 'Paraden'),
              ('${s.goalsAgainst}', 'Gegentore'),
              (_percent(s.saves, s.saves + s.goalsAgainst), 'Quote')
            ]
          : [
              ('${s.goals}', 'Tore'),
              ('${s.shots}', 'Würfe'),
              (_percent(s.goals, s.shots), 'Quote'),
              (
                s.sevenMeterShots == 0
                    ? '–'
                    : '${s.sevenMeterGoals}/${s.sevenMeterShots}',
                '7 m'
              ),
              (
                s.technicalFaults == 0 ? '–' : '${s.technicalFaults}',
                'Techn. F.'
              ),
            ];
      penalties = [
        if (s.yellowCards > 0) 'Gelb',
        if (s.twoMinutes > 0) '${s.twoMinutes}× 2 Min',
        if (s.redCards > 0) 'Rot',
      ].join(', ');
    }

    return Padding(
      key: const Key('PersonCard'),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              badge,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text(subtitle,
                        style: TextStyle(color: muted, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(status,
              key: const Key('PersonCardStatus'),
              style: const TextStyle(fontWeight: FontWeight.w600)),
          if (values.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 10),
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                for (final (value, label) in values)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(value,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              height: 1)),
                      Text(label.toUpperCase(),
                          style: TextStyle(
                              fontSize: 10, letterSpacing: 0.8, color: muted)),
                    ],
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 10),
          Text('Strafen: ${penalties.isEmpty ? 'keine' : penalties}',
              style: TextStyle(color: muted, fontSize: 13)),
        ],
      ),
    );
  }

  Penalty? _penaltyOf(String label) {
    for (final p in state.penalties) {
      if (p.side == side && p.label == label) return p;
    }
    return null;
  }

  String _playerStatus(Player p, PlayerStats s) {
    if (s.redCards > 0 || state.cards[p.id] == CardMark.red) {
      return 'Disqualifiziert';
    }
    final penalty = _penaltyOf('${p.number}');
    if (penalty != null) {
      return 'Zeitstrafe, noch ${formatPenalty(penalty.secondsLeft)}';
    }
    final place = state.field[side]!.indexOf(p.id);
    if (place >= 0) return 'Auf dem Feld · ${fieldPlaces[place]}';
    return 'Auf der Bank';
  }

  static String _percent(int part, int all) =>
      all == 0 ? '–' : '${(part * 100 / all).round()} %';
}

class _Badge extends StatelessWidget {
  const _Badge(
      {required this.label,
      required this.color,
      this.textColor,
      this.ring = false,
      this.square = false});

  final String label;
  final Color color;
  final Color? textColor;
  final bool ring;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final outline = ring || square;
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: square ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: square ? BorderRadius.circular(6) : null,
        color: outline ? null : color,
        border: outline ? Border.all(color: color, width: 2.5) : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: outline
              ? (square ? Theme.of(context).colorScheme.onSurface : color)
              : textColor,
        ),
      ),
    );
  }
}
