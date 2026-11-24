import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openapi/api.dart';
import 'package:provider/provider.dart';

import 'data/api_game_source.dart';
import 'data/api_team_source.dart';
import 'data/demo_game_source.dart';
import 'data/demo_team_source.dart';
import 'data/game_source.dart';
import 'data/team_source.dart';
import 'router.dart';
import 'theme/app_theme.dart';

/// Address of the Dart server, see server_application/bin/server.dart.
///
/// Given at start: `flutter run --dart-define=SERVER_URL=http://127.0.0.1:8080`.
/// Without it the app shows the demo game (DemoGameSource).
const serverUrl = String.fromEnvironment('SERVER_URL');

void main() {
  // Addresses without "#", so a link looks like /spiel/17/live (ADR-005).
  usePathUrlStrategy();
  final client = ApiClient(
      basePath: serverUrl.isEmpty ? 'http://127.0.0.1:8080' : serverUrl);
  runApp(
    MultiProvider(
      providers: [
        Provider<HealthApi>.value(value: HealthApi(client)),
        ...serverUrl.isEmpty ? _demo() : _server(client),
      ],
      child: const HandballApp(),
    ),
  );
}

/// Teams and games from the server (Bauplan step 6 and 7).
List<Provider> _server(ApiClient client) => [
      Provider<GameSource>.value(value: ApiGameSource(client)),
      Provider<TeamSource>.value(value: ApiTeamSource(client)),
    ];

/// TV Mettmann from memory, team link /team/tvm/k7Qp2xVz9LmA4tRb.
List<Provider> _demo() {
  final games = DemoGameSource();
  return [
    Provider<GameSource>.value(value: games),
    Provider<TeamSource>.value(value: DemoTeamSource(games)),
  ];
}

class HandballApp extends StatefulWidget {
  const HandballApp({super.key, this.initialLocation = '/'});

  /// Start address, used by tests, e.g. '/spiel/17/live'.
  final String initialLocation;

  @override
  State<HandballApp> createState() => _HandballAppState();
}

class _HandballAppState extends State<HandballApp> {
  late final GoRouter _router = createRouter(
    context.read<GameSource>(),
    initialLocation: widget.initialLocation,
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Handball-Live-Statistik',
      theme: buildHallTheme(),
      routerConfig: _router,
    );
  }
}
