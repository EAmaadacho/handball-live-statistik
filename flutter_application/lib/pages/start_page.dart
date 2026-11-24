import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openapi/api.dart';
import 'package:provider/provider.dart';

/// Start page (T1): "Team anlegen" leads to the form.
///
/// Below, a small line says whether the server answers GET /health with
/// {"status": "ok"}: "Server erreichbar".
class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Handball-Live-Statistik')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Dein Spiel live',
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    'Leg dein Team an, pfleg den Kader und tickere eure '
                    'Spiele. Eltern und Fans sehen Spielstand und Statistik '
                    'live im Browser.',
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('CreateTeam'),
                    onPressed: () => context.push('/team-neu'),
                    child: const Text('Team anlegen'),
                  ),
                  const SizedBox(height: 24),
                  FutureBuilder<bool>(
                    future: _serverIsUp,
                    builder: (context, snapshot) => Text(
                      !snapshot.hasData
                          ? 'Server wird gefragt …'
                          : snapshot.data!
                              ? 'Server erreichbar'
                              : 'Server nicht erreichbar',
                      key: snapshot.hasData
                          ? const Key('ServerStatusText')
                          : null,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
