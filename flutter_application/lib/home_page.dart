import 'package:material_ui/material_ui.dart';
import 'package:openapi/api.dart';
import 'package:provider/provider.dart';

/// Placeholder start page: asks the server once whether it is running.
///
/// Example: the server answers GET /health with {"status": "ok"},
/// so the page shows "Server erreichbar".
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Future<bool> _serverIsUp;

  @override
  void initState() {
    super.initState();
    _serverIsUp = _checkServer(context.read<HealthApi>());
  }

  static Future<bool> _checkServer(HealthApi api) async {
    try {
      final health = await api.getHealth();
      return health?.status == 'ok';
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Handball-Live-Statistik'),
      ),
      body: Center(
        child: FutureBuilder<bool>(
          future: _serverIsUp,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const CircularProgressIndicator();
            }
            return Text(
              snapshot.data! ? 'Server erreichbar' : 'Server nicht erreichbar',
              key: const Key('ServerStatusText'),
            );
          },
        ),
      ),
    );
  }
}
