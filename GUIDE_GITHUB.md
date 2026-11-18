# Obtenir l'APK Android avec GitHub — pas à pas

GitHub compile l'appli sur ses serveurs et te donne un fichier `.apk` à installer.
Rien à installer sur ton ordinateur. Durée totale : environ 20 minutes la première fois.

## Ce qu'il te faut
- Un compte GitHub (gratuit) : https://github.com/signup
- Ton téléphone Android
- Le fichier `wod_tracker_v0.3.zip`

---

## Étape 1 — Créer le dépôt
1. Connecte-toi sur https://github.com
2. En haut à droite : **+** → **New repository**.
3. **Repository name** : `wod-tracker`
4. Choisis **Private** (ton code reste privé).
5. Ne coche **rien** d'autre (pas de README, pas de .gitignore, pas de licence).
6. Clique **Create repository**.

## Étape 2 — Mettre le code dans le dépôt

### Option A — Claude l'envoie pour toi (le plus simple)
Donne à Claude le nom du dépôt, par exemple `ton-pseudo/wod-tracker`.
Claude envoie tout le projet ; tu devras peut-être autoriser l'accès au dépôt.
Passe ensuite à l'étape 3.

### Option B — À la main, depuis un ordinateur
1. Décompresse `wod_tracker_v0.3.zip`.
2. Sur la page du dépôt vide, clique **uploading an existing file**.
3. Ouvre le dossier `wod_tracker` décompressé et glisse **son contenu** (pas le dossier lui-même)
   dans la page : `lib`, `assets`, `test`, `tool`, `pubspec.yaml`, etc.
4. En bas, clique **Commit changes**.
5. Le dossier `.github` est **caché** par Mac et Windows, il faut donc le créer à la main :
   - **Add file** → **Create new file**
   - Nom du fichier : `.github/workflows/build-apk.yml` (tape-le tel quel, les `/` créent les dossiers)
   - Colle le contenu du fichier `build-apk.yml` (ouvre-le avec un éditeur de texte)
   - **Commit changes**
6. Fais de même si le fichier `.gitignore` n'apparaît pas (facultatif).

## Étape 3 — Lancer la compilation
1. Ouvre l'onglet **Actions** du dépôt.
2. Si GitHub le demande, clique **I understand my workflows, go ahead and enable them**.
3. La compilation **« Construire l'APK Android »** démarre toute seule après l'envoi du code.
   Sinon : clique dessus à gauche → **Run workflow** → **Run workflow**.
4. Attends 8 à 12 minutes. Un rond jaune tourne, puis une **coche verte** apparaît.
5. **Croix rouge ?** Clique sur le run, puis sur l'étape en rouge, copie les dernières lignes
   et envoie-les à Claude : il corrigera le code.

## Étape 4 — Télécharger l'APK sur ton téléphone
1. Sur ton téléphone, ouvre https://github.com et connecte-toi
   (le dépôt est privé, il faut être connecté).
2. Va sur ton dépôt → **Releases** (colonne de droite, ou en bas sur mobile).
3. Ouvre **WOD Tracker – build N** (le plus récent) → touche **app-release.apk**.

## Étape 5 — Installer
1. Ouvre le fichier téléchargé.
2. Android demande d'autoriser l'installation d'applis inconnues pour ton navigateur :
   **Paramètres** → active **Autoriser cette source** → reviens en arrière.
3. Touche **Installer**. Si Play Protect affiche un avertissement (appli non publiée sur le Play Store) :
   **Plus de détails** → **Installer quand même**.

## Étape 6 — Configurer l'appli
1. **Clé API Claude** : sur https://console.anthropic.com → **API Keys** → **Create Key**,
   ajoute un peu de crédit, puis colle la clé dans l'onglet **Réglages** de l'appli.
2. **Montre** : Health Connect est intégré à Android 14 et plus.
   Sur Android 13 ou moins, installe **Health Connect** depuis le Play Store.
   L'appli demandera ton accord la première fois que tu importes une séance.

## Mettre à jour l'appli
Chaque fois que le code change sur la branche `main`, GitHub construit un nouvel APK
(nouvelle « Release »). Télécharge-le et installe-le par-dessus : tes données sont conservées,
car toutes les versions sont signées avec la même clé (`tool/debug.keystore`).
