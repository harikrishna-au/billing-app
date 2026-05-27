MIT App testing — ADB scripts

Overview

This folder contains helper scripts to verify APK installation, collect diagnostics, and gather logs needed to reproduce and investigate "App not installed" or runtime issues when integrating with Pine Labs UAT devices.

Files
- tools/mit-testing/mit_test.sh — installs the APK, dumps APK info, attempts launch, and captures logs and system diagnostics into an output folder.
- tools/mit-testing/collect_logs.sh — starts a live `adb logcat` capture to a file (Ctrl-C to stop).

Prerequisites
- Host with Android SDK platform-tools (`adb`) installed and on PATH.
- Optional: Android build-tools (`aapt`, `apksigner`) for deeper APK inspection.
- ADB authorized device (the Pine Labs terminal) connected via USB or accessible over network.

Quick usage

1) Make scripts executable:

```bash
chmod +x tools/mit-testing/*.sh
```

2) Run the automated test (replace path/to/MIT.apk):

```bash
./tools/mit-testing/mit_test.sh path/to/MIT.apk
```

This creates an output folder `mit_test_output` with:
- `install_output.txt` — output from `adb install`
- `apk_badging.txt` — `aapt` badging (if available)
- `apk_signer.txt` — `apksigner` verification (if available)
- `dumpsys_package.txt`, `installed_packages.txt`, `monkey_output.txt` — device state
- `logcat.txt` — recent logs
- `getprop.txt`, `df.txt` — device properties and storage info

3) For continuous live logs while reproducing the issue:

```bash
./tools/mit-testing/collect_logs.sh mit_live_logs
# reproduce the install or launch on the device, then Ctrl-C to stop
```

What to share back
- Zip the output folder (e.g. `mit_test_output`) and upload it or paste the key files: `install_output.txt`, `logcat.txt`, `apk_signer.txt` (if present), and `apk_badging.txt` (if present).
- If `adb install` fails, include `install_output.txt` and `logcat.txt` captured while reproducing.

Next steps I can take for you
- Inspect the APK (manifest, signatures) if you upload it.  
- Analyze the collected logs and propose fixes for installation or runtime errors.  
- Draft a short Reply-All email to Pine Labs asking them to enable sideloading or confirm MDM policies if the logs show policy blocks.
