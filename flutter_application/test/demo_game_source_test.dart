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
    for (var i = 0; i < 3; i++) {
      final event = await source.record(
          _id, _code, EventKind.twoMinutes, Side.home,
          playerId: 'max7');
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
        playerId: 'tom9');
    expect(
        () => source.record(_id, _code, EventKind.yellowCard, Side.home,
            playerId: 'tom9'),
        throwsA(isA<RejectedAction>()
            .having((e) => e.message, 'message', 'Tom ist disqualifiziert.')));
  });

  test('R7 a goal for a bench player is refused', () async {
    expect(
        () => source.record(_id, _code, EventKind.goal, Side.home,
            playerId: 'tom9'),
        throwsA(isA<RejectedAction>()));
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
