"""Configure le dossier android/ généré par `flutter create` pour WOD Tracker.

- minSdk 26 (exigé par Health Connect)
- MainActivity -> FlutterFragmentActivity (exigé par le plugin health)
- Permissions : Internet (lecture du tableau par l'IA) et Health Connect
  (durée, calories, distance ; jamais la fréquence cardiaque)
- Déclarations Health Connect (rationale + Android 14)

Usage : python3 tool/patch_android.py [racine du projet]
"""
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
app = root / "android" / "app"
if not app.exists():
    sys.exit("android/app introuvable : lance d'abord `flutter create --platforms=android .`")

# 1. minSdk 26
for name in ("build.gradle.kts", "build.gradle"):
    f = app / name
    if f.exists():
        t = f.read_text()
        t = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 26", t)
        t = re.sub(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 26", t)
        f.write_text(t)
        print(f"minSdk 26 -> {f}")

# 2. MainActivity
for f in (app / "src" / "main").rglob("MainActivity.*"):
    t = f.read_text()
    t = t.replace("io.flutter.embedding.android.FlutterActivity",
                  "io.flutter.embedding.android.FlutterFragmentActivity")
    t = re.sub(r"\bFlutterActivity\(\)", "FlutterFragmentActivity()", t)
    t = re.sub(r"extends FlutterActivity\b", "extends FlutterFragmentActivity", t)
    f.write_text(t)
    print(f"FlutterFragmentActivity -> {f}")

# 3. Manifest
m = app / "src" / "main" / "AndroidManifest.xml"
t = m.read_text()
perms = [
    "android.permission.INTERNET",
    "android.permission.health.READ_EXERCISE",
    "android.permission.health.READ_ACTIVE_CALORIES_BURNED",
    "android.permission.health.READ_TOTAL_CALORIES_BURNED",
    "android.permission.health.READ_DISTANCE",
]
missing = "".join(f'    <uses-permission android:name="{p}"/>\n' for p in perms if p not in t)
t = re.sub(r"(<manifest[^>]*>\s*\n)", lambda mm: mm.group(1) + missing, t, count=1)

if "com.google.android.apps.healthdata" not in t:
    pkg = '        <package android:name="com.google.android.apps.healthdata"/>\n'
    if "<queries>" in t:
        t = t.replace("<queries>", "<queries>\n" + pkg.rstrip("\n"), 1)
    else:
        t = t.replace("</manifest>", "    <queries>\n" + pkg + "    </queries>\n</manifest>", 1)

if "ACTION_SHOW_PERMISSIONS_RATIONALE" not in t:
    t = re.sub(
        r'(<activity\s[^>]*android:name="\.MainActivity"[^>]*>)',
        r'\1\n            <intent-filter>\n'
        r'                <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE"/>\n'
        r'            </intent-filter>',
        t, count=1)

if "ViewPermissionUsageActivity" not in t:
    alias = """        <activity-alias
            android:name="ViewPermissionUsageActivity"
            android:exported="true"
            android:targetActivity=".MainActivity"
            android:permission="android.permission.START_VIEW_PERMISSION_USAGE">
            <intent-filter>
                <action android:name="android.intent.action.VIEW_PERMISSION_USAGE"/>
                <category android:name="android.intent.category.HEALTH_PERMISSIONS"/>
            </intent-filter>
        </activity-alias>
"""
    t = t.replace("</application>", alias + "    </application>", 1)

m.write_text(t)
print(f"Manifest configuré -> {m}")
