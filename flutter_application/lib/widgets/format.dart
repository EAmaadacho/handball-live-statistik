/// 2327 → "38:47" (clock on the scoreboard).
String formatClock(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

/// 82 → "1:22" (time left of a penalty).
String formatPenalty(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

/// e.g. "So 29.11.2026 · 15:00" for a game date.
String formatDate(DateTime date) {
  const days = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
  String two(int n) => n.toString().padLeft(2, '0');
  return '${days[date.weekday - 1]} ${two(date.day)}.${two(date.month)}.'
      '${date.year} · ${two(date.hour)}:${two(date.minute)}';
}
