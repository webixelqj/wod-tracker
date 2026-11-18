import '../utils/format.dart';
import 'movement_library.dart';

/// Une valeur prévue au tableau + éventuellement la valeur réalisée (adaptation).
class PV {
  double? planned;
  double? done;
  PV({this.planned, this.done});
  double? get effective => done ?? planned;
  bool get adapted => done != null && done != planned;
  Map<String, dynamic> toJson() => {'p': planned, 'd': done};
  factory PV.fromJson(Map<String, dynamic>? j) => PV(
      planned: (j?['p'] as num?)?.toDouble(), done: (j?['d'] as num?)?.toDouble());
}

/// Une ligne d'exercice (un round, ou toutes les séries si identiques).
class SetLine {
  PV reps, load, distance, calories, seconds;
  SetLine({PV? reps, PV? load, PV? distance, PV? calories, PV? seconds})
      : reps = reps ?? PV(),
        load = load ?? PV(),
        distance = distance ?? PV(),
        calories = calories ?? PV(),
        seconds = seconds ?? PV();

  List<PV> get all => [reps, load, distance, calories, seconds];
  SetLine copy() => SetLine.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'reps': reps.toJson(),
        'load': load.toJson(),
        'dist': distance.toJson(),
        'cal': calories.toJson(),
        'sec': seconds.toJson(),
      };
  factory SetLine.fromJson(Map<String, dynamic> j) => SetLine(
        reps: PV.fromJson(j['reps']),
        load: PV.fromJson(j['load']),
        distance: PV.fromJson(j['dist']),
        calories: PV.fromJson(j['cal']),
        seconds: PV.fromJson(j['sec']),
      );
}

enum CardioMode { distance, calories, time }

class Exercise {
  String name;
  InputKind kind;
  CardioMode cardioMode;
  bool variesByRound;
  List<SetLine> lines;
  Exercise({
    required this.name,
    required this.kind,
    this.cardioMode = CardioMode.distance,
    this.variesByRound = false,
    List<SetLine>? lines,
  }) : lines = lines ?? [SetLine()];

  Map<String, dynamic> toJson() => {
        'name': name,
        'kind': kind.name,
        'cm': cardioMode.name,
        'vary': variesByRound,
        'lines': lines.map((l) => l.toJson()).toList(),
      };
  factory Exercise.fromJson(Map<String, dynamic> j) {
    final lines = (j['lines'] as List? ?? []).map((e) => SetLine.fromJson(e)).toList();
    return Exercise(
      name: j['name'] ?? 'Exercice',
      kind: InputKind.values.asNameMap()[j['kind']] ?? InputKind.bodyweight,
      cardioMode: CardioMode.values.asNameMap()[j['cm']] ?? CardioMode.distance,
      variesByRound: j['vary'] ?? false,
      lines: lines.isEmpty ? null : lines,
    );
  }
}

/// Blocs d'une séance. Seuls la force et le WOD portent un score.
enum BlockType { echauffement, skill, force, wod, retourAuCalme }

extension BlockLabel on BlockType {
  String get label => switch (this) {
        BlockType.echauffement => 'Échauffement',
        BlockType.skill => 'Skill',
        BlockType.force => 'Force',
        BlockType.wod => 'WOD',
        BlockType.retourAuCalme => 'Retour au calme',
      };
  bool get scored => this == BlockType.wod || this == BlockType.force;
}

const blockFormats = ['For Time', 'AMRAP', 'EMOM', 'Charge max', 'Autre'];

class Block {
  BlockType type;
  String format;
  String notes;
  String level; // RX, Adapté, Débutant
  int? cap; // time cap en minutes (For Time)
  int? minutes; // durée en minutes (AMRAP, EMOM)
  /// Résultat selon le format :
  /// For Time {min, sec} ou {capped: true, reps} · AMRAP {rounds, reps}
  /// EMOM {ok: [bool…]} · Charge max {kg} · Autre {text}
  Map<String, dynamic> res;
  List<Exercise> exercises;

  Block({
    required this.type,
    this.format = 'For Time',
    this.notes = '',
    this.level = 'RX',
    this.cap,
    this.minutes,
    Map<String, dynamic>? res,
    List<Exercise>? exercises,
  })  : res = res ?? {},
        exercises = exercises ?? [];

  /// Plus grosse charge à la barre du bloc (pour un mouvement donné ou tous).
  double? maxLoad([String? name]) {
    double? top;
    for (final e in exercises) {
      if (e.kind != InputKind.barbell || (name != null && e.name != name)) continue;
      for (final l in e.lines) {
        final v = l.load.effective;
        if (v != null && (top == null || v > top)) top = v;
      }
    }
    return top;
  }

