#!/usr/bin/env python3
"""Applies Wateen's platform settings to the folders `flutter create` generates.

Safe to run repeatedly: every change is skipped when already present.
Run from the project root:  python3 tool/patch_platforms.py
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUNDLE_ID = "com.m3athrazaq.wateen"
NIGHT = "#0C0F17"
changed = []


def read(p):
    with open(os.path.join(ROOT, p), encoding="utf-8") as f:
        return f.read()


def write(p, s):
    full = os.path.join(ROOT, p)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    old = None
    if os.path.exists(full):
        with open(full, encoding="utf-8") as f:
            old = f.read()
    if old != s:
        with open(full, "w", encoding="utf-8") as f:
            f.write(s)
        changed.append(p)


def fail(msg):
    print("patch_platforms: " + msg, file=sys.stderr)
    sys.exit(1)


# --------------------------------------------------------------- Android

HEALTH_PERMISSIONS = [
    "READ_HEART_RATE",
    "READ_RESTING_HEART_RATE",
    "READ_HEART_RATE_VARIABILITY",
    "READ_RESPIRATORY_RATE",
    "READ_OXYGEN_SATURATION",
    "READ_SLEEP",
    "READ_STEPS",
    "READ_ACTIVE_CALORIES_BURNED",
    "READ_TOTAL_CALORIES_BURNED",
    "READ_DISTANCE",
    "READ_EXERCISE",
    "READ_SKIN_TEMPERATURE",
    "READ_HEALTH_DATA_HISTORY",
]


def patch_manifest():
    p = "android/app/src/main/AndroidManifest.xml"
    s = read(p)
    if "wateen:health" in s:
        return
    s = re.sub(r'android:label="[^"]*"', 'android:label="@string/app_name"', s, count=1)
    perms = "\n".join(
        f'    <uses-permission android:name="android.permission.health.{x}" />' for x in HEALTH_PERMISSIONS
    )
    m = re.search(r"<manifest[^>]*>", s)
    if not m:
        fail("no <manifest> tag")
    s = s[: m.end()] + "\n    <!-- wateen:health -->\n" + perms + "\n" + s[m.end():]

    rationale = (
        "            <intent-filter>\n"
        '                <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />\n'
        "            </intent-filter>\n"
        "        </activity>"
    )
    if "</activity>" not in s:
        fail("no </activity>")
    s = s.replace("        </activity>", rationale, 1) if "        </activity>" in s else s.replace("</activity>", rationale, 1)

    alias = (
        "\n        <activity-alias\n"
        '            android:name="ViewPermissionUsageActivity"\n'
        '            android:exported="true"\n'
        '            android:targetActivity=".MainActivity"\n'
        '            android:permission="android.permission.START_VIEW_PERMISSION_USAGE">\n'
        "            <intent-filter>\n"
        '                <action android:name="android.intent.action.VIEW_PERMISSION_USAGE" />\n'
        '                <category android:name="android.intent.category.HEALTH_PERMISSIONS" />\n'
        "            </intent-filter>\n"
        "        </activity-alias>"
    )
    idx = s.find("</activity>") + len("</activity>")
    s = s[:idx] + alias + s[idx:]

    queries = (
        '        <package android:name="com.google.android.apps.healthdata" />\n'
        "        <intent>\n"
        '            <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />\n'
        "        </intent>\n"
    )
    if "<queries>" in s:
        s = s.replace("<queries>", "<queries>\n" + queries, 1)
    else:
        s = s.replace("</manifest>", "    <queries>\n" + queries + "    </queries>\n</manifest>", 1)
    write(p, s)


def patch_gradle():
    kts = "android/app/build.gradle.kts"
    groovy = "android/app/build.gradle"
    if os.path.exists(os.path.join(ROOT, kts)):
        s = read(kts)
        if "wateen:signing" not in s:
            s = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 26", s)
            s = re.sub(r"compileSdk\s*=\s*flutter\.compileSdkVersion", "compileSdk = maxOf(flutter.compileSdkVersion, 36)", s)
            if "minSdk = 26" not in s:
                s = re.sub(r"minSdk\s*=\s*\d+", "minSdk = 26", s)
            header = "import java.io.FileInputStream\nimport java.util.Properties\n\n"
            s = header + s
            props = (
                "\n// wateen:signing\n"
                "val keystoreProperties = Properties()\n"
                'val keystorePropertiesFile = rootProject.file("key.properties")\n'
                "if (keystorePropertiesFile.exists()) {\n"
                "    keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n"
                "}\n"
            )
            m = re.search(r"plugins\s*\{[^}]*\}", s)
            if not m:
                fail("no plugins block in build.gradle.kts")
            s = s[: m.end()] + "\n" + props + s[m.end():]
            signing = (
                "    signingConfigs {\n"
                "        // Test builds: one fixed key so each new APK installs over the last.\n"
                '        create("sideload") {\n'
                '            storeFile = rootProject.file("../ci/sideload.keystore")\n'
                '            storeType = "pkcs12"\n'
                '            storePassword = "android"\n'
                '            keyAlias = "androiddebugkey"\n'
                '            keyPassword = "android"\n'
                "        }\n"
                '        create("release") {\n'
                "            if (keystorePropertiesFile.exists()) {\n"
                '                keyAlias = keystoreProperties["keyAlias"] as String\n'
                '                keyPassword = keystoreProperties["keyPassword"] as String\n'
                '                storeFile = file(keystoreProperties["storeFile"] as String)\n'
                '                storePassword = keystoreProperties["storePassword"] as String\n'
                "            }\n"
                "        }\n"
                "    }\n\n"
                "    buildTypes {"
            )
            if "    buildTypes {" not in s:
                fail("no buildTypes block")
            s = s.replace("    buildTypes {", signing, 1)
            s = re.sub(
                r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)',
                'signingConfig = if (keystorePropertiesFile.exists()) signingConfigs.getByName("release") '
                'else signingConfigs.getByName("sideload")',
                s,
                count=1,
            )
            write(kts, s)
    elif os.path.exists(os.path.join(ROOT, groovy)):
        s = read(groovy)
        s = re.sub(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 26", s)
        s = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 26", s)
        write(groovy, s)
    else:
        fail("no app build.gradle")


def patch_main_activity():
    files = glob.glob(os.path.join(ROOT, "android/app/src/main/kotlin/**/MainActivity.kt"), recursive=True)
    if not files:
        fail("MainActivity.kt not found")
    for f in files:
        rel = os.path.relpath(f, ROOT)
        s = read(rel)
        pkg = re.search(r"^package\s+([\w.]+)", s, re.M)
        body = (
            f"package {pkg.group(1) if pkg else BUNDLE_ID}\n\n"
            "import io.flutter.embedding.android.FlutterFragmentActivity\n\n"
            "// Health Connect's permission flow needs a ComponentActivity.\n"
            "class MainActivity : FlutterFragmentActivity()\n"
        )
        write(rel, body)


def patch_android_resources():
    res = "android/app/src/main/res"
    write(f"{res}/values/strings.xml",
          '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <string name="app_name">Wateen</string>\n</resources>\n')
    write(f"{res}/values-ar/strings.xml",
          '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <string name="app_name">وتين</string>\n</resources>\n')
    write(f"{res}/values/colors.xml",
          '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
          f'    <color name="ic_launcher_background">{NIGHT}</color>\n</resources>\n')
    write(f"{res}/mipmap-anydpi-v26/ic_launcher.xml",
          '<?xml version="1.0" encoding="utf-8"?>\n'
          '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
          '    <background android:drawable="@color/ic_launcher_background" />\n'
          '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
          '</adaptive-icon>\n')
    for name in ("drawable/launch_background.xml", "drawable-v21/launch_background.xml"):
        p = f"{res}/{name}"
        if os.path.exists(os.path.join(ROOT, p)):
            s = read(p)
            s = s.replace('@android:color/white', '@color/ic_launcher_background')
            s = s.replace('?android:colorBackground', '@color/ic_launcher_background')
            write(p, s)


def android_icons():
    try:
        from PIL import Image
    except ImportError:
        fail("Pillow is required: pip install pillow")
    src = Image.open(os.path.join(ROOT, "assets/icon/icon.png")).convert("RGB")
    fg = Image.open(os.path.join(ROOT, "assets/icon/icon_foreground.png")).convert("RGBA")
    dens = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    for d, k in dens.items():
        base = os.path.join(ROOT, f"android/app/src/main/res/mipmap-{d}")
        os.makedirs(base, exist_ok=True)
        src.resize((int(48 * k), int(48 * k)), Image.LANCZOS).save(os.path.join(base, "ic_launcher.png"))
        fg.resize((int(108 * k), int(108 * k)), Image.LANCZOS).save(os.path.join(base, "ic_launcher_foreground.png"))
    changed.append("android launcher icons")


# ------------------------------------------------------------------- iOS

HEALTH_TEXT = (
    "Wateen reads heart rate, HRV, sleep, breathing and workouts from Apple Health to calculate your "
    "recovery, strain and sleep. Your data stays on your iPhone. "
    "يقرأ وتين النبض وتقلّب النبض والنوم والتنفس والتمارين من Apple Health لحساب تعافيك وإجهادك ونومك. "
    "تبقى بياناتك على جهازك."
)


def patch_info_plist():
    p = "ios/Runner/Info.plist"
    s = read(p)
    if "NSHealthShareUsageDescription" in s:
        return
    extra = (
        "\t<key>NSHealthShareUsageDescription</key>\n"
        f"\t<string>{HEALTH_TEXT}</string>\n"
        "\t<key>NSHealthUpdateUsageDescription</key>\n"
        f"\t<string>{HEALTH_TEXT}</string>\n"
        "\t<key>ITSAppUsesNonExemptEncryption</key>\n"
        "\t<false/>\n"
        "\t<key>CFBundleLocalizations</key>\n"
        "\t<array>\n\t\t<string>ar</string>\n\t\t<string>en</string>\n\t</array>\n"
    )
    idx = s.rfind("</dict>")
    if idx < 0:
        fail("Info.plist has no </dict>")
    s = s[:idx] + extra + s[idx:]
    write(p, s)


def patch_entitlements():
    write(
        "ios/Runner/Runner.entitlements",
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
        '<plist version="1.0">\n<dict>\n'
        "\t<key>com.apple.developer.healthkit</key>\n\t<true/>\n"
        "\t<key>com.apple.developer.healthkit.access</key>\n\t<array/>\n"
        "</dict>\n</plist>\n",
    )


def patch_pbxproj():
    p = "ios/Runner.xcodeproj/project.pbxproj"
    s = read(p)
    s = re.sub(r"IPHONEOS_DEPLOYMENT_TARGET = \d+(\.\d+)?;", "IPHONEOS_DEPLOYMENT_TARGET = 15.0;", s)
    if "CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;" not in s:
        pattern = re.compile(r"^(\s*)PRODUCT_BUNDLE_IDENTIFIER = " + re.escape(BUNDLE_ID) + r";", re.M)
        count = len(pattern.findall(s))
        if count == 0:
            fail("Runner bundle identifier not found in project.pbxproj")
        s = pattern.sub(lambda m: f"{m.group(1)}CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\n{m.group(0)}", s)
    write(p, s)


def patch_podfile():
    p = "ios/Podfile"
    if not os.path.exists(os.path.join(ROOT, p)):
        return
    s = read(p)
    s2 = re.sub(r"^#?\s*platform :ios, '[\d.]+'", "platform :ios, '15.0'", s, flags=re.M)
    if "platform :ios" not in s2:
        s2 = "platform :ios, '15.0'\n" + s2
    write(p, s2)


def patch_launch_screen():
    p = "ios/Runner/Base.lproj/LaunchScreen.storyboard"
    if not os.path.exists(os.path.join(ROOT, p)):
        return
    s = read(p)
    night = '<color key="backgroundColor" red="0.047" green="0.059" blue="0.090" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>'
    s = re.sub(r'<color key="backgroundColor"[^>]*/>', night, s)
    write(p, s)


def ios_icons():
    from PIL import Image
    folder = os.path.join(ROOT, "ios/Runner/Assets.xcassets/AppIcon.appiconset")
    meta = os.path.join(folder, "Contents.json")
    if not os.path.exists(meta):
        fail("AppIcon Contents.json not found")
    with open(meta, encoding="utf-8") as f:
        data = json.load(f)
    src = Image.open(os.path.join(ROOT, "assets/icon/icon.png")).convert("RGB")
    for img in data.get("images", []):
        name = img.get("filename")
        size = img.get("size")
        if not name or not size:
            continue
        w = float(size.split("x")[0])
        scale = float(str(img.get("scale", "1x")).rstrip("x"))
        px = int(round(w * scale))
        src.resize((px, px), Image.LANCZOS).save(os.path.join(folder, name))
    changed.append("ios app icons")


def main():
    if not os.path.exists(os.path.join(ROOT, "android/app/src/main/AndroidManifest.xml")):
        fail("run `flutter create` first")
    patch_manifest()
    patch_gradle()
    patch_main_activity()
    patch_android_resources()
    android_icons()
    if os.path.exists(os.path.join(ROOT, "ios/Runner/Info.plist")):
        patch_info_plist()
        patch_entitlements()
        patch_pbxproj()
        patch_podfile()
        patch_launch_screen()
        ios_icons()
    print("patch_platforms: updated " + (", ".join(changed) if changed else "nothing"))


if __name__ == "__main__":
    main()
