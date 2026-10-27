#!/bin/sh
# Trial install: preserves the previous default Home and never disables apps.
set -eu
cd "$(dirname "$0")/.."
TV=${1:?Usage: sh install.sh TV_IP [APK_PATH]}
case "$TV" in *[!a-zA-Z0-9_.:-]*) echo 'Invalid TV address' >&2; exit 1 ;; esac
case "$TV" in *.*.*.*:*) ;; *.*.*.*) TV=$TV:5555 ;; esac
adb connect "$TV"
[ "$(adb -s "$TV" get-state)" = device ] || exit 1
MODEL=$(adb -s "$TV" shell getprop ro.product.model | tr -d '\r')
if [ "$MODEL" != MiTV-MFTP0 ] && [ "${ALLOW_UNTESTED_MODEL:-0}" != 1 ]; then
    echo "Untested model: $MODEL. Read docs/xiaomi/COMPATIBILITY.md; ALLOW_UNTESTED_MODEL=1 opts in." >&2
    exit 1
fi
mkdir -p backups out
BACKUP=$(mktemp -d backups/xiaomi-XXXXXXXX)
adb -s "$TV" shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME > "$BACKUP/home-before.txt"
adb -s "$TV" shell pm list packages -d > "$BACKUP/disabled-before.txt"
adb -s "$TV" shell getprop > "$BACKUP/properties-before.txt"
for scope in system secure global; do adb -s "$TV" shell settings list "$scope" > "$BACKUP/settings-$scope-before.txt"; done
APK=${2:-out/tvhome-xiaomi.apk}
if [ ! -f "$APK" ]; then
    RELEASE=https://github.com/tala2010/tv-detox/releases/download/xiaomi-v1.0.0
    curl -fsSL "$RELEASE/tvhome-xiaomi.apk" -o "$APK"
    curl -fsSL "$RELEASE/SHA256SUMS.txt" -o out/SHA256SUMS.txt
    EXPECTED=$(awk '$2=="tvhome-xiaomi.apk" {print $1}' out/SHA256SUMS.txt)
    if command -v sha256sum >/dev/null 2>&1; then ACTUAL=$(sha256sum "$APK" | awk '{print $1}')
    else ACTUAL=$(shasum -a 256 "$APK" | awk '{print $1}'); fi
    [ -n "$EXPECTED" ] && [ "$EXPECTED" = "$ACTUAL" ] || { echo 'APK SHA256 mismatch' >&2; exit 1; }
fi
adb -s "$TV" install -r "$APK"
HOME_BEFORE=$(tr -d '\r' < "$BACKUP/home-before.txt" | tail -1)
case "$HOME_BEFORE" in
    android/*) ;;
    */*) printf '%s' "$HOME_BEFORE" | grep -Eq '^[A-Za-z0-9_.]+/[A-Za-z0-9_.$]+$' && adb -s "$TV" shell cmd package set-home-activity "$HOME_BEFORE" ;;
esac
adb -s "$TV" shell am start -n dev.local.mitvhome/.MainActivity
printf 'Trial installed. Previous Home kept; no apps disabled. Backup: %s\n' "$BACKUP"
echo 'For default-Home opt-in and recovery, read README.md. Turn debugging off after testing.'
