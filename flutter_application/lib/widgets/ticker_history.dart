import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import 'format.dart';

/// Event history of the ticker with a delete button per event (E2).
///
/// Deleting asks first: "Tor · 7 Max Mustermann · 38:12 löschen?".
/// After the end of the game nothing can be deleted (R4.2): [onDelete] is null.
class TickerHistory extends StatelessWidget {
  const TickerHistory({super.key, required this.events, this.onDelete});

  final List<GameEvent> events;
  final void Function(GameEvent event)? onDelete;

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
      key: const Key('TickerHistory'),
      children: [
        for (final e in events)
          Container(
            padding: const EdgeInsets.only(left: 16, right: 4),
            decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: theme.dividerTheme.color!))),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text(formatClock(e.clockSeconds),
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: muted,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                ),
                Expanded(child: Text('${e.kind.label} · ${e.who}')),
                Text('${e.homeGoals}:${e.awayGoals}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                IconButton(
                  key: Key('Delete-${e.number}'),
                  tooltip: 'Löschen',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete == null
                      ? null
                      : () async {
                          if (await confirmDelete(context, e)) onDelete!(e);
                        },
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Asks before an event is deleted, because score and statistics change (E2.1).
Future<bool> confirmDelete(BuildContext context, GameEvent e) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Ereignis löschen?'),
      content:
          Text('${e.kind.label} · ${e.who} · ${formatClock(e.clockSeconds)}'
              '\n\nSpielstand und Statistik werden neu berechnet.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen')),
        FilledButton(
            key: const Key('ConfirmDelete'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Löschen')),
      ],
    ),
  );
  return yes ?? false;
}
