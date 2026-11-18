import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/movement_library.dart';
import '../models/record.dart';
import '../models/wod.dart';

/// Un nouveau record détecté (pour l'écran de félicitations).
class PrEvent {
  final String name;
  final double value;
  final String unit;
  final double? previous;
  const PrEvent(this.name, this.value, this.unit, this.previous);
}

/// Dernière charge utilisée sur un mouvement.
class LastLoad {
  final double value;
  final DateTime date;
  const LastLoad(this.value, this.date);
}

/// Stockage 100 % local sur l'appareil (aucune donnée envoyée à un serveur).
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();
  late SharedPreferences _prefs;

  List<Wod> wods = [];
  List<Movement> movements = [];

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final w = _prefs.getString('wods');
    if (w != null) {
      try {
        wods = (jsonDecode(w) as List).map((e) => Wod.fromJson(e)).toList();
      } catch (_) {
        wods = [];
      }
    }
    final m = _prefs.getString('movements');
    try {
      movements = m == null
          ? defaultMovements.map((n) => Movement(name: n)).toList()
          : (jsonDecode(m) as List).map((e) => Movement.fromJson(e)).toList();
    } catch (_) {
      movements = defaultMovements.map((n) => Movement(name: n)).toList();
    }
  }

  Future<void> _saveWods() =>
      _prefs.setString('wods', jsonEncode(wods.map((e) => e.toJson()).toList()));

  Future<void> saveWod(Wod wod) async {
    wods.removeWhere((w) => w.id == wod.id);
    wods.add(wod);
    wods.sort((a, b) => b.date.compareTo(a.date));
    await _saveWods();
  }

  Future<void> deleteWod(String id) async {
    wods.removeWhere((w) => w.id == id);
    await _saveWods();
  }

  Future<void> saveMovements() => _prefs.setString(
      'movements', jsonEncode(movements.map((e) => e.toJson()).toList()));

  Movement? movement(String name) {
    for (final m in movements) {
      if (m.name == name) return m;
    }
    return null;
  }

  /// Dernière charge utilisée sur [name] dans une autre séance.
  LastLoad? lastLoad(String name, {String? excludeWodId}) {
    LastLoad? out;
    for (final w in wods) {
      if (w.id == excludeWodId) continue;
      double? top;
      for (final b in w.blocks) {
        for (final e in b.exercises) {
          if (e.name != name) continue;
          for (final l in e.lines) {
            final v = l.load.effective;
            if (v != null && (top == null || v > top)) top = v;
          }
        }
      }
      if (top != null && (out == null || w.date.isAfter(out.date))) {
        out = LastLoad(top, w.date);
      }
    }
    return out;
  }

  /// Met à jour les records à partir d'une séance enregistrée :
  /// - bloc Force en « Charge max » -> charge max à la barre ;
  /// - WOD « For Time » dont le titre est un benchmark suivi (ex. Fran) -> temps.
  Future<List<PrEvent>> updateRecordsFrom(Wod wod) async {
    final events = <PrEvent>[];
    void add(String name, String unit, double value) {
      var m = movement(name);
      if (m == null) {
        m = Movement(name: name, unit: unit);
        movements.add(m);
      }
      final prev = m.best;
      if (Movement.better(m.unit, value, prev)) {
        m.history.add(RecordEntry(wod.date, value));
        m.sortHistory();
        events.add(PrEvent(name, value, m.unit, prev));
      }
    }

    for (final b in wod.blocks) {
      if (b.type == BlockType.force && b.format == 'Charge max') {
        final bars = b.exercises.where((e) => e.kind == InputKind.barbell).toList();
        final kg = (b.res['kg'] as num?)?.toDouble();
        for (final e in bars) {
          final top = bars.length == 1 && kg != null ? kg : b.maxLoad(e.name);
          if (top != null) add(e.name, 'kg', top);
        }
      }
      if (b.type == BlockType.wod &&
          b.format == 'For Time' &&
          b.res['capped'] != true &&
          (b.res['min'] != null || b.res['sec'] != null)) {
        final title = wod.title.trim().toLowerCase();
        String? bench;
        for (final m in movements) {
          if (m.unit == 'sec' && m.name.toLowerCase() == title) bench = m.name;
        }
        if (bench != null) {
          final secs = ((b.res['min'] as num?) ?? 0).toDouble() * 60 +
              ((b.res['sec'] as num?) ?? 0).toDouble();
          add(bench, 'sec', secs);
        }
      }
    }
    if (events.isNotEmpty) await saveMovements();
    return events;
  }

  String? get apiKey => _prefs.getString('apiKey');
  Future<void> setApiKey(String key) => _prefs.setString('apiKey', key);

  /// Suppression totale des données (droit à l'effacement).
  Future<void> wipeAll() async {
    await _prefs.clear();
    wods = [];
    movements = defaultMovements.map((n) => Movement(name: n)).toList();
  }
}
