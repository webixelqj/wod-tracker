import 'package:flutter/material.dart';

bool _dark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

/// Orange « marqueur » : adaptations de l'athlète.
Color adaptColor(BuildContext c) =>
    _dark(c) ? const Color(0xFFF0A356) : const Color(0xFFB85A06);
Color adaptBg(BuildContext c) =>
    _dark(c) ? const Color(0xFF3A2812) : const Color(0xFFFBE8D4);

/// Vert : réussi / progression.
Color goodColor(BuildContext c) =>
    _dark(c) ? const Color(0xFF55C486) : const Color(0xFF1D7F47);
Color goodBg(BuildContext c) =>
    _dark(c) ? const Color(0xFF16301F) : const Color(0xFFDCF2E5);

/// Thème : bleu « marqueur de tableau blanc », boutons d'au moins 48 px.
ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1C5BCC), brightness: brightness);
  const big = Size(64, 52);
  const label = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            minimumSize: big, shape: const StadiumBorder(), textStyle: label)),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            minimumSize: big, shape: const StadiumBorder(), textStyle: label)),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48))),
    iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48))),
  );
}
