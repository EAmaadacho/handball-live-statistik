import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/game_source.dart';
import '../data/models.dart';
import '../data/team_source.dart';
import '../widgets/form_scaffold.dart';
import '../widgets/format.dart';
import '../widgets/link_box.dart';
import '../widgets/section_heading.dart';
import '../widgets/squad_player_dialog.dart';

/// Team management (T2, S1.3), opened with the secret team link
/// /team/{teamId}/{code}.
///
/// Example for TV Mettmann: the squad "1 Nora Neumann · Torwart, 7 Max
/// Mustermann · Feldspieler …" and the games with status and links.
class TeamPage extends StatefulWidget {
  const TeamPage({super.key, required this.teamId, required this.code});

  final String teamId;
  final String code;

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  Team? _team;
  List<TeamGame> _games = const [];
  String? _error;

  TeamSource get _source => context.read<TeamSource>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final team = await _source.loadTeam(widget.teamId, widget.code);
      final games = await _source.loadGames(widget.teamId, widget.code);
      if (!mounted) return;
      setState(() {
        _team = team;
        _games = games;
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Keine Verbindung zum Server.');
    }
  }

  /// Adds, changes or removes a player; the server answers with the squad.
  Future<void> _editPlayer([Player? player]) async {
    final choice = await showSquadPlayerDialog(context, player: player);
    if (choice == null || !mounted) return;
    final id = widget.teamId;
    final code = widget.code;
    try {
      final team = choice.remove
          ? await _source.removePlayer(id, code, player!.id)
          : player == null
              ? await _source.addPlayer(id, code, choice.entry!)
              : await _source.updatePlayer(id, code, player.id, choice.entry!);
      setState(() => _team = team);
    } on RejectedAction catch (e) {
      _message(e.message);
    } catch (_) {
      _message('Nicht gespeichert: keine Verbindung zum Server.');
    }
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(key: const Key('TeamMessage'), content: Text(text)));

  Future<void> _newGame() async {
    await context.push('/team/${widget.teamId}/${widget.code}/spiel-neu');
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final team = _team;
    if (team == null) {
      return Scaffold(body: Center(child: Text(_error ?? 'Lädt …')));
    }
    final players = [...team.players]
      ..sort((a, b) => a.number.compareTo(b.number));
    return FormScaffold(
      title: 'Teamverwaltung',
      children: [
        _Header(team: team),
        if (_error != null) FormError(_error),
        SectionHeading('Kader · ${players.length} Spieler'),
        for (final p in players)
          ListTile(
            key: Key('SquadPlayer-${p.id}'),
            leading: CircleAvatar(child: Text('${p.number}')),
            title: Text('${p.firstName} ${p.lastName}'),
            subtitle: Text(p.isGoalkeeper ? 'Torwart' : 'Feldspieler'),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _editPlayer(p),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('AddSquadPlayer'),
            icon: const Icon(Icons.add),
            label: const Text('Spieler hinzufügen'),
            onPressed: () => _editPlayer(),
          ),
        ),
        const SizedBox(height: 8),
        const SectionHeading('Spiele'),
        if (_games.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Noch keine Spiele angelegt.'),
          ),
        for (final g in _games) _GameCard(game: g),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('NewGame'),
          icon: const Icon(Icons.add),
          label: const Text('Spiel anlegen'),
          onPressed: _newGame,
        ),
      ],
    );
  }
}

/// Name of the team with its short name in a circle; the logo follows (T6).
class _Header extends StatelessWidget {
  const _Header({required this.team});

  final Team team;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: theme.colorScheme.primary,
            child: Text(team.shortName,
                style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(team.name,
                key: const Key('TeamName'),
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// One game: date, opponent, status, and its links (S1.3).
class _GameCard extends StatelessWidget {
  const _GameCard({required this.game});

  final TeamGame game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ticker = '/spiel/${game.id}/ticker/${game.tickerCode}';
    final live = '/spiel/${game.id}/live';
    return Card(
      key: Key('Game-${game.id}'),
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(formatDate(game.date),
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ),
                Chip(
                  label: Text(game.status.label),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Text('gegen ${game.opponent}', style: theme.textTheme.titleMedium),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  key: Key('OpenTicker-${game.id}'),
                  onPressed: () => context.go(ticker),
                  child: const Text('Ticker öffnen'),
                ),
                TextButton(
                  key: Key('CopyLive-${game.id}'),
                  onPressed: () => copyLink(context, live, 'Zuschauer-Link'),
                  child: const Text('Zuschauer-Link kopieren'),
                ),
                TextButton(
                  onPressed: () => copyLink(context, ticker, 'Ticker-Link'),
                  child: const Text('Ticker-Link kopieren'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
