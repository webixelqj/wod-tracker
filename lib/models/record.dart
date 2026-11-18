class RecordEntry {
  final DateTime date;
  final double value; // kg, reps ou secondes selon l'unité du mouvement
  RecordEntry(this.date, this.value);

  Map<String, dynamic> toJson() => {'date': date.toIso8601String(), 'value': value};
  factory RecordEntry.fromJson(Map<String, dynamic> j) =>
      RecordEntry(DateTime.parse(j['date']), (j['value'] as num).toDouble());
}

class Movement {
  final String name;
  final String unit; // kg, reps, sec (pour un temps, plus bas = meilleur)
  final List<RecordEntry> history;

  Movement({required this.name, this.unit = 'kg', List<RecordEntry>? history})
      : history = history ?? [];

  /// Vrai si [value] bat [than] (ou s'il n'y a pas encore de record).
  static bool better(String unit, double value, double? than) =>
      than == null || (unit == 'sec' ? value < than : value > than);

  /// Le record : la meilleure valeur de l'historique, même après une reprise plus faible.
  RecordEntry? get bestEntry {
    RecordEntry? b;
    for (final e in history) {
      if (b == null || better(unit, e.value, b.value)) b = e;
    }
    return b;
  }

  double? get best => bestEntry?.value;

  void sortHistory() => history.sort((a, b) => a.date.compareTo(b.date));

  Map<String, dynamic> toJson() => {
        'name': name,
        'unit': unit,
        'history': history.map((e) => e.toJson()).toList(),
      };

  factory Movement.fromJson(Map<String, dynamic> j) => Movement(
        name: j['name'],
        unit: j['unit'] ?? 'kg',
        history: (j['history'] as List? ?? [])
            .map((e) => RecordEntry.fromJson(e))
            .toList(),
      );
}

const defaultMovements = [
  'Back Squat', 'Front Squat', 'Overhead Squat', 'Deadlift',
  'Clean', 'Clean & Jerk', 'Snatch', 'Push Press', 'Strict Press', 'Bench Press',
];
