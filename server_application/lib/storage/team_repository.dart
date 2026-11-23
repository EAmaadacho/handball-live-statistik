import 'dart:convert';
import 'dart:io';

import '../domain/team.dart';
import '../domain/team_name.dart';
import 'team_json.dart';

/// Keeps all teams in memory and writes them to data/teams.json after
/// every change (ADR-004).
///
/// Example: `TeamRepository.open('data/teams.json')` loads the teams that
/// were saved before the server restarted.
class TeamRepository {
  final File _file;
  final Map<String, Team> _teams;

  TeamRepository._(this._file, this._teams);

  /// Loads the teams from [path]. A missing file means: no teams yet.
  factory TeamRepository.open(String path) {
    final file = File(path);
    final teams = <String, Team>{};
    if (file.existsSync()) {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      json.forEach((id, team) {
        teams[id] = teamFromJson(team as Map<String, Object?>);
      });
    }
    return TeamRepository._(file, teams);
  }

  /// The team with [id], or `null`.
  Team? byId(String id) => _teams[id];

  /// Whether another team already has this name, e.g. "tv mettmann" Männer
  /// next to TV Mettmann Männer (T1.1). The team [exceptId] does not count.
  bool isNameTaken(TeamName name, {String? exceptId}) => _teams.entries
      .any((e) => e.key != exceptId && e.value.name.isSameTeamAs(name));

  /// Stores [team] under [id] and writes the file.
  void save(String id, Team team) {
    _teams[id] = team;
    _write();
  }

  /// Writes to teams.json.tmp first and then renames it, so the file is
  /// never left half written, e.g. if the server stops while writing.
  void _write() {
    final json = {
      for (final entry in _teams.entries) entry.key: teamToJson(entry.value),
    };
    _file.parent.createSync(recursive: true);
    final tmp = File('${_file.path}.tmp');
    tmp.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
    tmp.renameSync(_file.path);
  }
}
