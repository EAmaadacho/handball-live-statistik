import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_application/data/demo_game_source.dart';
import 'package:flutter_application/data/demo_team_source.dart';
import 'package:flutter_application/data/game_source.dart';
import 'package:flutter_application/data/team_source.dart';
import 'package:flutter_application/data/logo_check.dart';
import 'package:flutter_application/main.dart';
import 'package:flutter_application/pages/team_page.dart';
import 'package:flutter_application/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openapi/api.dart';
import 'package:provider/provider.dart';

const _teamLink = '/team/${DemoTeamSource.teamId}/${DemoTeamSource.teamCode}';

Future<DemoTeamSource> _open(WidgetTester tester, String location) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final games = DemoGameSource();
  final teams = DemoTeamSource(games);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<HealthApi>.value(value: HealthApi(ApiClient())),
        Provider<GameSource>.value(value: games),
        Provider<TeamSource>.value(value: teams),
      ],
      child: HandballApp(initialLocation: location),
    ),
  );
  await tester.pumpAndSettle();
  return teams;
}

/// A real PNG of 1 × 1 pixel, as the logo of TV Mettmann.
final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

/// The team management of TV Mettmann; [file] is what the file dialog gives.
Future<(DemoTeamSource, DemoGameSource)> _openWithFile(
    WidgetTester tester, Uint8List? file) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final games = DemoGameSource();
  final teams = DemoTeamSource(games);
  await tester.pumpWidget(Provider<TeamSource>.value(
    value: teams,
    child: MaterialApp(
      theme: buildHallTheme(),
      home: TeamPage(
          teamId: DemoTeamSource.teamId,
          code: DemoTeamSource.teamCode,
          pickLogo: () async => file),
    ),
  ));
  await tester.pumpAndSettle();
  return (teams, games);
}

