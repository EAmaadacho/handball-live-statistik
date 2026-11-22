import 'package:material_ui/material_ui.dart';

import '../data/models.dart';

/// Two buttons to choose a team, e.g. for the player table.
class TeamSwitch extends StatelessWidget {
  const TeamSwitch(
      {super.key,
      required this.state,
      required this.selected,
      required this.onSelect});

  final GameState state;
  final Side selected;
  final void Function(Side) onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerTheme.color!)),
      child: Row(
        children: [
          for (final side in Side.values)
            Expanded(
              child: InkWell(
                key: Key('TeamSwitch-${side.name}'),
                onTap: () => onSelect(side),
                child: Container(
                  color: side == selected ? scheme.onSurface : null,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  child: Text(
                    state.game.team(side).name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: side == selected
                          ? scheme.surface
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
