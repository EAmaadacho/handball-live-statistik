import 'package:flutter_application/data/demo_game_source.dart';
import 'package:flutter_application/data/game_source.dart';
import 'package:flutter_application/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

Future<void> _open(WidgetTester tester, String location) async {
  await tester.pumpWidget(
    Provider<GameSource>.value(
      value: DemoGameSource(),
      child: HandballApp(initialLocation: location),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ticker link with the right code opens the ticker',
      (tester) async {
    await _open(tester, '/spiel/17/ticker/x9Fw3cNs7Ke2Hy5D');
    expect(find.text('Ticker'), findsOneWidget);
  });

  testWidgets('T1_3 ticker link with a wrong code shows "Link ungültig"',
      (tester) async {
    await _open(tester, '/spiel/17/ticker/falsch');
    expect(find.byKey(const Key('LinkInvalidTitle')), findsOneWidget);
  });

  testWidgets('T1_3 team link with a wrong code shows "Link ungültig"',
      (tester) async {
    await _open(tester, '/team/falsch');
    expect(find.byKey(const Key('LinkInvalidTitle')), findsOneWidget);
  });

  testWidgets('live link of game 17 opens the live page', (tester) async {
    await _open(tester, '/spiel/17/live');
    expect(find.text('Live'), findsOneWidget);
  });

  testWidgets('live link of a game that does not exist shows "Link ungültig"',
      (tester) async {
    await _open(tester, '/spiel/99/live');
    expect(find.byKey(const Key('LinkInvalidTitle')), findsOneWidget);
  });

  testWidgets('unknown address shows "Link ungültig"', (tester) async {
    await _open(tester, '/gibt-es-nicht');
    expect(find.byKey(const Key('LinkInvalidTitle')), findsOneWidget);
  });
}
