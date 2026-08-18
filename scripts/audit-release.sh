#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DERIVED_DATA_PATH="${1:-$PROJECT_ROOT/.build/ReleaseDerivedData}"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Release-iphonesimulator/ParkNudge.app"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Release app not found at $APP_PATH" >&2
  exit 1
fi

if find "$APP_PATH" -name '*.storekit' -print -quit | grep -q .; then
  echo "Release app contains a Debug StoreKit configuration." >&2
  exit 1
fi

if /usr/libexec/PlistBuddy -c 'Print :UIBackgroundModes' "$APP_PATH/Info.plist" >/dev/null 2>&1; then
  echo "Release app unexpectedly declares UIBackgroundModes." >&2
  exit 1
fi

if /usr/libexec/PlistBuddy -c 'Print :NSUserTrackingUsageDescription' "$APP_PATH/Info.plist" >/dev/null 2>&1; then
  echo "Release app unexpectedly declares tracking usage." >&2
  exit 1
fi

if rg -n -i 'Firebase|Amplitude|Mixpanel|FacebookSDK|AppsFlyer|Adjust SDK' "$PROJECT_ROOT/ParkNudge"; then
  echo "A forbidden analytics or advertising SDK marker was found." >&2
  exit 1
fi

if [[ -f "$PROJECT_ROOT/Package.resolved" ]] || find "$PROJECT_ROOT" -name Package.resolved -print -quit | grep -q .; then
  echo "A Swift package dependency lockfile was found; review dependency policy." >&2
  exit 1
fi

plutil -lint "$APP_PATH/PrivacyInfo.xcprivacy" >/dev/null
echo "Release audit passed: no StoreKit config, background modes, tracking prompt, third-party SDK marker, or package lockfile."
