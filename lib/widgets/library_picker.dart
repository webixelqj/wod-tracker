import 'package:flutter/material.dart';
import '../models/movement_library.dart';

/// Feuille de sélection dans la bibliothèque, avec recherche et création libre.
class LibraryPicker extends StatefulWidget {
  final Set<String> exclude;
  final Set<InputKind>? onlyKinds;
  const LibraryPicker({super.key, this.exclude = const {}, this.onlyKinds});

  static Future<LibraryItem?> show(BuildContext context,
          {Set<String> exclude = const {}, Set<InputKind>? onlyKinds}) =>
      showModalBottomSheet<LibraryItem>(
          context: context, isScrollControlled: true,
          builder: (_) => LibraryPicker(exclude: exclude, onlyKinds: onlyKinds));

  @override
  State<LibraryPicker> createState() => _LibraryPickerState();
}

class _LibraryPickerState extends State<LibraryPicker> {
  String _q = '';
  InputKind _kind = InputKind.barbell;
  static const _kindLabels = {
    InputKind.barbell: 'Barre', InputKind.kettlebell: 'Kettlebell',
    InputKind.dumbbell: 'Haltère', InputKind.bodyweight: 'Poids du corps',
    InputKind.cardio: 'Cardio', InputKind.hold: 'Gainage / maintien',
    InputKind.benchmark: 'Benchmark',
  };

  @override
  Widget build(BuildContext context) {
    final items = movementLibrary
        .where((i) => !widget.exclude.contains(i.name))
        .where((i) => widget.onlyKinds == null || widget.onlyKinds!.contains(i.kind))
        .where((i) => i.name.toLowerCase().contains(_q.toLowerCase()))
        .toList();
    final cats = items.map((i) => i.category).toSet().toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            autofocus: true,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search),
                hintText: 'Rechercher (ex. handstand, swing, Fran…)'),
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        Expanded(child: ListView(children: [
          for (final c in cats) ...[
            Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(c, style: const TextStyle(fontWeight: FontWeight.bold))),
            ...items.where((i) => i.category == c).map((i) => ListTile(
                minVerticalPadding: 12, title: Text(i.name),
                trailing: Text(_kindLabels[i.kind]!,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                onTap: () => Navigator.pop(context, i))),
          ],
          if (_q.trim().isNotEmpty) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(child: Text('Créer « ${_q.trim()} »')),
                DropdownButton<InputKind>(
                  value: _kind,
                  items: _kindLabels.entries
                      .where((e) => e.key != InputKind.benchmark)
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setState(() => _kind = v!),
                ),
                IconButton(icon: const Icon(Icons.add_circle),
                    onPressed: () => Navigator.pop(
                        context, LibraryItem(_q.trim(), 'Perso', _kind))),
              ]),
            ),
          ],
        ])),
      ]),
    );
  }
}
