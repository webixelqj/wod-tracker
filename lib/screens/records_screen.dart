import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import '../models/record.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/ui.dart';
import '../widgets/action_bar.dart';
import '../widgets/controls.dart';
import '../widgets/library_picker.dart';
import '../widgets/pr_celebration.dart';

/// Mes records : historique par mouvement, ajout, modification,
/// suppression par glissement (avec Annuler ; confirmation pour un mouvement).
class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  final store = StorageService.instance;

  Future<void> _addMovement() async {
    final existing = store.movements.map((m) => m.name).toSet();
    final picked = await LibraryPicker.show(context, exclude: existing);
    if (picked == null) return;
    setState(() => store.movements.add(Movement(name: picked.name, unit: picked.recordUnit)));
    await store.saveMovements();
    if (mounted) showInfo(context, '${picked.name} ajouté aux records');
  }

  Future<bool> _confirmDeleteMovement(Movement m) async {
    final n = m.history.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le mouvement ?'),
        content: Text('« ${m.name} » et ${n == 0 ? 'son historique' : 'ses $n résultat${n > 1 ? 's' : ''}'} '
            'seront retirés de tes records. Tes séances ne changent pas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  void _removeMovement(Movement m) {
    final idx = store.movements.indexOf(m);
    if (idx < 0) return;
    setState(() => store.movements.removeAt(idx));
    store.saveMovements();
    showUndoSnack(context, '${m.name} supprimé', () {
      if (!mounted) return;
      setState(() => store.movements.insert(idx.clamp(0, store.movements.length), m));
      store.saveMovements();
    });
  }

  Future<void> _deleteMovementFromButton(Movement m) async {
    if (await _confirmDeleteMovement(m) && mounted) _removeMovement(m);
  }

  void _removeEntry(Movement m, RecordEntry e) {
    final idx = m.history.indexOf(e);
    if (idx < 0) return;
    setState(() => m.history.removeAt(idx));
    store.saveMovements();
    showUndoSnack(context, 'Résultat supprimé : ${fmtValue(e.value, m.unit)}', () {
      if (!mounted) return;
      setState(() => m.history.insert(idx.clamp(0, m.history.length), e));
      store.saveMovements();
    });
  }

  Future<void> _addEntry(Movement m) async {
    final r = await showModalBottomSheet<EntryResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EntrySheet(movement: m),
    );
    final v = r?.value;
    if (r == null || v == null) return;
    final prev = m.best;
    setState(() {
      m.history.add(RecordEntry(r.date, v));
      m.sortHistory();
    });
    await store.saveMovements();
    if (!mounted) return;
    if (Movement.better(m.unit, v, prev)) {
      await showPrCelebration(context, [PrEvent(m.name, v, m.unit, prev)]);
    } else if (prev != null) {
      showInfo(
          context,
          v == prev
              ? 'Résultat ajouté : tu égales ton record'
              : 'Résultat ajouté. Ton record reste ${fmtValue(prev, m.unit)}');
    }
  }

  Future<void> _editEntry(Movement m, RecordEntry e) async {
    final r = await showModalBottomSheet<EntryResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EntrySheet(movement: m, entry: e),
    );
    if (r == null || !mounted) return;
    if (r.delete) {
      _removeEntry(m, e);
      return;
    }
    final v = r.value;
    final idx = m.history.indexOf(e);
    if (v == null || idx < 0) return;
    setState(() {
      m.history[idx] = RecordEntry(r.date, v);
      m.sortHistory();
    });
    await store.saveMovements();
    if (mounted) showInfo(context, 'Résultat modifié');
  }

  Widget _trash(ColorScheme cs) => Container(
        color: cs.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        child: Icon(Icons.delete_outline, color: cs.onError, size: 26, semanticLabel: 'Supprimer'),
      );

  Widget _card(Movement m, ColorScheme cs) {
    final best = m.best;
    final n = m.history.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Dismissible(
          key: ObjectKey(m),
          direction: DismissDirection.endToStart,
          background: _trash(cs),
          confirmDismiss: (_) => _confirmDeleteMovement(m),
          onDismissed: (_) => _removeMovement(m),
          child: Material(
            color: cs.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant)),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: PageStorageKey<String>('rec-${m.name}'),
                tilePadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
                expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                title: Text(m.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                subtitle: Text('$n résultat${n > 1 ? 's' : ''}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(best == null ? '—' : fmtValue(best, m.unit),
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: cs.primary,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                  const SizedBox(width: 4),
                  const Icon(Icons.expand_more),
                ]),
                children: [
                  for (final e in m.history.reversed)
                    Dismissible(
                      key: ObjectKey(e),
                      direction: DismissDirection.endToStart,
                      background: _trash(cs),
                      onDismissed: (_) => _removeEntry(m, e),
                      child: Material(
                        color: cs.surface,
                        child: ListTile(
                          shape: Border(top: BorderSide(color: cs.outlineVariant)),
                          title: Row(children: [
                            Text(fmtValue(e.value, m.unit),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontFeatures: [FontFeature.tabularFigures()])),
                            if (best != null && e.value == best) ...[
                              const SizedBox(width: 8),
                              Tag('PR', bg: cs.primaryContainer, fg: cs.onPrimaryContainer),
                            ],
                          ]),
                          trailing: Text('${fmtShortDate(e.date)}  ›',
                              style: TextStyle(color: cs.onSurfaceVariant)),
                          onTap: () => _editEntry(m, e),
                        ),
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.outlineVariant))),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Wrap(alignment: WrapAlignment.spaceBetween, children: [
                      TextButton.icon(
                        onPressed: () => _addEntry(m),
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter un résultat'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: cs.error),
                        onPressed: () => _deleteMovementFromButton(m),
                        child: const Text('Supprimer le mouvement'),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text('RECORDS PERSONNELS', style: eyebrow(context)),
          const Text('Mes records', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            store.movements.isEmpty
                ? 'Aucun record. Ajoute un mouvement avec le bouton en bas de l\'écran.'
                : 'Touche un mouvement pour voir son historique. Glisse une ligne vers la gauche pour la supprimer.',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          for (final m in store.movements) _card(m, cs),
        ],
      ),
      bottomNavigationBar: ActionBar(children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _addMovement,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un mouvement'),
          ),
        ),
      ]),
    );
  }
}

