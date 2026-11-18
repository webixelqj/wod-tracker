import 'package:flutter/material.dart';
import '../utils/ui.dart';

/// Style des boutons carrés de la barre d'actions (52 × 52).
final squareButtonStyle = IconButton.styleFrom(
  minimumSize: const Size(52, 52),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
);

/// Barre d'actions en bas de l'écran, à portée du pouce.
class ActionBar extends StatelessWidget {
  final List<Widget> children;
  const ActionBar({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(children: gap(children, 10)),
        ),
      ),
    );
  }
}
