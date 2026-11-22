import 'package:material_ui/material_ui.dart';

/// Stands in for a page that a later step builds.
///
/// Example: /spiel/17/live shows "Live" and "TV Mettmann – HSG Hilden"
/// until the live page is built in step 3.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage(
      {super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(subtitle, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}
