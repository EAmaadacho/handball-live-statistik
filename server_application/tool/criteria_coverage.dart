// Reports which Muss criteria from docs/user-stories.md have an acceptance
// test and which a unit test.
// Run from server_application: dart run tool/criteria_coverage.dart
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
/// With [onlyWidgetTests] only `testWidgets(...)` counts.
Set<String> testedIds(Iterable<String> testSources,
    {bool onlyWidgetTests = false}) {
  final kind = onlyWidgetTests ? 'testWidgets' : '(?:test|testWidgets)';
  final testName = RegExp(kind + r'''\(\s*['"]([A-Z]\d+(?:_\d+)?) ''');
  return {
    for (final source in testSources)
      for (final match in testName.allMatches(source)) match.group(1)!,
  };
}

/// Reads all test files below [folders], e.g. "test/domain/team_test.dart".
Iterable<File> testFiles(List<String> folders) sync* {
  for (final folder in folders) {
    for (final file in Directory(folder).listSync(recursive: true)) {
      if (file is File && file.path.endsWith('_test.dart')) yield file;
    }
  }
}

/// Acceptance tests live in a folder "acceptance". Widget tests of the app
/// count as acceptance tests too, because they open a page and check what
/// the user sees (e.g. E1.4). All other tests are unit tests.
bool isAcceptanceTest(File file) =>
    file.uri.pathSegments.contains('acceptance');

void main() {
  final required =
      requiredIds(File('../docs/user-stories.md').readAsStringSync());
  final files = testFiles(['test', '../flutter_application/test']).toList();
  final acceptance = {
    ...testedIds([
      for (final file in files.where(isAcceptanceTest)) file.readAsStringSync(),
    ]),
    ...testedIds([
      for (final file in files.where((file) => !isAcceptanceTest(file)))
        file.readAsStringSync(),
    ], onlyWidgetTests: true),
  };
  final unit = testedIds([
    for (final file in files.where((file) => !isAcceptanceTest(file)))
      file.readAsStringSync(),
  ]);
  final open = required.where((id) => !acceptance.contains(id)).toList();

  int count(Set<String> tested) => required.where(tested.contains).length;
  final report = StringBuffer()
    ..writeln('## Muss-Kriterien')
    ..writeln()
    ..writeln(
        '- mit Akzeptanztest: ${count(acceptance)} von ${required.length}')
    ..writeln('- mit Unit-Test: ${count(unit)} von ${required.length}')
    ..writeln()
    ..writeln(open.isEmpty
        ? 'Alle Muss-Kriterien haben einen Akzeptanztest.'
        : 'Ohne Akzeptanztest: ${open.join(', ')}');

  stdout.write(report);
  final summary = Platform.environment['GITHUB_STEP_SUMMARY'];
  if (summary != null) {
    File(summary).writeAsStringSync('$report', mode: FileMode.append);
  }
}