class EntryResult {
  final double? value;
  final DateTime date;
  final bool delete;
  const EntryResult({this.value, required this.date, this.delete = false});
}

/// Ajout ou modification d'un résultat. À l'ajout, le champ est pré-rempli
/// avec le record ; un résultat plus faible demande une seconde validation.
class EntrySheet extends StatefulWidget {
  final Movement movement;
  final RecordEntry? entry;
  const EntrySheet({super.key, required this.movement, this.entry});

  @override
  State<EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<EntrySheet> {
  late final TextEditingController _ctrl;
  late DateTime _date;
  bool _warn = false;
  String? _error;

  Movement get m => widget.movement;
  bool get _edit => widget.entry != null;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: inputText(widget.entry?.value ?? m.best, m.unit));
    _date = widget.entry?.date ?? dayOnly(DateTime.now());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<double> get _quick => switch (m.unit) {
        'kg' => const [-2.5, -1.0, 1.0, 2.5, 5.0],
        'reps' => const [-1.0, 1.0, 2.0, 5.0],
        _ => const [-5.0, -1.0, 1.0, 5.0],
      };

  void _clear() {
    if (_warn || _error != null) {
      setState(() {
        _warn = false;
        _error = null;
      });
    }
  }

  void _step(double d) {
    var v = parseValue(_ctrl.text, m.unit) ?? m.best ?? 0;
    v = ((v + d) * 2).round() / 2;
    if (m.unit != 'kg') v = v.roundToDouble();
    if (v < 0) v = 0;
    setState(() {
      _ctrl.text = inputText(v, m.unit);
      _warn = false;
      _error = null;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(now) ? now : _date,
      firstDate: DateTime(2010),
      lastDate: now,
    );
    if (d != null) setState(() => _date = dayOnly(d));
  }

  void _submit() {
    final v = parseValue(_ctrl.text, m.unit);
    if (v == null) {
      setState(() => _error = 'Entre une valeur, par exemple ${m.unit == 'sec' ? '4:32' : '100'}.');
      return;
    }
    final prev = m.best;
    if (!_edit && !_warn && prev != null && v != prev && !Movement.better(m.unit, v, prev)) {
      setState(() => _warn = true);
      return;
    }
    Navigator.pop(context, EntryResult(value: v, date: _date));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final best = m.bestEntry;
    final v = parseValue(_ctrl.text, m.unit);
    final label = switch (m.unit) {
      'kg' => 'Charge (kg)',
      'reps' => 'Répétitions',
      _ => 'Temps (m:ss)',
    };
    final error = _error;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: gap([
            Row(children: [
              Expanded(
                child: Text(_edit ? 'Modifier le résultat' : m.name,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ),
              IconButton(
                  tooltip: 'Fermer',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
            ]),
            if (_edit) Text(m.name, style: TextStyle(color: cs.onSurfaceVariant)),
            if (!_edit && best != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration:
                    BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Expanded(
                    child: Text('Record actuel · ${fmtShortDate(best.date)}',
                        style: TextStyle(color: cs.onPrimaryContainer)),
                  ),
                  Text(fmtValue(best.value, m.unit),
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800, color: cs.onPrimaryContainer)),
                ]),
              ),
            Text(!_edit && best != null ? '$label · pré-rempli avec ton record' : label,
                style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
            TextField(
              controller: _ctrl,
              autofocus: !_edit && best == null,
              textAlign: TextAlign.center,
              keyboardType: m.unit == 'sec'
                  ? TextInputType.datetime
                  : const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                  border: const OutlineInputBorder(), hintText: m.unit == 'sec' ? '4:32' : '0'),
              onChanged: (_) => _clear(),
              onSubmitted: (_) => _submit(),
            ),
            Row(
              children: gap([
                for (final d in _quick)
                  Expanded(
                    child: QuickButton(
                      label: '${d > 0 ? '+' : '−'}${fmtNum(d.abs())}${m.unit == 'sec' ? ' s' : ''}',
                      onPressed: () => _step(d),
                    ),
                  ),
              ], 6),
            ),
            if (m.unit == 'sec')
              Text('Pour un temps, plus bas est meilleur.',
                  style: TextStyle(color: cs.onSurfaceVariant)),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event),
              label: Text(fmtLongDate(_date)),
            ),
            if (_warn && v != null && best != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration:
                    BoxDecoration(color: adaptBg(context), borderRadius: BorderRadius.circular(12)),
                child: Text(
                  "${fmtValue(v, m.unit)}, c'est en dessous de ton record (${fmtValue(best.value, m.unit)}). "
                  "Tu peux l'enregistrer quand même, par exemple pour une reprise : "
                  'ton record restera ${fmtValue(best.value, m.unit)}.',
                  style: TextStyle(color: adaptColor(context), fontWeight: FontWeight.w600),
                ),
              ),
            if (error != null) Text(error, style: TextStyle(color: cs.error)),
            FilledButton(
              onPressed: _submit,
              child: Text(_warn
                  ? 'Enregistrer quand même'
                  : (_edit ? 'Enregistrer' : 'Enregistrer le résultat')),
            ),
            if (_edit)
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: cs.error),
                onPressed: () => Navigator.pop(context, EntryResult(date: _date, delete: true)),
                child: const Text('Supprimer ce résultat'),
              ),
          ]),
        ),
      ),
    );
  }
}
