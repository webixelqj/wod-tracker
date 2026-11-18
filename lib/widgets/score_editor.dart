import 'package:flutter/material.dart';
import '../models/wod.dart';
import '../theme.dart';
import '../utils/ui.dart';
import 'controls.dart';

/// Saisie du score adaptée au format du bloc :
/// For Time (min:s ou time cap + reps), AMRAP (rounds + reps),
/// EMOM (une case par minute), Charge max (kg), Autre (texte).
class ScoreEditor extends StatelessWidget {
  final Block block;
  final VoidCallback onChanged;
  const ScoreEditor({super.key, required this.block, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final b = block;
    final r = b.res;
    double? g(String k) => (r[k] as num?)?.toDouble();
    void put(String k, double? v) {
      if (v == null) {
        r.remove(k);
      } else {
        r[k] = v;
      }
      onChanged();
    }

    final inputs = <Widget>[];
    switch (b.format) {
      case 'For Time':
        {
          final capped = r['capped'] == true;
          inputs.add(CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: capped,
            title: Text('Time cap atteint${b.cap != null ? ' (${b.cap} min)' : ''}'),
            onChanged: (v) {
              r['capped'] = v ?? false;
              onChanged();
            },
          ));
          if (capped) {
            inputs.add(StepperField(
                label: 'Reps réalisées', value: g('reps'), onChanged: (v) => put('reps', v)));
          } else {
            inputs.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: StepperField(
                      label: 'Minutes', value: g('min'), max: 180, onChanged: (v) => put('min', v))),
              const SizedBox(width: 10),
              Expanded(
                  child: StepperField(
                      label: 'Secondes', value: g('sec'), max: 59, onChanged: (v) => put('sec', v))),
            ]));
          }
        }
      case 'AMRAP':
        inputs.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: StepperField(
                  label: 'Rounds', value: g('rounds'), onChanged: (v) => put('rounds', v))),
          const SizedBox(width: 10),
          Expanded(
              child: StepperField(
                  label: 'Reps en plus', value: g('reps'), onChanged: (v) => put('reps', v))),
        ]));
      case 'EMOM':
        {
          final ok = b.emomMinutes();
          inputs.add(Text('Touche une minute ratée pour la barrer.',
              style: TextStyle(color: cs.onSurfaceVariant)));
          inputs.add(Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < ok.length; i++)
              _MinuteButton(
                index: i,
                ok: ok[i],
                onTap: () {
                  ok[i] = !ok[i];
                  onChanged();
                },
              ),
          ]));
        }
      case 'Charge max':
        {
          if (g('kg') == null) {
            final m = b.maxLoad();
            if (m != null) r['kg'] = m;
          }
          inputs.add(StepperField(
            label: 'Meilleure charge',
            value: g('kg'),
            step: 2.5,
            max: 300,
            suffix: 'kg',
            decimal: true,
            onChanged: (v) => put('kg', v),
          ));
        }
      default:
        inputs.add(TextFormField(
          initialValue: r['text'] as String?,
          decoration: const InputDecoration(labelText: 'Ton score', border: OutlineInputBorder()),
          onChanged: (t) {
            r['text'] = t;
            onChanged();
          },
        ));
    }

    return Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.outlineVariant, width: 2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: gap([
          Row(children: [
            Text(b.type == BlockType.force ? 'RÉSULTAT' : 'MON SCORE',
                style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            const Spacer(),
            Text(b.scoreText ?? '—',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: cs.primary)),
          ]),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              for (final l in const ['RX', 'Adapté', 'Débutant'])
                ButtonSegment(value: l, label: Text(l)),
            ],
            selected: {b.level},
            onSelectionChanged: (s) {
              b.level = s.first;
              onChanged();
            },
          ),
          ...inputs,
        ], 10),
      ),
    );
  }
}

class _MinuteButton extends StatelessWidget {
  final int index;
  final bool ok;
  final VoidCallback onTap;
  const _MinuteButton({required this.index, required this.ok, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = ok ? goodColor(context) : Theme.of(context).colorScheme.error;
    return Semantics(
      button: true,
      label: 'Minute ${index + 1} ${ok ? 'réussie' : 'ratée'}',
      excludeSemantics: true,
      child: SizedBox(
        width: 56,
        height: 52,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(56, 52),
            backgroundColor: ok ? goodBg(context) : Colors.transparent,
            foregroundColor: color,
            side: BorderSide(color: color, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text('${index + 1}',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  decoration: ok ? null : TextDecoration.lineThrough)),
        ),
      ),
    );
  }
}
