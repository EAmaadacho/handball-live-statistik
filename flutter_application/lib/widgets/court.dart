import 'dart:ui' show PathMetric;

import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../theme/app_theme.dart';
import 'player_circle.dart';
import 'team_badge.dart';

/// Short names of the seven places, in the order of [GameState.field].
const fieldPlaces = ['TH', 'LA', 'RL', 'RM', 'KL', 'RR', 'RA'];

/// Where the home team's places sit on the court (200 × 280 units, own goal at the bottom).
const _homePositions = [
  Offset(100, 262), // TH
  Offset(18, 246), // LA
  Offset(44, 203), // RL
  Offset(82, 190), // RM
  Offset(118, 190), // KL
  Offset(156, 203), // RR
  Offset(182, 246), // RA
];

/// The court is 200 × 280 units; around it is room for the goals.
const _view = Rect.fromLTWH(-4, -10, 208, 300);

/// Position of [place] for [side]. The guest team is the home team turned around.
Offset placePosition(Side side, int place) {
  final p = _homePositions[place];
  return side == Side.home ? p : Offset(200 - p.dx, 280 - p.dy);
}

/// The court upright: home team at the bottom, guest team at the top (E5).
///
/// Example: Nora (1) stands in the home goal at the bottom,
/// Lukas (1) in the guest goal at the top.
class Court extends StatelessWidget {
  const Court({super.key, required this.state, this.selected, this.onPlaceTap});

  final GameState state;

  /// The place that is tapped right now, e.g. (Side.home, 2).
  final (Side, int)? selected;

  /// Called with team and place when a circle is tapped. Null = only show.
  final void Function(Side side, int place)? onPlaceTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CourtColors>()!;
    return AspectRatio(
      aspectRatio: _view.width / _view.height,
      child: LayoutBuilder(
        builder: (context, box) {
          final scale = box.maxWidth / _view.width;
          final circle = box.maxWidth * 0.1;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                  child: CustomPaint(painter: CourtPainter(colors))),
              for (final side in Side.values)
                _watermark(colors, side, scale, box.maxWidth * 0.36),
              for (final side in Side.values)
                for (var place = 0; place < 7; place++)
                  _placed(
                    context,
                    colors,
                    side,
                    place,
                    (placePosition(side, place) - _view.topLeft) * scale,
                    circle,
                  ),
            ],
          );
        },
      ),
    );
  }

  /// The team circle large and faded in the middle of the team's half,
  /// e.g. the TV Mettmann logo at the bottom (T6). Taps go through it.
  Widget _watermark(CourtColors colors, Side side, double scale, double size) {
    final middle = Offset(100, side == Side.home ? 210 : 70);
    final center = (middle - _view.topLeft) * scale;
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      child: IgnorePointer(
        child: Opacity(
          key: Key('CourtBadge-${side.name}'),
          opacity: 0.15,
          child: TeamBadge(
              team: state.game.team(side),
              size: size,
              color: side == Side.home ? colors.home : colors.away,
              onColor: side == Side.home ? colors.onHome : colors.onAway),
        ),
      ),
    );
  }

  Widget _placed(BuildContext context, CourtColors colors, Side side, int place,
      Offset center, double size) {
    final id = state.field[side]![place];
    final team = state.game.team(side);
    final player = id == null ? null : team.player(id);
    return Positioned(
      left: center.dx - size,
      top: center.dy - size / 2 - 5, // 5 = selection ring around the circle
      width: size * 2,
      child: PlayerCircle(
        key: Key('Court-${side.name}-$place'),
        size: size,
        side: side,
        number: player?.number,
        name: player?.firstName,
        emptyLabel: fieldPlaces[place],
        // Whoever is in goal in this game, e.g. Max with a goalkeeper shirt.
        isGoalkeeper: id != null && state.goalkeeperOf(side) == id,
        selected: selected == (side, place),
        nameColor: colors.lines,
        onTap: onPlaceTap == null ? null : () => onPlaceTap!(side, place),
      ),
    );
  }
}

/// Draws lines and areas of a handball court (40 × 20 m, scaled).
class CourtPainter extends CustomPainter {
  const CourtPainter(this.colors);

  final CourtColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _view.width;
    canvas.save();
    canvas.scale(scale);
    canvas.translate(-_view.left, -_view.top);

    final line = Paint()
      ..color = colors.lines
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawRect(
        const Rect.fromLTWH(0, 0, 200, 280), Paint()..color = colors.court);

    for (final bottom in [true, false]) {
      canvas.save();
      if (!bottom) {
        // The upper half is the lower half mirrored at the centre line.
        canvas.translate(0, 280);
        canvas.scale(1, -1);
      }
      _half(canvas, line);
      canvas.restore();
    }

    canvas.drawLine(const Offset(0, 140), const Offset(200, 140), line);
    canvas.drawRect(
        const Rect.fromLTWH(0, 0, 200, 280), line..strokeWidth = 1.6);
    canvas.restore();
  }

  /// Goal area (6 m), free-throw line (9 m, dashed), 7 m line, 4 m line, goal.
  void _half(Canvas canvas, Paint line) {
    final goalArea = Path()
      ..moveTo(25, 280)
      ..arcToPoint(const Offset(85, 220), radius: const Radius.circular(60))
      ..lineTo(115, 220)
      ..arcToPoint(const Offset(175, 280), radius: const Radius.circular(60));
    canvas.drawPath(goalArea, Paint()..color = colors.goalArea);
    canvas.drawPath(goalArea, line);

    final freeThrow = Path()
      ..moveTo(0, 250.42)
      ..arcToPoint(const Offset(85, 190), radius: const Radius.circular(90))
      ..lineTo(115, 190)
      ..arcToPoint(const Offset(200, 250.42),
          radius: const Radius.circular(90));
    _dashed(canvas, freeThrow, line..strokeWidth = 1.2);

    line.strokeWidth = 1.4;
    canvas.drawLine(const Offset(95, 210), const Offset(105, 210), line);
    canvas.drawLine(const Offset(98.5, 240), const Offset(101.5, 240), line);
    canvas.drawRect(
        const Rect.fromLTWH(85, 280, 30, 7), line..strokeWidth = 1.6);
  }

  void _dashed(Canvas canvas, Path path, Paint paint) {
    for (final PathMetric metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 8) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(CourtPainter oldDelegate) => oldDelegate.colors != colors;
}
