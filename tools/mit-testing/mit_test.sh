#!/usr/bin/env bash
set -euo pipefail
APK="$1"
OUTDIR="${2:-mit_test_output}"
mkdir -p "$OUTDIR"

echo "Checking adb devices..."
adb devices

if [ -z "$APK" ]; then
  echo "Usage: $0 path/to/MIT.apk [output_dir]"
  exit 2
fi

if command -v aapt >/dev/null 2>&1; then
  echo "Dumping APK badging..."
  aapt dump badging "$APK" > "$OUTDIR/apk_badging.txt" || true
else
  echo "aapt not found; skipping apk badging dump (install Android build-tools)." >&2
fi

if command -v apksigner >/dev/null 2>&1; then
  echo "Verifying APK signature..."
  apksigner verify --print-certs "$APK" > "$OUTDIR/apk_signer.txt" || true
else
  echo "apksigner not found; skipping signature verification (install Android build-tools)." >&2
fi

echo "Attempting to uninstall existing package (if present)..."
adb uninstall com.mit || true

echo "Installing APK..."
adb install -r "$APK" 2>&1 | tee "$OUTDIR/install_output.txt" || true

echo "Listing installed packages matching com.mit..."
adb shell pm list packages | grep com.mit > "$OUTDIR/installed_packages.txt" || true

echo "Dumping package info (dumpsys)..."
adb shell dumpsys package com.mit > "$OUTDIR/dumpsys_package.txt" || true

echo "Attempting to launch the app (monkey)..."
adb shell monkey -p com.mit -c android.intent.category.LAUNCHER 1 > "$OUTDIR/monkey_output.txt" || true

echo "Capturing recent logcat (full dump)..."
adb logcat -d -v threadtime > "$OUTDIR/logcat.txt" || true

echo "Collecting additional diagnostics: getprop and df..."
adb shell getprop > "$OUTDIR/getprop.txt" || true
adb shell df -h > "$OUTDIR/df.txt" || true

echo "All outputs saved under $OUTDIR"

echo "If install failed, run 'adb logcat -c' then re-run this script while reproducing the failure to gather live logs."