import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openapi/api.dart';
import 'package:provider/provider.dart';

import 'data/demo_game_source.dart';
import 'data/game_source.dart';
import 'router.dart';
import 'theme/app_theme.dart';

/// Address of the Dart server, see server_application/bin/server.dart.
const serverUrl = 'http://127.0.0.1:8080';

void main() {
  // Addresses without "#", so a link looks like /spiel/17/live (ADR-005).
  usePathUrlStrategy();
  final api = HealthApi(ApiClient(basePath: serverUrl));
  runApp(
    MultiProvider(
      providers: [
        Provider<HealthApi>.value(value: api),
        // Example data until the server endpoints exist (Bauplan step 7).
        Provider<GameSource>.value(value: DemoGameSource()),
      ],
      child: const HandballApp(),
    ),
  );
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
