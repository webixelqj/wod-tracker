# WOD Tracker (MVP personnel) — v0.3

Carnet de WOD et de records. Stockage 100 % local, lecture du tableau blanc par l'IA Claude.

## Fonctionnalités
- **Accueil** : la séance du jour en avant, l'historique en dessous, « Photographier le tableau » en bas de l'écran.
- **Séance par blocs** (échauffement, skill, force, WOD, retour au calme), avec un mode « Tableau (prévu) » et un mode « Mon résultat ».
- **Champs adaptés au mouvement** : barre (gros chiffre, ±1 / ±2,5 / ±5 kg, curseur 0–300 kg, « Dernière fois : … »), kettlebells 4–32 kg, haltères 2,5–50 kg, cardio (distance, calories, durée), maintien.
- **Adaptations** : toute valeur différente du prévu passe en orange, le prévu reste barré à côté.
- **« Fait comme prévu »** : valide tout d'un geste, il ne reste que le score.
- **Score selon le format** : For Time (min:s ou time cap + reps), AMRAP (rounds + reps), EMOM (une case par minute), Charge max (kg).
- **Records** : ajout pré-rempli avec le record, alerte si plus faible (reprise), modification, suppression par glissement avec « Annuler », écran de félicitations avec vibration.
- **Photo** depuis l'appareil ou la galerie (la séance reprend la date de la photo).
- **Montre** via Health Connect : durée et calories uniquement.

## Compiler l'APK sans rien installer
Voir **GUIDE_GITHUB.md** : GitHub construit l'APK et te donne un lien de téléchargement.

## Compiler sur ton ordinateur (option)
1. Installer Flutter et Android Studio.
2. `flutter create --org be.wodtracker --project-name wod_tracker --platforms=android .`
3. `python3 tool/patch_android.py .`
4. `flutter pub get` puis `dart run flutter_launcher_icons`
5. `flutter run` (téléphone branché) ou `flutter build apk --release`

## Clé API
À créer sur console.anthropic.com, puis à saisir dans l'onglet Réglages.
Usage personnel uniquement : pour diffuser l'appli, la clé devra passer par un serveur.
Le modèle se règle dans `lib/services/ai_service.dart`.

## Signature
`tool/debug.keystore` est une clé de test (mot de passe `android`) qui garde la même signature
d'une version à l'autre. Avant une publication sur le Play Store, il faudra une vraie clé privée.
