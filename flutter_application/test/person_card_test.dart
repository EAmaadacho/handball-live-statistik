import 'package:flutter_application/data/demo_game_source.dart';
import 'package:flutter_application/data/game_source.dart';
import 'package:flutter_application/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

Future<void> _openTicker(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Provider<GameSource>.value(
      value: DemoGameSource(),
      child: const HandballApp(
          initialLocation: '/spiel/17/ticker/x9Fw3cNs7Ke2Hy5D'),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _inCard(String text) => find.descendant(
    of: find.byKey(const Key('PersonCard')), matching: find.text(text));

void main() {
  testWidgets('tapping Max on the court shows his card with goals and place',
      (tester) async {
    await _openTicker(tester);
    await tester.tap(find.byKey(const Key('Court-home-2')));
    await tester.pumpAndSettle();

    expect(_inCard('Max Mustermann'), findsOneWidget);
    expect(_inCard('TV Mettmann · Feldspieler'), findsOneWidget);
    expect(_inCard('Auf dem Feld · RL'), findsOneWidget);
    expect(_inCard('5'), findsOneWidget); // goals
    expect(_inCard('71 %'), findsOneWidget); // 5 of 7
    expect(_inCard('2/2'), findsOneWidget); // 7 m
  });

  testWidgets('tapping goalkeeper Nora shows saves instead of goals',
      (tester) async {
    await _openTicker(tester);
    await tester.tap(find.byKey(const Key('Court-home-0')));
    await tester.pumpAndSettle();

    expect(_inCard('Nora Neumann'), findsOneWidget);
    expect(_inCard('PARADEN'), findsOneWidget);
    expect(_inCard('43 %'), findsOneWidget); // 9 of 21
  });

  testWidgets('tapping Tom on the bench shows that he sits on the bench',
      (tester) async {
    await _openTicker(tester);
    await tester.tap(find.byKey(const Key('BenchPlayer-tom9')));
    await tester.pumpAndSettle();

    expect(_inCard('Tom Neumann'), findsOneWidget);
    expect(_inCard('Auf der Bank'), findsOneWidget);
  });

  testWidgets(
      'tapping official A of HSG Hilden shows name, role and yellow card',
      (tester) async {
    await _openTicker(tester);
    await tester.tap(find.byKey(const Key('BenchOfficial-away-A')));
    await tester.pumpAndSettle();

    expect(_inCard('Holger Brück'), findsOneWidget);
    expect(_inCard('HSG Hilden · Trainer'), findsOneWidget);
    expect(_inCard('Strafen: Gelb'), findsOneWidget);
  });
}
