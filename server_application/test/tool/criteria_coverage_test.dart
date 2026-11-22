import 'package:test/test.dart';

import '../../tool/criteria_coverage.dart';

void main() {
  group('requiredIds', () {
    test('takes every criterion of a Muss story', () {
      const stories = '''
- <a id="e2"></a>**E2 (Muss)** Als Ticker lösche ich ein Ereignis.
  - <a id="e2-1"></a>E2.1 Lösche ich das Tor von Max bei 12:11, steht es 11:11.
  - <a id="e2-2"></a>E2.2 Die automatische Rote Karte fällt mit weg.
''';

      final ids = requiredIds(stories);

      expect(ids, ['E2_1', 'E2_2']);
    });

    test('takes a Muss story without criteria as a whole', () {
      const stories =
          '- <a id="r2"></a>**R2 (Muss)** Die dritte Zeitstrafe führt zu Rot.\n';

      final ids = requiredIds(stories);

      expect(ids, ['R2']);
    });

    test('ignores Kann stories and their criteria', () {
      const stories = '''
- <a id="t3"></a>**T3 (Kann)** Login mit Passwort.
  - <a id="t3-1"></a>T3.1 Das Passwort wird nur als Hash gespeichert.
''';

      final ids = requiredIds(stories);

      expect(ids, isEmpty);
    });
  });

  group('testedIds', () {
    // Uses the made-up IDs X1_1 and X2_1, because this file is scanned too
    // and real IDs here would count as tested.
    test('finds the ID at the start of test and widget test names', () {
      const source = '''
test('X1_1 deleting Max's goal at 12:11 shows 11:11', () {});
testWidgets("X2_1 shows players as '7 Max Mustermann'", (tester) async {});
test('root answers with the server name', () {});
''';

      final ids = testedIds([source]);

      expect(ids, {'X1_1', 'X2_1'});
    });
  });
}
