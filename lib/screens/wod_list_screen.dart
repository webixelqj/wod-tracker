import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/wod.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/ui.dart';
import '../widgets/action_bar.dart';
import '../widgets/controls.dart';
import '../widgets/pr_celebration.dart';
import 'wod_edit_screen.dart';

/// Accueil : la séance du jour en avant, l'historique en dessous,
/// et « Photographier le tableau » à portée du pouce.
class WodListScreen extends StatefulWidget {
  const WodListScreen({super.key});

  @override
  State<WodListScreen> createState() => _WodListScreenState();
}

class _WodListScreenState extends State<WodListScreen> {
  final store = StorageService.instance;

  Future<void> _open({String? id, ImageSource? photo}) async {
    final res = await Navigator.push<EditResult>(
      context,
      MaterialPageRoute(builder: (_) => WodEditScreen(wodId: id, startWithPhoto: photo)),
    );
    if (!mounted) return;
    setState(() {});
    if (res == null) return;
    final deleted = res.deleted;
    if (deleted != null) {
      showUndoSnack(context, 'Séance supprimée', () async {
        await store.saveWod(deleted);
        if (mounted) setState(() {});
      });
    } else if (res.prs.isNotEmpty) {
      await showPrCelebration(context, res.prs);
    } else if (res.saved) {
      showInfo(context, 'Séance enregistrée');
    }
  }

  Widget _todayCard(Wod? w, ColorScheme cs) {
    final on = cs.onPrimary;
    final m = w?.mainBlock;
    final score = m?.scoreText;
    final id = w?.id;
    return Material(
      color: cs.primary,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: id == null ? null : () => _open(id: id),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("AUJOURD'HUI · ${fmtShortDate(DateTime.now()).toUpperCase()}",
                style: TextStyle(
                    color: on.withAlpha(200),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
            const SizedBox(height: 6),
            Text(w == null ? 'Pas encore de séance' : w.displayTitle,
                style: TextStyle(color: on, fontSize: 30, fontWeight: FontWeight.w800, height: 1.1)),
            const SizedBox(height: 4),
            Text(
              w == null
                  ? 'Photographie le tableau en arrivant à la box : la séance se remplit toute seule.'
                  : '${w.blockSummary}${m != null ? ' · ${m.format}' : ''}',
              style: TextStyle(color: on.withAlpha(220)),
            ),
            if (w != null) ...[
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: Text(score ?? '',
                      style: TextStyle(color: on, fontSize: 36, fontWeight: FontWeight.w800)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(color: on, borderRadius: BorderRadius.circular(999)),
                  child: Text(score == null ? 'Saisir mon résultat' : 'Voir ma séance',
                      style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
                ),
              ]),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _tile(Wod w, ColorScheme cs) {
    final m = w.mainBlock;
    final score = m?.scoreText;
    final ad = w.adaptationCount;
    return Material(
      color: cs.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(id: w.id),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(w.displayTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('${fmtShortDate(w.date)} · ${w.blockSummary}',
                    style: TextStyle(color: cs.onSurfaceVariant)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  if (m != null && score != null)
                    Tag(m.level,
                        bg: m.level == 'RX' ? cs.primaryContainer : cs.surfaceContainerHighest,
                        fg: m.level == 'RX' ? cs.onPrimaryContainer : cs.onSurfaceVariant),
                  if (m != null) Tag(m.format, bg: cs.surfaceContainerHighest, fg: cs.onSurfaceVariant),
                  if (score == null)
                    Tag('Résultat à saisir', bg: adaptBg(context), fg: adaptColor(context)),
                  if (ad > 0)
                    Tag('$ad adaptation${ad > 1 ? 's' : ''}',
                        bg: adaptBg(context), fg: adaptColor(context)),
                ]),
              ]),
            ),
            const SizedBox(width: 12),
            Text(score ?? '—',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()])),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    Wod? today;
    for (final w in store.wods) {
      if (sameDay(w.date, now)) {
        today = w;
        break;
      }
    }
    final history = [
      for (final w in store.wods)
        if (!identical(w, today)) w
    ];

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text("CARNET D'ENTRAÎNEMENT", style: eyebrow(context)),
          const Text('Mes séances', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          _todayCard(today, cs),
          if (history.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text('HISTORIQUE', style: eyebrow(context)),
            const SizedBox(height: 8),
            for (final w in history)
              Padding(padding: const EdgeInsets.only(bottom: 10), child: _tile(w, cs)),
          ],
        ],
      ),
      bottomNavigationBar: ActionBar(children: [
        IconButton.outlined(
          tooltip: 'Saisir une séance à la main',
          style: squareButtonStyle,
          icon: const Icon(Icons.edit_note),
          onPressed: () => _open(),
        ),
        IconButton.outlined(
          tooltip: 'Choisir une photo dans la galerie',
          style: squareButtonStyle,
          icon: const Icon(Icons.photo_library_outlined),
          onPressed: () => _open(photo: ImageSource.gallery),
        ),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _open(photo: ImageSource.camera),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Photographier le tableau', maxLines: 1),
          ),
        ),
      ]),
    );
  }
}
