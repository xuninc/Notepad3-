#!/usr/bin/env bash
# Generate the native iOS project so it can be opened in Xcode.
#
# Usage:
#   ./scripts/prebuild-ios.sh
#
# After running, open ios/*.xcworkspace in Xcode and build for "Any iOS Device".
# For unsigned/sideload builds, set Signing > Team to "None" and
# CODE_SIGNING_ALLOWED=NO in Build Settings.

set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Running expo prebuild for iOS"
EXPO_NO_TELEMETRY=1 pnpm exec expo prebuild --platform ios --clean

if command -v pod >/dev/null 2>&1; then
  echo "==> Installing CocoaPods"
  (cd ios && pod install --repo-update)
else
  echo "WARNING: 'pod' not found. Install CocoaPods, then run: cd ios && pod install"
fi

echo
echo "Done."
echo "Open the workspace in Xcode:"
echo "  open ios/*.xcworkspace"
