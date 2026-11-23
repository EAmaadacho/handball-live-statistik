import 'package:material_ui/material_ui.dart';

import '../data/models.dart';

/// Who goes in goal after the goalkeeper got 2 minutes or red (E5.6)?
///
/// Example for Mettmann: "16 Mia Schröder (Torwart, Bank)" or a field
/// player, or "Tor bleibt leer" (E1.5). Returns the chosen player id,
/// null for an empty goal.
Future<String?> chooseGoalkeeper(
    BuildContext context, GameState state, Side side) {
  final team = state.game.team(side);
  final fromBench = [
    for (final id in state.bench[side]!)
      if (team.player(id).isGoalkeeper) team.player(id)
  ];
  final fromField = [
    for (final id in state.onField(side)) team.player(id),
  ];
  return _choosePlayer(
      context,
      'Wer geht ins Tor?',
      [
        for (final p in fromBench) (p, 'Torwart, Bank'),
        for (final p in fromField) (p, 'Feldspieler'),
      ],
      emptyChoice: 'Tor bleibt leer');
}

/// Which field player leaves for the goalkeeper from the bench (E5.6)?
Future<String?> chooseWhoLeaves(
    BuildContext context, GameState state, Side side) {
  final team = state.game.team(side);
  return _choosePlayer(
      context,
      'Wer geht dafür vom Feld?',
      [
        for (final id in state.onField(side)) (team.player(id), 'Feldspieler'),
      ],
      emptyChoice: 'Abbrechen, Tor bleibt leer');
}

Future<String?> _choosePlayer(
    BuildContext context, String title, List<(Player, String)> players,
    {String? emptyChoice}) {
  return showModalBottomSheet<String>(
    context: context,
    isDismissible: false,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 480),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          key: Key('Choose-$title'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            for (final (p, role) in players)
              ListTile(
                key: Key('Choose-${p.id}'),
                title: Text('${p.number} ${p.firstName} ${p.lastName}'),
                subtitle: Text(role),
                onTap: () => Navigator.of(context).pop(p.id),
              ),
            if (emptyChoice != null)
              ListTile(
                key: const Key('Choose-empty'),
                title: Text(emptyChoice),
                onTap: () => Navigator.of(context).pop(),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

/// How does a field player come in on the goal place (IHF rule 4:7)?
///
/// "Als Torwart" (with goalkeeper shirt): saves and goals against count for
/// them. "Als Feldspieler": the goal stays empty (E1.5). With 7 on the field
/// that is a 7th field player, while short-handed a 6th.
/// Returns true, false, or null when cancelled.
Future<bool?> chooseGoalRole(BuildContext context, Player player) {
  return showModalBottomSheet<bool>(
    context: context,
    constraints: const BoxConstraints(maxWidth: 480),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text('Wie spielt ${player.number} ${player.firstName}?',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          ListTile(
            key: const Key('Role-goalkeeper'),
            title: const Text('Als Torwart'),
            subtitle: const Text(
                'Mit Torwarttrikot. Paraden und Gegentore zählen dann mit.'),
            onTap: () => Navigator.of(context).pop(true),
          ),
          ListTile(
            key: const Key('Role-fieldPlayer'),
            title: const Text('Als Feldspieler'),
            subtitle: const Text(
                'Das Tor bleibt leer, ein Feldspieler mehr greift an.'),
            onTap: () => Navigator.of(context).pop(false),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
