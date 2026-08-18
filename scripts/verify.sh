#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DERIVED_DATA_PATH="$PROJECT_ROOT/.build/DerivedData"
RELEASE_DERIVED_DATA_PATH="$PROJECT_ROOT/.build/ReleaseDerivedData"
SIMULATOR_NAME="ParkNudge-Verify-$(date -u +%Y%m%dT%H%M%SZ)-$$"
SIMULATOR_ID=""

cleanup() {
  if [[ -n "$SIMULATOR_ID" ]]; then
    xcrun simctl shutdown "$SIMULATOR_ID" >/dev/null 2>&1 || true
    xcrun simctl delete "$SIMULATOR_ID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

cd "$PROJECT_ROOT"
"$SCRIPT_DIR/generate-project.sh"
python3 site/scripts/check_site.py
plutil -lint ParkNudge/Resources/PrivacyInfo.xcprivacy >/dev/null
python3 -m json.tool ParkNudge/Resources/ParkNudge.storekit >/dev/null

RUNTIME_ID="$(xcrun simctl list runtimes --json | python3 -c 'import json,sys; runtimes=[r for r in json.load(sys.stdin)["runtimes"] if r.get("isAvailable") and r["name"].startswith("iOS")]; print(sorted(runtimes,key=lambda r: tuple(int(x) for x in r["version"].split(".")))[-1]["identifier"])')"
DEVICE_TYPE_ID="$(xcrun simctl list devicetypes --json | python3 -c 'import json,sys; devices=[d for d in json.load(sys.stdin)["devicetypes"] if d["name"].startswith("iPhone")]; print(devices[0]["identifier"])')"
SIMULATOR_ID="$(xcrun simctl create "$SIMULATOR_NAME" "$DEVICE_TYPE_ID" "$RUNTIME_ID")"
xcrun simctl boot "$SIMULATOR_ID"
SIMULATOR_READY=0
for _ in {1..120}; do
  if xcrun simctl spawn "$SIMULATOR_ID" launchctl print system/com.apple.SpringBoard >/dev/null 2>&1; then
    SIMULATOR_READY=1
    break
  fi
  sleep 1
done

if [[ "$SIMULATOR_READY" -ne 1 ]]; then
  echo "Timed out waiting for transient simulator $SIMULATOR_ID to become ready." >&2
  exit 1
fi

xcodebuild \
  -project ParkNudge.xcodeproj \
  -scheme ParkNudge \
  -configuration Debug \
  -jobs 4 \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build-for-testing

xcodebuild \
  -project ParkNudge.xcodeproj \
  -scheme ParkNudge \
  -configuration Debug \
  -jobs 4 \
  -parallel-testing-enabled NO \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  test-without-building

xcodebuild \
  -project ParkNudge.xcodeproj \
  -scheme ParkNudge \
  -configuration Release \
  -jobs 4 \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$RELEASE_DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  build

"$SCRIPT_DIR/audit-release.sh" "$RELEASE_DERIVED_DATA_PATH"
echo "ParkNudge local verification passed on transient simulator $SIMULATOR_ID."
