#!/usr/bin/env bash
# Generate the native Android project so it can be opened in Android Studio.
#
# Usage:
#   ./scripts/prebuild-android.sh
#
# After running, open android/ in Android Studio and run on emulator or device.
# For a sideload-able APK headlessly:
#   (cd android && ./gradlew assembleDebug)

set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Running expo prebuild for Android"
EXPO_NO_TELEMETRY=1 pnpm exec expo prebuild --platform android --clean

echo
echo "Done."
echo "Open the project in Android Studio:"
echo "  studio android"
echo "Or build a debug APK headlessly:"
echo "  (cd android && ./gradlew assembleDebug)"
