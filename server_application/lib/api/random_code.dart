import 'dart:math';

final _random = Random.secure();
const _letters = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// A random code that cannot be guessed, e.g. "k7Qm2xPa9RtB4wZe" (T1.2).
///
/// Used for the secret part of team and ticker links (16 characters,
/// ADR-005) and for ids (8 characters).
String randomCode([int length = 16]) => String.fromCharCodes([
      for (var i = 0; i < length; i++)
        _letters.codeUnitAt(_random.nextInt(_letters.length)),
    ]);
