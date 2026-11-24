import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/game_source.dart';
import '../data/team_source.dart';
import '../widgets/form_scaffold.dart';
import '../widgets/format.dart';
import '../widgets/link_box.dart';
import '../widgets/section_heading.dart';
import '../widgets/team_name_fields.dart';

/// One row of the opponent's game squad while typing (S1.1).
class _SquadRow {
  final number = TextEditingController();
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  bool goalkeeper = false;

  bool get isEmpty =>
      number.text.trim().isEmpty &&
      firstName.text.trim().isEmpty &&
      lastName.text.trim().isEmpty;

  /// The row as a player, or null if something is missing.
  SquadEntry? get entry {
    final n = int.tryParse(number.text.trim());
    if (n == null || n < 1 || n > 99) return null;
    if (firstName.text.trim().isEmpty || lastName.text.trim().isEmpty) {
      return null;
    }
    return SquadEntry(
        number: n,
        firstName: firstName.text.trim(),
        lastName: lastName.text.trim(),
        isGoalkeeper: goalkeeper);
  }

  void dispose() {
    number.dispose();
    firstName.dispose();
    lastName.dispose();
  }
}

/// "Spiel anlegen" (S1): opponent, date, half length and the opponent's
/// game squad; afterwards ticker link and viewer link (S1.2).
///
/// Example: against HSG Hilden Männer (HSG) on Sunday at 15:00, 30 minutes,
/// with "1 Lukas Kern, Torwart", "5 Jan Becker" … in the game squad.
/// Fewer than 7 opponents are allowed here: they can still be added in the
/// ticker before kick-off (S1.1); the lineup needs 7.
class GameCreatePage extends StatefulWidget {
  const GameCreatePage({super.key, required this.teamId, required this.code});

  final String teamId;
  final String code;

  @override
  State<GameCreatePage> createState() => _GameCreatePageState();
}

class _GameCreatePageState extends State<GameCreatePage> {
  final _opponent = TeamNameInput();
  final _rows = [for (var i = 0; i < 7; i++) _SquadRow()];
  late DateTime _date = _nextFullHour();
  int _halfMinutes = 30;
  String? _error;
  bool _sending = false;
  TeamGame? _created;

  static DateTime _nextFullHour() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, now.hour + 1);
  }

  @override
  void dispose() {
    _opponent.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  List<SquadEntry> get _players => [
        for (final row in _rows)
          if (row.entry case final entry?) entry
      ];

  /// Why the form cannot be sent yet, or null.
  String? get _problem {
    if (_opponent.problem case final problem?) return problem;
    for (var i = 0; i < _rows.length; i++) {
      if (!_rows[i].isEmpty && _rows[i].entry == null) {
        return 'Spieler ${i + 1}: bitte Nummer (1–99), Vor- und Nachname '
            'eingeben.';
      }
    }
    final numbers = _players.map((p) => p.number).toList();
    for (final n in numbers) {
      if (numbers.where((m) => m == n).length > 1) {
        return 'Die Nummer $n steht zweimal im Spielkader.';
      }
    }
    return null;
  }

  Future<void> _pickDate() async {
    final day = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 1),
      lastDate: DateTime(_date.year + 2),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_date));
    if (!mounted) return;
    setState(() => _date = DateTime(day.year, day.month, day.day,
        time?.hour ?? _date.hour, time?.minute ?? _date.minute));
  }

  Future<void> _create() async {
    final problem = _problem;
    if (problem != null) return setState(() => _error = problem);
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final game = await context.read<TeamSource>().createGame(
            widget.teamId,
            widget.code,
            NewGameEntry(
              opponent: _opponent.name,
              opponentShortName: _opponent.shortName.text,
              date: _date,
              halfMinutes: _halfMinutes,
              opponentPlayers: _players,
            ),
          );
      setState(() => _created = game);
    } on RejectedAction catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(
          () => _error = 'Keine Verbindung zum Server. Bitte noch einmal.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_created case final game?) return _links(game);
    final complete = _players.length;
    return FormScaffold(
      title: 'Spiel anlegen',
      children: [
        const SectionHeading('Gegner'),
        const SizedBox(height: 12),
        TeamNameFields(input: _opponent, prefix: 'Opponent'),
        const SizedBox(height: 8),
        const SectionHeading('Termin'),
        ListTile(
          key: const Key('GameDate'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event),
          title: Text(formatDate(_date)),
          subtitle: const Text('Antippen zum Ändern'),
          onTap: _pickDate,
        ),
        DropdownButtonFormField<int>(
          key: const Key('HalfMinutes'),
          initialValue: _halfMinutes,
          decoration: const InputDecoration(labelText: 'Halbzeitlänge'),
          items: [
            for (final m in const [10, 15, 20, 25, 30])
              DropdownMenuItem(value: m, child: Text('$m Minuten')),
          ],
          onChanged: (m) => setState(() => _halfMinutes = m!),
        ),
        const SizedBox(height: 8),
        SectionHeading('Spielkader des Gegners · $complete Spieler'),
        for (var i = 0; i < _rows.length; i++) _squadRow(i),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('AddOpponentRow'),
            icon: const Icon(Icons.add),
            label: const Text('Spieler'),
            onPressed: () => setState(() => _rows.add(_SquadRow())),
          ),
        ),
        if (complete < 7)
          Text(
            'Für den Anpfiff braucht der Gegner mindestens 7 Spieler. '
            'Fehlende kannst du auch später im Ticker nachtragen.',
            key: const Key('SquadHint'),
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        const SizedBox(height: 20),
        FilledButton(
          key: const Key('CreateGameSubmit'),
          onPressed: _sending ? null : _create,
          child: const Text('Spiel anlegen'),
        ),
        FormError(_error),
      ],
    );
  }

  Widget _squadRow(int i) {
    final row = _rows[i];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: TextField(
              key: Key('OpponentNumber-$i'),
              controller: row.number,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Nr.'),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: Key('OpponentFirstName-$i'),
              controller: row.firstName,
              decoration: const InputDecoration(labelText: 'Vorname'),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: Key('OpponentLastName-$i'),
              controller: row.lastName,
              decoration: const InputDecoration(labelText: 'Nachname'),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Tooltip(
            message: 'Torwart',
            child: Checkbox(
              key: Key('OpponentGoalkeeper-$i'),
              value: row.goalkeeper,
              onChanged: (value) => setState(() => row.goalkeeper = value!),
            ),
          ),
        ],
      ),
    );
  }

  /// After creating: the two links of the game (S1.2).
  Widget _links(TeamGame game) {
    final ticker = '/spiel/${game.id}/ticker/${game.tickerCode}';
    return FormScaffold(
      title: 'Spiel angelegt',
      children: [
        Text('Gegen ${game.opponent} · ${formatDate(game.date)}',
            key: const Key('GameCreated'),
            style: Theme.of(context).textTheme.titleLarge),
        LinkBox(
          label: 'Ticker-Link',
          path: ticker,
          hint: 'Nur für die Person, die tickert.',
        ),
        LinkBox(
          label: 'Zuschauer-Link',
          path: '/spiel/${game.id}/live',
          hint: 'Für Eltern und Fans, z. B. in der Teamgruppe teilen.',
        ),
        const SizedBox(height: 20),
        FilledButton(
          key: const Key('ToTicker'),
          onPressed: () => context.go(ticker),
          child: const Text('Zum Ticker'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => context.pop(),
          child: const Text('Zurück zur Teamverwaltung'),
        ),
      ],
    );
  }
}
