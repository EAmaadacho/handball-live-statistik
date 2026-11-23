// Reports which Muss acceptance criteria from docs/user-stories.md have no
// test yet. Run from server_application: dart run tool/criteria_coverage.dart
import 'dart:io';

/// Finds the IDs that must be covered by a test, in test-name form.
///
/// Every criterion of a Muss story counts, e.g. "E2.1" becomes "E2_1".
/// A Muss story without criteria counts as a whole, e.g. "R2".
/// Kann stories are ignored.
List<String> requiredIds(String userStories) {
  final storyLine = RegExp(r'^- .*\*\*([A-Z]\d+) \((Muss|Kann)\)\*\*');
  final criterionLine =
      RegExp(r'^  - (?:<a id="[^"]*"></a>)?([A-Z]\d+)\.(\d+) ');

  final ids = <String>[];
  String? story;
  var isMuss = false;
  var hasCriteria = false;

  void finishStory() {
    if (story != null && isMuss && !hasCriteria) ids.add(story);
  }

  for (final line in userStories.split('\n')) {
    final storyMatch = storyLine.firstMatch(line);
    if (storyMatch != null) {
      finishStory();
      story = storyMatch.group(1);
      isMuss = storyMatch.group(2) == 'Muss';
      hasCriteria = false;
      continue;
    }
    final criterionMatch = criterionLine.firstMatch(line);
    if (criterionMatch != null && criterionMatch.group(1) == story) {
      hasCriteria = true;
      if (isMuss) {
        ids.add('${criterionMatch.group(1)}_${criterionMatch.group(2)}');
      }
    }
  }
  finishStory();
  return ids;
}

/// Finds the IDs at the start of test names, e.g. "E2_1" in
/// `test('E2_1 deleting Max's goal at 12:11 shows 11:11', ...)`.
Set<String> testedIds(Iterable<String> testSources) {
  final testName =
      RegExp(r'''(?:test|testWidgets)\(\s*['"]([A-Z]\d+(?:_\d+)?) ''');
  return {
    for (final source in testSources)
      for (final match in testName.allMatches(source)) match.group(1)!,
  };
}

void main() {
  final required =
      requiredIds(File('../docs/user-stories.md').readAsStringSync());
  final tested = testedIds([
    for (final folder in ['test', '../flutter_application/test'])
      for (final file in Directory(folder).listSync(recursive: true))
        if (file is File && file.path.endsWith('_test.dart'))
          file.readAsStringSync(),
  ]);
  final open = required.where((id) => !tested.contains(id)).toList();

  final report = StringBuffer()
    ..writeln('## Muss-Kriterien mit Test: '
        '${required.length - open.length} von ${required.length}')
    ..writeln()
    ..writeln(open.isEmpty
        ? 'Alle Muss-Kriterien haben einen Test.'
        : 'Offen: ${open.join(', ')}');

  stdout.write(report);
  final summary = Platform.environment['GITHUB_STEP_SUMMARY'];
  if (summary != null) {
    File(summary).writeAsStringSync('$report', mode: FileMode.append);
  }
}
