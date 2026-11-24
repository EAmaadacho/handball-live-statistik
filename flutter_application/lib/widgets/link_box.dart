import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// The full address of [path] in this app, e.g.
/// "https://handball.example/spiel/ydVsnTnc/live" for "/spiel/ydVsnTnc/live".
/// In tests, where the app has no web address, just [path].
String appLink(String path) {
  final base = Uri.base;
  return base.scheme.startsWith('http') ? '${base.origin}$path' : path;
}

/// Copies the full address of [path] and says so, e.g. for "Zuschauer-Link
/// kopieren" in the team management (S1.3).
Future<void> copyLink(BuildContext context, String path, String what) async {
  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(ClipboardData(text: appLink(path)));
  messenger.showSnackBar(SnackBar(content: Text('$what kopiert.')));
}

/// A link to keep, with a button to copy it (T1, S1.2).
///
/// Example: "Ticker-Link" with /spiel/ydVsnTnc/ticker/x9Fw3cNs7Ke2Hy5D.
class LinkBox extends StatelessWidget {
  const LinkBox(
      {super.key, required this.label, required this.path, this.hint});

  final String label;
  final String path;

  /// e.g. "Nur für die Person, die tickert."
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  SelectableText(appLink(path),
                      key: Key('Link-$label'),
                      style: theme.textTheme.bodySmall),
                  if (hint != null) ...[
                    const SizedBox(height: 4),
                    Text(hint!,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
            IconButton(
              key: Key('Copy-$label'),
              tooltip: '$label kopieren',
              icon: const Icon(Icons.copy),
              onPressed: () => copyLink(context, path, label),
            ),
          ],
        ),
      ),
    );
  }
}
