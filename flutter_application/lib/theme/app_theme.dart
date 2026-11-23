import 'package:material_ui/material_ui.dart';

/// Font for score, clock and penalty times (LED look of a hall scoreboard).
const ledFontFamily = 'Doto';

/// Colors of the court and the scoreboard that [ColorScheme] has no slot for.
///
/// Example: the home team's circles are drawn in [home] with the number
/// in [onHome], so Max (7) is a red circle with a white 7.
@immutable
class CourtColors extends ThemeExtension<CourtColors> {
  const CourtColors({
    required this.court,
    required this.goalArea,
    required this.lines,
    required this.home,
    required this.onHome,
    required this.away,
    required this.onAway,
    required this.board,
    required this.onBoard,
    required this.ledScore,
    required this.ledPenalty,
    required this.penaltyText,
    required this.yellowCard,
    required this.redCard,
  });

  /// Theme "Halle": light page, blue court, orange goal area, dark scoreboard.
  static const hall = CourtColors(
    court: Color(0xFF3D86D8),
    goalArea: Color(0xFFF2A541),
    lines: Color(0xFFFFFFFF),
    home: Color(0xFFD21F3C),
    onHome: Color(0xFFFFFFFF),
    away: Color(0xFF1F2630),
    onAway: Color(0xFFFFFFFF),
    board: Color(0xFF16191F),
    onBoard: Color(0xFFFFFFFF),
    ledScore: Color(0xFFFF4A3D),
    ledPenalty: Color(0xFFFFC400),
    penaltyText: Color(0xFF9A5B00),
    yellowCard: Color(0xFFF6C800),
    redCard: Color(0xFFE0202A),
  );

  final Color court;
  final Color goalArea;
  final Color lines;
  final Color home;
  final Color onHome;
  final Color away;
  final Color onAway;

  /// Background of the scoreboard, the only dark area of the app.
  final Color board;
  final Color onBoard;
  final Color ledScore;

  /// Penalty times on the dark scoreboard.
  final Color ledPenalty;

  /// Penalty times on light backgrounds (yellow would not be readable there).
  final Color penaltyText;
  final Color yellowCard;
  final Color redCard;

  @override
  CourtColors copyWith({
    Color? court,
    Color? goalArea,
    Color? lines,
    Color? home,
    Color? onHome,
    Color? away,
    Color? onAway,
    Color? board,
    Color? onBoard,
    Color? ledScore,
    Color? ledPenalty,
    Color? penaltyText,
    Color? yellowCard,
    Color? redCard,
  }) {
    return CourtColors(
      court: court ?? this.court,
      goalArea: goalArea ?? this.goalArea,
      lines: lines ?? this.lines,
      home: home ?? this.home,
      onHome: onHome ?? this.onHome,
      away: away ?? this.away,
      onAway: onAway ?? this.onAway,
      board: board ?? this.board,
      onBoard: onBoard ?? this.onBoard,
      ledScore: ledScore ?? this.ledScore,
      ledPenalty: ledPenalty ?? this.ledPenalty,
      penaltyText: penaltyText ?? this.penaltyText,
      yellowCard: yellowCard ?? this.yellowCard,
      redCard: redCard ?? this.redCard,
    );
  }

  /// We have only one theme, so there is nothing to blend between.
  @override
  CourtColors lerp(CourtColors? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

/// Builds the theme "Halle".
///
/// The design rules live here instead of in a separate document:
/// no elevation and no shadows, 1 px dividers instead of cards,
/// corners rounded by at most 6 px, one font for text.
ThemeData buildHallTheme() {
  const text = Color(0xFF1B2028);
  const muted = Color(0xFF5C6573);
  const rule = Color(0x241B2028); // text color at 14 % opacity
  const white = Color(0xFFFFFFFF);
  const corners = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(6)),
  );

  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF1667C9),
    onPrimary: white,
    secondary: Color(0xFFD21F3C),
    onSecondary: white,
    error: Color(0xFFC62828),
    onError: white,
    surface: Color(0xFFF6F5F2),
    onSurface: text,
    onSurfaceVariant: muted,
    surfaceContainerLowest: white,
    surfaceContainerLow: white,
    surfaceContainer: white,
    surfaceContainerHigh: white,
    surfaceContainerHighest: white,
    outline: rule,
    outlineVariant: rule,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    fontFamily: 'TitilliumWeb',
    dividerTheme: const DividerThemeData(color: rule, thickness: 1, space: 1),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Color(0xFFF6F5F2),
      foregroundColor: text,
    ),
    cardTheme: const CardThemeData(elevation: 0, shape: corners),
    bottomSheetTheme: const BottomSheetThemeData(
      elevation: 0,
      backgroundColor: white,
      shape: RoundedRectangleBorder(),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(elevation: 0, shape: corners),
    ),
    extensions: const [CourtColors.hall],
  );
}
