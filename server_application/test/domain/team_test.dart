import 'package:server_application/domain/player.dart';
import 'package:server_application/domain/team.dart';
import 'package:test/test.dart';

import 'builders.dart';

void main() {
  group('T1 create a team', () {
    test('T1 creates TV Mettmann with an empty squad', () {
      final team =
          Team.create(name: 'TV Mettmann', shortCode: 'TVM', code: 'abc123');

      expect(team.name, 'TV Mettmann');
      expect(team.shortCode, 'TVM');
      expect(team.code, 'abc123');
      expect(team.squad, isEmpty);
    });

    test('T1 rejects an empty team name', () {
      expect(
        () => Team.create(name: '  ', shortCode: 'TVM', code: 'abc123'),
        throwsRuleViolation('Bitte einen Teamnamen eingeben.'),
      );
    });

    test('T1 rejects a short code with 1 or 5 characters', () {
      expect(
        () => Team.create(name: 'TV Mettmann', shortCode: 'T', code: 'abc123'),
        throwsRuleViolation('Das Kürzel braucht 2 bis 4 Zeichen.'),
      );
      expect(
        () => Team.create(
            name: 'TV Mettmann', shortCode: 'TVMET', code: 'abc123'),
        throwsRuleViolation('Das Kürzel braucht 2 bis 4 Zeichen.'),
      );
    });
  });

  group('T2 add a player', () {
    test('T2 adding Tom returns a new team and keeps the old one', () {
      final before = mettmann();

      final after = before.addPlayer(tom());

      expect(
          after.squad.map((p) => p.firstName), ['Max', 'Lisa', 'Nora', 'Tom']);
      expect(before.squad, hasLength(3));
    });

    test('T2_1 rejects a second No. 7 next to Max', () {
      final team = mettmann();

      expect(
        () => team.addPlayer(tom().copyWith(number: 7)),
        throwsRuleViolation('Die Nummer 7 ist schon vergeben.'),
      );
    });

    test('T2_1 accepts No. 1 and No. 99', () {
      final team = anEmptyTeam();

      final result = team
          .addPlayer(aPlayer(id: 'a', number: 1))
          .addPlayer(aPlayer(id: 'b', number: 99));

      expect(result.squad.map((p) => p.number), [1, 99]);
    });

    test('T2_1 rejects No. 0 and No. 100', () {
      final team = anEmptyTeam();

      expect(() => team.addPlayer(aPlayer(number: 0)),
          throwsRuleViolation('Nummern gehen von 1 bis 99.'));
      expect(() => team.addPlayer(aPlayer(number: 100)),
          throwsRuleViolation('Nummern gehen von 1 bis 99.'));
    });

    test('T2 rejects an empty first or last name', () {
      final team = anEmptyTeam();

      expect(() => team.addPlayer(aPlayer(firstName: ' ')),
          throwsRuleViolation('Bitte Vor- und Nachnamen eingeben.'));
      expect(() => team.addPlayer(aPlayer(lastName: '')),
          throwsRuleViolation('Bitte Vor- und Nachnamen eingeben.'));
    });

    test('T2 the squad has no upper limit', () {
      var team = anEmptyTeam();

      for (var number = 1; number <= 30; number++) {
        team = team.addPlayer(aPlayer(id: 'p$number', number: number));
      }

      expect(team.squad, hasLength(30));
    });
  });

  group('T2 change a player', () {
    test('T2 Max switches from No. 7 to No. 10 and keeps his id', () {
      final team = mettmann();

      final result = team.updatePlayer(max().copyWith(number: 10));

      expect(result.playerById('p-max')!.number, 10);
      expect(result.squad, hasLength(3));
    });

    test('T2_1 Max may keep his own No. 7 when changing his name', () {
      final team = mettmann();

      final result = team.updatePlayer(max().copyWith(firstName: 'Maximilian'));

      expect(
          result.playerById('p-max')!.displayName, '7 Maximilian Mustermann');
    });

    test('T2_1 Max cannot take Lisa\'s No. 12', () {
      final team = mettmann();

      expect(
        () => team.updatePlayer(max().copyWith(number: 12)),
        throwsRuleViolation('Die Nummer 12 ist schon vergeben.'),
      );
    });

    test('T2 rejects changing a player who is not in the squad', () {
      final team = mettmann();

      expect(() => team.updatePlayer(tom()),
          throwsRuleViolation('Spieler nicht gefunden.'));
    });

    test('T2 Max becomes a goalkeeper', () {
      final team = mettmann();

      final result =
          team.updatePlayer(max().copyWith(position: Position.goalkeeper));

      expect(result.playerById('p-max')!.position, Position.goalkeeper);
    });
  });

  group('T2 remove a player', () {
    test('T2 removing Lisa frees No. 12 for Tom', () {
      final team = mettmann();

      final result =
          team.removePlayer('p-lisa').addPlayer(tom().copyWith(number: 12));

      expect(result.playerById('p-lisa'), isNull);
      expect(result.playerById('p-tom')!.number, 12);
    });

    test('T2 rejects removing a player who is not in the squad', () {
      final team = mettmann();

      expect(() => team.removePlayer('p-tom'),
          throwsRuleViolation('Spieler nicht gefunden.'));
    });
  });

  test('E1_4 a player is shown with number and name', () {
    final player = max();

    final shown = player.displayName;

    expect(shown, '7 Max Mustermann');
  });
}
