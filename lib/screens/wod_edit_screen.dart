import 'dart:io';
import 'package:exif/exif.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/wod.dart';
import '../services/ai_service.dart';
import '../services/health_service.dart';
import '../services/storage_service.dart';
import '../utils/format.dart';
import '../utils/ui.dart';
import '../widgets/action_bar.dart';
import '../widgets/charge_helper.dart';
import '../widgets/controls.dart';
import '../widgets/exercise_card.dart';
import '../widgets/library_picker.dart';
import '../widgets/score_editor.dart';

/// Ce que l'écran de séance renvoie à la liste.
class EditResult {
  final List<PrEvent> prs;
  final Wod? deleted;
  final bool saved;
  const EditResult({this.prs = const [], this.deleted, this.saved = false});
}

class WodEditScreen extends StatefulWidget {
  final String? wodId;
  final ImageSource? startWithPhoto;
  const WodEditScreen({super.key, this.wodId, this.startWithPhoto});

  @override
  State<WodEditScreen> createState() => _WodEditScreenState();
}

class _WodEditScreenState extends State<WodEditScreen> {
  final store = StorageService.instance;
  late Wod wod;
  late bool isNew;
  final _title = TextEditingController();
  final _scoreKey = GlobalKey();
  bool _loading = false;
  bool _editPlanned = true; // true = « Tableau (prévu) », false = « Mon résultat »

  @override
  void initState() {
    super.initState();
    Wod? existing;
    for (final w in store.wods) {
      if (w.id == widget.wodId) existing = w;
    }
    isNew = existing == null;
    // On travaille sur une copie : rien n'est modifié tant qu'on n'enregistre pas.
    wod = existing?.copy() ??
        Wod(id: DateTime.now().microsecondsSinceEpoch.toString(), date: dayOnly(DateTime.now()));
    _title.text = wod.title;
    _editPlanned = isNew;
    final src = widget.startWithPhoto;
    if (src != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fromPhoto(src));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  /// Date de prise de vue (EXIF), utile pour les anciennes photos.
  Future<DateTime?> _photoDate(File f) async {
    try {
      final tags = await readExifFromBytes(await f.readAsBytes());
      final raw = tags['EXIF DateTimeOriginal']?.printable ?? tags['Image DateTime']?.printable;
      if (raw == null) return null;
      final p = raw.split(' ');
      return DateTime.parse('${p[0].replaceAll(':', '-')}T${p[1]}');
    } catch (_) {
      return null;
    }
  }

  Future<void> _fromPhoto(ImageSource source) async {
    final key = store.apiKey;
    if (key == null || key.isEmpty) {
      showInfo(context, 'Ajoute ta clé API Claude dans les Réglages.');
      return;
    }
    final img = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 80);
    if (img == null) return;
    final file = File(img.path);
    setState(() => _loading = true);
    try {
      final date = dayOnly(await _photoDate(file) ?? wod.date);
      final parsed = await AiService(key).parseWhiteboard(file, date);
      if (!mounted) return;
      setState(() {
        wod.blocks = parsed.blocks;
        wod.date = date;
        wod.fromPhoto = true;
        if (_title.text.trim().isEmpty) _title.text = parsed.title;
        _editPlanned = true;
      });
      showInfo(
          context,
          source == ImageSource.gallery
              ? 'Photo du ${fmtShortDate(date)} lue : la séance reprend sa date.'
              : 'Tableau lu : vérifie-le, puis passe à ton résultat.');
    } catch (e) {
      if (mounted) showInfo(context, 'Lecture impossible : $e');
    } finally {
      // On supprime la copie de l'appareil photo, jamais l'original de la galerie.
      if (source == ImageSource.camera) {
        try {
          await file.delete();
        } catch (_) {}
      }
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: wod.date.isAfter(now) ? now : wod.date,
      firstDate: DateTime(2015),
      lastDate: now,
    );
    if (d != null) setState(() => wod.date = dayOnly(d));
  }

