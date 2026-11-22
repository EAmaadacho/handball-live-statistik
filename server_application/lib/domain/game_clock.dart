import 'rule_violation.dart';

/// The parts of a game the clock goes through (U1, U5).
enum ClockPhase { notStarted, firstHalf, halfTime, secondHalf, finished }

/// The game clock, kept on the server (ADR-003).
///
/// It stores only whether it runs, when it was last started and how much
/// game time had passed before that. The game time is computed from these
/// values and the current time, which is passed in.
///
/// Example: started at 15:00:00 with 23:00 already played, at 15:00:14 the
/// game time is 23:14.
class GameClock {
  final ClockPhase phase;
  final bool running;
  final DateTime? startedAt;
  final Duration elapsedBefore;
  final Duration halfLength;

  const GameClock._({
    required this.phase,
    required this.running,
    required this.startedAt,
    required this.elapsedBefore,
    required this.halfLength,
  });

  /// A clock before kick-off, at 00:00.
  ///
  /// Example: `GameClock.initial(halfLength: Duration(minutes: 25))` for a
  /// B-Jugend game.
  factory GameClock.initial({
    Duration halfLength = const Duration(minutes: 30),
  }) {
    return GameClock._(
      phase: ClockPhase.notStarted,
      running: false,
      startedAt: null,
      elapsedBefore: Duration.zero,
      halfLength: halfLength,
    );
  }

  /// The game time at [now], never past the end of the current half (U3.2).
  ///
  /// Example: running since 15:00:00 from 29:50, at 15:01:00 the game time
  /// is 30:00, not 30:50.
  Duration gameTime(DateTime now) {
    final time =
        running ? elapsedBefore + now.difference(startedAt!) : elapsedBefore;
    return time > _halfEnd ? _halfEnd : time;
  }

  /// Whether the clock is ticking at [now]. At the end of a half it stops
  /// by itself (U3.2).
  bool isRunningAt(DateTime now) => running && gameTime(now) < _halfEnd;

  /// Starts the clock: kick-off, second half or after a stop (U1).
  ///
  /// Example: after half-time the second half starts at 30:00 (U5.1).
  GameClock start(DateTime now) {
    if (phase == ClockPhase.finished) {
      throw const RuleViolation('Das Spiel ist beendet.');
    }
    if (isRunningAt(now)) {
      throw const RuleViolation('Die Uhr läuft schon.');
    }
    final nextPhase = switch (phase) {
      ClockPhase.notStarted => ClockPhase.firstHalf,
      ClockPhase.halfTime => ClockPhase.secondHalf,
      _ => phase,
    };
    final next = _copy(phase: nextPhase, elapsedBefore: gameTime(now));
    if (next.elapsedBefore >= next._halfEnd) {
      throw const RuleViolation(
          'Die Halbzeit ist vorbei, bitte „Halbzeit“ drücken.');
    }
    return next._copy(running: true, startedAt: now);
  }

  /// Stops the clock by hand, e.g. for a 7-metre throw (U1.1).
  ///
  /// Example: stopped at 15:00:14 after starting at 23:00 → 23:14.
  GameClock stop(DateTime now) {
    if (!isRunningAt(now)) {
      throw const RuleViolation('Die Uhr steht schon.');
    }
    return _copy(running: false, elapsedBefore: gameTime(now));
  }

  /// Sets the game time of a stopped clock, e.g. 23:14 → 23:05 (U2).
  ///
  /// The time must stay inside the current half: 0:00–30:00 in the first,
  /// 30:00–60:00 in the second half.
  GameClock adjust(Duration newTime, DateTime now) {
    if (phase != ClockPhase.firstHalf && phase != ClockPhase.secondHalf) {
      throw const RuleViolation(
          'Die Zeit lässt sich nur während einer Halbzeit korrigieren.');
    }
    if (isRunningAt(now)) {
      throw const RuleViolation('Bitte erst die Uhr anhalten.');
    }
    if (newTime < _halfStart || newTime > _halfEnd) {
      throw const RuleViolation('Diese Zeit liegt nicht in der Halbzeit.');
    }
    return _copy(running: false, elapsedBefore: newTime);
  }

  /// Ends the first half. The clock stops at 30:00, even if the ticker
  /// presses it a little earlier, e.g. at 29:50 (U5.1).
  GameClock halfTime(DateTime now) {
    if (phase != ClockPhase.firstHalf) {
      throw const RuleViolation('„Halbzeit“ geht nur in der ersten Halbzeit.');
    }
    return _copy(
      phase: ClockPhase.halfTime,
      running: false,
      elapsedBefore: halfLength,
    );
  }

  /// Ends the game. The clock stops at the current game time (U5.2).
  GameClock end(DateTime now) {
    if (phase != ClockPhase.secondHalf) {
      throw const RuleViolation(
          '„Spielende“ geht nur in der zweiten Halbzeit.');
    }
    return _copy(
      phase: ClockPhase.finished,
      running: false,
      elapsedBefore: gameTime(now),
    );
  }

  Duration get _halfStart =>
      phase == ClockPhase.secondHalf ? halfLength : Duration.zero;

  Duration get _halfEnd => switch (phase) {
        ClockPhase.notStarted ||
        ClockPhase.firstHalf ||
        ClockPhase.halfTime =>
          halfLength,
        ClockPhase.secondHalf || ClockPhase.finished => halfLength * 2,
      };

  GameClock _copy({
    ClockPhase? phase,
    bool? running,
    DateTime? startedAt,
    Duration? elapsedBefore,
  }) {
    return GameClock._(
      phase: phase ?? this.phase,
      running: running ?? this.running,
      startedAt: startedAt ?? this.startedAt,
      elapsedBefore: elapsedBefore ?? this.elapsedBefore,
      halfLength: halfLength,
    );
  }
}