Finder _key(String key) => find.byKey(Key(key));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(_key(key));
  await tester.enterText(_key(key), text);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('T1 TV Mettmann Männer II gets a team link', (tester) async {
    await _open(tester, '/');
    await _tap(tester, _key('CreateTeam'));
    await _enter(tester, 'Club', 'TV Mettmann');
    await _tap(tester, _key('TeamNumber'));
    await _tap(tester, find.text('2 (II)').last);
    await _enter(tester, 'ShortName', 'TVM2');
    expect(find.text('TV Mettmann Männer II'), findsOneWidget);

    await _tap(tester, _key('CreateTeamSubmit'));
    expect(_key('TeamCreated'), findsOneWidget);
    expect(find.textContaining('/team/'), findsOneWidget);

    await _tap(tester, _key('ToTeam'));
    expect(find.text('TV Mettmann Männer II'), findsOneWidget);
    expect(find.text('Noch keine Spiele angelegt.'), findsOneWidget);
  });

  testWidgets('T1_1 "tv mettmann" Männer a second time is refused',
      (tester) async {
    await _open(tester, '/team-neu');
    await _enter(tester, 'Club', 'tv mettmann');
    await _enter(tester, 'ShortName', 'TVM');
    await _tap(tester, _key('CreateTeamSubmit'));
    expect(find.text('tv mettmann Männer gibt es schon.'), findsOneWidget);
  });

  testWidgets('T1_3 team link with a wrong code shows "Link ungültig"',
      (tester) async {
    await _open(tester, '/team/${DemoTeamSource.teamId}/falsch');
    expect(_key('LinkInvalidTitle'), findsOneWidget);
  });

  testWidgets('T2 Ole joins the squad, a second number 7 is refused',
      (tester) async {
    final teams = await _open(tester, _teamLink);
    await _tap(tester, _key('AddSquadPlayer'));
    await _enter(tester, 'SquadNumber', '20');
    await _enter(tester, 'SquadFirstName', 'Ole');
    await _enter(tester, 'SquadLastName', 'Brandt');
    await _tap(tester, _key('SquadSave'));
    expect(find.text('Ole Brandt'), findsOneWidget);

    await _tap(tester, _key('AddSquadPlayer'));
    await _enter(tester, 'SquadNumber', '7');
    await _enter(tester, 'SquadFirstName', 'Mats');
    await _enter(tester, 'SquadLastName', 'Klein');
    await _tap(tester, _key('SquadSave'));
    expect(find.text('Die Nummer 7 ist schon vergeben.'), findsOneWidget);
    final team =
        await teams.loadTeam(DemoTeamSource.teamId, DemoTeamSource.teamCode);
    expect(team!.players.where((p) => p.number == 7), hasLength(1));
  });

  testWidgets('T2 Erik leaves the squad after asking again', (tester) async {
    await _open(tester, _teamLink);
    await _tap(tester, _key('SquadPlayer-erik15'));
    await _tap(tester, _key('RemovePlayer'));
    await _tap(tester, _key('ConfirmRemovePlayer'));
    expect(_key('SquadPlayer-erik15'), findsNothing);
  });

  testWidgets('S1_3 the team management lists games 17 and 18 with status',
      (tester) async {
    await _open(tester, _teamLink);
    expect(_key('Game-17'), findsOneWidget);
    expect(find.descendant(of: _key('Game-17'), matching: find.text('läuft')),
        findsOneWidget);
    expect(find.descendant(of: _key('Game-18'), matching: find.text('geplant')),
        findsOneWidget);
  });

  testWidgets('S1 a game against Hilden II gets ticker and viewer link',
      (tester) async {
    await _open(tester, _teamLink);
    await _tap(tester, _key('NewGame'));
    await _enter(tester, 'OpponentClub', 'HSG Hilden');
    await _enter(tester, 'OpponentShortName', 'HSG');
    expect(_key('SquadHint'), findsOneWidget);
    const names = ['Lukas', 'Jan', 'Erik', 'Ole', 'Tim', 'Nils', 'Kai'];
    for (var i = 0; i < names.length; i++) {
      await _enter(tester, 'OpponentNumber-$i', '${i + 1}');
      await _enter(tester, 'OpponentFirstName-$i', names[i]);
      await _enter(tester, 'OpponentLastName-$i', 'Hilden');
    }
    expect(_key('SquadHint'), findsNothing);

    await _tap(tester, _key('CreateGameSubmit'));
    expect(_key('GameCreated'), findsOneWidget);
    expect(_key('Link-Ticker-Link'), findsOneWidget);
    expect(_key('Link-Zuschauer-Link'), findsOneWidget);

    // The new game opens in the ticker, before kick-off (E5.1).
    await _tap(tester, _key('ToTicker'));
    expect(_key('LineupBoard'), findsOneWidget);
  });

  testWidgets('S1_1 a half-filled squad row is not sent', (tester) async {
    await _open(tester, '$_teamLink/spiel-neu');
    await _enter(tester, 'OpponentClub', 'HSG Hilden');
    await _enter(tester, 'OpponentShortName', 'HSG');
    await _enter(tester, 'OpponentNumber-0', '5');
    await _tap(tester, _key('CreateGameSubmit'));
    expect(find.textContaining('Spieler 1: bitte Nummer'), findsOneWidget);
  });

  testWidgets('T6 TV Mettmann uploads its logo, the ticker shows it too',
      (tester) async {
    final (teams, games) = await _openWithFile(tester, _png);
    expect(find.text('TVM'), findsWidgets);
    await _tap(tester, _key('UploadLogo'));
    expect(find.text('Logo gespeichert.'), findsOneWidget);
    expect(_key('TeamLogo'), findsOneWidget);
    expect(find.text('Logo ändern'), findsOneWidget);
    final team =
        await teams.loadTeam(DemoTeamSource.teamId, DemoTeamSource.teamCode);
    expect(team!.logo, _png);
    expect(games.stateOf(DemoGameSource.gameId)!.game.home.logo, _png);
  });

  testWidgets('T6_1 a GIF is refused with the server\'s text', (tester) async {
    final gif = Uint8List.fromList(ascii.encode('GIF89a......'));
    await _openWithFile(tester, gif);
    await _tap(tester, _key('UploadLogo'));
    expect(
        find.text('Bitte ein PNG- oder JPG-Bild hochladen.'), findsOneWidget);
    expect(_key('TeamLogo'), findsNothing);
  });

  test('T6_1 a PNG over 500 KB is refused before sending', () {
    final big = Uint8List(maxLogoBytes + 1)..setAll(0, _png.take(8));
    expect(logoProblem(big), 'Das Logo darf höchstens 500 KB groß sein.');
    expect(logoProblem(_png), isNull);
    expect(logoProblem(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0])), isNull);
  });
}
