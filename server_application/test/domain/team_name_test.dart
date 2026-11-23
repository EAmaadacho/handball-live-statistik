import 'package:server_application/domain/team_name.dart';
import 'package:test/test.dart';

import 'builders.dart';

void main() {
  group('T1 team name like in nuLiga', () {
    test('T1 the first team shows club and age group', () {
      final name = TeamName(club: 'TV Mettmann', ageGroup: AgeGroup.men);

      expect(name.display, 'TV Mettmann Männer');
    });

    test('T1 the second team gets a Roman number: TV Mettmann Männer II', () {
      final name =
          TeamName(club: 'TV Mettmann', ageGroup: AgeGroup.men, teamNumber: 2);

      expect(name.display, 'TV Mettmann Männer II');
    });

    test('T1 youth teams show the full age group', () {
      final name = TeamName(club: 'HSG Hilden', ageGroup: AgeGroup.femaleB);

      expect(name.display, 'HSG Hilden weibliche Jugend B');
    });

    test('T1 spaces around the club are removed', () {
      final name = TeamName(club: '  TV Mettmann ', ageGroup: AgeGroup.men);

      expect(name.club, 'TV Mettmann');
    });

    test('T1 rejects an empty club', () {
      expect(() => TeamName(club: '  ', ageGroup: AgeGroup.men),
          throwsRuleViolation('Bitte einen Vereinsnamen eingeben.'));
    });

    test('T1 rejects team number 0 and 10', () {
      for (final number in [0, 10]) {
        expect(
            () => TeamName(
                club: 'TV Mettmann',
                ageGroup: AgeGroup.men,
                teamNumber: number),
            throwsRuleViolation('Die Mannschaftsnummer geht von 1 bis 9.'));
      }
    });
  });

  group('T1_1 the same team only once', () {
    test('T1_1 "tv mettmann" Männer is the same team as "TV Mettmann" Männer',
        () {
      final other = TeamName(club: 'tv mettmann', ageGroup: AgeGroup.men);

      expect(other.isSameTeamAs(mettmannName), isTrue);
    });

    test('T1_1 Männer II and männliche Jugend A of the club are other teams',
        () {
      final second =
          TeamName(club: 'TV Mettmann', ageGroup: AgeGroup.men, teamNumber: 2);
      final youth = TeamName(club: 'TV Mettmann', ageGroup: AgeGroup.maleA);

      expect(second.isSameTeamAs(mettmannName), isFalse);
      expect(youth.isSameTeamAs(mettmannName), isFalse);
    });
  });
}
