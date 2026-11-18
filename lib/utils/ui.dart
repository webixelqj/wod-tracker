import 'package:flutter/material.dart';

/// Insère un espace régulier entre des widgets (colonne ou ligne).
List<Widget> gap(List<Widget> children, [double size = 12]) {
  final out = <Widget>[];
  for (final c in children) {
    if (out.isNotEmpty) out.add(SizedBox(height: size, width: size));
    out.add(c);
  }
  return out;
}

TextStyle eyebrow(BuildContext context) => TextStyle(
      fontSize: 12,
      letterSpacing: 1.4,
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

void showInfo(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Message avec bouton « Annuler », fermé automatiquement après 5 secondes.
void showUndoSnack(BuildContext context, String message, VoidCallback onUndo) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  var closed = false;
  final ctrl = messenger.showSnackBar(SnackBar(
    content: Text(message),
    duration: const Duration(seconds: 5),
    action: SnackBarAction(label: 'Annuler', onPressed: onUndo),
  ));
  ctrl.closed.then((_) => closed = true);
  Future.delayed(const Duration(seconds: 5), () {
    if (!closed) ctrl.close();
  });
}
