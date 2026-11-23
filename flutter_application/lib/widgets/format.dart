/// 2327 → "38:47" (clock on the scoreboard).
String formatClock(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

/// 82 → "1:22" (time left of a penalty).
String formatPenalty(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
