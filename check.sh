#!/bin/sh
# Read-only checks. No --fix mode and no app changes.
set -eu
TV=${1:?Usage: sh check.sh TV_IP}
case "$TV" in *[!a-zA-Z0-9_.:-]*) exit 1 ;; esac
case "$TV" in *.*.*.*:*) ;; *.*.*.*) TV=$TV:5555 ;; esac
adb connect "$TV"
adb -s "$TV" shell getprop ro.product.model
adb -s "$TV" shell pm list packages dev.local.mitvhome
adb -s "$TV" shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME
adb -s "$TV" shell dumpsys activity activities | grep mResumedActivity || true
adb -s "$TV" shell settings get system intelligent_update
adb -s "$TV" shell pm list packages -d
