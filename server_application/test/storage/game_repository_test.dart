import 'dart:io';

import 'package:server_application/domain/game.dart';
import 'package:server_application/domain/game_clock.dart';
import 'package:server_application/domain/game_event.dart';
import 'package:server_application/storage/game_repository.dart';
import 'package:server_application/storage/stored_game.dart';
import 'package:test/test.dart';

import '../domain/builders.dart';

StoredGame stored(Game game, {String id = 'g1', String teamId = 't1'}) =>
    StoredGame(
      id: id,
      homeTeamId: teamId,
      date: DateTime(2026, 11, 28, 18),
      tickerCode: 'ticker-code',
      game: game,
    );

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('games_'));
  tearDown(() => dir.deleteSync(recursive: true));

  group('ADR-004 a running game survives a restart', () {
    test('score, lineup, clock and event numbers are the same after loading',
        () {
      final game = aRunningGame()
          .record(EventType.goal, Side.home, 'p-max', at(5))
          .record(EventType.twoMinutes, Side.away, 'p-jan', at(8))
          .substitute(Side.home, 'p-nora', 'p-tom', at(9), intoGoal: true)
          .record(EventType.goal, Side.home, 'p-lisa', at(10));
      GameRepository.open(dir.path).save(stored(game));

      final loaded = GameRepository.open(dir.path).byId('g1')!;

      expect(loaded.tickerCode, 'ticker-code');
      expect(loaded.date, DateTime(2026, 11, 28, 18));
      expect(loaded.game.score, game.score);
      expect(loaded.game.activeGoalkeeperOf(Side.home), 'p-tom');
      expect(loaded.game.lineupOf(Side.away)!.playerIds, hasLength(6));
      expect(loaded.game.clock.gameTime(at(12)), time(12));
      expect(loaded.game.nextEventNumber, 5);
      expect(loaded.game.home.name.display, 'TV Mettmann Männer');
    });

    test('a game before kick-off has no lineups after loading', () {
      GameRepository.open(dir.path).save(stored(aGame()));

      final loaded = GameRepository.open(dir.path).byId('g1')!.game;

      expect(loaded.clock.phase, ClockPhase.notStarted);
      expect(loaded.lineupOf(Side.home), isNull);
    });

    test('each game gets its own file and no .tmp file is left', () {
      final repository = GameRepository.open(dir.path)
        ..save(stored(aGame(), id: 'g1'))
        ..save(stored(aGame(), id: 'g2'));

      final names = dir.listSync().map((f) => f.uri.pathSegments.last);

      expect(names, unorderedEquals(['g1.json', 'g2.json']));
      expect(repository.byId('g2'), isNotNull);
    });
  });

  group('S1_3 games of a team', () {
    test('S1_3 only the games of TV Mettmann, ordered by date', () {
      final repository = GameRepository.open(dir.path)
        ..save(StoredGame(
            id: 'later',
            homeTeamId: 't1',
            date: DateTime(2026, 12, 5),
            tickerCode: 'a',
            game: aGame()))
        ..save(StoredGame(
            id: 'earlier',
            homeTeamId: 't1',
            date: DateTime(2026, 11, 28),
            tickerCode: 'b',
            game: aGame()))
        ..save(stored(aGame(), id: 'other', teamId: 't2'));

      final ids = repository.ofTeam('t1').map((g) => g.id);

      expect(ids, ['earlier', 'later']);
    });
  });
}
