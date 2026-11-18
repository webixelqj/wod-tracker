import 'package:flutter/material.dart';
import '../services/storage_service.dart';

/// Calcule la charge à partir d'un pourcentage du record (ex. 75 % du Back Squat).
class ChargeHelper extends StatefulWidget {
  final VoidCallback? onChanged;
  const ChargeHelper({super.key, this.onChanged});
  @override
  State<ChargeHelper> createState() => _ChargeHelperState();
}

class _ChargeHelperState extends State<ChargeHelper> {
  final store = StorageService.instance;
  String? _movement;
  double _percent = 75;

  @override
  Widget build(BuildContext context) {
    final withPr = store.movements.where((m) => m.unit == 'kg' && m.best != null).toList();
    if (withPr.isEmpty) {
      return const Text('Astuce : enregistre tes records pour calculer tes charges.',
          style: TextStyle(fontStyle: FontStyle.italic));
    }
    _movement ??= withPr.first.name;
    final pr = withPr.firstWhere((m) => m.name == _movement, orElse: () => withPr.first).best!;
    final load = pr * _percent / 100;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Calculateur de charge', style: TextStyle(fontWeight: FontWeight.bold)),
          DropdownButton<String>(
            value: _movement, isExpanded: true,
            items: withPr.map((m) => DropdownMenuItem(
                value: m.name, child: Text('${m.name} (PR ${m.best} kg)'))).toList(),
            onChanged: (v) => setState(() => _movement = v),
          ),
          Slider(value: _percent, min: 30, max: 110, divisions: 80,
              label: '${_percent.round()} %',
              onChanged: (v) => setState(() => _percent = v)),
          Text('${_percent.round()} % → ${load.toStringAsFixed(1)} kg',
              style: Theme.of(context).textTheme.titleLarge),
        ]),
      ),
    );
  }
}