  /// Minutes de l'EMOM (réussie = true). Par défaut tout est réussi.
  List<bool> emomMinutes() {
    final n = minutes ?? 10;
    final current = res['ok'] is List<bool> ? res['ok'] as List<bool> : <bool>[];
    if (current.length != n) {
      res['ok'] = List<bool>.generate(n, (i) => i < current.length ? current[i] : true);
    }
    return res['ok'] as List<bool>;
  }

  static int _i(dynamic v) => (v as num).round();

  String? get scoreText {
    switch (format) {
      case 'For Time':
        if (res['capped'] == true) {
          final r = res['reps'];
          return r == null ? 'CAP' : 'CAP + ${_i(r)}';
        }
        if (res['min'] == null && res['sec'] == null) return null;
        final m = _i(res['min'] ?? 0), s = _i(res['sec'] ?? 0);
        return '$m:${s.toString().padLeft(2, '0')}';
      case 'AMRAP':
        if (res['rounds'] == null) return null;
        final reps = _i(res['reps'] ?? 0);
        return '${_i(res['rounds'])} rds${reps > 0 ? ' + $reps' : ''}';
      case 'EMOM':
        final ok = res['ok'];
        if (ok is! List<bool>) return null;
        return '${ok.where((e) => e).length}/${ok.length}';
      case 'Charge max':
        final kg = res['kg'];
        return kg is num ? '${fmtNum(kg.toDouble())} kg' : null;
      default:
        final t = res['text'];
        return t is String && t.trim().isNotEmpty ? t.trim() : null;
    }
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'format': format,
        'notes': notes,
        'level': level,
        'cap': cap,
        'min': minutes,
        'res': res,
        'ex': exercises.map((e) => e.toJson()).toList(),
      };

  factory Block.fromJson(Map<String, dynamic> j) {
    final res = Map<String, dynamic>.from(j['res'] as Map? ?? {});
    final ok = res['ok'];
    if (ok is List) res['ok'] = ok.map((e) => e == true).toList();
    final legacy = j['score'];
    if (res.isEmpty && legacy is String && legacy.isNotEmpty) res['text'] = legacy;
    return Block(
      type: BlockType.values.asNameMap()[j['type']] ?? BlockType.wod,
      format: j['format'] ?? 'Autre',
      notes: j['notes'] ?? '',
      level: j['level'] ?? 'RX',
      cap: (j['cap'] as num?)?.toInt(),
      minutes: (j['min'] as num?)?.toInt(),
      res: res,
      exercises: (j['ex'] as List? ?? []).map((e) => Exercise.fromJson(e)).toList(),
    );
  }
}

class Wod {
  final String id;
  DateTime date;
  String title;
  List<Block> blocks;
  bool fromPhoto;
  int? watchCalories;
  int? watchMinutes;

  Wod({
    required this.id,
    required this.date,
    this.title = '',
    List<Block>? blocks,
    this.fromPhoto = false,
    this.watchCalories,
    this.watchMinutes,
  }) : blocks = blocks ?? [Block(type: BlockType.wod)];

  Block? get mainBlock {
    for (final b in blocks) {
      if (b.type == BlockType.wod) return b;
    }
    for (final b in blocks) {
      if (b.type == BlockType.force) return b;
    }
    return blocks.isEmpty ? null : blocks.first;
  }

  String get displayTitle =>
      title.trim().isNotEmpty ? title.trim() : (mainBlock?.format ?? 'Séance');
  String get blockSummary => blocks.map((b) => b.type.label).join(' + ');

  int get adaptationCount {
    var n = 0;
    for (final b in blocks) {
      for (final e in b.exercises) {
        for (final l in e.lines) {
          for (final pv in l.all) {
            if (pv.adapted) n++;
          }
        }
      }
    }
    return n;
  }

  /// « Fait comme prévu » : on efface toutes les adaptations.
  void resetAdaptations() {
    for (final b in blocks) {
      for (final e in b.exercises) {
        for (final l in e.lines) {
          for (final pv in l.all) {
            pv.done = null;
          }
        }
      }
      final ok = b.res['ok'];
      if (ok is List<bool>) {
        for (var i = 0; i < ok.length; i++) {
          ok[i] = true;
        }
      }
    }
  }

  Wod copy() => Wod.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'title': title,
        'blocks': blocks.map((b) => b.toJson()).toList(),
        'fromPhoto': fromPhoto,
        'wCal': watchCalories,
        'wMin': watchMinutes,
      };

  factory Wod.fromJson(Map<String, dynamic> j) => Wod(
        id: j['id'],
        date: DateTime.parse(j['date']),
        title: j['title'] ?? '',
        blocks: (j['blocks'] as List? ?? []).map((e) => Block.fromJson(e)).toList(),
        fromPhoto: j['fromPhoto'] ?? false,
        watchCalories: (j['wCal'] as num?)?.toInt(),
        watchMinutes: (j['wMin'] as num?)?.toInt(),
      );
}
