#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
TV=${1:?Usage: sh undo.sh TV_IP BACKUP_DIRECTORY}
BACKUP=${2:?Pass the backup directory printed during installation}
case "$TV" in *[!a-zA-Z0-9_.:-]*) exit 1 ;; esac
case "$TV" in *.*.*.*:*) ;; *.*.*.*) TV=$TV:5555 ;; esac
adb connect "$TV"
if [ -f "$BACKUP/stock-disabled-by-installer.txt" ]; then adb -s "$TV" shell pm enable --user 0 com.mitv.tvhome; fi
HOME_BEFORE=$(tr -d '\r\357\273\277' < "$BACKUP/home-before.txt" | tail -1)
printf '%s' "$HOME_BEFORE" | grep -Eq '^[A-Za-z0-9_.]+/[A-Za-z0-9_.$]+$' || { echo 'No previous Home component saved' >&2; exit 1; }
case "$HOME_BEFORE" in android/*) echo 'Select a default Home in TV settings' >&2; exit 1 ;; esac
adb -s "$TV" shell cmd package set-home-activity "$HOME_BEFORE"
adb -s "$TV" shell am start -n "$HOME_BEFORE"
echo 'Previous Home restored. No app uninstalled; no other app state changed.'
