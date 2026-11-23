import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import 'court.dart' show fieldPlaces;

/// Who goes on [place] in the starting lineup (E5.1)?
///
/// Lists the match report of [side], e.g. "7 Max Mustermann · RL" when Max
/// already stands on RL; choosing him moves him to the new place.
Future<String?> choosePlayerForPlace(BuildContext context, GameState state,
    Side side, int place, List<String?> lineup) {
  final team = state.game.team(side);
  return _chooseFrom(
    context,
    title: '${fieldPlaces[place]} bei ${team.name}',
    entries: [
      for (final id in state.reportOf(side))
        (
          team.player(id),
          [
            if (team.player(id).isGoalkeeper) 'Torwart',
            if (lineup.contains(id))
              'steht auf ${fieldPlaces[lineup.indexOf(id)]}',
          ].join(' · ')
        ),
    ],
  );
}

/// Which squad player of a registered team is registered late (S1.4)?
///
/// Example: Leon and Luca of TV Mettmann are not on the match report yet.
/// Returns null when cancelled or when there is nobody left.
Future<String?> chooseLatePlayer(
    BuildContext context, GameState state, Side side) {
  final team = state.game.team(side);
  final report = state.reportOf(side);
  return _chooseFrom(
    context,
    title: 'Nachmelden für ${team.name}',
    empty: 'Alle Spieler des Kaders stehen schon im Spielbericht.',
    entries: [
      for (final p in team.players)
        if (!report.contains(p.id)) (p, p.isGoalkeeper ? 'Torwart' : ''),
    ],
  );
}

Future<String?> _chooseFrom(BuildContext context,
    {required String title,
    required List<(Player, String)> entries,
    String? empty}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 480),
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: ListView(
          key: const Key('PlayerChoice'),
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            if (entries.isEmpty && empty != null)
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Text(empty)),
            for (final (p, note) in entries)
              ListTile(
                key: Key('Pick-${p.id}'),
                title: Text('${p.number} ${p.firstName} ${p.lastName}'),
                subtitle: note.isEmpty ? null : Text(note),
                onTap: () => Navigator.of(context).pop(p.id),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

/// A new player for an opponent without registration (S1.1, S1.4).
typedef NewPlayer = ({int number, String firstName, String lastName});

/// Asks for number, first and last name, e.g. 20, Ole, Brandt.
/// Returns null when cancelled.
Future<NewPlayer?> enterNewPlayer(BuildContext context, Team team) {
  return showDialog<NewPlayer>(
    context: context,
    builder: (context) => _NewPlayerDialog(team: team),
  );
}

class _NewPlayerDialog extends StatefulWidget {
  const _NewPlayerDialog({required this.team});

  final Team team;

  @override
  State<_NewPlayerDialog> createState() => _NewPlayerDialogState();
}

class _NewPlayerDialogState extends State<_NewPlayerDialog> {
  final _number = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _number.dispose();
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  /// Number 1–99 and both names are required; the server checks the rest.
  void _submit() {
    final number = int.tryParse(_number.text.trim());
    final first = _firstName.text.trim();
    final last = _lastName.text.trim();
    if (number == null || number < 1 || number > 99) {
      setState(() => _error = 'Bitte eine Nummer von 1 bis 99 eingeben.');
    } else if (first.isEmpty || last.isEmpty) {
      setState(() => _error = 'Bitte Vor- und Nachname eingeben.');
    } else {
      Navigator.of(context)
          .pop((number: number, firstName: first, lastName: last));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Nachmelden für ${widget.team.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              key: const Key('NewPlayerNumber'),
              controller: _number,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Nummer')),
          TextField(
              key: const Key('NewPlayerFirstName'),
              controller: _firstName,
              decoration: const InputDecoration(labelText: 'Vorname')),
          TextField(
              key: const Key('NewPlayerLastName'),
              controller: _lastName,
              decoration: const InputDecoration(labelText: 'Nachname')),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen')),
        FilledButton(
            key: const Key('NewPlayerSave'),
            onPressed: _submit,
            child: const Text('Nachmelden')),
      ],
    );
  }
}
