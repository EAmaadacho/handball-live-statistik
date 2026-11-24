import 'package:go_router/go_router.dart';

import 'package:provider/provider.dart';

import 'data/game_source.dart';
import 'data/team_source.dart';
import 'pages/link_invalid_page.dart';
import 'pages/live_page.dart';
import 'pages/game_create_page.dart';
import 'pages/start_page.dart';
import 'pages/team_create_page.dart';
import 'pages/team_page.dart';
import 'pages/ticker_page.dart';

/// Address of the page "Link ungültig" (T1.3).
const linkInvalidPath = '/link-ungueltig';

/// All addresses of the app (see Bauplan, "Seiten").
///
/// Addresses with a secret code are checked before the page opens:
/// /spiel/17/ticker/x9Fw3cNs7Ke2Hy5D opens the ticker,
/// /spiel/17/ticker/falsch leads to "Link ungültig" (T1.3), the same for
/// the team link /team/{teamId}/{code}.
GoRouter createRouter(GameSource source, {String initialLocation = '/'}) {
  return GoRouter(
    initialLocation: initialLocation,
    errorBuilder: (context, state) => const LinkInvalidPage(),
    routes: [
      GoRoute(path: '/', builder: (context, state) => const StartPage()),
      GoRoute(
          path: linkInvalidPath,
          builder: (context, state) => const LinkInvalidPage()),
      GoRoute(
          path: '/team-neu',
          builder: (context, state) => const TeamCreatePage()),
      GoRoute(
        path: '/team/:teamId/:teamCode',
        redirect: (context, state) async {
          // Only the right code opens the team management (T1.2).
          final p = state.pathParameters;
          final team = await context
              .read<TeamSource>()
              .loadTeam(p['teamId']!, p['teamCode']!);
          return team == null ? linkInvalidPath : null;
        },
        builder: (context, state) => TeamPage(
            teamId: state.pathParameters['teamId']!,
            code: state.pathParameters['teamCode']!),
        routes: [
          GoRoute(
            path: 'spiel-neu',
            builder: (context, state) => GameCreatePage(
                teamId: state.pathParameters['teamId']!,
                code: state.pathParameters['teamCode']!),
          ),
        ],
      ),
      GoRoute(
        path: '/spiel/:gameId/ticker/:tickerCode',
        redirect: (context, state) async {
          final ok = await source.isTickerCode(state.pathParameters['gameId']!,
              state.pathParameters['tickerCode']!);
          return ok ? null : linkInvalidPath;
        },
        builder: (context, state) => TickerPage(
            gameId: state.pathParameters['gameId']!,
            tickerCode: state.pathParameters['tickerCode']!),
      ),
      GoRoute(
        path: '/spiel/:gameId/live',
        redirect: (context, state) async {
          final game = await source.loadGame(state.pathParameters['gameId']!);
          return game == null ? linkInvalidPath : null;
        },
        builder: (context, state) =>
            LivePage(gameId: state.pathParameters['gameId']!),
      ),
    ],
  );
}
