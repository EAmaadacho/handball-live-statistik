import 'package:flutter_application/data/demo_game_source.dart';
import 'package:flutter_application/data/game_source.dart';
import 'package:flutter_application/data/models.dart';
import 'package:flutter_application/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

const _home = ['nora1', 'paul11', 'max7', 'lisa12', 'finn23', 'jonas4', 'ben5'];
const _away = ['a1', 'a3', 'a5', 'a8', 'a10', 'a6', 'a14'];

Future<DemoGameSource> _open(WidgetTester tester, {int game = 18}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final source = DemoGameSource();
  final code =
      game == 18 ? DemoGameSource.nextTickerCode : DemoGameSource.tickerCode;
  await tester.pumpWidget(
    Provider<GameSource>.value(
      value: source,
      child: HandballApp(initialLocation: '/spiel/$game/ticker/$code'),
    ),
  );
  await tester.pumpAndSettle();
  return source;
}

Finder _key(String key) => find.byKey(Key(key));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _lineUp(WidgetTester tester, String side, List<String> ids) async {
  for (var place = 0; place < 7; place++) {
    await _tap(tester, _key('Court-$side-$place'));
    await _tap(tester, _key('Pick-${ids[place]}'));
  }
}

String _message(WidgetTester tester) => tester
    .widget<Text>(find
        .descendant(of: _key('TickerMessage'), matching: find.byType(Text))
        .first)
    .data!;

void main() {
  testWidgets('E5_1 before kick-off the ticker shows the lineup',
      (tester) async {
    await _open(tester);
    expect(_key('LineupBoard'), findsOneWidget);
    expect(find.text('TVM 0/7 · HSG 0/7'), findsOneWidget);
    expect(tester.widget<FilledButton>(_key('Kickoff')).onPressed, isNull);
    expect(find.text('TV Mettmann: noch 7 Plätze frei'), findsOneWidget);
  });

  testWidgets('E5_1 7 players per team, then kick-off starts the game',
      (tester) async {
    final source = await _open(tester);
    await _lineUp(tester, 'home', _home);
    await _lineUp(tester, 'away', _away);
    expect(find.text('TVM 7/7 · HSG 7/7'), findsOneWidget);

    await _tap(tester, _key('Kickoff'));
    final state = (await source.loadState('18'))!;
    expect(state.clockRunning, isTrue);
    expect(state.field[Side.home], _home);
    expect(state.goalkeeperOf(Side.away), 'a1');
    expect(_key('Timeout-home'), findsOneWidget); // ticker controls now
  });

  testWidgets('E5_1 tapping a placed player sends him back to the bench',
      (tester) async {
    await _open(tester);
    await _tap(tester, _key('Court-home-2'));
    await _tap(tester, _key('Pick-max7'));
    expect(find.text('TVM 1/7 · HSG 0/7'), findsOneWidget);

    await _tap(tester, _key('Court-home-2'));
    expect(find.text('TVM 0/7 · HSG 0/7'), findsOneWidget);
    expect(_key('BenchPlayer-max7'), findsOneWidget);
  });

  testWidgets('S1_4 Leon of Mettmann is registered late from the squad',
      (tester) async {
    await _open(tester);
    await _tap(tester, _key('BenchAdd-home'));
    await _tap(tester, _key('Pick-leon18'));

    expect(_key('BenchPlayer-leon18'), findsOneWidget);
    expect(_message(tester), 'Nachgemeldet: 18 Leon, sitzt auf der Bank.');
  });

  testWidgets('S1_4 during the game Hilden registers "20 Ole Brandt"',
      (tester) async {
    await _open(tester, game: 17);
    await _tap(tester, _key('BenchAdd-away'));
    await tester.enterText(_key('NewPlayerNumber'), '20');
    await tester.enterText(_key('NewPlayerFirstName'), 'Ole');
    await tester.enterText(_key('NewPlayerLastName'), 'Brandt');
    await _tap(tester, _key('NewPlayerSave'));

    expect(_key('BenchPlayer-hsg-20'), findsOneWidget);
  });

  testWidgets('S1_4 a number of Hilden that is taken is refused',
      (tester) async {
    await _open(tester, game: 17);
    await _tap(tester, _key('BenchAdd-away'));
    await tester.enterText(_key('NewPlayerNumber'), '3');
    await tester.enterText(_key('NewPlayerFirstName'), 'Ole');
    await tester.enterText(_key('NewPlayerLastName'), 'Brandt');
    await _tap(tester, _key('NewPlayerSave'));

    expect(_message(tester), 'Die Nummer 3 ist schon vergeben.');
  });

  testWidgets('S1_4 before kick-off Erik is taken off the match report',
      (tester) async {
    final source = await _open(tester);
    await _tap(tester, _key('BenchPlayer-erik15'));
    await _tap(tester, _key('RemoveFromReport'));

    expect(_key('BenchPlayer-erik15'), findsNothing);
    final state = (await source.loadState('18'))!;
    expect(state.reportOf(Side.home), isNot(contains('erik15')));
  });
}
