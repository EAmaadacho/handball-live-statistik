import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import 'format.dart';

/// Event history for spectators, newest on top (L1).
///
/// Example row: "38:12   Tor · 7 Max Mustermann   14:12".
class EventFeed extends StatelessWidget {
  const EventFeed({super.key, required this.events});

  final List<GameEvent> events;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    if (events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Noch keine Ereignisse.', style: TextStyle(color: muted)),
      );
    }
    return Column(
      key: const Key('EventFeed'),
      children: [
        for (final e in events)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: theme.dividerTheme.color!))),
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  child: Text(
                    formatClock(e.clockSeconds),
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: muted,
                        fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                            text: e.kind.label,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        TextSpan(text: ' · ${e.who}'),
                      ],
                    ),
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                Text(
                  '${e.homeGoals}:${e.awayGoals}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
