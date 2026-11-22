import 'game_source.dart';
import 'models.dart';

/// Example data from the prototype: TV Mettmann against HSG Hilden, game 17.
class DemoGameSource implements GameSource {
  static const gameId = 17;
  static const teamCode = 'k7Qp2xVz9LmA4tRb';
  static const tickerCode = 'x9Fw3cNs7Ke2Hy5D';

  static const mettmann = Team(
    id: 'tvm',
    name: 'TV Mettmann',
    shortName: 'TVM',
    players: [
      Player(
          id: 'nora1',
          number: 1,
          firstName: 'Nora',
          lastName: 'Neumann',
          isGoalkeeper: true),
      Player(id: 'max7', number: 7, firstName: 'Max', lastName: 'Mustermann'),
      Player(
          id: 'lisa12', number: 12, firstName: 'Lisa', lastName: 'Mustermann'),
      Player(id: 'jonas4', number: 4, firstName: 'Jonas', lastName: 'Becker'),
      Player(id: 'ben5', number: 5, firstName: 'Ben', lastName: 'Schulz'),
      Player(id: 'paul11', number: 11, firstName: 'Paul', lastName: 'Wagner'),
      Player(id: 'finn23', number: 23, firstName: 'Finn', lastName: 'Krüger'),
      Player(id: 'tom9', number: 9, firstName: 'Tom', lastName: 'Neumann'),
      Player(id: 'erik15', number: 15, firstName: 'Erik', lastName: 'Hoffmann'),
      Player(
          id: 'mia16',
          number: 16,
          firstName: 'Mia',
          lastName: 'Schröder',
          isGoalkeeper: true),
    ],
    officials: [
      Official(letter: 'A', name: 'Sven Krause', role: 'Trainer'),
      Official(letter: 'B', name: 'Anja Wolf', role: 'Co-Trainerin'),
      Official(letter: 'C', name: 'Dirk Meier', role: 'Betreuer'),
    ],
  );

  static const hilden = Team(
    id: 'hsg',
    name: 'HSG Hilden',
    shortName: 'HSG',
    players: [
      Player(
          id: 'a1',
          number: 1,
          firstName: 'Lukas',
          lastName: 'Kern',
          isGoalkeeper: true),
      Player(id: 'a3', number: 3, firstName: 'Jan', lastName: 'Vogel'),
      Player(id: 'a5', number: 5, firstName: 'Jan', lastName: 'Becker'),
      Player(id: 'a8', number: 8, firstName: 'Nico', lastName: 'Hahn'),
      Player(id: 'a10', number: 10, firstName: 'Kai', lastName: 'Roth'),
    ],
    officials: [
      Official(letter: 'A', name: 'Holger Brück', role: 'Trainer'),
      Official(letter: 'B', name: 'Sara Linde', role: 'Betreuerin'),
    ],
  );

  static const game = Game(id: gameId, home: mettmann, away: hilden);

  @override
  Future<Game?> loadGame(int id) async => id == gameId ? game : null;

  @override
  Future<Team?> loadTeamByCode(String code) async =>
      code == teamCode ? mettmann : null;

  @override
  Future<bool> isTickerCode(int id, String code) async =>
      id == gameId && code == tickerCode;
}
