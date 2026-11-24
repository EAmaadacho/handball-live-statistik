import 'package:material_ui/material_ui.dart';

/// Page frame for the forms: title bar and a column at most 560 wide,
/// so the form does not stretch across a large screen.
class FormScaffold extends StatelessWidget {
  const FormScaffold({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            // Forms are short: build everything at once, so every field
            // keeps its input while scrolling.
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The server's or the form's reason in red, e.g. "Die Nummer 7 ist schon
/// vergeben."; nothing when [text] is null.
class FormError extends StatelessWidget {
  const FormError(this.text, {super.key});

  final String? text;

  @override
  Widget build(BuildContext context) {
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(text!,
          key: const Key('FormError'),
          style: TextStyle(color: Theme.of(context).colorScheme.error)),
    );
  }
}
