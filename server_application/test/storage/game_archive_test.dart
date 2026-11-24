import 'dart:convert';
import 'dart:io';

import 'package:server_application/domain/game_clock.dart';
import 'package:server_application/domain/game_event.dart';
import 'package:server_application/storage/game_archive.dart';
import 'package:server_application/storage/game_json.dart';
import 'package:server_application/storage/game_repository.dart';
import 'package:test/test.dart';

import '../domain/builders.dart';
import 'game_repository_test.dart' show stored;

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('archive_'));
  tearDown(() => dir.deleteSync(recursive: true));

  /// Mettmann wins 2:0, goals by Max and Lisa, Nora saves against Jan.
  /// Half-time at 30:00, final whistle at 60:00.
  final finished = aRunningGame()
      .record(EventType.goal, Side.home, 'p-max', at(5))
      .record(EventType.save, Side.away, 'p-jan', at(8))
      .record(EventType.goal, Side.home, 'p-lisa', at(10))
      .halfTime()
      .startClock(at(45))
      .end(at(75));

  GameArchive openArchive() => GameArchive.open('${dir.path}/archive.db');
  GameRepository openGames() =>
      GameRepository.open('${dir.path}/games', archive: openArchive());
  File gameFile() => File('${dir.path}/games/g1.json');

  group('U5.2 a finished game goes into the archive (ADR-004)', () {
    test(
        'U5_2 after the final whistle the file is gone, the game is in '
        'the archive', () {
      openGames().save(stored(finished));

      expect(gameFile().existsSync(), isFalse);
      expect(openArchive().byId('g1'), isNotNull);
    });

    test(
        'U5_2 after a restart the viewer link still shows the final score, '
        'the events and the statistics', () {
      openGames().save(stored(finished));

      final loaded = openGames().byId('g1')!.game;

      expect(loaded.clock.phase, ClockPhase.finished);
      expect(loaded.score, finished.score);
      expect(loaded.events.map((e) => e.number),
          finished.events.map((e) => e.number));
      final nora = loaded
          .statisticsOf(Side.home)
          .singleWhere((row) => row.playerId == 'p-nora');
      expect(nora.saves, 1);
      expect(loaded.home.name.display, 'TV Mettmann Männer');
    });

    test('a running game stays a file and is not in the archive', () {
      openGames().save(stored(aRunningGame()));

      expect(gameFile().existsSync(), isTrue);
      expect(openArchive().byId('g1'), isNull);
    });

    test('a finished game left as a file is archived at the next start', () {
      gameFile().parent.createSync(recursive: true);
      gameFile()
          .writeAsStringSync(jsonEncode(storedGameToJson(stored(finished))));

      final games = openGames();

      expect(gameFile().existsSync(), isFalse);
      expect(games.byId('g1')!.game.score, finished.score);
    });

    test('S1.3 the team sees running and finished games, ordered by date', () {
      final games = openGames()
        ..save(stored(finished, id: 'old'))
        ..save(stored(aGame(), id: 'new'));

      expect(
          games.ofTeam('t1').map((g) => g.id), unorderedEquals(['old', 'new']));
    });
  });
}
