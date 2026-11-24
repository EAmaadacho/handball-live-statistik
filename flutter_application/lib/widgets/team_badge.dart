import 'package:material_ui/material_ui.dart';

import '../data/models.dart';

/// The club logo in a circle, or the short name, e.g. "TVM", when the team
/// has no logo, also for an opponent without registration (T6, T6.2).
class TeamBadge extends StatelessWidget {
  const TeamBadge(
      {super.key,
      required this.team,
      this.size = 40,
      this.color,
      this.onColor});

  final Team team;
  final double size;

  /// Background behind the short name; default is the primary color.
  final Color? color;

  /// Color of the short name on [color]; default fits the primary color.
  final Color? onColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final logo = team.logo;
    return Container(
      key: Key('TeamBadge-${team.id}'),
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: logo == null ? (color ?? scheme.primary) : Colors.white,
      ),
      alignment: Alignment.center,
      child: logo != null
          ? Image.memory(logo,
              key: const Key('TeamLogo'),
              width: size,
              height: size,
              fit: BoxFit.contain)
          : Text(
              team.shortName,
              style: TextStyle(
                color: onColor ?? scheme.onPrimary,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.3,
              ),
            ),
    );
  }
}
