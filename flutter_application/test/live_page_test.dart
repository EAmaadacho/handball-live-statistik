import 'package:flutter_application/data/demo_game_source.dart';
import 'package:flutter_application/data/game_source.dart';
import 'package:flutter_application/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

Future<DemoGameSource> _openLive(WidgetTester tester,
    {Size size = const Size(390, 844)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final source = DemoGameSource();
  await tester.pumpWidget(
    Provider<GameSource>.value(
      value: source,
      child: const HandballApp(initialLocation: '/spiel/17/live'),
    ),
  );
  await tester.pumpAndSettle();
  return source;
}

void main() {
  testWidgets('history shows the newest event on top with the score after it',
      (tester) async {
    await _openLive(tester);
    expect(find.text('Tor · 7 Max Mustermann', findRichText: true),
        findsOneWidget);
    expect(find.text('14:12'), findsOneWidget);
    final newest = tester.getTopLeft(find.text('14:12'));
    final older = tester.getTopLeft(find.text('13:11'));
    expect(newest.dy, lessThan(older.dy));
  });

  testWidgets('short-handed line names team, player and time left',
      (tester) async {
    await _openLive(tester);
    expect(find.text('HSG Hilden in Unterzahl · Nr. 8 1:22'), findsOneWidget);
  });

  testWidgets('tab "Spiel" compares both teams', (tester) async {
    await _openLive(tester);
    await tester.tap(find.byKey(const Key('Tab-Spiel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('TeamComparison')), findsOneWidget);
    expect(find.text('Halbzeit 8:7'), findsOneWidget);
  });

  testWidgets('tab "Spieler" shows the table of the chosen team',
      (tester) async {
    await _openLive(tester);
    await tester.tap(find.byKey(const Key('Tab-Spieler')));
    await tester.pumpAndSettle();
    expect(find.text('Max Mustermann'), findsOneWidget);

    await tester.tap(find.byKey(const Key('TeamSwitch-away')));
    await tester.pumpAndSettle();
    expect(find.text('Kai Roth'), findsOneWidget);
  });

  testWidgets('L1_1 lost connection shows a notice and keeps the last state',
      (tester) async {
    final source = await _openLive(tester);
    source.online = false;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.byKey(const Key('OfflineNotice')), findsOneWidget);
    expect(find.text('14:12'), findsOneWidget);

    source.online = true;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.byKey(const Key('OfflineNotice')), findsNothing);
  });

  testWidgets('web layout shows history and player table side by side',
      (tester) async {
    await _openLive(tester, size: const Size(1440, 900));
    expect(find.byKey(const Key('EventFeed')), findsOneWidget);
    expect(find.byKey(const Key('PlayerTable-home')), findsOneWidget);
    expect(find.byKey(const Key('Tab-Verlauf')), findsNothing);
  });
}
