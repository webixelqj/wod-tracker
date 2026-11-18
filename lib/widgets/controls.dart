import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../utils/format.dart';

/// Libellé de champ, avec la valeur prévue barrée quand l'athlète a adapté.
class FieldLabel extends StatelessWidget {
  final String label;
  final double? planned;
  const FieldLabel({super.key, required this.label, this.planned});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      Text(label,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: muted)),
      if (planned != null)
        Text('prévu ${fmtNum(planned)}',
            style: TextStyle(
                fontSize: 13, color: muted, decoration: TextDecoration.lineThrough)),
    ]);
  }
}

/// Bouton carré d'au moins 48 px (−, +, ±2,5…).
class QuickButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final String? semantic;
  final double fontSize;
  const QuickButton(
      {super.key, required this.label, required this.onPressed, this.semantic, this.fontSize = 15});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: semantic,
        excludeSemantics: semantic != null,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700),
          ),
          child: FittedBox(child: Text(label)),
        ),
      );
}

/// Champ numérique avec boutons − et + (reps, durée, score…).
class StepperField extends StatefulWidget {
  final String label;
  final double? value;
  final ValueChanged<double?> onChanged;
  final double step;
  final double min;
  final double max;
  final String? suffix;
  final bool decimal;
  final bool adapted;
  final double? planned;

  const StepperField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.step = 1,
    this.min = 0,
    this.max = 9999,
    this.suffix,
    this.decimal = false,
    this.adapted = false,
    this.planned,
  });

  @override
  State<StepperField> createState() => _StepperFieldState();
}

class _StepperFieldState extends State<StepperField> {
  late final TextEditingController _ctrl = TextEditingController(text: _text(widget.value));
  final _focus = FocusNode();

  String _text(double? v) =>
      v == null ? '' : (v % 1 == 0 ? v.toInt().toString() : v.toString());

  @override
  void didUpdateWidget(covariant StepperField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && _ctrl.text != _text(widget.value)) {
      _ctrl.text = _text(widget.value);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  double _clamp(double v) => v.clamp(widget.min, widget.max).toDouble();

  void _step(int dir) {
    final next = _clamp((((widget.value ?? 0) + dir * widget.step) * 2).round() / 2);
    _ctrl.text = _text(next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final a = widget.adapted;
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c, width: w));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FieldLabel(label: widget.label, planned: a ? widget.planned : null),
      const SizedBox(height: 6),
      Row(children: [
        SizedBox(
            width: 48,
            child: QuickButton(
                label: '−',
                fontSize: 20,
                semantic: '${widget.label} moins ${fmtNum(widget.step)}',
                onPressed: () => _step(-1))),
        const SizedBox(width: 6),
        Expanded(
          child: TextField(
            controller: _ctrl,
            focusNode: _focus,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.numberWithOptions(decimal: widget.decimal),
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: a ? adaptColor(context) : null,
                fontFeatures: const [FontFeature.tabularFigures()]),
            decoration: InputDecoration(
              isDense: true,
              hintText: '—',
              suffixText: widget.suffix,
              filled: a,
              fillColor: a ? adaptBg(context) : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              enabledBorder: border(a ? adaptColor(context) : cs.outlineVariant, 1.5),
              focusedBorder: border(cs.primary, 2),
            ),
            onChanged: (t) {
              final v = double.tryParse(t.trim().replaceAll(',', '.'));
              widget.onChanged(v == null ? null : _clamp(v));
            },
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
            width: 48,
            child: QuickButton(
                label: '+',
                fontSize: 20,
                semantic: '${widget.label} plus ${fmtNum(widget.step)}',
                onPressed: () => _step(1))),
      ]),
    ]);
  }
}

/// Poids standards (kettlebells, haltères) en gros boutons.
class WeightChips extends StatelessWidget {
  final List<double> weights;
  final double? value;
  final bool adapted;
  final ValueChanged<double> onSelect;
  const WeightChips(
      {super.key, required this.weights, required this.value, required this.adapted, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    const size = Size(56, 48);
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final w in weights)
        value == w
            ? FilledButton(
                style: FilledButton.styleFrom(
                    minimumSize: size,
                    shape: shape,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    backgroundColor: adapted ? adaptColor(context) : cs.primary,
                    foregroundColor: adapted ? cs.surface : cs.onPrimary),
                onPressed: () => onSelect(w),
                child: Text(fmtNum(w)))
            : OutlinedButton(
                style: OutlinedButton.styleFrom(
                    minimumSize: size,
                    shape: shape,
                    padding: const EdgeInsets.symmetric(horizontal: 10)),
                onPressed: () => onSelect(w),
                child: Text(fmtNum(w))),
    ]);
  }
}

/// « Dernière fois : 95 kg · lun. 16 nov. » — un geste pour reprendre la charge.
class LastLoadChip extends StatelessWidget {
  final LastLoad last;
  final VoidCallback onTap;
  const LastLoadChip({super.key, required this.last, required this.onTap});

  @override
  Widget build(BuildContext context) => ActionChip(
        avatar: const Icon(Icons.history, size: 18),
        label: Text('Dernière fois : ${fmtNum(last.value)} kg · ${fmtShortDate(last.date)}'),
        onPressed: onTap,
      );
}

/// Petite pastille (RX, PR, « Résultat à saisir »…).
class Tag extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const Tag(this.text, {super.key, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text.toUpperCase(),
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .6, color: fg)),
      );
}
