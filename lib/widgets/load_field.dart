import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/ui.dart';
import 'controls.dart';

/// Charge à la barre : gros chiffre, boutons ±1 / ±2,5 / ±5 kg,
/// curseur 0–300 kg et rappel de la dernière charge utilisée.
class LoadField extends StatefulWidget {
  final String label;
  final double? value;
  final ValueChanged<double?> onChanged;
  final bool adapted;
  final double? planned;
  final LastLoad? last;

  const LoadField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.adapted = false,
    this.planned,
    this.last,
  });

  @override
  State<LoadField> createState() => _LoadFieldState();
}

class _LoadFieldState extends State<LoadField> {
  late final TextEditingController _ctrl = TextEditingController(text: _text(widget.value));
  final _focus = FocusNode();

  String _text(double? v) =>
      v == null ? '' : (v % 1 == 0 ? v.toInt().toString() : v.toString());

  @override
  void didUpdateWidget(covariant LoadField old) {
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

  void _emit(double? v, {bool updateText = true}) {
    final clamped = v?.clamp(0, 300).toDouble();
    if (updateText) _ctrl.text = _text(clamped);
    widget.onChanged(clamped);
  }

  void _step(double d) => _emit((((widget.value ?? 0) + d) * 2).round() / 2);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final a = widget.adapted;
    final accent = a ? adaptColor(context) : cs.primary;
    final last = widget.last;
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c, width: w));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: gap([
        FieldLabel(label: widget.label, planned: a ? widget.planned : null),
        TextField(
          controller: _ctrl,
          focusNode: _focus,
          textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              color: a ? adaptColor(context) : null,
              fontFeatures: const [FontFeature.tabularFigures()]),
          decoration: InputDecoration(
            hintText: '0',
            suffixText: 'kg',
            filled: a,
            fillColor: a ? adaptBg(context) : null,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            enabledBorder: border(a ? adaptColor(context) : cs.outlineVariant, 1.5),
            focusedBorder: border(cs.primary, 2),
          ),
          onChanged: (t) =>
              _emit(double.tryParse(t.trim().replaceAll(',', '.')), updateText: false),
        ),
        Row(
          children: gap([
            for (final d in const [-5.0, -2.5, -1.0, 1.0, 2.5, 5.0])
              Expanded(
                child: QuickButton(
                  label: '${d > 0 ? '+' : '−'}${fmtNum(d.abs())}',
                  semantic: '${d > 0 ? 'Ajouter' : 'Retirer'} ${fmtNum(d.abs())} kg',
                  onPressed: () => _step(d),
                ),
              ),
          ], 6),
        ),
        Slider(
          value: (widget.value ?? 0).clamp(0, 300).toDouble(),
          min: 0,
          max: 300,
          divisions: 600,
          activeColor: accent,
          label: '${fmtNum(widget.value ?? 0)} kg',
          onChanged: (v) => _emit((v * 2).round() / 2),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (final s in const ['0', '100', '200', '300 kg'])
            Text(s, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ]),
        if (last != null && last.value != widget.value)
          Align(
            alignment: Alignment.centerLeft,
            child: LastLoadChip(last: last, onTap: () => _emit(last.value)),
          ),
      ], 8),
    );
  }
}
