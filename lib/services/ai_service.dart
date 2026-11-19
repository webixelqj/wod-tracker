import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/movement_library.dart';
import '../models/wod.dart';

/// Erreur lisible par l'utilisateur.
class AiError implements Exception {
  final String message;
  const AiError(this.message);
  @override
  String toString() => message;
}

/// Envoie la photo du tableau à l'API Claude et récupère une séance structurée.
/// La photo n'est jamais conservée : seul le résultat est enregistré.
class AiService {
  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  /// Modèles essayés dans l'ordre (le premier disponible est utilisé).
  static const _models = ['claude-sonnet-5-5', 'claude-haiku-5-5', 'claude-opus-5-5'];
  final String apiKey;
  AiService(this.apiKey);

  static String get _prompt {
    final names = movementLibrary.map((m) => m.name).join(', ');
    return '''Tu lis la photo d'un tableau blanc de box de CrossFit.
Ignore les noms de personnes, logos et visages.
Réponds UNIQUEMENT avec un JSON valide, sans texte autour, au format :
{"title": "titre court",
 "blocks": [
  {"type": "echauffement|skill|force|wod|retourAuCalme",
   "format": "For Time|AMRAP|EMOM|Charge max|Autre",
   "minutes": 12,
   "cap": 8,
   "notes": "consignes utiles (schéma de reps...)",
   "exercises": [
     {"name": "nom du mouvement",
      "kind": "barbell|kettlebell|dumbbell|bodyweight|cardio|hold|benchmark",
      "cardioMode": "distance|calories|time",
      "lines": [{"reps": 21, "load": 43, "distance": null, "calories": null, "seconds": null}]}
   ]}]}
Règles :
- "minutes" = durée d'un AMRAP ou d'un EMOM, "cap" = time cap d'un For Time, sinon null.
- Si les reps ou la charge changent selon le round (ex. 21-15-9), une ligne par round.
- Charges en kg (convertis les lb si besoin : 95 lb = 43 kg).
- Utilise si possible ces noms exacts : $names.
- Si une valeur est illisible, mets null.''';
  }

  Future<Wod> parseWhiteboard(File image, DateTime date) async {
    final bytes = await image.readAsBytes();
    final mediaType =
        image.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    final body = <String, dynamic>{
      'max_tokens': 3000,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {'type': 'base64', 'media_type': mediaType, 'data': base64Encode(bytes)}
            },
            {'type': 'text', 'text': _prompt},
          ]
        }
      ]
    };

    http.Response? res;
    try {
      // Si un modèle n'est plus disponible (404), on essaie le suivant.
      for (final model in _models) {
        res = await http
            .post(
              Uri.parse(_endpoint),
              headers: {
                'x-api-key': apiKey,
                'anthropic-version': '2023-06-01',
                'content-type': 'application/json',
              },
              body: jsonEncode({...body, 'model': model}),
            )
            .timeout(const Duration(seconds: 90));
        if (res.statusCode != 404) break;
      }
    } on SocketException {
      throw const AiError('Pas de connexion internet. Réessaie quand tu as du réseau.');
    } on TimeoutException {
      throw const AiError("L'IA met trop de temps à répondre. Réessaie dans un instant.");
    }

    final r = res!;
    if (r.statusCode != 200) throw AiError(_friendly(r));
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    final text = (data['content'] as List)
        .where((c) => c['type'] == 'text')
        .map((c) => c['text'])
        .join();
    final s = text.indexOf('{'), e = text.lastIndexOf('}');
    if (s < 0 || e < 0) {
      throw const AiError("Le tableau n'a pas pu être lu. Reprends la photo de plus près, bien de face.");
    }
    return _toWod(jsonDecode(text.substring(s, e + 1)), date);
  }

  /// Traduit les erreurs de l'API en messages compréhensibles.
  static String _friendly(http.Response r) {
    var msg = '';
    try {
      msg = (jsonDecode(utf8.decode(r.bodyBytes))['error']?['message'] ?? '').toString();
    } catch (_) {}
    final low = msg.toLowerCase();
    if (r.statusCode == 401) {
      return 'Clé API refusée. Vérifie la clé copiée dans les Réglages.';
    }
    if (low.contains('credit') || low.contains('billing') || r.statusCode == 402) {
      return 'Crédit API épuisé. Ajoute du crédit dans la Claude Console (Billing).';
    }
    if (r.statusCode == 429 || r.statusCode == 529) {
      return "L'IA est très sollicitée. Réessaie dans une minute.";
    }
    if (r.statusCode == 404) {
      return "Aucun modèle d'IA disponible pour ta clé. Envoie ce message à Claude : $msg";
    }
    return 'Erreur ${r.statusCode} : $msg';
  }

  static double? _n(dynamic v) => v is num ? v.toDouble() : null;

  Wod _toWod(Map<String, dynamic> j, DateTime date) {
    final blocks = <Block>[];
    for (final b in (j['blocks'] as List? ?? [])) {
      final type = BlockType.values.asNameMap()[b['type']] ?? BlockType.wod;
      final exercises = <Exercise>[];
      for (final x in (b['exercises'] as List? ?? [])) {
        final lib = findInLibrary(x['name'] ?? '');
        final kind =
            lib?.kind ?? InputKind.values.asNameMap()[x['kind']] ?? InputKind.bodyweight;
        final lines = (x['lines'] as List? ?? [])
            .map((l) => SetLine(
                  reps: PV(planned: _n(l['reps'])),
                  load: PV(planned: _n(l['load'])),
                  distance: PV(planned: _n(l['distance'])),
                  calories: PV(planned: _n(l['calories'])),
                  seconds: PV(planned: _n(l['seconds'])),
                ))
            .toList();
        exercises.add(Exercise(
          name: lib?.name ?? (x['name'] ?? 'Exercice'),
          kind: kind,
          cardioMode:
              CardioMode.values.asNameMap()[x['cardioMode']] ?? CardioMode.distance,
          variesByRound: lines.length > 1,
          lines: lines.isEmpty ? null : lines,
        ));
      }
      final format = b['format'];
      blocks.add(Block(
        type: type,
        format: blockFormats.contains(format) ? format : 'Autre',
        minutes: (b['minutes'] as num?)?.toInt(),
        cap: (b['cap'] as num?)?.toInt(),
        notes: b['notes'] ?? '',
        exercises: exercises,
      ));
    }
    return Wod(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      date: date,
      title: j['title'] ?? '',
      blocks: blocks.isEmpty ? null : blocks,
      fromPhoto: true,
    );
  }
}
