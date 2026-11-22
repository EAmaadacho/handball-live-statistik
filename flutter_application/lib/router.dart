import 'package:go_router/go_router.dart';

import 'data/game_source.dart';
import 'pages/link_invalid_page.dart';
import 'pages/placeholder_page.dart';
import 'pages/start_page.dart';

/// Address of the page "Link ungültig" (T1.3).
const linkInvalidPath = '/link-ungueltig';

/// All addresses of the app (see Bauplan, "Seiten").
///
/// Addresses with a secret code are checked before the page opens:
/// /spiel/17/ticker/x9Fw3cNs7Ke2Hy5D opens the ticker,
/// /spiel/17/ticker/falsch leads to "Link ungültig".
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
        path: '/team/:teamCode',
        redirect: (context, state) async =>
            await source.loadTeamByCode(state.pathParameters['teamCode']!) ==
                    null
                ? linkInvalidPath
                : null,
        builder: (context, state) => const PlaceholderPage(
            title: 'Teamverwaltung', subtitle: 'kommt in Schritt 6'),
        routes: [
          GoRoute(
            path: 'spiel-neu',
            builder: (context, state) => const PlaceholderPage(
                title: 'Spiel anlegen', subtitle: 'kommt in Schritt 6'),
          ),
        ],
      ),
      GoRoute(
        path: '/spiel/:gameId/ticker/:tickerCode',
        redirect: (context, state) async {
          final gameId = int.tryParse(state.pathParameters['gameId']!);
          final ok = gameId != null &&
              await source.isTickerCode(
                  gameId, state.pathParameters['tickerCode']!);
          return ok ? null : linkInvalidPath;
        },
        builder: (context, state) => const PlaceholderPage(
            title: 'Ticker', subtitle: 'kommt in Schritt 4 und 5'),
      ),
      GoRoute(
        path: '/spiel/:gameId/live',
        redirect: (context, state) async {
          final gameId = int.tryParse(state.pathParameters['gameId']!);
          final game = gameId == null ? null : await source.loadGame(gameId);
          return game == null ? linkInvalidPath : null;
        },
        builder: (context, state) => const PlaceholderPage(
            title: 'Live', subtitle: 'kommt in Schritt 3'),
      ),
    ],
  );
}
