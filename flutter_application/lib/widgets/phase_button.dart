import 'package:material_ui/material_ui.dart';

import '../data/models.dart';

/// "Halbzeit" or "Abpfiff" for the ticker, once the clock stands in the
/// last minute of a half (U5).
///
/// Example: the clock stopped by itself at 30:00 → "Halbzeit" ends the
/// first half; at 59:40 after the last throw → "Abpfiff" ends the game.
/// Shows nothing otherwise.
class PhaseButton extends StatelessWidget {
  const PhaseButton(
      {super.key,
      required this.state,
      required this.onHalfTime,
      required this.onEnd});

  final GameState state;
  final VoidCallback onHalfTime;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final inLastMinute =
        !state.clockRunning && state.clockSeconds >= state.halfEndSeconds - 60;
    final (label, onPressed) = switch (state.phase) {
      GamePhase.firstHalf when inLastMinute => ('Halbzeit', onHalfTime),
      GamePhase.secondHalf when inLastMinute => ('Abpfiff', onEnd),
      _ => (null, null),
    };
    if (label == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: FilledButton(
          key: const Key('PhaseButton'),
          onPressed: onPressed,
          child: Text(label)),
    );
  }
}
