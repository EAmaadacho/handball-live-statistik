import 'package:material_ui/material_ui.dart';

import '../data/team_source.dart';

/// The values of [TeamNameFields] while the user types.
class TeamNameInput {
  final club = TextEditingController();
  final shortName = TextEditingController();
  AgeGroup ageGroup = AgeGroup.men;
  int teamNumber = 1;

  TeamName get name => TeamName(
      club: club.text.trim(), ageGroup: ageGroup, teamNumber: teamNumber);

  /// Why the input is not complete yet, or null, e.g. "Bitte den Verein
  /// eingeben." The server checks the same again (T1).
  String? get problem {
    if (club.text.trim().isEmpty) return 'Bitte den Verein eingeben.';
    final length = shortName.text.trim().length;
    if (length < 2 || length > 4) return 'Das Kürzel braucht 2 bis 4 Zeichen.';
    return null;
  }

  void dispose() {
    club.dispose();
    shortName.dispose();
  }
}

/// Club, age group, team number and short name, as in nuLiga (T1, S1).
///
/// Used for the own team and for the opponent; below the fields the full
/// name, e.g. "TV Mettmann Männer II".
class TeamNameFields extends StatefulWidget {
  const TeamNameFields({super.key, required this.input, this.prefix = ''});

  final TeamNameInput input;

  /// Key prefix for tests, e.g. "Opponent".
  final String prefix;

  @override
  State<TeamNameFields> createState() => _TeamNameFieldsState();
}

class _TeamNameFieldsState extends State<TeamNameFields> {
  TeamNameInput get _in => widget.input;

  @override
  Widget build(BuildContext context) {
    final p = widget.prefix;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: Key('${p}Club'),
          controller: _in.club,
          decoration: const InputDecoration(
              labelText: 'Verein', hintText: 'z. B. TV Mettmann'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<AgeGroup>(
          key: Key('${p}AgeGroup'),
          isExpanded: true,
          initialValue: _in.ageGroup,
          decoration: const InputDecoration(labelText: 'Mannschaft'),
          items: [
            for (final group in AgeGroup.values)
              DropdownMenuItem(value: group, child: Text(group.label)),
          ],
          onChanged: (group) => setState(() => _in.ageGroup = group!),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                key: Key('${p}TeamNumber'),
                isExpanded: true,
                initialValue: _in.teamNumber,
                decoration: const InputDecoration(labelText: 'Nummer'),
                items: [
                  for (var n = 1; n <= 9; n++)
                    DropdownMenuItem(
                        value: n,
                        child: Text(n == 1
                            ? '1 (ohne Zusatz)'
                            : '$n (${TeamName.romanNumber(n)})')),
                ],
                onChanged: (n) => setState(() => _in.teamNumber = n!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                key: Key('${p}ShortName'),
                controller: _in.shortName,
                maxLength: 4,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                    labelText: 'Kürzel',
                    hintText: 'z. B. TVM',
                    counterText: ''),
              ),
            ),
          ],
        ),
        if (_in.club.text.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_in.name.display,
                key: Key('${p}TeamNamePreview'),
                style: Theme.of(context).textTheme.titleMedium),
          ),
      ],
    );
  }
}
