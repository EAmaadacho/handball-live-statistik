import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../data/team_source.dart';

/// What the user chose in [showSquadPlayerDialog]: save [entry] or remove.
typedef SquadPlayerChoice = ({SquadEntry? entry, bool remove});

/// Adds a player to the squad or changes one (T2).
///
/// Number 1–99, first and last name, field player or goalkeeper. For an
/// existing [player] there is also "Entfernen", after asking again.
/// Returns null when cancelled.
Future<SquadPlayerChoice?> showSquadPlayerDialog(BuildContext context,
    {Player? player}) {
  return showDialog<SquadPlayerChoice>(
    context: context,
    builder: (context) => _SquadPlayerDialog(player: player),
  );
}

class _SquadPlayerDialog extends StatefulWidget {
  const _SquadPlayerDialog({this.player});

  final Player? player;

  @override
  State<_SquadPlayerDialog> createState() => _SquadPlayerDialogState();
}

class _SquadPlayerDialogState extends State<_SquadPlayerDialog> {
  late final _number =
      TextEditingController(text: widget.player?.number.toString());
  late final _firstName = TextEditingController(text: widget.player?.firstName);
  late final _lastName = TextEditingController(text: widget.player?.lastName);
  late bool _goalkeeper = widget.player?.isGoalkeeper ?? false;
  String? _error;

  @override
  void dispose() {
    _number.dispose();
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  /// The server checks again, e.g. that the number is still free (T2.1).
  void _save() {
    final number = int.tryParse(_number.text.trim());
    if (number == null || number < 1 || number > 99) {
      return setState(
          () => _error = 'Bitte eine Nummer von 1 bis 99 eingeben.');
    }
    if (_firstName.text.trim().isEmpty || _lastName.text.trim().isEmpty) {
      return setState(() => _error = 'Bitte Vor- und Nachnamen eingeben.');
    }
    Navigator.of(context).pop((
      entry: SquadEntry(
          number: number,
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          isGoalkeeper: _goalkeeper),
      remove: false,
    ));
  }

  Future<void> _remove() async {
    final p = widget.player!;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Spieler entfernen?'),
        content: Text('${p.number} ${p.firstName} ${p.lastName} verlässt den '
            'Kader. In alten Spielen bleibt er im Spielbericht.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Abbrechen')),
          FilledButton(
              key: const Key('ConfirmRemovePlayer'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Entfernen')),
        ],
      ),
    );
    if (sure == true && mounted) {
      Navigator.of(context).pop((entry: null, remove: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title:
          Text(widget.player == null ? 'Spieler hinzufügen' : 'Spieler ändern'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              key: const Key('SquadNumber'),
              controller: _number,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Nummer')),
          TextField(
              key: const Key('SquadFirstName'),
              controller: _firstName,
              decoration: const InputDecoration(labelText: 'Vorname')),
          TextField(
              key: const Key('SquadLastName'),
              controller: _lastName,
              decoration: const InputDecoration(labelText: 'Nachname')),
          const SizedBox(height: 8),
          SwitchListTile(
            key: const Key('SquadGoalkeeper'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Torwart'),
            value: _goalkeeper,
            onChanged: (value) => setState(() => _goalkeeper = value),
          ),
          if (_error != null)
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ),
      actions: [
        if (widget.player != null)
          TextButton(
              key: const Key('RemovePlayer'),
              onPressed: _remove,
              child: const Text('Entfernen')),
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen')),
        FilledButton(
            key: const Key('SquadSave'),
            onPressed: _save,
            child: const Text('Speichern')),
      ],
    );
  }
}
