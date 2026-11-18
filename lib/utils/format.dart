import 'package:intl/intl.dart';

/// 42.5 -> "42,5" ; 100 -> "100"
String fmtNum(double? v) {
  if (v == null) return '—';
  final r = (v * 10).round() / 10;
  final s = r % 1 == 0 ? r.toInt().toString() : r.toStringAsFixed(1);
  return s.replaceAll('.', ',');
}

/// 272 -> "4:32"
String fmtTime(num seconds) {
  final t = seconds.round();
  return '${t ~/ 60}:${(t % 60).toString().padLeft(2, '0')}';
}

/// Valeur d'un record selon son unité (kg, reps, sec).
String fmtValue(double v, String unit) => switch (unit) {
      'kg' => '${fmtNum(v)} kg',
      'reps' => '${v.round()} reps',
      _ => fmtTime(v),
    };

/// Texte saisi -> valeur. Accepte "4:32" pour les temps et la virgule décimale.
double? parseValue(String text, String unit) {
  final t = text.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  if (unit == 'sec') {
    final m = RegExp(r'^(\d+):(\d{1,2})$').firstMatch(t);
    if (m != null) return int.parse(m.group(1)!) * 60.0 + int.parse(m.group(2)!);
  }
  return double.tryParse(t);
}

/// Valeur -> texte éditable dans un champ.
String inputText(double? v, String unit) {
  if (v == null) return '';
  if (unit == 'sec') return fmtTime(v);
  return v % 1 == 0 ? v.toInt().toString() : v.toString();
}

String fmtShortDate(DateTime d) => DateFormat('EEE d MMM', 'fr').format(d);
String fmtLongDate(DateTime d) => DateFormat('EEEE d MMMM yyyy', 'fr').format(d);
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
