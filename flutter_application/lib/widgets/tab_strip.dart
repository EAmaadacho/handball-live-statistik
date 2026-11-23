import 'package:material_ui/material_ui.dart';

/// Row of tabs with an underline below the selected one.
///
/// Example: VERLAUF  FELD  SPIEL  SPIELER on the live page.
class TabStrip<T> extends StatelessWidget {
  const TabStrip(
      {super.key,
      required this.tabs,
      required this.selected,
      required this.onSelect});

  final List<(T, String)> tabs;
  final T selected;
  final void Function(T) onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
          border: Border(
              bottom:
                  BorderSide(color: Theme.of(context).dividerTheme.color!))),
      // Scrolls sideways if the tabs do not fit, e.g. with large system fonts.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (t, label) in tabs)
              Semantics(
                selected: t == selected,
                button: true,
                child: InkWell(
                  key: Key('Tab-$label'),
                  onTap: () => onSelect(t),
                  child: Container(
                    margin: const EdgeInsets.only(right: 20),
                    padding: const EdgeInsets.only(top: 14, bottom: 11),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                            color: t == selected
                                ? scheme.primary
                                : Colors.transparent,
                            width: 3),
                      ),
                    ),
                    child: Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: t == selected
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
