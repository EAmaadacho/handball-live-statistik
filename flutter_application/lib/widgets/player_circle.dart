import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../theme/app_theme.dart';

/// A player as a circle with the shirt number, the first name below.
///
/// Goalkeepers are a ring instead of a filled circle. An empty place
/// shows its short name (e.g. "KL") as a thin ring.
class PlayerCircle extends StatelessWidget {
  const PlayerCircle({
    super.key,
    required this.size,
    required this.side,
    this.number,
    this.name,
    this.emptyLabel = '',
    this.isGoalkeeper = false,
    this.selected = false,
    this.nameColor,
    this.onTap,
  });

  final double size;
  final Side side;

  /// Null = empty place.
  final int? number;
  final String? name;
  final String emptyLabel;
  final bool isGoalkeeper;
  final bool selected;
  final Color? nameColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<CourtColors>()!;
    final fill = side == Side.home ? colors.home : colors.away;
    final onFill = side == Side.home ? colors.onHome : colors.onAway;
    final empty = number == null;

    final circle = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: empty ? null : (isGoalkeeper ? Colors.white : fill),
        border: empty
            ? Border.all(color: colors.lines.withValues(alpha: 0.6), width: 1.5)
            : isGoalkeeper
                ? Border.all(color: fill, width: 2.5)
                : null,
      ),
      child: Text(
        empty ? emptyLabel : '$number',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: size * (empty ? 0.32 : 0.42),
          height: 1,
          color: empty
              ? colors.lines.withValues(alpha: 0.7)
              : (isGoalkeeper ? fill : onFill),
        ),
      ),
    );

    return Semantics(
      button: onTap != null,
      selected: selected,
      label: empty ? 'Platz $emptyLabel frei' : 'Nr. $number $name',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: selected ? 1.12 : 1,
              duration: const Duration(milliseconds: 120),
              child: Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: selected
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      width: 2.5),
                ),
                child: circle,
              ),
            ),
            Text(
              empty ? ' ' : (name ?? ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: size * 0.3,
                  fontWeight: FontWeight.w600,
                  color: nameColor,
                  height: 1.1),
            ),
          ],
        ),
      ),
    );
  }
}
