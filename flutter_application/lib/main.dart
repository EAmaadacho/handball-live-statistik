import 'package:material_ui/material_ui.dart';
import 'package:openapi/api.dart';
import 'package:provider/provider.dart';

import 'home_page.dart';

/// Address of the Dart server, see server_application/bin/server.dart.
const serverUrl = 'http://127.0.0.1:8080';

void main() {
  final api = HealthApi(ApiClient(basePath: serverUrl));
  runApp(
    Provider<HealthApi>(
      create: (_) => api,
      child: const HandballApp(),
    ),
  );
}

class HandballApp extends StatelessWidget {
  const HandballApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Handball-Live-Statistik',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
