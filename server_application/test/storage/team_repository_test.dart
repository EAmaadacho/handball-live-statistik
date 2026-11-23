import 'dart:io';

import 'package:server_application/domain/team_name.dart';
import 'package:server_application/storage/team_repository.dart';
import 'package:test/test.dart';

import '../domain/builders.dart';

void main() {
  late Directory dir;
  late String path;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('teams_');
    path = '${dir.path}/teams.json';
  });
  tearDown(() => dir.deleteSync(recursive: true));

  group('ADR-004 teams survive a restart', () {
    test('a saved team with Max, Lisa and Nora is there after reopening', () {
      TeamRepository.open(path).save('t1', mettmann());

      final team = TeamRepository.open(path).byId('t1')!;

      expect(team.name.display, 'TV Mettmann Männer');
      expect(team.code, 'abc123');
      expect(team.squad.map((p) => p.firstName), ['Max', 'Lisa', 'Nora']);
      expect(team.playerById('p-nora')!.position, mettmann().squad[2].position);
    });

    test('without a file there are no teams yet', () {
      final repository = TeamRepository.open(path);

      expect(repository.byId('t1'), isNull);
    });

    test('no .tmp file is left after saving', () {
      TeamRepository.open(path).save('t1', mettmann());

      expect(File('$path.tmp').existsSync(), isFalse);
      expect(File(path).existsSync(), isTrue);
    });
  });

  group('T1_1 a team only once', () {
    test('T1_1 "tv mettmann" Männer is taken once TV Mettmann Männer exists',
        () {
      final repository = TeamRepository.open(path)..save('t1', mettmann());

      final name = TeamName(club: 'tv mettmann', ageGroup: AgeGroup.men);

      expect(repository.isNameTaken(name), isTrue);
      expect(repository.isNameTaken(name, exceptId: 't1'), isFalse);
    });

    test('T1_1 TV Mettmann Männer II is still free', () {
      final repository = TeamRepository.open(path)..save('t1', mettmann());

      final second =
          TeamName(club: 'TV Mettmann', ageGroup: AgeGroup.men, teamNumber: 2);

      expect(repository.isNameTaken(second), isFalse);
    });
  });
}
