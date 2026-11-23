import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../data/ticker_rules.dart';
import 'person_card.dart';

/// What the ticker chose on a player's card: an event, a substitution or
/// "Ins Tor" (a field player becomes goalkeeper, IHF rule 4:7).
class TickerChoice {
  const TickerChoice.event(EventKind this.kind) : intoGoal = false;
  const TickerChoice.substitute()
      : kind = null,
        intoGoal = false;
  const TickerChoice.intoGoal()
      : kind = null,
        intoGoal = true;

  /// Null = substitute this player or put them in goal.
  final EventKind? kind;
  final bool intoGoal;
}

/// Events for a player on the field, in the order of the buttons (E1).
const fieldActions = [
  EventKind.goal,
  EventKind.miss,
  EventKind.save,
  EventKind.sevenMeterGoal,
  EventKind.sevenMeterMiss,
  EventKind.technicalFault,
  EventKind.yellowCard,
  EventKind.twoMinutes,
  EventKind.redCard,
];

/// Players on the bench only get cards and penalties (R7).
const benchActions = [
  EventKind.yellowCard,
  EventKind.twoMinutes,
  EventKind.redCard
];

/// Opens the card of a player with the ticker's actions below it.
///
/// Example: tapping Max shows his card and "Tor", "Fehlwurf", … "Wechseln".
Future<TickerChoice?> showActionSheet(
        BuildContext context, GameState state, Side side, String playerId) =>
    showModalBottomSheet<TickerChoice>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 520),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PersonCard.player(state: state, side: side, playerId: playerId),
              ActionButtons(state: state, side: side, playerId: playerId),
            ],
          ),
        ),
      ),
    );

/// The buttons under the person card. A greyed out button says why below (R1–R7).
class ActionButtons extends StatelessWidget {
  const ActionButtons(
      {super.key,
      required this.state,
      required this.side,
      required this.playerId});

  final GameState state;
  final Side side;
  final String playerId;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final onField = state.onField(side).contains(playerId);
    final kinds = onField ? fieldActions : benchActions;
    final blocked = <(String, String)>[]; // (label, reason)

    // Three buttons per row; only "Tor" is filled, it is used most.
    Widget button(String label, String? reason, TickerChoice choice,
        {bool main = false}) {
      if (reason != null) blocked.add((label, reason));
      final onPressed =
          reason == null ? () => Navigator.of(context).pop(choice) : null;
      const style = ButtonStyle(
          padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4)));
      final child = Text(label, maxLines: 1, softWrap: false);
      return main
          ? FilledButton(
              key: Key('Action-$label'),
              style: style,
              onPressed: onPressed,
              child: child)
          : OutlinedButton(
              key: Key('Action-$label'),
              style: style,
              onPressed: onPressed,
              child: child);
    }

    final buttons = [
      for (final kind in kinds)
        button(kind.label, eventBlockReason(state, kind, side, playerId),
            TickerChoice.event(kind),
            main: kind == EventKind.goal),
      button(
        onField ? 'Wechseln' : 'Einwechseln',
        gameNotRunningReason(state),
        const TickerChoice.substitute(),
      ),
      // Only offered while the goal is empty (E5.6).
      if (onField && state.goalkeeperOf(side) == null)
        button('Ins Tor', gameNotRunningReason(state),
            const TickerChoice.intoGoal()),
    ];

    // One line when everything is blocked for the same reason, e.g. the
    // game has not started; otherwise one line per button.
    final sameForAll = blocked.length == buttons.length &&
        blocked.every((b) => b.$2 == blocked.first.$2);
    final reasons = sameForAll
        ? [blocked.first.$2]
        : [for (final (label, reason) in blocked) '$label: $reason'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, box) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final b in buttons)
                  SizedBox(width: (box.maxWidth - 16) / 3, child: b),
              ],
            ),
          ),
          for (final reason in reasons)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(reason,
                  key: const Key('ActionBlockReason'),
                  style: TextStyle(color: muted, fontSize: 13)),
            ),
        ],
      ),
    );
  }
}
