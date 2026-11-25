import 'package:flutter_application/data/demo_game_source.dart';
import 'package:flutter_application/data/models.dart';
import 'package:flutter_application/theme/app_theme.dart';
import 'package:flutter_application/widgets/bench.dart';
import 'package:flutter_application/widgets/court.dart';
import 'package:flutter_application/widgets/scoreboard.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _state = DemoGameSource.state;

Future<void> _show(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHallTheme(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  group('Scoreboard', () {
    testWidgets('shows score, half, clock and the running penalty',
        (tester) async {
      await _show(tester, const Scoreboard(state: _state));

      expect(find.text('14'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('2. HALBZEIT'), findsOneWidget);
      expect(find.text('38:47'), findsOneWidget);
      expect(find.text('8 1:22'), findsOneWidget);
    });

    testWidgets('tapping the clock calls back only on the ticker',
        (tester) async {
      var taps = 0;
      await _show(tester, Scoreboard(state: _state, onClockTap: () => taps++));
      await tester.tap(find.byKey(const Key('ScoreboardClock')));
      expect(taps, 1);
      expect(find.text('LÄUFT · TIPPEN = STOPP'), findsOneWidget);
    });
  });

  group('Court', () {
    testWidgets('E5 home team at the bottom, guest team at the top',
        (tester) async {
      await _show(
          tester, const SizedBox(width: 300, child: Court(state: _state)));

      final noraHomeGoal =
          tester.getCenter(find.byKey(const Key('Court-home-0')));
      final lukasAwayGoal =
          tester.getCenter(find.byKey(const Key('Court-away-0')));
      expect(noraHomeGoal.dy, greaterThan(lukasAwayGoal.dy));
      expect(find.text('Nora'), findsOneWidget);
      expect(find.text('Lukas'), findsOneWidget);
    });

    testWidgets('T6_2 without logo the short names stand faded in each half',
        (tester) async {
      await _show(
          tester, const SizedBox(width: 300, child: Court(state: _state)));
      final home = tester.getCenter(find.byKey(const Key('CourtBadge-home')));
      final away = tester.getCenter(find.byKey(const Key('CourtBadge-away')));
      expect(home.dy, greaterThan(away.dy));
      expect(
          find.descendant(
              of: find.byKey(const Key('CourtBadge-home')),
              matching: find.text('TVM')),
          findsOneWidget);
      expect(find.byKey(const Key('TeamLogo')), findsNothing);
    });

    testWidgets('T6_2 the unregistered opponent HSG Hilden shows "HSG"',
        (tester) async {
      await _show(
          tester, const SizedBox(width: 300, child: Court(state: _state)));

      expect(
          find.descendant(
              of: find.byKey(const Key('CourtBadge-away')),
              matching: find.text('HSG')),
          findsOneWidget);
    });

    testWidgets('empty place shows its short name', (tester) async {
      await _show(
          tester, const SizedBox(width: 300, child: Court(state: _state)));
      // Place 4 (KL) of HSG Hilden is empty while Nico sits out his penalty.
      expect(
        find.descendant(
            of: find.byKey(const Key('Court-away-4')),
            matching: find.text('KL')),
        findsOneWidget,
      );
    });

    testWidgets('tapping Max reports home team, place 2', (tester) async {
      (Side, int)? tapped;
      await _show(
        tester,
        SizedBox(
            width: 300,
            child: Court(
                state: _state,
                onPlaceTap: (side, place) => tapped = (side, place))),
      );
      await tester.tap(find.text('7'));
      expect(tapped, (Side.home, 2));
    });
  });

  group('Bench', () {
    testWidgets('shows substitutes, officials and the count for TV Mettmann',
        (tester) async {
      await _show(
          tester,
          const SizedBox(
              width: 64, child: Bench(state: _state, side: Side.home)));

      for (final id in ['tom9', 'erik15', 'mia16']) {
        expect(find.byKey(Key('BenchPlayer-$id')), findsOneWidget);
      }
      for (final letter in ['A', 'B', 'C']) {
        expect(find.byKey(Key('BenchOfficial-home-$letter')), findsOneWidget);
      }
      expect(find.text('10/16 Sp.\n3/4 Off.'), findsOneWidget);
    });

    testWidgets('S1_4 late registration is possible below 16 players',
        (tester) async {
      await _show(
          tester,
          SizedBox(
              width: 64,
              child:
                  Bench(state: _state, side: Side.home, onAddPlayer: () {})));
      expect(find.byKey(const Key('BenchAdd-home')), findsOneWidget);
    });

    testWidgets('S1_4 no late registration with 16 players on the match report',
        (tester) async {
      final ids = List.generate(16, (i) => 'p$i');
      const base = DemoGameSource.mettmann;
      final full = GameState(
        game: Game(
          id: '1',
          home: Team(
            id: base.id,
            name: base.name,
            shortName: base.shortName,
            players: [
              for (var i = 0; i < 16; i++)
                Player(
                    id: ids[i], number: i + 1, firstName: 'S$i', lastName: 'X')
            ],
          ),
          away: DemoGameSource.hilden,
        ),
        goals: const {Side.home: 0, Side.away: 0},
        clockSeconds: 0,
        clockRunning: false,
        phase: GamePhase.notStarted,
        timeouts: const {Side.home: 0, Side.away: 0},
        field: {
          Side.home: ids.sublist(0, 7),
          Side.away: _state.field[Side.away]!
        },
        bench: {Side.home: ids.sublist(7), Side.away: const []},
      );
      await _show(
          tester,
          SizedBox(
              width: 64,
              child: Bench(state: full, side: Side.home, onAddPlayer: () {})));
      expect(find.byKey(const Key('BenchAdd-home')), findsNothing);
      expect(find.text('16/16 Sp.\n0/4 Off.'), findsOneWidget);
    });
  });
}
