import 'rule_violation.dart';

/// The age group of a team, as in nuLiga (T1).
enum AgeGroup {
  men('Männer'),
  women('Frauen'),
  maleA('männliche Jugend A'),
  maleB('männliche Jugend B'),
  maleC('männliche Jugend C'),
  maleD('männliche Jugend D'),
  maleE('männliche Jugend E'),
  femaleA('weibliche Jugend A'),
  femaleB('weibliche Jugend B'),
  femaleC('weibliche Jugend C'),
  femaleD('weibliche Jugend D'),
  femaleE('weibliche Jugend E'),
  mixedE('gemischte Jugend E'),
  mixedF('gemischte Jugend F');

  /// The German name shown in the app, e.g. "männliche Jugend A".
  final String label;

  const AgeGroup(this.label);
}

/// The full name of a team: club, age group and team number (T1).
///
/// Example: club "TV Mettmann", age group men, number 2 is shown as
/// "TV Mettmann Männer II". Home team and opponent are entered the same way.
class TeamName {
  final String club;
  final AgeGroup ageGroup;
  final int teamNumber;

  const TeamName._(this.club, this.ageGroup, this.teamNumber);

  /// Rejects an empty club and a team number outside 1 to 9.
  factory TeamName({
    required String club,
    required AgeGroup ageGroup,
    int teamNumber = 1,
  }) {
    if (club.trim().isEmpty) {
      throw const RuleViolation('Bitte einen Vereinsnamen eingeben.');
    }
    if (teamNumber < 1 || teamNumber > 9) {
      throw const RuleViolation('Die Mannschaftsnummer geht von 1 bis 9.');
    }
    return TeamName._(club.trim(), ageGroup, teamNumber);
  }

  /// "TV Mettmann Männer", or "TV Mettmann Männer II" for the second team.
  String get display {
    final suffix = teamNumber == 1 ? '' : ' ${_roman[teamNumber - 1]}';
    return '$club ${ageGroup.label}$suffix';
  }

  /// Whether both names mean the same team. Upper and lower case do not
  /// count: "tv mettmann" Männer is the same as "TV Mettmann" Männer (T1.1).
  bool isSameTeamAs(TeamName other) =>
      club.toLowerCase() == other.club.toLowerCase() &&
      ageGroup == other.ageGroup &&
      teamNumber == other.teamNumber;

  @override
  String toString() => display;

  static const _roman = [
    'I',
    'II',
    'III',
    'IV',
    'V',
    'VI',
    'VII',
    'VIII',
    'IX'
  ];
}
