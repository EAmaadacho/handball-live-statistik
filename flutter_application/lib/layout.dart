import 'dart:ui' show Size;

/// The three layouts of the app (see prototype, "Ansicht").
enum ScreenKind {
  /// Narrow and upright: scoreboard on top, court below.
  phone,

  /// Phone turned sideways: scoreboard left, court right (court stays upright, E5).
  phoneLandscape,

  /// Wide screen: event history and statistics next to each other.
  web,
}

/// Picks the layout for the available [size] in logical pixels.
///
/// Example: an iPhone upright has 390 × 844 → [ScreenKind.phone],
/// turned sideways 844 × 390 → [ScreenKind.phoneLandscape],
/// a laptop browser 1440 × 900 → [ScreenKind.web].
ScreenKind screenKindFor(Size size) {
  if (size.width >= 1000 && size.height >= 500) {
    return ScreenKind.web;
  }
  if (size.width > size.height && size.height < 500) {
    return ScreenKind.phoneLandscape;
  }
  return ScreenKind.phone;
}
