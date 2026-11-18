import 'package:health/health.dart';

/// Lecture des calories et de la durée d'entraînement depuis
/// Health Connect (Android) ou Apple Santé (iOS).
/// Aucune donnée de fréquence cardiaque n'est demandée.
class HealthService {
  final _health = Health();
  static const _types = [HealthDataType.WORKOUT, HealthDataType.ACTIVE_ENERGY_BURNED];

  Future<bool> requestAccess() async {
    await _health.configure();
    return _health.requestAuthorization(_types,
        permissions: _types.map((_) => HealthDataAccess.READ).toList());
  }

  /// Renvoie (calories, minutes) des entraînements du jour donné.
  Future<(int, int)?> workoutOf(DateTime day) async {
    if (!await requestAccess()) return null;
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final points = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WORKOUT], startTime: start, endTime: end);
    if (points.isEmpty) return (0, 0);
    var cal = 0, min = 0;
    for (final p in points) {
      min += p.dateTo.difference(p.dateFrom).inMinutes;
      final v = p.value;
      if (v is WorkoutHealthValue) cal += v.totalEnergyBurned ?? 0;
    }
    return (cal, min);
  }
}