  Future<void> _importWatch() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Montre connectée'),
        content: const Text(
            "L'appli va demander à lire la durée et les calories de tes entraînements "
            "dans Health Connect. Ta fréquence cardiaque n'est jamais lue."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Refuser')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continuer')),
        ],
      ),
    );
    if (go != true) return;
    try {
      final r = await HealthService().workoutOf(wod.date);
      if (!mounted) return;
      if (r == null) {
        showInfo(context, "Accès refusé : rien n'a été importé.");
      } else if (r.$2 == 0) {
        showInfo(context, 'Aucun entraînement trouvé ce jour-là.');
      } else {
        setState(() {
          wod.watchCalories = r.$1;
          wod.watchMinutes = r.$2;
        });
        showInfo(context, 'Durée et calories importées.');
      }
    } catch (e) {
      if (mounted) showInfo(context, 'Import impossible : $e');
    }
  }

  Future<void> _addBlock() async {
    final t = await showModalBottomSheet<BlockType>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final b in BlockType.values)
            ListTile(
              title: Text(b.label),
              subtitle: Text(b.scored ? 'avec score' : 'sans score'),
              onTap: () => Navigator.pop(ctx, b),
            ),
        ]),
      ),
    );
    if (t != null) {
      setState(() => wod.blocks
          .add(Block(type: t, format: t == BlockType.force ? 'Charge max' : 'For Time')));
    }
  }

  Future<void> _addExercise(Block b) async {
    final item = await LibraryPicker.show(context);
    if (item != null) {
      setState(() => b.exercises.add(Exercise(name: item.name, kind: item.kind)));
    }
  }

  void _asPlanned() {
    FocusScope.of(context).unfocus();
    setState(() => wod.resetAdaptations());
    final reduce = MediaQuery.of(context).disableAnimations;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _scoreKey.currentContext;
      if (c != null) {
        Scrollable.ensureVisible(c,
            alignment: 0.2,
            duration: reduce ? Duration.zero : const Duration(milliseconds: 350));
      }
    });
    showInfo(context, 'Tout est validé comme prévu. Il reste ton score.');
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    wod.title = _title.text.trim();
    await store.saveWod(wod);
    final prs = await store.updateRecordsFrom(wod);
    if (mounted) Navigator.pop(context, EditResult(prs: prs, saved: true));
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la séance ?'),
        content: Text('« ${wod.displayTitle} » sera retirée de ton carnet. Tes records ne changent pas.'),
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
    if (ok != true || !mounted) return;
    if (isNew) {
      Navigator.pop(context);
      return;
    }
    Wod? original;
    for (final w in store.wods) {
      if (w.id == wod.id) original = w;
    }
    await store.deleteWod(wod.id);
    if (mounted) Navigator.pop(context, EditResult(deleted: original));
  }

  Widget _block(Block b, int i, bool scoreAnchor) {
    final cs = Theme.of(context).colorScheme;
    final plan = _editPlanned;
    final scored = b.type.scored;
    final info = [
      if (b.format == 'For Time' && b.cap != null) 'Time cap ${b.cap} min',
      if ((b.format == 'AMRAP' || b.format == 'EMOM') && b.minutes != null) '${b.minutes} min',
      if (b.notes.trim().isNotEmpty) b.notes.trim(),
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: gap([
          Row(children: [
            Expanded(
              child: Text(b.type.label.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.4, fontSize: 16)),
            ),
            if (scored)
              DropdownButton<String>(
                value: blockFormats.contains(b.format) ? b.format : 'Autre',
                items: [for (final f in blockFormats) DropdownMenuItem(value: f, child: Text(f))],
                onChanged: plan
                    ? (v) => setState(() {
                          b.format = v ?? b.format;
                          b.res = {};
                        })
                    : null,
              ),
            if (plan)
              IconButton(
                tooltip: 'Supprimer le bloc',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => setState(() => wod.blocks.removeAt(i)),
              ),
          ]),
          if (plan)
            TextFormField(
              key: ObjectKey(b),
              initialValue: b.notes,
              decoration: const InputDecoration(
                  hintText: 'Consignes : rounds, schéma de reps…', border: OutlineInputBorder()),
              onChanged: (v) => b.notes = v,
            ),
          if (plan && scored && b.format == 'For Time')
            StepperField(
              label: 'Time cap (min)',
              value: b.cap?.toDouble(),
              max: 120,
              onChanged: (v) => setState(() => b.cap = v?.round()),
            ),
          if (plan && scored && (b.format == 'AMRAP' || b.format == 'EMOM'))
            StepperField(
              label: 'Durée (min)',
              value: b.minutes?.toDouble(),
              max: 120,
              onChanged: (v) => setState(() => b.minutes = v?.round()),
            ),
          if (!plan && info.isNotEmpty) Text(info, style: TextStyle(color: cs.onSurfaceVariant)),
          for (var e = 0; e < b.exercises.length; e++)
            ExerciseCard(
              key: ObjectKey(b.exercises[e]),
              ex: b.exercises[e],
              editPlanned: plan,
              wodId: wod.id,
              onChanged: _refresh,
              onDelete: () => setState(() => b.exercises.removeAt(e)),
            ),
          if (plan)
            OutlinedButton.icon(
              onPressed: () => _addExercise(b),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un exercice'),
            ),
          if (!plan && b.exercises.isEmpty)
            Text('Aucun exercice. Passe sur « Tableau » pour en ajouter.',
                style: TextStyle(color: cs.onSurfaceVariant)),
          if (!plan && scored)
            ScoreEditor(key: scoreAnchor ? _scoreKey : null, block: b, onChanged: _refresh),
        ]),
      ),
    );
  }

  Widget _watchTile(ColorScheme cs) => Material(
        color: cs.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant)),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: const Icon(Icons.watch_outlined),
          title: Text(wod.watchMinutes == null
              ? 'Importer depuis ma montre'
              : '${wod.watchMinutes} min · ${wod.watchCalories} kcal'),
          subtitle: Text(wod.watchMinutes == null
              ? 'Durée et calories, via Health Connect'
              : 'Importé depuis Health Connect'),
          onTap: wod.watchMinutes == null ? _importWatch : null,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    var firstScored = -1;
    if (!_editPlanned) {
      for (var i = 0; i < wod.blocks.length; i++) {
        if (wod.blocks[i].type.scored) {
          firstScored = i;
          break;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Séance'),
        actions: [
          IconButton(
              tooltip: 'Supprimer la séance',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Lecture du tableau…'),
              ]),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                TextField(
                  controller: _title,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(hintText: 'Titre (ex. Fran)'),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.event),
                      label: Text(fmtLongDate(wod.date), overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  if (wod.fromPhoto) ...[
                    const SizedBox(width: 8),
                    Tag("Lu par l'IA", bg: cs.surfaceContainerHighest, fg: cs.onSurfaceVariant),
                  ],
                ]),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                        value: true,
                        icon: Icon(Icons.dashboard_outlined),
                        label: Text('Tableau (prévu)')),
                    ButtonSegment(
                        value: false, icon: Icon(Icons.person_outline), label: Text('Mon résultat')),
                  ],
                  selected: {_editPlanned},
                  onSelectionChanged: (s) => setState(() => _editPlanned = s.first),
                ),
                const SizedBox(height: 8),
                Text(
                  _editPlanned
                      ? "Ce qui est écrit au tableau. Les champs s'adaptent à chaque mouvement."
                      : 'Tout est pré-rempli avec le prévu. Change une valeur seulement si tu as adapté : elle passe en orange.',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < wod.blocks.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _block(wod.blocks[i], i, i == firstScored),
                  ),
                if (_editPlanned)
                  OutlinedButton.icon(
                    onPressed: _addBlock,
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un bloc'),
                  ),
                const SizedBox(height: 12),
                const ChargeHelper(),
                const SizedBox(height: 12),
                _watchTile(cs),
              ],
            ),
      bottomNavigationBar: _loading
          ? null
          : ActionBar(
              children: _editPlanned
                  ? [
                      IconButton.outlined(
                        tooltip: 'Photographier le tableau',
                        style: squareButtonStyle,
                        icon: const Icon(Icons.photo_camera_outlined),
                        onPressed: () => _fromPhoto(ImageSource.camera),
                      ),
                      IconButton.outlined(
                        tooltip: 'Choisir une photo dans la galerie',
                        style: squareButtonStyle,
                        icon: const Icon(Icons.photo_library_outlined),
                        onPressed: () => _fromPhoto(ImageSource.gallery),
                      ),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => setState(() => _editPlanned = false),
                          child: const Text('Passer à mon résultat'),
                        ),
                      ),
                    ]
                  : [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _asPlanned,
                          icon: const Icon(Icons.check),
                          label: const Text('Fait comme prévu', maxLines: 1),
                        ),
                      ),
                      Expanded(
                        child: FilledButton(onPressed: _save, child: const Text('Enregistrer')),
                      ),
                    ],
            ),
    );
  }
}
