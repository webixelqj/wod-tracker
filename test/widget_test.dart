import 'package:flutter_test/flutter_test.dart';
import 'package:wod_tracker/models/record.dart';
import 'package:wod_tracker/utils/format.dart';

void main() {
  test('formats et saisie des temps', () {
    expect(fmtTime(272), '4:32');
    expect(parseValue('4:32', 'sec'), 272);
    expect(parseValue('42,5', 'kg'), 42.5);
    expect(fmtNum(42.5), '42,5');
  });

  test('le record reste la meilleure valeur après une reprise', () {
    final m = Movement(name: 'Back Squat', history: [
      RecordEntry(DateTime(2026, 1, 1), 100),
      RecordEntry(DateTime(2026, 6, 1), 85),
    ]);
    expect(m.best, 100);
    expect(Movement.better('sec', 260, 272), isTrue);
  });
}
