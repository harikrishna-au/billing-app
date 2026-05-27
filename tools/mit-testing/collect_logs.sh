#!/usr/bin/env bash
set -euo pipefail
OUTDIR="${1:-mit_live_logs}"
mkdir -p "$OUTDIR"

echo "Clearing device log buffer..."
adb logcat -c || true

echo "Starting live logcat to $OUTDIR/live_logcat.txt"
adb logcat -v threadtime > "$OUTDIR/live_logcat.txt"

# Use Ctrl-C to stop the log capture. The file will contain live logs for analysis.
