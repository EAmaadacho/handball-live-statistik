import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../theme/app_theme.dart';
import 'format.dart';

/// "Verbindung unterbrochen" with the last known state (L1.1).
class OfflineNotice extends StatelessWidget {
  const OfflineNotice({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('OfflineNotice'),
      color: scheme.onSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        'Verbindung unterbrochen. Du siehst den letzten Stand von ${formatClock(state.clockSeconds)}. '
        'Die Seite lädt von selbst neu, sobald die Verbindung wieder da ist.',
        style: TextStyle(
            color: scheme.surface, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}

/// One line per running penalty, e.g. "HSG Hilden in Unterzahl · Nr. 8 1:22" (L3.3).
class ShortHandedLines extends StatelessWidget {
  const ShortHandedLines({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    if (state.penalties.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colors = theme.extension<CourtColors>()!;
    return Container(
      color: theme.colorScheme.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final p in state.penalties)
            Text(
              '${state.game.team(p.side).name} in Unterzahl · '
              '${int.tryParse(p.label) != null ? 'Nr. ${p.label}' : 'Offizielle ${p.label}'} ${formatPenalty(p.secondsLeft)}',
              style: TextStyle(
                  color: colors.penaltyText,
                  fontWeight: FontWeight.w600,
                  fontSize: 14),
            ),
        ],
      ),
    );
  }
}
