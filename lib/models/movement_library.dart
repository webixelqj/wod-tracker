/// Type de saisie : détermine automatiquement les champs affichés.
enum InputKind {
  barbell,    // reps + charge libre (0-300 kg)
  kettlebell, // reps + poids KB standard
  dumbbell,   // reps + poids haltère standard
  bodyweight, // reps seulement
  cardio,     // distance, calories ou durée
  hold,       // durée
  benchmark,  // score global (temps ou reps)
}

const kettlebellWeights = <double>[4, 6, 8, 12, 16, 20, 24, 28, 32];
final dumbbellWeights = <double>[for (var i = 1; i <= 20; i++) i * 2.5];

class LibraryItem {
  final String name;
  final String category;
  final InputKind kind;
  const LibraryItem(this.name, this.category, this.kind);

  /// Unité utilisée pour les records.
  String get recordUnit => switch (kind) {
        InputKind.barbell || InputKind.kettlebell || InputKind.dumbbell => 'kg',
        InputKind.bodyweight => 'reps',
        _ => 'sec',
      };
}

const _b = InputKind.barbell, _k = InputKind.kettlebell, _d = InputKind.dumbbell,
    _w = InputKind.bodyweight, _c = InputKind.cardio, _h = InputKind.hold,
    _x = InputKind.benchmark;

// `final` : une liste const ne peut pas contenir de boucle `for`.
final movementLibrary = <LibraryItem>[
  // Haltérophilie
  LibraryItem('Snatch', 'Haltérophilie', _b),
  LibraryItem('Power Snatch', 'Haltérophilie', _b),
  LibraryItem('Hang Snatch', 'Haltérophilie', _b),
  LibraryItem('Clean', 'Haltérophilie', _b),
  LibraryItem('Power Clean', 'Haltérophilie', _b),
  LibraryItem('Hang Clean', 'Haltérophilie', _b),
  LibraryItem('Clean & Jerk', 'Haltérophilie', _b),
  LibraryItem('Split Jerk', 'Haltérophilie', _b),
  LibraryItem('Push Jerk', 'Haltérophilie', _b),
  LibraryItem('Thruster', 'Haltérophilie', _b),
  // Force
  LibraryItem('Back Squat', 'Force', _b),
  LibraryItem('Front Squat', 'Force', _b),
  LibraryItem('Overhead Squat', 'Force', _b),
  LibraryItem('Deadlift', 'Force', _b),
  LibraryItem('Sumo Deadlift High Pull', 'Force', _b),
  LibraryItem('Strict Press', 'Force', _b),
  LibraryItem('Push Press', 'Force', _b),
  LibraryItem('Bench Press', 'Force', _b),
  // Kettlebell
  LibraryItem('Kettlebell Swing', 'Kettlebell', _k),
  LibraryItem('Goblet Squat', 'Kettlebell', _k),
  LibraryItem('Turkish Get-up', 'Kettlebell', _k),
  LibraryItem('Kettlebell Snatch', 'Kettlebell', _k),
  // Haltères
  LibraryItem('Dumbbell Snatch', 'Haltères', _d),
  LibraryItem('Dumbbell Clean & Jerk', 'Haltères', _d),
  LibraryItem('Dumbbell Thruster', 'Haltères', _d),
  LibraryItem('Devil Press', 'Haltères', _d),
  LibraryItem('Dumbbell Lunge', 'Haltères', _d),
  LibraryItem('Dumbbell Box Step-up', 'Haltères', _d),
  // Gymnastique
  LibraryItem('Pull-up', 'Gymnastique', _w),
  LibraryItem('Chest-to-Bar', 'Gymnastique', _w),
  LibraryItem('Bar Muscle-up', 'Gymnastique', _w),
  LibraryItem('Ring Muscle-up', 'Gymnastique', _w),
  LibraryItem('Toes-to-Bar', 'Gymnastique', _w),
  LibraryItem('Handstand Push-up', 'Gymnastique', _w),
  LibraryItem('Strict Handstand Push-up', 'Gymnastique', _w),
  LibraryItem('Handstand Walk (m)', 'Gymnastique', _w),
  LibraryItem('Rope Climb', 'Gymnastique', _w),
  LibraryItem('Pistol', 'Gymnastique', _w),
  LibraryItem('Push-up', 'Gymnastique', _w),
  LibraryItem('Sit-up', 'Gymnastique', _w),
  LibraryItem('Air Squat', 'Gymnastique', _w),
  LibraryItem('Burpee', 'Gymnastique', _w),
  LibraryItem('Box Jump', 'Gymnastique', _w),
  LibraryItem('Wall Ball', 'Gymnastique', _w),
  LibraryItem('Double-Under', 'Gymnastique', _w),
  LibraryItem('Handstand Hold', 'Gymnastique', _h),
  LibraryItem('L-Sit Hold', 'Gymnastique', _h),
  LibraryItem('Plank', 'Gymnastique', _h),
  // Cardio
  LibraryItem('Rameur', 'Cardio', _c),
  LibraryItem('Assault Bike', 'Cardio', _c),
  LibraryItem('Bike Erg', 'Cardio', _c),
  LibraryItem('Ski Erg', 'Cardio', _c),
  LibraryItem('Course', 'Cardio', _c),
  // Benchmarks
  for (final n in ['Fran', 'Grace', 'Isabel', 'Diane', 'Elizabeth', 'Helen',
      'Karen', 'Annie', 'Jackie', 'Nancy', 'Amanda', 'Cindy', 'Mary',
      'Fight Gone Bad'])
    LibraryItem(n, 'Benchmark', _x),
  for (final n in ['Murph', 'DT', 'JT', 'Michael', 'Randy'])
    LibraryItem(n, 'Hero', _x),
];

LibraryItem? findInLibrary(String name) {
  for (final i in movementLibrary) {
    if (i.name.toLowerCase() == name.toLowerCase()) return i;
  }
  return null;
}

/// Libellé lisible d'un type de saisie.
String kindLabel(InputKind k) => switch (k) {
      InputKind.barbell => 'Barre',
      InputKind.kettlebell => 'Kettlebell',
      InputKind.dumbbell => 'Haltère',
      InputKind.bodyweight => 'Poids du corps',
      InputKind.cardio => 'Cardio',
      InputKind.hold => 'Maintien',
      InputKind.benchmark => 'Benchmark',
    };
