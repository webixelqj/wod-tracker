import 'package:flutter/material.dart';
import '../models/movement_library.dart';
import '../models/wod.dart';
import '../services/storage_service.dart';
import '../utils/ui.dart';
import 'controls.dart';
import 'load_field.dart';

/// Carte d'un exercice : affiche automatiquement les bons champs selon son type.
/// En mode « Tableau », on édite le prévu ; en mode « Mon résultat »,
/// toute valeur différente du prévu devient une adaptation (orange).
class ExerciseCard extends StatelessWidget {
  final Exercise ex;
  final bool editPlanned;
  final String? wodId;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const ExerciseCard({
    super.key,
    required this.ex,
    required this.editPlanned,
    required this.onChanged,
    required this.onDelete,
    this.wodId,
  });

  double? _val(PV pv) => editPlanned ? pv.planned : pv.effective;
  bool _ad(PV pv) => !editPlanned && pv.adapted;

  void _set(PV pv, double? v) {
    if (editPlanned) {
      pv.planned = v;
    } else {
      pv.done = (v == pv.planned) ? null : v;
    }
    onChanged();
  }

  Widget _num(String label, PV pv, {double step = 1}) => StepperField(
        label: label,
        value: _val(pv),
        adapted: _ad(pv),
        planned: pv.planned,
        step: step,
        onChanged: (v) => _set(pv, v),
      );

  Widget _weights(String label, PV pv, List<double> weights, LastLoad? last) {
    final v = _val(pv);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: gap([
        FieldLabel(label: label, planned: _ad(pv) ? pv.planned : null),
        WeightChips(weights: weights, value: v, adapted: _ad(pv), onSelect: (w) => _set(pv, w)),
        if (last != null && last.value != v)
          LastLoadChip(last: last, onTap: () => _set(pv, last.value)),
      ], 8),
    );
  }

  List<Widget> _fields(SetLine l, bool first) {
    final loaded = ex.kind == InputKind.barbell ||
        ex.kind == InputKind.kettlebell ||
        ex.kind == InputKind.dumbbell;
    final last =
        first && loaded ? StorageService.instance.lastLoad(ex.name, excludeWodId: wodId) : null;
    return switch (ex.kind) {
      InputKind.barbell => [
          _num('Reps', l.reps),
          LoadField(
            label: 'Charge',
            value: _val(l.load),
            adapted: _ad(l.load),
            planned: l.load.planned,
            last: last,
            onChanged: (v) => _set(l.load, v),
          ),
        ],
      InputKind.kettlebell => [
          _num('Reps', l.reps),
          _weights('Kettlebell (kg)', l.load, kettlebellWeights, last),
        ],
      InputKind.dumbbell => [
          _num('Reps', l.reps),
          _weights('Haltère (kg)', l.load, dumbbellWeights, last),
        ],
      InputKind.bodyweight => [_num('Reps', l.reps)],
      InputKind.hold => [_num('Durée (s)', l.seconds, step: 5)],
      InputKind.cardio => switch (ex.cardioMode) {
          CardioMode.distance => [_num('Distance (m)', l.distance, step: 50)],
          CardioMode.calories => [_num('Calories', l.calories)],
          CardioMode.time => [_num('Durée (s)', l.seconds, step: 10)],
        },
      InputKind.benchmark => [const Text('Benchmark : note ton score en bas du bloc.')],
    };
  }

  void _setVary(bool v) {
    ex.variesByRound = v;
    if (!v && ex.lines.length > 1) ex.lines = [ex.lines.first];
    if (v && ex.lines.length == 1) {
      ex.lines = [ex.lines.first, ex.lines.first.copy(), ex.lines.first.copy()];
    }
    onChanged();
  }

  Widget _line(BuildContext context, int i) {
    final fields = _fields(ex.lines[i], i == 0);
    if (ex.lines.length == 1) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: gap(fields));
    }
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.outlineVariant))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: gap([
          Row(children: [
            Text('ROUND ${i + 1}',
                style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant)),
            const Spacer(),
            if (editPlanned)
              TextButton(
                onPressed: () {
                  ex.lines.removeAt(i);
                  if (ex.lines.length == 1) ex.variesByRound = false;
                  onChanged();
                },
                child: const Text('Retirer'),
              ),
          ]),
          ...fields,
        ], 10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final plan = editPlanned;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: gap([
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ex.name,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                Text(kindLabel(ex.kind).toUpperCase(),
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurfaceVariant)),
              ]),
            ),
            if (plan)
              IconButton(
                  tooltip: 'Retirer ${ex.name}',
                  icon: const Icon(Icons.close),
                  onPressed: onDelete),
          ]),
          if (ex.kind == InputKind.cardio)
            SegmentedButton<CardioMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: CardioMode.distance, label: Text('Distance')),
                ButtonSegment(value: CardioMode.calories, label: Text('Calories')),
                ButtonSegment(value: CardioMode.time, label: Text('Durée')),
              ],
              selected: {ex.cardioMode},
              onSelectionChanged: plan
                  ? (s) {
                      ex.cardioMode = s.first;
                      onChanged();
                    }
                  : null,
            ),
          if (plan && ex.kind != InputKind.benchmark)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Varie selon le round'),
              value: ex.variesByRound,
              onChanged: _setVary,
            ),
          for (var i = 0; i < ex.lines.length; i++) _line(context, i),
          if (plan && ex.variesByRound)
            TextButton.icon(
              onPressed: () {
                ex.lines.add(ex.lines.last.copy());
                onChanged();
              },
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un round'),
            ),
        ]),
      ),
    );
  }
}
