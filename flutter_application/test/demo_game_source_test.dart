import 'package:flutter_application/data/demo_game_source.dart';
import 'package:flutter_application/data/game_source.dart';
import 'package:flutter_application/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

const _id = DemoGameSource.gameId;
const _code = DemoGameSource.tickerCode;

void main() {
  late DemoGameSource source;
  late DateTime time;
  setUp(() {
    time = DateTime(2026, 11, 22, 15);
    source = DemoGameSource(now: () => time);
  });

  Future<GameState> now() async => (await source.loadState(_id))!;

  test('E1_3 a goal of Max counts for him and against goalkeeper Lukas',
      () async {
    await source.record(_id, _code, EventKind.goal, Side.home,
        playerId: 'max7');
    final s = await now();
    expect(s.goals[Side.home], 15);
    expect(s.statsOf('max7').goals, 6);
    expect(s.statsOf('a1').goalsAgainst, 15);
    expect(s.events.first.who, '7 Max Mustermann');
  });

  test('R2 the third 2 minutes of Max mean red, deleting it lifts it (E2_2)',
      () async {
    final numbers = <int>[];
    // From the bench, someone on the field has to go off for Max (E5.4).
    for (final leaving in [null, 'paul11', 'nora1']) {
      final event = await source.record(
          _id, _code, EventKind.twoMinutes, Side.home,
          playerId: 'max7', leavingPlayerId: leaving);
      numbers.add(event.number);
      time = time.add(const Duration(seconds: 121)); // Max back on the bench
    }
    var s = await now();
    expect(s.cards['max7'], CardMark.red);
    expect(s.bench[Side.home], isNot(contains('max7')));

    await source.deleteEvent(_id, _code, numbers.last);
    s = await now();
    expect(s.cards['max7'], isNull);
    expect(s.bench[Side.home], contains('max7'));
  });

  test('E5_4 after 2 minutes Nico of Hilden is back on the bench', () async {
    expect((await now()).bench[Side.away], isNot(contains('a8')));
    time = time.add(const Duration(seconds: 82));
    expect((await now()).bench[Side.away], contains('a8'));
  });

  test('R3 a disqualified player gets no events', () async {
    await source.record(_id, _code, EventKind.redCard, Side.home,
        playerId: 'tom9', leavingPlayerId: 'paul11');
    expect(
        () => source.record(_id, _code, EventKind.yellowCard, Side.home,
            playerId: 'tom9'),
        throwsA(isA<RejectedAction>()
            .having((e) => e.message, 'message', 'Tom ist disqualifiziert.')));
  });

  test('E5_4 2 minutes for Tom on the bench: Paul goes off the field',
      () async {
    expect(
        () => source.record(_id, _code, EventKind.twoMinutes, Side.home,
            playerId: 'tom9'),
        throwsA(isA<RejectedAction>().having((e) => e.message, 'message',
            'Bitte wählen, wer das Feld verlässt.')));
    await source.record(_id, _code, EventKind.twoMinutes, Side.home,
        playerId: 'tom9', leavingPlayerId: 'paul11');
    final s = await now();
    expect(s.onField(Side.home), isNot(contains('paul11')));
    expect(s.bench[Side.home], contains('paul11'));
  });

  test('U5 half time stops the clock at 30:00, the next start is half 2',
      () async {
    const next = DemoGameSource.nextGameId;
    const code = DemoGameSource.nextTickerCode;
    final lineup = (await source.loadState(next))!.reportOf(Side.home);
    final guests = (await source.loadState(next))!.reportOf(Side.away);
    await source.setLineup(
        next, code, Side.home, lineup[0], lineup.sublist(1, 7));
    await source.setLineup(
        next, code, Side.away, guests[0], guests.sublist(1, 7));
    await source.toggleClock(next, code);
    time = time.add(const Duration(minutes: 31));
    var s = (await source.loadState(next))!;
    expect((s.clockSeconds, s.clockRunning), (1800, false));
    expect(
        () => source.toggleClock(next, code), throwsA(isA<RejectedAction>()));

    await source.halfTime(next, code);
    await source.toggleClock(next, code);
    s = (await source.loadState(next))!;
    expect((s.phase, s.half, s.clockRunning), (GamePhase.secondHalf, 2, true));
    await source.endGame(next, code);
    expect((await source.loadState(next))!.ended, isTrue);
  });

  test('R7 a goal for a bench player is refused', () async {
    expect(
        () => source.record(_id, _code, EventKind.goal, Side.home,
            playerId: 'tom9'),
        throwsA(isA<RejectedAction>()));
  });

  test('IHF 4:7 a save against Max in goal counts for Max', () async {
    await source.record(_id, _code, EventKind.redCard, Side.home,
        playerId: 'nora1');
    await source.putInGoal(_id, _code, Side.home, 'max7');
    await source.record(_id, _code, EventKind.save, Side.away, playerId: 'a3');
    expect((await now()).statsOf('max7').saves, 1);
  });

  test('S1_4 a 17th player on the match report is refused', () async {
    // Hilden has 11 players on the report; 5 more fit.
    for (var number = 30; number < 35; number++) {
      await source.addSquadPlayer(
          _id, _code, Side.away, number, 'Neu', 'Spieler');
    }
    expect((await now()).reportOf(Side.away).length, 16);
    expect(
        () => source.addSquadPlayer(_id, _code, Side.away, 40, 'Zu', 'Viel'),
        throwsA(isA<RejectedAction>().having((e) => e.message, 'message',
            'Im Spielbericht stehen schon 16 Spieler.')));
  });

  test('E5_1 kick-off needs both lineups', () async {
    expect(
        () => source.toggleClock(
            DemoGameSource.nextGameId, DemoGameSource.nextTickerCode),
        throwsA(isA<RejectedAction>().having((e) => e.message, 'message',
            'Bitte zuerst beide Teams aufstellen.')));
  });

  test('ADR-005 a wrong ticker code is refused', () async {
    expect(() => source.toggleClock(_id, 'falsch'),
        throwsA(isA<RejectedAction>()));
  });

  test('E1_6 without connection writes fail with a connection error', () async {
    source.online = false;
    expect(
        () => source.record(_id, _code, EventKind.goal, Side.home,
            playerId: 'max7'),
        throwsA(isNot(isA<RejectedAction>())));
  });
}
