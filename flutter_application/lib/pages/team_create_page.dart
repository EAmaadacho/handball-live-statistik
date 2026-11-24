import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/game_source.dart';
import '../data/team_source.dart';
import '../widgets/form_scaffold.dart';
import '../widgets/link_box.dart';
import '../widgets/team_name_fields.dart';

/// "Team anlegen" (T1): name as in nuLiga, then the secret team link.
///
/// Example: TV Mettmann, Männer, 2, TVM → "TV Mettmann Männer II" with the
/// link /team/8oAL6f58/k7Qp2xVz9LmA4tRb. "TV Mettmann Männer" a second
/// time is refused by the server (T1.1).
class TeamCreatePage extends StatefulWidget {
  const TeamCreatePage({super.key});

  @override
  State<TeamCreatePage> createState() => _TeamCreatePageState();
}

class _TeamCreatePageState extends State<TeamCreatePage> {
  final _input = TeamNameInput();
  String? _error;
  bool _sending = false;

  /// The team link once the team exists, e.g. /team/8oAL6f58/k7Qp….
  String? _teamLink;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final problem = _input.problem;
    if (problem != null) return setState(() => _error = problem);
    setState(() => _sending = true);
    try {
      final team = await context
          .read<TeamSource>()
          .createTeam(_input.name, _input.shortName.text);
      setState(() => _teamLink = '/team/${team.teamId}/${team.code}');
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
    final link = _teamLink;
    if (link != null) return _created(link);
    return FormScaffold(
      title: 'Team anlegen',
      children: [
        TeamNameFields(input: _input),
        const SizedBox(height: 20),
        FilledButton(
          key: const Key('CreateTeamSubmit'),
          onPressed: _sending ? null : _create,
          child: const Text('Team anlegen'),
        ),
        FormError(_error),
      ],
    );
  }

  /// "Dein Team-Link": only this link opens the team management (T1.2).
  Widget _created(String link) => FormScaffold(
        title: 'Dein Team-Link',
        children: [
          Text('${_input.name.display} ist angelegt.',
              key: const Key('TeamCreated'),
              style: Theme.of(context).textTheme.titleLarge),
          LinkBox(
            label: 'Team-Link',
            path: link,
            hint: 'Gut aufheben und nur im Trainerteam teilen: '
                'Ohne diesen Link kommst du nicht in die Teamverwaltung.',
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('ToTeam'),
            onPressed: () => context.go(link),
            child: const Text('Zur Teamverwaltung'),
          ),
        ],
      );
}
