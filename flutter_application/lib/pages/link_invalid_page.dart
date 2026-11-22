import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Shown for a wrong or outdated link instead of an empty screen (T1.3).
class LinkInvalidPage extends StatelessWidget {
  const LinkInvalidPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Link ungültig',
                      key: const Key('LinkInvalidTitle'),
                      style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 12),
                  Text(
                    'Dieser Link ist falsch oder nicht mehr gültig. Prüf, ob du ihn '
                    'vollständig kopiert hast. Den richtigen Link bekommst du von der '
                    'Person, die das Spiel oder Team angelegt hat.',
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Zur Startseite'),
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
