import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../data/ticker_rules.dart';

/// Timeout buttons for both teams and the button for the history (U3, R1, E2).
///
/// A greyed out timeout button says why below,
/// e.g. "HSG Hilden hat keine Auszeit mehr."
class TickerControls extends StatelessWidget {
  const TickerControls(
      {super.key,
      required this.state,
      required this.onTimeout,
      this.onHistory});

  final GameState state;
  final void Function(Side side) onTimeout;

  /// Null when the history is shown next to the court anyway (web).
  final VoidCallback? onHistory;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    Widget timeout(Side side) {
      final reason = timeoutBlockReason(state, side);
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton(
              key: Key('Timeout-${side.name}'),
              style: _compact,
              onPressed: reason == null ? () => onTimeout(side) : null,
              child: Text('Auszeit ${state.game.team(side).shortName}'),
            ),
            if (reason != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(reason,
                    key: Key('TimeoutReason-${side.name}'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: muted)),
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          timeout(Side.home),
          const SizedBox(width: 8),
          if (onHistory != null) ...[
            OutlinedButton(
                key: const Key('HistoryButton'),
                style: _compact,
                onPressed: onHistory,
                child: const Text('Verlauf')),
            const SizedBox(width: 8),
          ],
          timeout(Side.away),
        ],
      ),
    );
  }
}

/// Fits three buttons next to each other on a phone held sideways.
final _compact = OutlinedButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600));

/// Shown while a substitution waits for its second tap (E5.2), e.g.
/// "7 Max raus: Bankspieler von TVM antippen".
class SwapBanner extends StatelessWidget {
  const SwapBanner({super.key, required this.text, required this.onCancel});

  final String text;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('SwapBanner'),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600))),
          TextButton(onPressed: onCancel, child: const Text('Abbrechen')),
        ],
      ),
    );
  }
}
