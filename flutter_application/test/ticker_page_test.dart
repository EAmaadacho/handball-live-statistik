import 'package:flutter_application/data/demo_game_source.dart';
import 'package:flutter_application/data/game_source.dart';
import 'package:flutter_application/data/models.dart';
import 'package:flutter_application/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

Future<DemoGameSource> _openTicker(WidgetTester tester,
    {Size size = const Size(390, 844)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final source = DemoGameSource();
  await tester.pumpWidget(
    Provider<GameSource>.value(
      value: source,
      child: const HandballApp(
          initialLocation: '/spiel/17/ticker/x9Fw3cNs7Ke2Hy5D'),
    ),
  );
  await tester.pumpAndSettle();
  return source;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _key(String key) => find.byKey(Key(key));

String _homeGoals(WidgetTester tester) =>
    tester.widget<Text>(_key('ScoreboardGoals-home')).data!;

String _message(WidgetTester tester) => tester
    .widget<Text>(find
        .descendant(of: _key('TickerMessage'), matching: find.byType(Text))
        .first)
    .data!;

void main() {
  testWidgets('E1 goal by Max raises the score and can be undone',
      (tester) async {
    await _openTicker(tester);
    await _tap(tester, _key('Court-home-2')); // Max on RL
    await _tap(tester, _key('Action-Tor'));

    expect(_homeGoals(tester), '15');
    expect(_message(tester), startsWith('Tor · 7 Max · '));

    await _tap(tester, find.text('Rückgängig'));
    expect(_homeGoals(tester), '14');
  });

  testWidgets('E5_4 2 minutes for Tom on the bench: the ticker picks Paul',
      (tester) async {
    final source = await _openTicker(tester);
    await _tap(tester, _key('BenchPlayer-tom9'));
    await _tap(tester, _key('Action-2 Minuten'));
    expect(find.text('Wer verlässt dafür das Feld?'), findsOneWidget);

    await _tap(tester, _key('Choose-paul11'));
    final state = (await source.loadState('17'))!;
    expect(state.onField(Side.home), isNot(contains('paul11')));
    expect(state.penalties.where((p) => p.label == '9'), hasLength(1));
  });

  testWidgets('E5_2 Max goes to the bench, Tom comes on', (tester) async {
    final source = await _openTicker(tester);
    await _tap(tester, _key('Court-home-2'));
    await _tap(tester, _key('Action-Wechseln'));
    expect(_key('SwapBanner'), findsOneWidget);

    await _tap(tester, _key('BenchPlayer-tom9'));
    final state = (await source.loadState('17'))!;
    expect(state.field[Side.home]![2], 'tom9');
    expect(state.bench[Side.home], contains('max7'));
    expect(_key('BenchPlayer-max7'), findsOneWidget);
  });

  testWidgets('E5_4 2 minutes take Max off the field and keep his place free',
      (tester) async {
    await _openTicker(tester);
    await _tap(tester, _key('Court-home-2'));
    await _tap(tester, _key('Action-2 Minuten'));

    await _tap(tester, _key('Court-home-2')); // now empty
    expect(_message(tester),
        'Platz RL bleibt frei, solange die Zeitstrafe läuft.');
  });

  testWidgets('E5_6 2 minutes for goalkeeper Nora ask who goes in goal',
      (tester) async {
    final source = await _openTicker(tester);
    await _tap(tester, _key('Court-home-0'));
    await _tap(tester, _key('Action-2 Minuten'));
    expect(find.text('Wer geht ins Tor?'), findsOneWidget);

    await _tap(tester, _key('Choose-mia16'));
    expect(find.text('Wer geht dafür vom Feld?'), findsOneWidget);
    await _tap(tester, _key('Choose-ben5'));

    final state = (await source.loadState('17'))!;
    expect(state.field[Side.home]![0], 'mia16');
    expect(state.onField(Side.home), isNot(contains('ben5')));
    expect(state.onField(Side.home).length, 6);
  });

  testWidgets('R5 no save while the goal is empty', (tester) async {
    await _openTicker(tester);
    await _tap(tester, _key('Court-home-0'));
    await _tap(tester, _key('Action-2 Minuten'));
    await _tap(tester, _key('Choose-empty'));

    await _tap(tester, _key('Court-away-6')); // Jan Vogel of Hilden
    final save = tester.widget<OutlinedButton>(_key('Action-Parade'));
    expect(save.onPressed, isNull);
    expect(find.text('Parade: TV Mettmann hat keinen Torwart auf dem Feld.'),
        findsOneWidget);
  });

  testWidgets('R1 third timeout of Hilden stops the clock, a fourth is blocked',
      (tester) async {
    await _openTicker(tester);
    await _tap(tester, _key('Timeout-away'));

    expect(find.text('GESTOPPT · TIPPEN = START'), findsOneWidget);
    final button = tester.widget<OutlinedButton>(_key('Timeout-away'));
    expect(button.onPressed, isNull);
    expect(find.text('HSG Hilden hat keine Auszeit mehr.'), findsOneWidget);
  });

  testWidgets('U1 tapping the clock stops and starts it', (tester) async {
    await _openTicker(tester);
    await _tap(tester, _key('ScoreboardClock'));
    expect(find.text('GESTOPPT · TIPPEN = START'), findsOneWidget);
    await _tap(tester, _key('ScoreboardClock'));
    expect(find.text('LÄUFT · TIPPEN = STOPP'), findsOneWidget);
  });

  testWidgets('E2_1 deleting the goal of Max from the history counts again',
      (tester) async {
    await _openTicker(tester);
    await _tap(tester, _key('HistoryButton'));
    await _tap(tester, _key('Delete-6')); // 38:12 Tor · 7 Max Mustermann
    expect(find.text('Ereignis löschen?'), findsOneWidget);
    await _tap(tester, _key('ConfirmDelete'));

    expect(_homeGoals(tester), '13');
    expect(_message(tester), 'Gelöscht: Tor · 7 Max Mustermann');
  });

  testWidgets('E1_6 without connection the goal can be sent again',
      (tester) async {
    final source = await _openTicker(tester);
    source.online = false;
    await _tap(tester, _key('Court-home-2'));
    await _tap(tester, _key('Action-Tor'));

    expect(_message(tester), 'Nicht gesendet: Tor · 7 Max');
    expect(_key('TickerOffline'), findsOneWidget);
    expect(_homeGoals(tester), '14');

    source.online = true;
    await _tap(tester, find.text('Erneut senden'));
    expect(_homeGoals(tester), '15');
  });

  testWidgets('E1_5 short-handed, Nora goes off for Tom: 6 players, empty goal',
      (tester) async {
    final source = await _openTicker(tester);
    await _tap(tester, _key('Court-home-2')); // Max gets 2 minutes
    await _tap(tester, _key('Action-2 Minuten'));

    await _tap(tester, _key('Court-home-0')); // Nora
    await _tap(tester, _key('Action-Wechseln'));
    await _tap(tester, _key('BenchPlayer-tom9'));
    expect(find.text('Wie spielt 9 Tom?'), findsOneWidget);
    await _tap(tester, _key('Role-fieldPlayer'));

    final state = (await source.loadState('17'))!;
    expect(state.goalkeeperOf(Side.home), isNull);
    expect(state.onField(Side.home).length, 6);
    expect(_message(tester), contains('Tor leer'));

    // Nora comes back into goal for Tom.
    await _tap(tester, _key('Court-home-0'));
    await _tap(tester, _key('Action-Wechseln'));
    await _tap(tester, _key('BenchPlayer-nora1'));
    expect((await source.loadState('17'))!.goalkeeperOf(Side.home), 'nora1');
  });

  testWidgets(
      'IHF 4:7 Tom comes in for Nora as goalkeeper with goalkeeper shirt',
      (tester) async {
    final source = await _openTicker(tester);
    await _tap(tester, _key('Court-home-0'));
    await _tap(tester, _key('Action-Wechseln'));
    await _tap(tester, _key('BenchPlayer-tom9'));
    await _tap(tester, _key('Role-goalkeeper'));

    expect((await source.loadState('17'))!.goalkeeperOf(Side.home), 'tom9');
    await _tap(tester, _key('Court-home-0'));
    expect(find.text('Im Tor · Feldspieler mit Torwarttrikot'), findsOneWidget);
  });

  testWidgets('E5_6 with the goal empty, Max goes into goal for good',
      (tester) async {
    final source = await _openTicker(tester);
    await _tap(tester, _key('Court-home-0')); // Nora gets red
    await _tap(tester, _key('Action-Rot'));
    await _tap(tester, _key('Choose-empty'));

    await _tap(tester, _key('Court-home-2')); // Max
    await _tap(tester, _key('Action-Ins Tor'));

    final state = (await source.loadState('17'))!;
    expect(state.goalkeeperOf(Side.home), 'max7');
    expect(state.field[Side.home]![0], 'max7');
    expect(_message(tester), '7 Max geht ins Tor und zählt jetzt als Torwart.');
  });

  testWidgets(
      'E1_4 the goal of Max stands as "7 Max Mustermann" in the history',
      (tester) async {
    await _openTicker(tester, size: const Size(1280, 800));
    final maxGoals = find.descendant(
        of: _key('TickerHistory'),
        matching: find.text('Tor · 7 Max Mustermann'));
    final before = maxGoals.evaluate().length;

    await _tap(tester, _key('Court-home-2')); // Max on RL
    await _tap(tester, _key('Action-Tor'));

    expect(maxGoals.evaluate().length, before + 1);
  });

  testWidgets('web shows the history next to the court', (tester) async {
    await _openTicker(tester, size: const Size(1280, 800));
    expect(_key('TickerHistory'), findsOneWidget);
    expect(_key('HistoryButton'), findsNothing);
  });

  testWidgets('phone sideways shows scoreboard and court side by side',
      (tester) async {
    await _openTicker(tester, size: const Size(844, 390));
    final board = tester.getTopLeft(_key('Scoreboard'));
    final court = tester.getTopLeft(_key('Court-home-0'));
    expect(court.dx, greaterThan(board.dx + 300));
  });
}
