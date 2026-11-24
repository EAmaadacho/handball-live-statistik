import 'dart:typed_data';

import 'models.dart';

/// The age groups as in nuLiga (T1), e.g. "männliche Jugend B".
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

  const AgeGroup(this.label);

  final String label;
}

/// A team name as in nuLiga: club, age group and team number (T1, S1).
///
/// Example: TV Mettmann, Männer, 2 → "TV Mettmann Männer II".
class TeamName {
  const TeamName(
      {required this.club, required this.ageGroup, this.teamNumber = 1});

  final String club;
  final AgeGroup ageGroup;

  /// 1 to 9; the first team has no suffix.
  final int teamNumber;

  String get display =>
      '$club ${ageGroup.label}${teamNumber == 1 ? '' : ' ${romanNumber(teamNumber)}'}';

  /// 2 → "II", as in "TV Mettmann Männer II".
  static String romanNumber(int number) => const [
        'I',
        'II',
        'III',
        'IV',
        'V',
        'VI',
        'VII',
        'VIII',
        'IX'
      ][number - 1];
}

/// What the form for one player holds, e.g. 7, Max, Mustermann, field player.
class SquadEntry {
  const SquadEntry({
    required this.number,
    required this.firstName,
    required this.lastName,
    this.isGoalkeeper = false,
  });

  final int number;
  final String firstName;
  final String lastName;
  final bool isGoalkeeper;
}

/// What the form "Spiel anlegen" holds (S1).
///
/// Example: against HSG Hilden Männer (HSG) on 29.11. at 15:00, 30 minutes
/// per half, with 8 players of Hilden in the game squad (S1.1).
class NewGameEntry {
  const NewGameEntry({
    required this.opponent,
    required this.opponentShortName,
    required this.date,
    required this.halfMinutes,
    required this.opponentPlayers,
  });

  final TeamName opponent;
  final String opponentShortName;
  final DateTime date;
  final int halfMinutes;
  final List<SquadEntry> opponentPlayers;
}

enum TeamGameStatus {
  planned('geplant'),
  running('läuft'),
  finished('beendet');

  const TeamGameStatus(this.label);

  final String label;
}

/// One game in the team management, with its links (S1.2, S1.3).
class TeamGame {
  const TeamGame({
    required this.id,
    required this.tickerCode,
    required this.opponent,
    required this.date,
    required this.status,
  });

  /// Also the viewer link: /spiel/{id}/live.
  final String id;

  /// Secret part of the ticker link: /spiel/{id}/ticker/{tickerCode}.
  final String tickerCode;

  /// e.g. "HSG Hilden Männer".
  final String opponent;
  final DateTime date;
  final TeamGameStatus status;
}

/// Where the team management gets its data from (T1, T2, S1).
///
/// [ApiTeamSource] asks the server, [DemoTeamSource] answers from memory.
/// Every change needs the secret [code] from the team link (T1.2, ADR-005).
/// A rule that forbids a change throws RejectedAction, e.g.
/// "Die Nummer 7 ist schon vergeben." (T2.1).
abstract class TeamSource {
  /// Creates a team; the answer holds the code for the team link (T1).
  /// "TV Mettmann Männer" a second time is refused (T1.1).
  Future<({String teamId, String code})> createTeam(
      TeamName name, String shortName);

  /// The team with its squad, or null when id or code are wrong (T1.3).
  Future<Team?> loadTeam(String teamId, String code);

  /// The changes to the squad answer with the whole team (T2).
  Future<Team> addPlayer(String teamId, String code, SquadEntry player);
  Future<Team> updatePlayer(
      String teamId, String code, String playerId, SquadEntry player);
  Future<Team> removePlayer(String teamId, String code, String playerId);

  /// Uploads or replaces the club logo, PNG or JPG up to 500 KB (T6, T6.1).
  Future<Team> uploadLogo(String teamId, String code, Uint8List logo);

  /// All games of the team, by date (S1.3).
  Future<List<TeamGame>> loadGames(String teamId, String code);

  /// Creates a game; the answer holds ticker code and id (S1, S1.2).
  Future<TeamGame> createGame(String teamId, String code, NewGameEntry game);
}
